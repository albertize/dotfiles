#!/usr/bin/env bash

# Refresh the Waybar Bluetooth module on BlueZ events and connection markers.
set -u

runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$UID}
[[ -d $runtime_dir && -w $runtime_dir ]] || runtime_dir=${TMPDIR:-/tmp}
readonly status_script="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/scripts/bluetooth-status.sh"
readonly connection_marker="$runtime_dir/waybar-bluetooth-connecting-$UID"
readonly watcher_pid_file="$runtime_dir/waybar-bluetooth-watcher-$UID.pid"

monitor_pid=''
refresh_requested=false
last_connection_state=false

cleanup() {
  [[ -n $monitor_pid ]] && kill "$monitor_pid" 2>/dev/null || true
  [[ -n $monitor_pid ]] && wait "$monitor_pid" 2>/dev/null || true
  if [[ -r $watcher_pid_file ]] && [[ $(<"$watcher_pid_file") == "$$" ]]; then
    rm -f -- "$watcher_pid_file"
  fi
}
trap cleanup EXIT
trap 'exit 0' INT TERM
trap 'refresh_requested=true' USR1

for command in bluetoothctl "$status_script"; do
  if [[ $command == */* ]]; then
    [[ -x $command ]] || exit 1
  else
    command -v "$command" >/dev/null 2>&1 || exit 1
  fi
done

printf '%s\n' "$$" > "$watcher_pid_file"
"$status_script"

coproc BLUEZ_EVENTS { exec bluetoothctl --monitor 2>/dev/null; }
monitor_pid=$BLUEZ_EVENTS_PID
events_fd=${BLUEZ_EVENTS[0]}

while kill -0 "$monitor_pid" 2>/dev/null; do
  changed=false
  if IFS= read -r -t 0.25 -u "$events_fd" _; then
    changed=true
    # Coalesce the group of lines emitted for one BlueZ property change.
    while IFS= read -r -t 0.05 -u "$events_fd" _; do :; done
  fi

  connection_state=false
  if [[ -r $connection_marker ]]; then
    read -r owner < "$connection_marker" || owner=''
    [[ $owner =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null &&
      connection_state=true
  fi
  if [[ $connection_state != "$last_connection_state" ]]; then
    last_connection_state=$connection_state
    changed=true
  fi
  if [[ $refresh_requested == true ]]; then
    refresh_requested=false
    changed=true
  fi

  [[ $changed == true ]] && "$status_script"
done

wait "$monitor_pid" 2>/dev/null || true
