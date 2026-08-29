#!/usr/bin/env bash

# Create symbolic links for the dotfiles regardless of the directory
# from which this script is executed.
set -u

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}

links=(
  ".vimrc|$HOME/.vimrc"
  ".tmux.conf|$HOME/.tmux.conf"
  "alacritty|$config_home/alacritty"
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

exit "$status"
