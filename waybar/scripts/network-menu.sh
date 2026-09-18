#!/usr/bin/env bash

set -u

readonly menu_width=380
readonly menu_height=340
readonly input_height=100
readonly active_prefix='󰄬  '
readonly enable_wifi='󰖩  Enable Wi-Fi'
readonly disable_wifi='󰖪  Disable Wi-Fi'
readonly disconnect_wifi='󰤭  Disconnect'
readonly rescan_wifi='󰑐  Refresh networks'
readonly hidden_wifi='󰛐  Hidden network'
readonly saved_wifi='󰑕  Saved networks'
readonly activate_saved='󰤨  Connect'
readonly disconnect_saved='󰤭  Disconnect'
readonly forget_saved='󰆴  Forget network'
readonly back='󰁍  Back'

notify() {
  local urgency=$1
  local message=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" 'Wi-Fi' "$message"
  else
    printf 'Wi-Fi: %s\n' "$message" >&2
  fi
}

signal_icon() {
  local strength=$1

  if ((strength >= 75)); then
    printf '󰤨'
  elif ((strength >= 50)); then
    printf '󰤥'
  elif ((strength >= 25)); then
    printf '󰤢'
  else
    printf '󰤟'
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

manage_saved_networks() {
  local name uuid type marker entry choice action output answer
  local -a saved_entries=() rows=() actions=()
  local -A saved_uuids=() active_uuids=()

  while IFS= read -r uuid; do
    [[ -n $uuid ]] && active_uuids["$uuid"]=1
  done < <(LC_ALL=C nmcli --get-values UUID connection show --active)

  # Omitting read's -r decodes delimiters escaped by nmcli.
  while IFS=: read name uuid type; do
    [[ ($type == 802-11-wireless || $type == wifi) &&
        -n $name && -n $uuid ]] || continue
    marker=''
    [[ -n ${active_uuids[$uuid]+x} ]] && marker=$active_prefix
    rows+=("$name"$'\t'"$uuid"$'\t'"$marker")
  done < <(
    LC_ALL=C nmcli --escape yes --terse --get-values NAME,UUID,TYPE \
      connection show
  )

  while IFS=$'\t' read -r name uuid marker; do
    entry="${marker}󰑕  $name  [${uuid:0:8}]"
    saved_entries+=("$entry")
    saved_uuids["$entry"]=$uuid
  done < <(printf '%s\n' "${rows[@]}" | LC_ALL=C sort -f)

  ((${#saved_entries[@]} > 0)) || {
    notify normal 'No saved Wi-Fi networks.'
    return 0
  }
  choice=$(printf '%s\n' "${saved_entries[@]}" |
    wofi --dmenu --prompt 'Saved Wi-Fi networks' --insensitive \
      --width "$menu_width" --height "$menu_height") || return 0
  [[ -n $choice ]] || return 0
  [[ -n ${saved_uuids[$choice]+x} ]] || return 0
  uuid=${saved_uuids[$choice]}
  name=${choice#*󰑕  }
  name=${name%  \[*}

  actions=("$activate_saved" "$forget_saved" "$back")
  [[ -n ${active_uuids[$uuid]+x} ]] && actions=("$disconnect_saved" "$forget_saved" "$back")
  action=$(printf '%s\n' "${actions[@]}" |
    wofi --dmenu --prompt "$name" --insensitive \
      --width 340 --height 135) || return 0

  case $action in
    "$activate_saved")
      if output=$(nmcli --wait 30 connection up uuid "$uuid" 2>&1); then
        notify normal "Connected using $name."
      else
        notify critical "$output"
        return 1
      fi
      ;;
    "$disconnect_saved")
      nmcli connection down uuid "$uuid" >/dev/null &&
        notify normal "Disconnected from $name."
      ;;
    "$forget_saved")
      answer=$(printf 'No\nYes\n' |
        wofi --dmenu --prompt "Forget $name?" --insensitive \
          --width 340 --height "$input_height") || return 0
      [[ $answer == Yes ]] || return 0
      if nmcli connection delete uuid "$uuid" >/dev/null; then
        notify normal "$name was removed."
      else
        notify critical "Unable to remove $name."
        return 1
      fi
      ;;
  esac
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
  declare -A network_ssids=()

  if [[ $(LC_ALL=C nmcli radio wifi) != enabled ]]; then
    entries+=("$enable_wifi" "$saved_wifi")
  else
    active_ssid=''
    network_rows=()
    declare -A seen_ssids=()
    # Omitting read's -r decodes the separators escaped by nmcli.
    while IFS=: read active ssid signal security; do
      [[ -n $ssid ]] || continue
      [[ $active == yes ]] && active_ssid=$ssid
      [[ $signal =~ ^[0-9]+$ ]] || signal=0
      network_rows+=("$signal"$'\t'"$ssid"$'\t'"$security")
    done < <(
      LC_ALL=C nmcli --escape yes --terse \
        --get-values ACTIVE,SSID,SIGNAL,SECURITY device wifi list \
        ifname "$device" --rescan no
    )

    [[ -n $active_ssid ]] && entries+=("$disconnect_wifi")
    entries+=("$rescan_wifi" "$hidden_wifi" "$saved_wifi" "$disable_wifi")

    while IFS=$'\t' read -r signal ssid security; do
      [[ -n $ssid && -z ${seen_ssids[$ssid]+x} ]] || continue
      seen_ssids["$ssid"]=1
      marker=''
      [[ $ssid == "$active_ssid" ]] && marker=$active_prefix
      if [[ -z $security || $security == -- ]]; then
        security_label='󰿆  Open'
      else
        security_label="󰌾  $security"
      fi
      entry="${marker}$(signal_icon "$signal")  $ssid · ${signal}% · $security_label"
      entries+=("$entry")
      network_ssids["$entry"]=$ssid
    done < <(printf '%s\n' "${network_rows[@]}" |
      LC_ALL=C sort -t $'\t' -k1,1nr)
  fi

  choice=$(printf '%s\n' "${entries[@]}" |
    wofi --dmenu --prompt 'Wi-Fi' --insensitive \
      --width "$menu_width" --height "$menu_height") || exit 0
  [[ -n $choice ]] || exit 0

  case $choice in
    "$enable_wifi")
      nmcli radio wifi on
      exit $?
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
    "$saved_wifi")
      manage_saved_networks
      exit $?
      ;;
    *)
      [[ -n ${network_ssids[$choice]+x} ]] || exit 0
      ssid=${network_ssids[$choice]}
      [[ $ssid == "${active_ssid:-}" ]] && exit 0
      connect_wifi "$device" "$ssid"
      exit $?
      ;;
  esac
done
