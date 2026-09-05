#!/usr/bin/env bash

# Apply the theme to the current user environment without relying on a
# desktop-specific settings service.
set -u

gtk_theme='catppuccin-macchiato-blue-standard+default'
kvantum_theme='catppuccin-macchiato-blue'

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

printf 'Applied Catppuccin Macchiato to GTK and Qt.\n'
