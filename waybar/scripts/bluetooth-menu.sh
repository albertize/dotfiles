#!/usr/bin/env bash

set -u

readonly menu_width=430
readonly menu_height=360
readonly input_height=135
readonly enable_bluetooth='  Enable Bluetooth'
readonly disable_bluetooth='󰂲  Disable Bluetooth'
readonly scan_devices='󰑐  Scan for devices'
readonly connect_device='󰂱  Connect'
readonly disconnect_device='󰂲  Disconnect'
readonly pair_device='󰌹  Pair'
readonly trust_device='󰌾  Trust'
readonly untrust_device='󰌿  Untrust'
readonly remove_device='󰆴  Remove device'
readonly back='󰁍  Back'
readonly connected_prefix='󰂱  '
readonly paired_prefix='󰂯  '
readonly available_prefix='  '

notify() {
  local urgency=$1
  local message=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" 'Bluetooth' "$message"
  else
    printf 'Bluetooth: %s\n' "$message" >&2
  fi
}

bt() {
  LC_ALL=C bluetoothctl "$@"
}

controller_powered() {
  bt show 2>/dev/null |
    awk -F': ' '/^[[:space:]]*Powered:/ { print $2; exit }'
}

device_property() {
  local address=$1
  local property=$2

  bt info "$address" 2>/dev/null |
    awk -v property="$property" '$1 == property ":" { print $2; exit }'
}

last_output_line() {
  local output=$1

  printf '%s\n' "$output" | awk 'NF { line=$0 } END { print line }'
}

failed_action() {
  local description=$1
  local output=$2
  local detail

  detail=$(last_output_line "$output")
  if [[ -n $detail ]]; then
    notify critical "$description"$'\n'"$detail"
  else
    notify critical "$description"
  fi
}

set_power() {
  local state=$1
  local expected=$2
  local output unblock_output

  # Powering the adapter off can leave it soft-blocked. Clear that block before
  # asking BlueZ to power it on again; hard blocks still require a hardware key.
  if [[ $state == on ]] && command -v rfkill >/dev/null 2>&1; then
    if ! unblock_output=$(LC_ALL=C rfkill unblock bluetooth 2>&1); then
      failed_action 'Unable to unblock Bluetooth.' "$unblock_output"
      return 1
    fi
    sleep 0.5
  fi

  output=$(bt power "$state" 2>&1)
  sleep 1
  if [[ $(controller_powered) == "$expected" ]]; then
    return 0
  fi

  failed_action 'Unable to change the Bluetooth state.' "$output"
  return 1
}

set_device_property() {
  local address=$1
  local command=$2
  local property=$3
  local expected=$4
  local success_message=$5
  local output

  output=$(bt --timeout 20 "$command" "$address" 2>&1)
  sleep 1
  if [[ $(device_property "$address" "$property") == "$expected" ]]; then
    notify normal "$success_message"
    return 0
  fi

  failed_action "Operation failed for ${aliases[$address]}." "$output"
  return 1
}

pair_selected_device() {
  local address=$1
  local output

  notify normal "Pairing with ${aliases[$address]}…"
  # DisplayYesNo supports both Just Works and confirmation-based pairing. The
  # user has already selected the device explicitly, so confirm its passkey.
  output=$(printf 'yes\n' |
    LC_ALL=C bluetoothctl --agent DisplayYesNo --timeout 30 pair "$address" 2>&1)
  sleep 1
  if [[ $(device_property "$address" Paired) == yes ]]; then
    notify normal "${aliases[$address]} paired."
    return 0
  fi

  failed_action "Unable to pair ${aliases[$address]}." "$output"
  return 1
}

remove_selected_device() {
  local address=$1
  local answer output

  answer=$(printf 'No\nYes\n' |
    wofi --dmenu --prompt "Remove ${aliases[$address]}?" \
      --width "$menu_width" --height "$input_height") || return 0
  [[ $answer == Yes ]] || return 0

  output=$(bt remove "$address" 2>&1)
  sleep 1
  if [[ $(device_property "$address" Paired) != yes ]]; then
    notify normal "${aliases[$address]} removed."
    return 0
  fi

  failed_action "Unable to remove ${aliases[$address]}." "$output"
  return 1
}

