#!/usr/bin/env bash

set -u

readonly menu_width=440
readonly menu_height=340
mode=${1:-select}

notify() {
  local urgency=$1
  local message=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" 'Clipboard history' "$message"
  else
    printf 'Clipboard history: %s\n' "$message" >&2
  fi
}

for command in cliphist wl-copy wl-paste wofi; do
  command -v "$command" >/dev/null 2>&1 || {
    notify critical "$command is not installed."
    exit 1
  }
done

# Recover automatically if cliphist was installed after Sway started or if its
# listener stopped unexpectedly.
if ! pgrep -f '[c]lipboard-history.sh' >/dev/null 2>&1; then
  config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
  nohup "$config_home/sway/scripts/clipboard-history.sh" \
    >"${XDG_RUNTIME_DIR:-/tmp}/clipboard-history.log" 2>&1 &
  sleep 0.3
fi

case $mode in
  select)
    history=$(cliphist list)
    [[ -n $history ]] || {
      notify normal 'The history is empty.'
      exit 0
    }

    selection=$(printf '%s\n' "$history" |
      wofi --dmenu --prompt 'Clipboard history' --insensitive \
        --width "$menu_width" --height "$menu_height") || exit 0
    [[ -n $selection ]] || exit 0
    printf '%s\n' "$selection" | cliphist decode | wl-copy
    notify low 'Copied the selected entry.'
    ;;
  delete)
    selection=$(cliphist list |
      wofi --dmenu --prompt 'Delete clipboard entry' --insensitive \
        --width "$menu_width" --height "$menu_height") || exit 0
    [[ -n $selection ]] || exit 0
    printf '%s\n' "$selection" | cliphist delete
    ;;
  wipe)
    confirmation=$(printf 'No\nYes\n' |
      wofi --dmenu --prompt 'Clear clipboard history?' --insensitive \
        --width 340 --height 100) || exit 0
    [[ $confirmation == Yes ]] || exit 0
    cliphist wipe
    notify normal 'Clipboard history cleared.'
    ;;
  *)
    printf 'Unknown mode: %s\n' "$mode" >&2
    exit 2
    ;;
esac
