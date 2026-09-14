#!/usr/bin/env bash

# Select a repository-managed desktop theme, interactively or by profile name.
set -euo pipefail

script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
repo_dir=$(CDPATH= cd -- "$(dirname -- "$script_path")/../.." && pwd -P)
profiles_dir="$repo_dir/themes/profiles"

usage() {
  printf 'Usage: %s [--list | THEME]\n' "${0##*/}"
}

list_themes() {
  local profile DISPLAY_NAME
  for profile in "$profiles_dir"/*; do
    [[ -d $profile && -r $profile/theme.conf ]] || continue
    DISPLAY_NAME=''
    # shellcheck disable=SC1090
    source "$profile/theme.conf"
    printf '%s\t%s\n' "${profile##*/}" "$DISPLAY_NAME"
  done
}

build_menu() {
  local profile color line DISPLAY_NAME PREVIEW_COLORS
  local -a colors

  menu_lines=()
  menu_themes=()
  for profile in "$profiles_dir"/*; do
    [[ -d $profile && -r $profile/theme.conf ]] || continue
    DISPLAY_NAME=''
    PREVIEW_COLORS=''
    # shellcheck disable=SC1090
    source "$profile/theme.conf"
    read -r -a colors <<< "$PREVIEW_COLORS"
    (( ${#colors[@]} > 0 )) || {
      printf 'Theme has no preview palette: %s\n' "${profile##*/}" >&2
      return 1
    }

    line=$(printf '<b>%-24s</b>' "$DISPLAY_NAME")
    for color in "${colors[@]}"; do
      [[ $color =~ ^#[0-9A-Fa-f]{6}$ ]] || {
        printf 'Invalid preview color in theme %s: %s\n' \
          "${profile##*/}" "$color" >&2
        return 1
      }
      line+="<span foreground=\"$color\">■■</span>"
    done
    menu_lines+=("$line")
    menu_themes+=("${profile##*/}")
  done
}

case ${1:-} in
  -h|--help) usage; exit 0 ;;
  --list) list_themes; exit 0 ;;
  '')
    command -v wofi >/dev/null 2>&1 || {
      printf 'Wofi is required for interactive theme selection.\n' >&2
      usage >&2
      exit 1
    }
    build_menu
    selection=$(printf '%s\n' "${menu_lines[@]}" | wofi --dmenu \
      --allow-markup --hide-search --cache-file /dev/null \
      --width 520 --height 96 --location center)
    [[ -n $selection ]] || exit 0

    theme=''
    for index in "${!menu_lines[@]}"; do
      if [[ $selection == "${menu_lines[index]}" ]]; then
        theme=${menu_themes[index]}
        break
      fi
    done
    # Some Wofi versions return rendered text rather than the original markup.
    if [[ -z $theme ]]; then
      plain_selection=$(sed 's/<[^>]*>//g' <<< "$selection")
      for profile in "$profiles_dir"/*; do
        [[ -r $profile/theme.conf ]] || continue
        DISPLAY_NAME=''
        # shellcheck disable=SC1090
        source "$profile/theme.conf"
        if [[ $plain_selection == "$DISPLAY_NAME"* ]]; then
          theme=${profile##*/}
          break
        fi
      done
    fi
    [[ -n $theme ]] || {
      printf 'Could not identify selected theme.\n' >&2
      exit 1
    }
    ;;
  *) theme=$1 ;;
esac

# Accept the common misspelling without making it the canonical profile name.
[[ $theme == grouvbox ]] && theme=gruvbox
exec "$repo_dir/scripts/apply-theme.sh" "$theme"
