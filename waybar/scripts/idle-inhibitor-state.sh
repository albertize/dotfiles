#!/usr/bin/env bash

# Persist the Waybar idle inhibitor state across bar and session restarts.
set -u

readonly state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
readonly state_dir="$state_home/dotfiles"
readonly state_file="$state_dir/idle-inhibitor"

action=${1:-}
[[ $action == toggle ]] || {
  printf 'Usage: %s toggle\n' "${0##*/}" >&2
  exit 2
}

current=deactivated
[[ -r $state_file ]] && read -r current < "$state_file"
if [[ $current == activated ]]; then
  next=deactivated
else
  next=activated
fi

mkdir -p -- "$state_dir"
temporary_file="$state_file.$$"
(umask 077; printf '%s\n' "$next" > "$temporary_file")
mv -f -- "$temporary_file" "$state_file"
