#!/usr/bin/env bash

set -u

lock='  Blocca schermo'
logout='󰗽  Esci da Sway'
poweroff='  Spegni il computer'

choice=$(printf '%s\n%s\n%s\n' "$lock" "$logout" "$poweroff" |
  wofi --dmenu --prompt 'Sessione' --insensitive --width 340 --height 135) || exit 0

case "$choice" in
  "$lock")
    swaylock
    ;;
  "$logout")
    swaymsg exit
    ;;
  "$poweroff")
    confirm=$(printf 'No\nSì\n' | wofi --dmenu --prompt 'Confermi lo spegnimento?' \
      --insensitive --width 340 --height 100) || exit 0
    [[ "$confirm" == 'Sì' ]] && systemctl poweroff
    ;;
esac
