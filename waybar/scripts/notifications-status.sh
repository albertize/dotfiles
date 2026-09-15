#!/usr/bin/env bash

# Report Dunst state and keep the saved do-not-disturb preference applied.
set -u

readonly state_script="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/scripts/notifications-state.sh"

if ! command -v dunstctl >/dev/null 2>&1 || [[ ! -x $state_script ]]; then
  jq -cn --arg text '󰂚' --arg class 'unavailable' \
    --arg tooltip 'Dunst is unavailable' \
    '{text: $text, class: $class, tooltip: $tooltip}'
  exit 0
fi

"$state_script" restore >/dev/null 2>&1 || true
if ! paused=$(dunstctl is-paused 2>/dev/null); then
  jq -cn --arg text '󰂚' --arg class 'unavailable' \
    --arg tooltip 'Dunst is unavailable' \
    '{text: $text, class: $class, tooltip: $tooltip}'
  exit 0
fi
history_count=$(LC_ALL=C dunstctl count history 2>/dev/null || printf '0')
[[ $history_count =~ ^[0-9]+$ ]] || history_count=0

if [[ $paused == true ]]; then
  text='󰂛'
  class=paused
  tooltip=$'<span color="#eed49f"><b>Notifications paused</b></span>\n'
else
  text='󰂚'
  class=active
  tooltip=$'<span color="#a6da95"><b>Notifications enabled</b></span>\n'
fi
tooltip+="History: $history_count"$'\n'
tooltip+='Click to manage notifications'

jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
  '{text: $text, class: $class, tooltip: $tooltip}'
