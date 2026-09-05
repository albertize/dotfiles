#!/usr/bin/env bash

# Adjust PipeWire volume and show a replaceable Dunst progress notification.
set -u

action=${1:-}

case $action in
  up) wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+ ;;
  down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  mic-mute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
  *) printf 'Usage: %s <up|down|mute|mic-mute>\n' "${0##*/}" >&2; exit 2 ;;
esac

command -v dunstify >/dev/null 2>&1 || exit 0

if [[ $action == mic-mute ]]; then
  status=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SOURCE@) || exit 0
  volume=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<< "$status")
  progress=$(( volume > 100 ? 100 : volume ))
  if [[ $status == *'[MUTED]'* ]]; then
    icon='microphone-sensitivity-muted-symbolic'
    label='Microphone muted'
  else
    icon='microphone-sensitivity-high-symbolic'
    label="Microphone ${volume}%"
  fi
  dunstify --app-name='Desktop controls' --urgency=normal --timeout=1200 \
    --stack-tag=microphone --icon="$icon" --hint="int:value:$progress" \
    'Microphone' "$label"
  exit 0
fi

status=$(LC_ALL=C wpctl get-volume @DEFAULT_AUDIO_SINK@) || exit 0
volume=$(awk '{ printf "%d", $2 * 100 + 0.5 }' <<< "$status")
progress=$(( volume > 100 ? 100 : volume ))

if [[ $status == *'[MUTED]'* ]]; then
  icon='audio-volume-muted-symbolic'
  label='Muted'
elif (( volume < 34 )); then
  icon='audio-volume-low-symbolic'
  label="${volume}%"
elif (( volume < 67 )); then
  icon='audio-volume-medium-symbolic'
  label="${volume}%"
else
  icon='audio-volume-high-symbolic'
  label="${volume}%"
fi

dunstify --app-name='Desktop controls' --urgency=normal --timeout=1200 \
  --stack-tag=volume --icon="$icon" --hint="int:value:$progress" \
  'Volume' "$label"
