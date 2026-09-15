#!/usr/bin/env bash

set -u

readonly menu_width=520
readonly menu_height=380
readonly state_script="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/scripts/notifications-state.sh"
readonly show_history='󰋚  Notification history'
readonly clear_history='󰎟  Clear history'
readonly pause_notifications='󰂛  Enable do not disturb'
readonly resume_notifications='󰂚  Disable do not disturb'
readonly restore_notification='󰑐  Restore notification'
readonly remove_notification='󰆴  Remove from history'
readonly back='󰁍  Back'

signal_status() {
  pkill -RTMIN+10 -x waybar 2>/dev/null || true
}

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency=critical 'Notifications' "$1"
  else
    printf 'Notifications: %s\n' "$1" >&2
  fi
}

toggle_pause() {
  "$state_script" toggle || {
    notify_error 'Unable to change do-not-disturb mode.'
    return 1
  }
  signal_status
}

show_notification_history() {
  local history_json id app summary body entry choice action
  local -a history_entries=()
  local -A notification_ids=()

  history_json=$(LC_ALL=C dunstctl history 2>/dev/null) || return 1
  while IFS=$'\t' read -r id app summary body; do
    [[ -n $id ]] || continue
    [[ -n $app ]] || app='Unknown application'
    [[ -n $summary ]] || summary='Notification'
    entry="$app · $summary"
    [[ -n $body ]] && entry+=" — $body"
    entry+="  [$id]"
    history_entries+=("$entry")
    notification_ids["$entry"]=$id
  done < <(
    jq -r '
      .data[0][]?
      | [(.id.data // .id // 0 | tostring),
         (.appname.data // .appname // ""),
         (.summary.data // .summary // ""),
         (.body.data // .body // "")]
      | map(tostring | gsub("[\\n\\r\\t]+"; " "))
      | @tsv
    ' <<< "$history_json"
  )

  ((${#history_entries[@]} > 0)) || {
    notify_error 'Notification history is empty.'
    return 0
  }

  choice=$(printf '%s\n' "${history_entries[@]}" |
    wofi --dmenu --prompt 'Notification history' --insensitive \
      --width "$menu_width" --height "$menu_height") || return 0
  [[ -n $choice ]] || return 0
  [[ -n ${notification_ids[$choice]+x} ]] || return 0
  id=${notification_ids[$choice]}

  action=$(printf '%s\n' "$restore_notification" "$remove_notification" "$back" |
    wofi --dmenu --prompt 'Notification action' --insensitive \
      --width 360 --height 135) || return 0
  case $action in
    "$restore_notification") dunstctl history-pop "$id" ;;
    "$remove_notification") dunstctl history-rm "$id" ;;
  esac
  signal_status
}

for command in dunstctl jq wofi; do
  command -v "$command" >/dev/null 2>&1 || {
    notify_error "$command is not installed."
    exit 1
  }
done
[[ -x $state_script ]] || {
  notify_error 'The notification state helper is unavailable.'
  exit 1
}

if [[ ${1:-} == toggle-pause ]]; then
  toggle_pause
  exit $?
fi

if [[ $(dunstctl is-paused 2>/dev/null) == true ]]; then
  pause_entry=$resume_notifications
else
  pause_entry=$pause_notifications
fi
history_count=$(LC_ALL=C dunstctl count history 2>/dev/null || printf '0')

choice=$(printf '%s\n' "$pause_entry" "$show_history" "$clear_history" |
  wofi --dmenu --prompt "Notifications · $history_count in history" \
    --insensitive --width "$menu_width" --height 135) || exit 0

case $choice in
  "$pause_notifications"|"$resume_notifications") toggle_pause ;;
  "$show_history") show_notification_history ;;
  "$clear_history")
    confirm=$(printf 'No\nYes\n' |
      wofi --dmenu --prompt 'Clear notification history?' --insensitive \
        --width 360 --height 100) || exit 0
    if [[ $confirm == Yes ]]; then
      dunstctl history-clear
      signal_status
    fi
    ;;
esac
