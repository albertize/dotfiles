#!/usr/bin/env bash

set -u

readonly menu_width=360
readonly lock='  Lock screen'
readonly suspend='󰒲  Suspend'
readonly hibernate='󰤄  Hibernate'
readonly logout='󰗽  Log out of Sway'
readonly reboot='󰜉  Restart'
readonly poweroff='  Power off'
readonly lock_script="${XDG_CONFIG_HOME:-$HOME/.config}/sway/scripts/lock.sh"

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency=critical 'Session' "$1"
  else
    printf 'Session: %s\n' "$1" >&2
  fi
}

can_logind() {
  local action=$1
  local response

  command -v busctl >/dev/null 2>&1 || {
    [[ $action != Hibernate ]]
    return
  }
  response=$(LC_ALL=C busctl call org.freedesktop.login1 \
    /org/freedesktop/login1 org.freedesktop.login1.Manager \
    "Can$action" 2>/dev/null) || return 1
  [[ $response == *'"yes"'* || $response == *'"challenge"'* ]]
}

confirm_action() {
  local prompt=$1
  local answer

  answer=$(printf 'No\nYes\n' |
    wofi --dmenu --prompt "$prompt" --insensitive \
      --width "$menu_width" --height 100) || return 1
  [[ $answer == Yes ]]
}

lock_before_sleep() {
  "$lock_script" &
  sleep 0.5
}

for command in systemctl swaymsg wofi; do
  command -v "$command" >/dev/null 2>&1 || {
    notify_error "$command is not installed."
    exit 1
  }
done
[[ -x $lock_script ]] || {
  notify_error 'The lock-screen helper is unavailable.'
  exit 1
}

entries=("$lock")
can_logind Suspend && entries+=("$suspend")
can_logind Hibernate && entries+=("$hibernate")
entries+=("$logout" "$reboot" "$poweroff")
menu_height=$((65 + ${#entries[@]} * 35))

choice=$(printf '%s\n' "${entries[@]}" |
  wofi --dmenu --prompt 'Session' --insensitive \
    --width "$menu_width" --height "$menu_height") || exit 0

case $choice in
  "$lock") "$lock_script" ;;
  "$suspend")
    lock_before_sleep
    systemctl suspend || notify_error 'Unable to suspend the computer.'
    ;;
  "$hibernate")
    lock_before_sleep
    systemctl hibernate || notify_error 'Unable to hibernate the computer.'
    ;;
  "$logout") swaymsg exit ;;
  "$reboot")
    confirm_action 'Restart the computer?' && systemctl reboot
    ;;
  "$poweroff")
    confirm_action 'Power off the computer?' && systemctl poweroff
    ;;
esac
