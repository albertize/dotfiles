#!/usr/bin/env bash

# Report Bluetooth state and menu-initiated connection attempts to Waybar.
set -u

runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$UID}
[[ -d $runtime_dir && -w $runtime_dir ]] || runtime_dir=${TMPDIR:-/tmp}
readonly connection_marker="$runtime_dir/waybar-bluetooth-connecting-$UID"

pango_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'
}

connection_in_progress() {
  local owner

  [[ -r $connection_marker ]] || return 1
  read -r owner < "$connection_marker" || return 1
  if [[ $owner =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null; then
    return 0
  fi

  rm -f -- "$connection_marker"
  return 1
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
  jq -cn --arg text '' --arg class 'no-controller' \
    --arg tooltip 'Bluetooth is unavailable' \
    '{text: $text, class: $class, tooltip: $tooltip}'
  exit 0
fi

controller=$(LC_ALL=C bluetoothctl show 2>/dev/null) || controller=''
if [[ -z $controller ]]; then
  jq -cn --arg text '' --arg class 'no-controller' \
    --arg tooltip 'No Bluetooth controller detected' \
    '{text: $text, class: $class, tooltip: $tooltip}'
  exit 0
fi

controller_alias=$(printf '%s\n' "$controller" |
  awk -F': ' '/^[[:space:]]*Alias:/ { print $2; exit }')
powered=$(printf '%s\n' "$controller" |
  awk -F': ' '/^[[:space:]]*Powered:/ { print $2; exit }')
discovering=$(printf '%s\n' "$controller" |
  awk -F': ' '/^[[:space:]]*Discovering:/ { print $2; exit }')
controller_alias=$(pango_escape "${controller_alias:-Bluetooth controller}")

if [[ $powered != yes ]]; then
  tooltip=$'<span color="#8aadf4"><b>Bluetooth</b></span> · off\n'
  tooltip+="$controller_alias"$'\n'
  tooltip+='Click to manage devices'
  jq -cn --arg text '󰂲' --arg class 'off' --arg tooltip "$tooltip" \
    '{text: $text, class: $class, tooltip: $tooltip}'
  exit 0
fi

mapfile -t connected_devices < <(
  LC_ALL=C bluetoothctl devices Connected 2>/dev/null |
    sed -n 's/^Device [[:xdigit:]:]\{17\} //p'
)
connection_count=${#connected_devices[@]}

if connection_in_progress; then
  class=connecting
  status=connecting
elif [[ $discovering == yes ]]; then
  class=discovering
  status=scanning
elif ((connection_count > 0)); then
  class=connected
  status=connected
else
  class=on
  status=on
fi

if ((connection_count > 0)); then
  text='󰂱'
  device_list=''
  for device in "${connected_devices[@]}"; do
    device_list+=$'\n  '"$(pango_escape "$device")"
  done
  tooltip="<span color=\"#8bd5ca\"><b>Bluetooth</b></span> · $status"$'\n'
  tooltip+="$controller_alias"$'\n'
  tooltip+="Connected devices: $connection_count${device_list}"$'\n'
  tooltip+='Click to manage devices'
else
  text=''
  tooltip="<span color=\"#8aadf4\"><b>Bluetooth</b></span> · $status"$'\n'
  tooltip+="$controller_alias"$'\n'
  tooltip+='Click to manage devices'
fi

jq -cn --arg text "$text" --arg class "$class" --arg tooltip "$tooltip" \
  '{text: $text, class: $class, tooltip: $tooltip}'
