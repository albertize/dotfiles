#!/usr/bin/env bash

set -u

readonly menu_width=380
readonly menu_height=340
readonly input_height=100
readonly network_prefix='  '
readonly enable_wifi='󰖩  Enable Wi-Fi'
readonly disable_wifi='󰖪  Disable Wi-Fi'
readonly disconnect_wifi='󰤭  Disconnect'
readonly rescan_wifi='󰑐  Refresh networks'
readonly hidden_wifi='󰛐  Hidden network'

notify() {
  local urgency=$1
  local message=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" 'Wi-Fi' "$message"
  else
    printf 'Wi-Fi: %s\n' "$message" >&2
  fi
}

ask() {
  local prompt=$1
  local password_mode=${2:-false}
  local args=(--dmenu --prompt "$prompt" --width "$menu_width" --height "$input_height")

  [[ $password_mode == true ]] && args+=(--password)
  printf '\n' | wofi "${args[@]}"
}

connect_wifi() {
  local device=$1
  local ssid=$2
  local output password

  if output=$(nmcli --wait 20 device wifi connect "$ssid" ifname "$device" 2>&1); then
    notify normal "Connected to $ssid"
    return 0
  fi

  password=$(ask "Password for $ssid" true) || return 0
  [[ -n $password ]] || {
    notify critical "$output"
    return 1
  }

  if output=$(nmcli --wait 30 device wifi connect "$ssid" password "$password" \
      ifname "$device" 2>&1); then
    notify normal "Connected to $ssid"
  else
    notify critical "$output"
    return 1
  fi
}

connect_hidden_wifi() {
  local device=$1
  local ssid password output

  ssid=$(ask 'Hidden network name') || return 0
  [[ -n $ssid ]] || return 0
  password=$(ask "Password for $ssid (leave empty if open)" true) || return 0

  if [[ -n $password ]]; then
    output=$(nmcli --wait 30 device wifi connect "$ssid" password "$password" \
      ifname "$device" hidden yes 2>&1) || {
        notify critical "$output"
        return 1
      }
  else
    output=$(nmcli --wait 30 device wifi connect "$ssid" ifname "$device" \
      hidden yes 2>&1) || {
        notify critical "$output"
        return 1
      }
  fi

  notify normal "Connected to $ssid"
}

command -v nmcli >/dev/null 2>&1 || {
  notify critical 'nmcli is not installed.'
  exit 1
}
command -v wofi >/dev/null 2>&1 || {
  notify critical 'Wofi is not installed.'
  exit 1
}

device=$(LC_ALL=C nmcli --escape no --get-values DEVICE,TYPE device status |
  awk -F: '$2 == "wifi" { print $1; exit }')
[[ -n $device ]] || {
  notify critical 'No Wi-Fi adapter detected.'
  exit 1
}

while true; do
  entries=()

  if [[ $(LC_ALL=C nmcli radio wifi) != enabled ]]; then
    entries+=("$enable_wifi")
  else
    active_ssid=$(LC_ALL=C nmcli --escape no --get-values ACTIVE,SSID \
      device wifi list ifname "$device" --rescan no |
      sed -n 's/^yes://p' | head -n 1)
    [[ -n $active_ssid ]] && entries+=("$disconnect_wifi")
    entries+=("$rescan_wifi" "$hidden_wifi" "$disable_wifi")

    mapfile -t networks < <(
      LC_ALL=C nmcli --escape no --get-values SSID \
        device wifi list ifname "$device" --rescan auto |
        awk 'NF && !seen[$0]++'
    )
    for ssid in "${networks[@]}"; do
      entries+=("${network_prefix}${ssid}")
    done
  fi

  choice=$(printf '%s\n' "${entries[@]}" |
    wofi --dmenu --prompt 'Wi-Fi' --insensitive \
      --width "$menu_width" --height "$menu_height") || exit 0

  case $choice in
    "$enable_wifi")
      nmcli radio wifi on
      sleep 1
      ;;
    "$disable_wifi")
      nmcli radio wifi off
      exit 0
      ;;
    "$disconnect_wifi")
      nmcli device disconnect "$device" >/dev/null &&
        notify normal "Disconnected from $active_ssid"
      exit 0
      ;;
    "$rescan_wifi")
      nmcli device wifi rescan ifname "$device" 2>/dev/null || true
      ;;
    "$hidden_wifi")
      connect_hidden_wifi "$device"
      exit $?
      ;;
    "$network_prefix"*)
      connect_wifi "$device" "${choice#"$network_prefix"}"
      exit $?
      ;;
    *) exit 0 ;;
  esac
done
