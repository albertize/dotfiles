#!/usr/bin/env bash

# Reuse the desktop wallpaper on the lock screen without hardcoding $HOME.
set -u

wallpaper="${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/dotfiles/leaves_line_neon_139772_2560x1600.jpg"

if [[ -r $wallpaper ]]; then
  exec swaylock --image "$wallpaper" --scaling fill
fi

printf 'Lock-screen wallpaper not found: %s; using the configured solid color.\n' "$wallpaper" >&2
exec swaylock
