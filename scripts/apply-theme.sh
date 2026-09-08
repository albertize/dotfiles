#!/usr/bin/env bash

# Apply the theme to the current user environment without relying on a
# desktop-specific settings service.
set -u

gtk_theme='catppuccin-macchiato-blue-standard+default'
icon_theme='Papirus-Dark'
font_name='JetBrainsMono Nerd Font 10'
kvantum_theme='catppuccin-macchiato-blue'

if command -v gsettings >/dev/null 2>&1 &&
   gsettings list-schemas | grep -qx 'org.gnome.desktop.interface'; then
  gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme" || true
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
  gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" || true
  gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' || true
  gsettings set org.gnome.desktop.interface font-name "$font_name" || true
fi

# KDE applications read icons and fonts from KConfig instead of GTK settings.
# Update only these keys and preserve all other KDE settings.
kconfig=()
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kconfig=(kwriteconfig6 --file kdeglobals)
elif command -v kwriteconfig5 >/dev/null 2>&1; then
  kconfig=(kwriteconfig5 --file kdeglobals)
fi
if (( ${#kconfig[@]} > 0 )); then
  "${kconfig[@]}" --group Icons --key Theme "$icon_theme" || true
  for key in font fixed menuFont toolBarFont activeFont smallestReadableFont; do
    "${kconfig[@]}" --group General --key "$key" \
      'JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0' || true
  done
fi

# The Kvantum file is already reproducible, but this refreshes any engine
# caches when Kvantum is installed.
if command -v kvantummanager >/dev/null 2>&1; then
  QT_QPA_PLATFORM=offscreen kvantummanager --set "$kvantum_theme" >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user set-environment \
    "GTK_THEME=$gtk_theme" \
    'QT_STYLE_OVERRIDE=kvantum' \
    'QT_QPA_PLATFORMTHEME=gtk3' \
    'QT_QPA_PLATFORM=wayland;xcb' 2>/dev/null || true
fi

if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    "GTK_THEME=$gtk_theme" \
    'QT_STYLE_OVERRIDE=kvantum' \
    'QT_QPA_PLATFORMTHEME=gtk3' \
    'QT_QPA_PLATFORM=wayland;xcb' 2>/dev/null || true
fi

printf 'Applied the desktop theme, icons, and JetBrainsMono Nerd Font.\n'
