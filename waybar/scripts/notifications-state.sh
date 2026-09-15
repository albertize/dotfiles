#!/usr/bin/env bash

# Persist Dunst's do-not-disturb state across daemon and session restarts.
set -u

readonly state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
readonly state_dir="$state_home/dotfiles"
readonly state_file="$state_dir/notifications-paused"

action=${1:-}

save_state() {
  local state=$1
  local temporary_file="$state_file.$$"

  [[ $state == true || $state == false ]] || return 2
  mkdir -p -- "$state_dir"
  (umask 077; printf '%s\n' "$state" > "$temporary_file")
  mv -f -- "$temporary_file" "$state_file"
}

current_state() {
  dunstctl is-paused 2>/dev/null
}

command -v dunstctl >/dev/null 2>&1 || exit 0

case $action in
  toggle)
    current=$(current_state) || exit 1
    if [[ $current == true ]]; then
      desired=false
    else
      desired=true
    fi
    dunstctl set-paused "$desired"
    save_state "$desired"
    ;;
  restore)
    current=$(current_state) || exit 1
    if [[ ! -r $state_file ]]; then
      save_state "$current"
      exit $?
    fi
    read -r desired < "$state_file"
    [[ $desired == true || $desired == false ]] || exit 1
    [[ $current == "$desired" ]] || dunstctl set-paused "$desired"
    ;;
  *)
    printf 'Usage: %s {toggle|restore}\n' "${0##*/}" >&2
    exit 2
    ;;
esac
