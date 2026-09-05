#!/usr/bin/env bash

# Adjust backlight brightness and show a replaceable Dunst progress notification.
set -u

action=${1:-}

case $action in
  up) brightnessctl --quiet set 5%+ ;;
  down) brightnessctl --quiet set 5%- ;;
  *) printf 'Usage: %s <up|down>\n' "${0##*/}" >&2; exit 2 ;;
esac

command -v dunstify >/dev/null 2>&1 || exit 0

brightness=$(LC_ALL=C brightnessctl --machine-readable info |
  awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }')
[[ $brightness =~ ^[0-9]+$ ]] || exit 0

dunstify --app-name='Desktop controls' --urgency=normal --timeout=1200 \
  --stack-tag=brightness --icon='display-brightness-symbolic' \
  --hint="int:value:$brightness" 'Brightness' "${brightness}%"
