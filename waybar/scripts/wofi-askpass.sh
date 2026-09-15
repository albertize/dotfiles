#!/usr/bin/env bash

# SUDO_ASKPASS helper used by the VPN applet.
set -u

command -v wofi >/dev/null 2>&1 || exit 1
prompt=${1:-Administrator password}
printf '\n' | wofi --dmenu --password --prompt "$prompt" --width 380 --height 100
