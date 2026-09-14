#!/usr/bin/env bash

# Launch Flameshot through its normal XDG path. This is important because the
# graphical process may be D-Bus activated instead of inheriting this command's
# temporary environment.
set -u

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
config="$config_home/flameshot/flameshot.ini"
marker="$config_home/flameshot/.dotfiles-theme-managed"

[[ -r $config && -e $marker ]] || {
  printf 'Managed Flameshot configuration not found; run install.sh first.\n' >&2
  exit 1
}

exec flameshot "$@"
