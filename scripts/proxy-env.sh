#!/usr/bin/env bash
# Shared proxy environment resolver.
#
# Chromium-based applications pick the proxy source from the detected desktop
# (net/proxy_resolution/proxy_config_service_linux.cc): GNOME-like sessions read
# the org.gnome.system.proxy GSettings schema, KDE reads kioslaverc, and every
# other session - including Sway - falls back to the proxy environment
# variables. Under Sway those variables are therefore the legitimate channel,
# and this helper is the single place that computes them.
#
# The values must not be frozen into the session environment at login. A VPN is
# connected and disconnected while the session keeps running, and Chromium does
# not fall back to a direct connection when a configured PAC URL is unreachable:
# every request fails instead. Callers must evaluate this helper at process
# start-up, which is what scripts/with-proxy does.
#
# Site-specific values are deliberately not stored in this repository. Configure
# them in "$XDG_CONFIG_HOME/proxy-env.conf" (see proxy-env.conf.example) or pass
# them through the PROXY_ENV_* variables. Without configuration the helper
# reports that no proxy is available, so a machine outside a corporate network
# needs no extra setup.
#
# Usage:
#   source proxy-env.sh
#   proxy_env_apply   # exports the variables when the proxy is reachable,
#                     # unsets them otherwise
set -u

_proxy_env_config="${XDG_CONFIG_HOME:-$HOME/.config}/proxy-env.conf"
if [[ -r "$_proxy_env_config" ]]; then
  # shellcheck source=/dev/null
  source -- "$_proxy_env_config"
fi
unset _proxy_env_config

PROXY_ENV_HOST=${PROXY_ENV_HOST:-}
PROXY_ENV_PORT=${PROXY_ENV_PORT:-8080}
PROXY_ENV_PAC_URL=${PROXY_ENV_PAC_URL:-}
PROXY_ENV_NO_PROXY=${PROXY_ENV_NO_PROXY:-localhost,127.0.0.1,::1}
if [[ -n "$PROXY_ENV_HOST" ]]; then
  PROXY_ENV_URL=${PROXY_ENV_URL:-http://${PROXY_ENV_HOST}:${PROXY_ENV_PORT}}
else
  PROXY_ENV_URL=${PROXY_ENV_URL:-}
fi

# The proxy is usable only when it resolves *and* the port answers. The TCP
# probe avoids false positives from cached DNS or split-horizon resolvers that
# keep answering for internal names while the tunnel is down.
proxy_env_available() {
  [[ -n "$PROXY_ENV_HOST" ]] || return 1
  command -v getent >/dev/null 2>&1 || return 1
  getent hosts -- "$PROXY_ENV_HOST" >/dev/null 2>&1 || return 1
  timeout 2 bash -c "exec 3<>/dev/tcp/${PROXY_ENV_HOST}/${PROXY_ENV_PORT}" 2>/dev/null
}

proxy_env_unset() {
  unset http_proxy https_proxy ftp_proxy all_proxy no_proxy auto_proxy
  unset HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY NO_PROXY
}

proxy_env_export() {
  export http_proxy="$PROXY_ENV_URL"
  export https_proxy="$PROXY_ENV_URL"
  export no_proxy="$PROXY_ENV_NO_PROXY"
  export HTTP_PROXY="$PROXY_ENV_URL"
  export HTTPS_PROXY="$PROXY_ENV_URL"
  export NO_PROXY="$PROXY_ENV_NO_PROXY"

  # Chromium reads a PAC URL from auto_proxy and gives it precedence over the
  # fixed servers above. Publishing the PAC keeps the split between proxied and
  # direct destinations identical to the GSettings configuration that GNOME-like
  # sessions use, instead of forcing every host through the proxy.
  if [[ -n "$PROXY_ENV_PAC_URL" ]]; then
    export auto_proxy="$PROXY_ENV_PAC_URL"
  fi
}

proxy_env_apply() {
  if proxy_env_available; then
    proxy_env_export
    return 0
  fi
  proxy_env_unset
  return 1
}
