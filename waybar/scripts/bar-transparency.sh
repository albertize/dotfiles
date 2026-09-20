#!/usr/bin/env bash

# Toggle Waybar between its themed background and a transparent dark-text mode.
set -euo pipefail

readonly state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
readonly state_file="$state_home/dotfiles/waybar-transparent"
readonly runtime_dir=${XDG_RUNTIME_DIR:-"/tmp/waybar-$UID"}
readonly runtime_config="$runtime_dir/waybar-output.json"
readonly bar_pid_file="$runtime_dir/waybar.pid"

for command_name in jq mktemp; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf 'Missing command: %s\n' "$command_name" >&2
    exit 1
  }
done
[[ -r $runtime_config && -r $bar_pid_file ]] || {
  printf 'The managed Waybar instance is not running.\n' >&2
  exit 1
}

mkdir -p -- "$(dirname -- "$state_file")"
if [[ -r $state_file ]] && [[ $(<"$state_file") == true ]]; then
  transparent=false
  bar_name=opaque
else
  transparent=true
  bar_name=transparent
fi
printf '%s\n' "$transparent" > "$state_file"

temporary_config=$(mktemp "$runtime_dir/.waybar-output.XXXXXX")
trap 'rm -f -- "$temporary_config"' EXIT
jq --arg name "$bar_name" '.name = $name' "$runtime_config" > "$temporary_config"
mv -f -- "$temporary_config" "$runtime_config"
trap - EXIT

bar_pid=$(<"$bar_pid_file")
[[ $bar_pid =~ ^[0-9]+$ ]] && kill -0 "$bar_pid" 2>/dev/null &&
  ps -p "$bar_pid" -o comm= | grep -Fqx waybar || {
    printf 'The managed Waybar process is not running.\n' >&2
    exit 1
  }
kill -USR2 "$bar_pid"
