#!/usr/bin/env bash

# Run the configured VPN script with administrator privileges.
set -u

script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
repo_dir=$(CDPATH= cd -- "$(dirname -- "$script_path")/../.." && pwd -P)

readonly menu_width=400
readonly menu_height=110
readonly connect_entry='󰖂  Connect VPN'
readonly disconnect_entry='󰖂  Disconnect VPN'
readonly config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
readonly askpass="$config_home/waybar/scripts/wofi-askpass.sh"
readonly runtime_dir=${XDG_RUNTIME_DIR:-"/tmp/waybar-$UID"}

notify() {
  local urgency=$1
  local message=$2

  if command -v notify-send >/dev/null 2>&1; then
    notify-send --urgency="$urgency" 'VPN' "$message"
  else
    printf 'VPN: %s\n' "$message" >&2
  fi
}

refresh_waybar() {
  pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

for command in flock pgrep pkill sudo wofi; do
  command -v "$command" >/dev/null 2>&1 || {
    notify critical "$command is not installed."
    exit 1
  }
done
[[ -x $askpass ]] || {
  notify critical "Sudo askpass helper is not executable: $askpass"
  exit 1
}

if source -- "$repo_dir/scripts/proxy-env.sh" 2>/dev/null; then
  proxy_env_apply || true
fi

manager_environment=''
if command -v systemctl >/dev/null 2>&1; then
  manager_environment=$(LC_ALL=C systemctl --user show-environment 2>/dev/null || true)
fi
vpn_script=${VPN_SCRIPT:-}
if [[ -z $vpn_script ]]; then
  vpn_script=$(printf '%s\n' "$manager_environment" |
    awk -v prefix='VPN_SCRIPT=' \
      'index($0, prefix) == 1 { print substr($0, length(prefix) + 1); exit }')
fi

mkdir -p -- "$runtime_dir" || exit 1
exec 9>"$runtime_dir/vpn-menu.lock"
flock -n 9 || exit 0

if pgrep -x openconnect >/dev/null 2>&1; then
  choice=$(printf '%s\n' "$disconnect_entry" |
    wofi --dmenu --prompt 'VPN' --width "$menu_width" --height "$menu_height") || exit 0
  [[ $choice == "$disconnect_entry" ]] || exit 0

  if SUDO_ASKPASS="$askpass" sudo --askpass -- "$(command -v pkill)" -x openconnect \
      >/dev/null 2>&1; then
    notify normal 'VPN disconnected.'
  else
    notify critical 'Unable to stop OpenConnect.'
  fi
else
  [[ -n $vpn_script ]] || {
    notify critical 'VPN_SCRIPT is not configured. See the VPN section in README.md.'
    exit 1
  }
  [[ $vpn_script == /* && -f $vpn_script && -x $vpn_script ]] || {
    notify critical 'VPN_SCRIPT must be an absolute path to an executable regular file.'
    exit 1
  }

  choice=$(printf '%s\n' "$connect_entry" |
    wofi --dmenu --prompt 'VPN' --width "$menu_width" --height "$menu_height") || exit 0
  [[ $choice == "$connect_entry" ]] || exit 0

  if SUDO_ASKPASS="$askpass" sudo --askpass --preserve-env -- "$vpn_script" \
      >/dev/null 2>&1; then
    notify normal 'VPN script completed.'
  else
    notify critical 'The VPN script failed.'
  fi
fi
refresh_waybar
