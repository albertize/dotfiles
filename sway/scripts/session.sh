#!/usr/bin/env bash

# Register a manually started Sway instance as a graphical systemd user
# session so D-Bus services such as xdg-desktop-portal can be activated.
set -u

command -v systemctl >/dev/null 2>&1 || exit 0

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export XDG_SESSION_TYPE=wayland

variables=(
  DISPLAY
  WAYLAND_DISPLAY
  SWAYSOCK
  XDG_CURRENT_DESKTOP
  XDG_SESSION_DESKTOP
  XDG_SESSION_TYPE
  GTK_THEME
  QT_STYLE_OVERRIDE
  QT_QPA_PLATFORMTHEME
  QT_QPA_PLATFORM
)

systemctl --user import-environment "${variables[@]}"
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd "${variables[@]}"
fi
systemctl --user start dotfiles-sway-session.target

cleanup() {
  systemctl --user stop dotfiles-sway-session.target 2>/dev/null || true
}
trap cleanup EXIT INT TERM

if command -v swaymsg >/dev/null 2>&1 && [[ -n ${SWAYSOCK:-} ]]; then
  swaymsg -t subscribe '["shutdown"]' >/dev/null
fi
