#!/usr/bin/env bash

# Create symbolic links for the dotfiles regardless of the directory
# from which this script is executed.
set -u

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}

links=(
  ".tmux.conf|$HOME/.tmux.conf"
  "alacritty|$config_home/alacritty"
  "nvim|$config_home/nvim"
  "sway|$config_home/sway"
  "waybar|$config_home/waybar"
  "wofi|$config_home/wofi"
  "swaylock|$config_home/swaylock"
  "dunst|$config_home/dunst"
  "flameshot|$config_home/flameshot"
  "xdg-desktop-portal/sway-portals.conf|$config_home/xdg-desktop-portal/sway-portals.conf"
  "systemd/user/dotfiles-sway-session.target|$config_home/systemd/user/dotfiles-sway-session.target"
  "gtk-3.0|$config_home/gtk-3.0"
  "gtk-4.0|$config_home/gtk-4.0"
  "Kvantum|$config_home/Kvantum"
  "environment.d/90-catppuccin.conf|$config_home/environment.d/90-catppuccin.conf"
  "themes/catppuccin-macchiato-blue-standard+default|$data_home/themes/catppuccin-macchiato-blue-standard+default"
  "media|$data_home/backgrounds/dotfiles"
)

link_file() {
  local relative_source=$1
  local destination=$2
  local source="$repo_dir/$relative_source"
  local answer

  if [[ ! -e "$source" ]]; then
    printf 'Source not found: %s\n' "$source" >&2
    return 1
  fi

  # Do nothing if the existing link already points to the correct file.
  if [[ -e "$destination" && "$destination" -ef "$source" ]]; then
    printf 'Already linked: %s\n' "$destination"
    return 0
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    printf '"%s" already exists. Replace it? [y/N] ' "$destination"
    read -r answer
    case $answer in
      y|Y) rm -rf -- "$destination" || return 1 ;;
      *)   printf 'Skipped: %s\n' "$destination"; return 0 ;;
    esac
  fi

  mkdir -p -- "$(dirname -- "$destination")" || return 1
  ln -s -- "$source" "$destination" || return 1
  printf 'Created: %s -> %s\n' "$destination" "$source"
}

status=0
for entry in "${links[@]}"; do
  link_file "${entry%%|*}" "${entry#*|}" || status=1
done

# This can be disabled during tests or non-interactive installations.
if [[ ${DOTFILES_SKIP_THEME_APPLY:-0} != 1 ]]; then
  "$repo_dir/scripts/apply-theme.sh" || status=1
fi

exit "$status"
