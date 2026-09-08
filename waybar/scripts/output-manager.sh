#!/usr/bin/env bash

# Keep one Waybar instance on the preferred external output and maintain valid
# output coordinates when the external monitor is connected or disconnected.
set -u

readonly external_output='HDMI-A-1'
readonly internal_output='eDP-1'
readonly config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
readonly runtime_dir=${XDG_RUNTIME_DIR:-"/tmp/waybar-$UID"}
readonly source_config="$config_home/waybar/config"
readonly style="$config_home/waybar/style.css"
readonly runtime_config="$runtime_dir/waybar-output.json"
readonly manager_pid_file="$runtime_dir/waybar-output-manager.pid"

bar_pid=''
events_pid=''

mkdir -p -- "$runtime_dir"
if [[ -r $manager_pid_file ]]; then
  previous_pid=$(<"$manager_pid_file")
  if [[ $previous_pid =~ ^[0-9]+$ ]] && (( previous_pid != $$ )) &&
     kill -0 "$previous_pid" 2>/dev/null &&
     ps -p "$previous_pid" -o args= | grep -Fq 'output-manager.sh'; then
    kill "$previous_pid" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "$previous_pid" 2>/dev/null || break
      sleep 0.05
    done
  fi
fi
printf '%s\n' "$$" > "$manager_pid_file"

cleanup() {
  [[ -n $bar_pid ]] && kill "$bar_pid" 2>/dev/null || true
  [[ -n $events_pid ]] && kill "$events_pid" 2>/dev/null || true
  [[ -n $bar_pid ]] && wait "$bar_pid" 2>/dev/null || true
  [[ -n $events_pid ]] && wait "$events_pid" 2>/dev/null || true
  if [[ -r $manager_pid_file ]] && [[ $(<"$manager_pid_file") == "$$" ]]; then
    rm -f -- "$manager_pid_file"
  fi
}
trap cleanup EXIT
trap 'exit 0' INT TERM

for command in jq swaymsg waybar; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Missing command: %s\n' "$command" >&2
    exit 1
  }
done

arrange_outputs() {
  local outputs external_active desired_x desired_y current_position

  outputs=$(swaymsg -r -t get_outputs)
  external_active=$(jq -r --arg output "$external_output" \
    'any(.[]; .active and .name == $output)' <<< "$outputs")

  if [[ $external_active == true ]]; then
    desired_x=192
    desired_y=1080
  else
    # Keep an active output at the global origin. Flameshot cannot determine
    # capture geometry reliably when a lone output retains an old offset.
    desired_x=0
    desired_y=0
  fi

  current_position=$(jq -r --arg output "$internal_output" '
    [.[] | select(.active and .name == $output) | .rect.x, .rect.y] | @tsv
  ' <<< "$outputs")
  [[ -n $current_position ]] || return 0
  [[ $current_position == "$desired_x"$'\t'"$desired_y" ]] ||
    swaymsg -q output "$internal_output" position "$desired_x" "$desired_y"
}

select_output() {
  swaymsg -r -t get_outputs | jq -r \
    --arg external "$external_output" --arg internal "$internal_output" '
      ([.[] | select(.active and .name == $external) | .name][0]) //
      ([.[] | select(.active and .name == $internal) | .name][0]) //
      ([.[] | select(.active) | .name][0]) // empty
    '
}

stop_bar() {
  if [[ -n $bar_pid ]]; then
    kill "$bar_pid" 2>/dev/null || true
    wait "$bar_pid" 2>/dev/null || true
    bar_pid=''
  fi
}

start_bar() {
  local output=$1
  local temporary_config="$runtime_config.tmp"

  mkdir -p -- "$runtime_dir"
  jq --arg output "$output" '.output = [$output]' \
    "$source_config" > "$temporary_config"
  mv -- "$temporary_config" "$runtime_config"
  waybar --config "$runtime_config" --style "$style" &
  bar_pid=$!
}

refresh_bar() {
  local selected_output

  selected_output=$(select_output)
  [[ $selected_output == "${current_output:-}" ]] &&
    [[ -n $bar_pid ]] && kill -0 "$bar_pid" 2>/dev/null && return 0

  stop_bar
  current_output=$selected_output
  [[ -n $current_output ]] && start_bar "$current_output"
}

# Remove the unmanaged instance used by older revisions of this configuration.
if [[ ${WAYBAR_MANAGER_SKIP_LEGACY_CLEANUP:-0} != 1 ]]; then
  pkill -x waybar 2>/dev/null || true
fi
current_output=''
arrange_outputs
refresh_bar

coproc OUTPUT_EVENTS { exec swaymsg -m -r -t subscribe '["output"]'; }
events_pid=$OUTPUT_EVENTS_PID
events_fd=${OUTPUT_EVENTS[0]}

while IFS= read -r -u "$events_fd" event; do
  sleep 0.2
  arrange_outputs
  refresh_bar
done
