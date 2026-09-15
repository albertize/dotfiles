#!/usr/bin/env bash

# Save and restore the Bluetooth controller power state.
set -u

readonly state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
readonly state_dir="$state_home/dotfiles"
readonly state_file="$state_dir/bluetooth"

action=${1:-}

controller_powered() {
  LC_ALL=C bluetoothctl show 2>/dev/null |
    awk -F': ' '/^[[:space:]]*Powered:/ { print $2; exit }'
}

save_state() {
  local state=$1
  local temporary_file="$state_file.$$"

  [[ $state == on || $state == off ]] || return 2
  mkdir -p -- "$state_dir"
  (umask 077; printf '%s\n' "$state" > "$temporary_file")
  mv -f -- "$temporary_file" "$state_file"
}

restore_state() {
  local desired current expected

  command -v bluetoothctl >/dev/null 2>&1 || return 0
  if [[ ! -r $state_file ]]; then
    for _ in {1..20}; do
      current=$(controller_powered)
      case $current in
        yes) save_state on; return $? ;;
        no) save_state off; return $? ;;
      esac
      sleep 0.5
    done
    return 0
  fi

  read -r desired < "$state_file"
  case $desired in
    on) expected=yes ;;
    off) expected=no ;;
    *) return 1 ;;
  esac

  for _ in {1..20}; do
    current=$(controller_powered)
    if [[ $current == "$expected" ]]; then
      return 0
    fi
    if [[ -n $current ]]; then
      if [[ $desired == on ]] && command -v rfkill >/dev/null 2>&1; then
        LC_ALL=C rfkill unblock bluetooth >/dev/null 2>&1 || true
      fi
      LC_ALL=C bluetoothctl power "$desired" >/dev/null 2>&1 || true
    fi
    sleep 0.5
  done

  return 1
}

case $action in
  save) save_state "${2:-}" ;;
  restore) restore_state ;;
  *)
    printf 'Usage: %s save {on|off} | restore\n' "${0##*/}" >&2
    exit 2
    ;;
esac
