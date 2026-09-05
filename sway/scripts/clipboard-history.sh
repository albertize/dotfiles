#!/usr/bin/env bash

# Store text and image clipboard entries for the Waybar history menu.
set -u

if ! command -v cliphist >/dev/null 2>&1 || ! command -v wl-paste >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 &&
    notify-send --urgency=critical 'Clipboard history' 'cliphist and wl-clipboard are required.'
  exit 1
fi

children=()
cleanup() {
  if (( ${#children[@]} > 0 )); then
    kill "${children[@]}" 2>/dev/null || true
    wait "${children[@]}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

wl-paste --type text --watch cliphist store &
children+=("$!")
wl-paste --type image --watch cliphist store &
children+=("$!")

wait
