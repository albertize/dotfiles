#!/usr/bin/env bash

# Reuse the active theme's wallpaper and Swaylock palette.
set -u

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
theme_dir="$config_home/dotfiles-theme"
theme_config="$theme_dir/theme.conf"
font_config="$config_home/dotfiles-font/font.conf"

[[ -r $theme_config ]] || {
  printf 'Active theme configuration not found: %s\n' "$theme_config" >&2
  exec swaylock
}
# The profile is managed by this repository and contains only quoted values.
# shellcheck disable=SC1090
source "$theme_config"
wallpaper="${XDG_DATA_HOME:-$HOME/.local/share}/backgrounds/dotfiles/$WALLPAPER"
lock_config="$theme_dir/swaylock.conf"

if [[ -r $wallpaper && -r $lock_config && -r $font_config ]]; then
  # shellcheck disable=SC1090
  source "$font_config"
  exec swaylock --config "$lock_config" --font "$FONT_FAMILY" \
    --image "$wallpaper" --scaling fill
fi

printf 'Theme lock-screen assets are incomplete; using the default configuration.\n' >&2
exec swaylock
