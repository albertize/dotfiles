#!/usr/bin/env bash

# Keep one Waybar instance on the preferred external output and maintain valid
# output coordinates when the external monitor is connected or disconnected.
set -u

# Preferred external connectors, in priority order.
readonly external_outputs=('HDMI-A-1' 'DP-3')
readonly internal_output='eDP-1'
readonly laptop_workspace=''
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

external_outputs_json=$(printf '%s\n' "${external_outputs[@]}" | jq -R . | jq -s .)
readonly external_outputs_json

# Print the first active external output, or nothing when none is connected.
active_external_output() {
  jq -r --argjson candidates "$external_outputs_json" '
    [$candidates[] as $name | .[] | select(.active and .name == $name) | .name][0]
      // empty
  ' <<< "$1"
}

arrange_outputs() {
  local outputs external desired_x desired_y current_position

  outputs=$(swaymsg -r -t get_outputs)
  external=$(active_external_output "$outputs")

  if [[ -n $external ]]; then
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

arrange_workspaces() {
  local outputs workspaces external internal_active laptop_output
  local internal_visible focused_workspace restore_workspace workspace_number

  outputs=$(swaymsg -r -t get_outputs)
  external=$(active_external_output "$outputs")
  internal_active=$(jq -r --arg output "$internal_output" \
    'any(.[]; .active and .name == $output)' <<< "$outputs")
  [[ -n $external && $internal_active == true ]] || return 0

  workspaces=$(swaymsg -r -t get_workspaces)
  focused_workspace=$(jq -r '[.[] | select(.focused)][0].name // empty' \
    <<< "$workspaces")
  restore_workspace=$focused_workspace
  laptop_output=$(jq -r --arg workspace "$laptop_workspace" \
    '[.[] | select(.name == $workspace)][0].output // empty' <<< "$workspaces")

  if [[ -z $laptop_output ]]; then
    # Reuse the workspace Sway placed on the panel instead of leaving behind
    # an arbitrary dynamically numbered workspace.
    internal_visible=$(jq -r --arg output "$internal_output" \
      '[.[] | select(.output == $output and .visible)][0].name // empty' \
      <<< "$workspaces")
    [[ -n $internal_visible ]] || return 0
    swaymsg -q rename workspace "$internal_visible" to "$laptop_workspace"
    [[ $restore_workspace == "$internal_visible" ]] && \
      restore_workspace=$laptop_workspace
  elif [[ $laptop_output != "$internal_output" ]]; then
    swaymsg -q workspace "$laptop_workspace"
    swaymsg -q move workspace to output "$internal_output"
  fi

  # Existing numbered workspaces may have been created while only the laptop
  # panel was active. Move them to the external output after hot-plugging it.
  workspaces=$(swaymsg -r -t get_workspaces)
  for workspace_number in {1..9}; do
    if jq -e --arg workspace "$workspace_number" --arg output "$external" \
      'any(.[]; .name == $workspace and .output != $output)' \
      <<< "$workspaces" >/dev/null; then
      swaymsg -q workspace number "$workspace_number"
      swaymsg -q move workspace to output "$external"
    fi
  done

  [[ -n $restore_workspace ]] && swaymsg -q workspace "$restore_workspace"
}

select_output() {
  local outputs external

  outputs=$(swaymsg -r -t get_outputs)
  external=$(active_external_output "$outputs")
  if [[ -n $external ]]; then
    printf '%s\n' "$external"
    return 0
  fi

  jq -r --arg internal "$internal_output" '
    ([.[] | select(.active and .name == $internal) | .name][0]) //
    ([.[] | select(.active) | .name][0]) // empty
  ' <<< "$outputs"
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
arrange_workspaces
refresh_bar

coproc OUTPUT_EVENTS { exec swaymsg -m -r -t subscribe '["output"]'; }
events_pid=$OUTPUT_EVENTS_PID
events_fd=${OUTPUT_EVENTS[0]}

while IFS= read -r -u "$events_fd" event; do
  sleep 0.2
  arrange_outputs
  arrange_workspaces
  refresh_bar
done