load_devices() {
  local filter=${1:-}
  local target_name=$2
  local line address alias
  local -n target=$target_name
  local command=(devices)

  [[ -n $filter ]] && command+=("$filter")
  while IFS= read -r line; do
    if [[ $line =~ ^Device[[:space:]]+([[:xdigit:]]{2}(:[[:xdigit:]]{2}){5})[[:space:]]+(.+)$ ]]; then
      address=${BASH_REMATCH[1]^^}
      alias=${BASH_REMATCH[3]}
      target["$address"]=$alias
    fi
  done < <(bt "${command[@]}" 2>/dev/null)
}

extract_address() {
  local entry=$1

  if [[ $entry =~ \[([[:xdigit:]]{2}(:[[:xdigit:]]{2}){5})\]$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]^^}"
  fi
}

device_menu() {
  local address=$1
  local choice paired_state connected_state trusted_state
  local -a entries

  while true; do
    paired_state=$(device_property "$address" Paired)
    connected_state=$(device_property "$address" Connected)
    trusted_state=$(device_property "$address" Trusted)
    entries=()

    if [[ $connected_state == yes ]]; then
      entries+=("$disconnect_device")
    elif [[ $paired_state == yes ]]; then
      entries+=("$connect_device")
    fi
    if [[ $paired_state != yes ]]; then
      entries+=("$pair_device")
    elif [[ $trusted_state == yes ]]; then
      entries+=("$untrust_device")
    else
      entries+=("$trust_device")
    fi
    [[ $paired_state == yes ]] && entries+=("$remove_device")
    entries+=("$back")

    choice=$(printf '%s\n' "${entries[@]}" |
      wofi --dmenu --prompt "${aliases[$address]}" --insensitive \
        --width "$menu_width" --height "$menu_height") || return 0

    case $choice in
      "$connect_device")
        set_device_property "$address" connect Connected yes \
          "${aliases[$address]} connected."
        ;;
      "$disconnect_device")
        set_device_property "$address" disconnect Connected no \
          "${aliases[$address]} disconnected."
        ;;
      "$pair_device") pair_selected_device "$address" ;;
      "$trust_device")
        set_device_property "$address" trust Trusted yes \
          "${aliases[$address]} is now trusted."
        ;;
      "$untrust_device")
        set_device_property "$address" untrust Trusted no \
          "${aliases[$address]} is no longer trusted."
        ;;
      "$remove_device") remove_selected_device "$address"; return 0 ;;
      "$back") return 0 ;;
      *) return 0 ;;
    esac
  done
}

for command in bluetoothctl wofi; do
  command -v "$command" >/dev/null 2>&1 || {
    notify critical "$command is not installed."
    exit 1
  }
done

bt list 2>/dev/null | grep -q '^Controller ' || {
  notify critical 'No Bluetooth adapter detected.'
  exit 1
}

while true; do
  declare -A aliases=() paired=() connected=()
  entries=()

  if [[ $(controller_powered) != yes ]]; then
    entries+=("$enable_bluetooth")
  else
    entries+=("$scan_devices" "$disable_bluetooth")
    load_devices '' aliases
    load_devices Paired paired
    load_devices Connected connected

    # A paired device can remain known even when it is absent from the general
    # discovery list, so merge both sources before creating menu entries.
    for address in "${!paired[@]}"; do
      aliases["$address"]=${paired[$address]}
    done

    for address in "${!aliases[@]}"; do
      if [[ -n ${connected[$address]+x} ]]; then
        entries+=("${connected_prefix}${aliases[$address]}  [$address]")
      elif [[ -n ${paired[$address]+x} ]]; then
        entries+=("${paired_prefix}${aliases[$address]}  [$address]")
      else
        entries+=("${available_prefix}${aliases[$address]}  [$address]")
      fi
    done
  fi

  choice=$(printf '%s\n' "${entries[@]}" |
    wofi --dmenu --prompt 'Bluetooth' --insensitive \
      --width "$menu_width" --height "$menu_height") || exit 0

  case $choice in
    "$enable_bluetooth") set_power on yes || true ;;
    "$disable_bluetooth") set_power off no; exit $? ;;
    "$scan_devices")
      notify normal 'Scanning for devices for 8 seconds…'
      bt --timeout 8 scan on >/dev/null 2>&1 || true
      ;;
    *)
      address=$(extract_address "$choice")
      [[ -n $address && -n ${aliases[$address]+x} ]] || exit 0
      device_menu "$address"
      ;;
  esac
done
