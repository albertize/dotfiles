#!/usr/bin/env bash

# Print the OpenConnect process state in Waybar's JSON format.
set -u

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

if pgrep -x openconnect >/dev/null 2>&1; then
  jq -cn \
    --arg text '󰖂' \
    --arg class 'connected' \
    --arg tooltip $'OpenConnect is running\nClick to disconnect it' \
    '{text: $text, class: $class, tooltip: $tooltip}'
elif [[ -z $vpn_script ]]; then
  jq -cn \
    --arg text '󰖂' \
    --arg class 'unconfigured' \
    --arg tooltip $'VPN not configured\nSet VPN_SCRIPT to an executable absolute path' \
    '{text: $text, class: $class, tooltip: $tooltip}'
elif [[ $vpn_script != /* || ! -f $vpn_script || ! -x $vpn_script ]]; then
  jq -cn \
    --arg text '󰖂' \
    --arg class 'error' \
    --arg tooltip $'VPN configuration error\nVPN_SCRIPT is not an executable absolute path' \
    '{text: $text, class: $class, tooltip: $tooltip}'
else
  jq -cn \
    --arg text '󰖂' \
    --arg class 'disconnected' \
    --arg tooltip $'OpenConnect is not running\nClick to run the configured VPN script' \
    '{text: $text, class: $class, tooltip: $tooltip}'
fi
