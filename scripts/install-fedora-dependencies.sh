#!/usr/bin/env bash

# Install the Fedora packages and user-local font required by this repository.
set -euo pipefail

readonly nerd_font_version='3.5.1'
readonly nerd_font_archive='JetBrainsMono.tar.xz'
readonly nerd_font_sha256='04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf'
readonly nerd_font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v${nerd_font_version}/${nerd_font_archive}"
readonly data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
readonly font_dir="$data_home/fonts/JetBrainsMonoNerdFont"
readonly font_version_file="$font_dir/.version"

packages=(
  adwaita-icon-theme
  alacritty
  bluez
  brightnessctl
  cliphist
  curl
  dunst
  flameshot
  fontconfig
  git-core
  gnome-keyring
  gnome-keyring-pam
  gsettings-desktop-schemas
  jq
  kvantum
  libnotify
  libsecret
  NetworkManager
  neovim
  pavucontrol
  pipewire
  qt5-qtbase-gui
  qt6-qtbase-gui
  ripgrep
  sway
  swayidle
  swaylock
  tmux
  tuned-ppd
  util-linux
  waybar
  wireplumber
  wl-clipboard
  wofi
  xdg-desktop-portal
  xdg-desktop-portal-gtk
  xdg-desktop-portal-wlr
  xdg-utils
  xsettingsd
  xz
)

assume_yes=false
check_only=false

usage() {
  printf 'Usage: %s [--check] [--yes]\n' "${0##*/}"
  printf '  --check  Report missing dependencies without changing the system.\n'
  printf '  --yes    Skip the confirmation prompt.\n'
}

while (( $# > 0 )); do
  case $1 in
    --check) check_only=true ;;
    --yes) assume_yes=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ -r /etc/os-release ]] || {
  printf 'Cannot identify the operating system.\n' >&2
  exit 1
}
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == fedora ]] || {
  printf 'This script supports Fedora only; detected: %s\n' "${ID:-unknown}" >&2
  exit 1
}

missing_packages=()
for package in "${packages[@]}"; do
  rpm -q "$package" >/dev/null 2>&1 || missing_packages+=("$package")
done

font_installed=false
if [[ -r $font_version_file ]] &&
   [[ $(<"$font_version_file") == "$nerd_font_version" ]]; then
  font_installed=true
fi

if (( ${#missing_packages[@]} == 0 )); then
  printf 'All Fedora packages are installed.\n'
else
  printf 'Missing Fedora packages:\n'
  printf '  %s\n' "${missing_packages[@]}"
fi

if $font_installed; then
  printf 'JetBrainsMono Nerd Font %s is installed in %s.\n' \
    "$nerd_font_version" "$font_dir"
else
  printf 'JetBrainsMono Nerd Font %s will be installed in %s.\n' \
    "$nerd_font_version" "$font_dir"
fi

if $check_only; then
  if (( ${#missing_packages[@]} > 0 )) || ! $font_installed; then
    exit 1
  fi
  exit 0
fi

if (( ${#missing_packages[@]} > 0 )) || ! $font_installed; then
  if ! $assume_yes; then
    printf 'Continue with package and font installation? [y/N] '
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Cancelled.\n'; exit 0 ;;
    esac
  fi

  if (( ${#missing_packages[@]} > 0 )); then
    dnf_command=(dnf)
    if (( EUID != 0 )); then
      command -v sudo >/dev/null 2>&1 || {
        printf 'sudo is required to install Fedora packages.\n' >&2
        exit 1
      }
      dnf_command=(sudo dnf)
    fi
    "${dnf_command[@]}" install --assumeyes "${missing_packages[@]}"
  fi
fi

if command -v systemctl >/dev/null 2>&1 &&
   systemctl --user cat gnome-keyring-daemon.socket >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now gnome-keyring-daemon.socket
  systemctl --user try-restart xdg-desktop-portal.service 2>/dev/null || true
fi

if ! $font_installed; then
  tmp_dir=$(mktemp -d)
  trap 'rm -rf -- "$tmp_dir"' EXIT

  curl --fail --location --silent --show-error \
    "$nerd_font_url" --output "$tmp_dir/$nerd_font_archive"
  printf '%s  %s\n' "$nerd_font_sha256" "$tmp_dir/$nerd_font_archive" |
    sha256sum --check --status

  install -d -m 0755 -- "$font_dir"
  rm -f -- "$font_dir"/*.ttf
  tar -xJf "$tmp_dir/$nerd_font_archive" -C "$font_dir" \
    JetBrainsMonoNerdFont-Regular.ttf \
    JetBrainsMonoNerdFont-Bold.ttf \
    JetBrainsMonoNerdFont-Italic.ttf \
    JetBrainsMonoNerdFont-BoldItalic.ttf
  printf '%s\n' "$nerd_font_version" > "$font_version_file"
  fc-cache -f "$font_dir" >/dev/null
fi

printf 'Fedora dependencies installed successfully.\n'
printf 'Run install.sh and then scripts/configure-tty-login.sh to enable the tty1 login.\n'
