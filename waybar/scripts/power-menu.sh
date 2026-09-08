#!/usr/bin/env bash

set -u

lock='  Lock screen'
logout='󰗽  Log out of Sway'
poweroff='  Power off'

choice=$(printf '%s\n%s\n%s\n' "$lock" "$logout" "$poweroff" |
  wofi --dmenu --prompt 'Session' --insensitive --width 340 --height 135) || exit 0

case "$choice" in
  "$lock")
    swaylock
    ;;
  "$logout")
    swaymsg exit
    ;;
  "$poweroff")
    confirm=$(printf 'No\nYes\n' | wofi --dmenu --prompt 'Power off the computer?' \
      --insensitive --width 340 --height 100) || exit 0
    [[ $confirm == Yes ]] && systemctl poweroff
    ;;
esac
