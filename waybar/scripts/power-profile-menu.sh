#!/usr/bin/env bash

set -u

readonly power_saver_label='󰌪  Battery save'
readonly balanced_label='  Balanced'
readonly performance_label='󰓅  Performance'

notify() {
  command -v notify-send >/dev/null 2>&1 &&
    notify-send --app-name='Power profile' -- "$1" || true
}

command -v wofi >/dev/null 2>&1 || {
  notify 'Wofi is not installed.'
  exit 1
}

profile_backend=
service=
object=
interface=

if command -v powerprofilesctl >/dev/null 2>&1; then
  profile_backend=powerprofilesctl
elif command -v busctl >/dev/null 2>&1; then
  for endpoint in \
    'org.freedesktop.UPower.PowerProfiles|/org/freedesktop/UPower/PowerProfiles|org.freedesktop.UPower.PowerProfiles' \
    'net.hadess.PowerProfiles|/net/hadess/PowerProfiles|net.hadess.PowerProfiles'; do
    IFS='|' read -r candidate_service candidate_object candidate_interface <<< "$endpoint"
    if busctl --system get-property "$candidate_service" "$candidate_object" \
      "$candidate_interface" ActiveProfile >/dev/null 2>&1; then
      service=$candidate_service
      object=$candidate_object
      interface=$candidate_interface
      profile_backend=busctl
      break
    fi
  done
fi

[[ -n $profile_backend ]] || {
  notify 'The power profile service is unavailable.'
  exit 1
}

current_profile=
if [[ $profile_backend == powerprofilesctl ]]; then
  current_profile=$(LC_ALL=C powerprofilesctl get 2>/dev/null || true)
else
  current_profile=$(LC_ALL=C busctl --system get-property "$service" "$object" \
    "$interface" ActiveProfile 2>/dev/null || true)
  current_profile=${current_profile#*\"}
  current_profile=${current_profile%\"*}
fi

menu_entry() {
  local profile=$1
  local label=$2

  if [[ $profile == "$current_profile" ]]; then
    printf '● %s\n' "$label"
  else
    printf '  %s\n' "$label"
  fi
}

choice=$({
  menu_entry power-saver "$power_saver_label"
  menu_entry balanced "$balanced_label"
  menu_entry performance "$performance_label"
} | wofi --dmenu --prompt 'Power profile' --insensitive \
  --width 340 --height 135) || exit 0

case $choice in
  *"$power_saver_label") profile=power-saver; label='Battery save' ;;
  *"$balanced_label") profile=balanced; label='Balanced' ;;
  *"$performance_label") profile=performance; label='Performance' ;;
  *) exit 0 ;;
esac

if [[ $profile_backend == powerprofilesctl ]]; then
  profile_set=(powerprofilesctl set "$profile")
else
  profile_set=(busctl --system set-property "$service" "$object" "$interface" \
    ActiveProfile s "$profile")
fi

if "${profile_set[@]}" >/dev/null 2>&1; then
  notify "Power profile: $label"
else
  notify "Unable to activate the $label profile."
  exit 1
fi
