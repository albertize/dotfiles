#!/usr/bin/env bash

# Select repository-managed desktop themes and fonts from nested Wofi menus.
set -euo pipefail

script_path=$(readlink -f -- "${BASH_SOURCE[0]}")
repo_dir=$(CDPATH= cd -- "$(dirname -- "$script_path")/../.." && pwd -P)
themes_dir="$repo_dir/themes/profiles"
fonts_dir="$repo_dir/fonts/profiles"
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
active_theme="$config_home/dotfiles-theme"
active_font="$config_home/dotfiles-font"
runtime_dir=${XDG_RUNTIME_DIR:-"/tmp/dotfiles-$UID"}
appearance_style="$runtime_dir/dotfiles-appearance-menu.css"

usage() {
  printf 'Usage: %s [--list | THEME | --list-fonts | --font FONT]\n' "${0##*/}"
}

list_themes() {
  local profile DISPLAY_NAME
  for profile in "$themes_dir"/*; do
    [[ -d $profile && -r $profile/theme.conf ]] || continue
    DISPLAY_NAME=''
    # shellcheck disable=SC1090
    source "$profile/theme.conf"
    printf '%s\t%s\n' "${profile##*/}" "$DISPLAY_NAME"
  done
}

list_fonts() {
  local profile FONT_DISPLAY_NAME FONT_FAMILY
  for profile in "$fonts_dir"/*; do
    [[ -d $profile && -r $profile/font.conf ]] || continue
    FONT_DISPLAY_NAME=''
    FONT_FAMILY=''
    # shellcheck disable=SC1090
    source "$profile/font.conf"
    printf '%s\t%s\t%s\n' "${profile##*/}" "$FONT_DISPLAY_NAME" "$FONT_FAMILY"
  done
}

active_profile_name() {
  local active=$1
  local fallback=$2
  if [[ -L $active ]]; then
    basename -- "$(readlink -f -- "$active")"
  else
    printf '%s\n' "$fallback"
  fi
}

canonical_font_name() {
  local font=${1,,}
  case $font in
    meslo|meslolg|meslo-lgs) font=meslo-lg ;;
    jetbrains|jetbrainsmono|jetbrains-mono) font=jetbrains-mono ;;
  esac
  printf '%s\n' "$font"
}

menu_height() {
  local count=$1
  local height=$(( count * 42 + 58 ))
  (( height < 142 )) && height=142
  (( height > 520 )) && height=520
  printf '%s\n' "$height"
}

prepare_appearance_style() {
  local source_style="$config_home/wofi/theme.css"
  local temporary_style

  [[ -r $source_style ]] || {
    printf 'Wofi theme not found: %s\n' "$source_style" >&2
    return 1
  }
  mkdir -p -- "$runtime_dir"
  temporary_style=$(mktemp "$runtime_dir/.appearance-menu.XXXXXX")
  cat -- "$source_style" > "$temporary_style"
  cat >> "$temporary_style" <<'EOF'

/* Compact layout specific to the appearance selector. */
#outer-box {
  margin: 8px;
}

#input {
  min-height: 28px;
  margin-bottom: 10px;
  padding: 0 10px;
}

#entry {
  min-height: 34px;
  margin: 4px 0;
  padding: 0 12px;
}

#text {
  padding: 0 2px;
}
EOF
  mv -f -- "$temporary_style" "$appearance_style"
}

select_category_menu() {
  local theme font theme_config font_config selection plain_selection
  local DISPLAY_NAME FONT_DISPLAY_NAME theme_line font_line

  theme=$(active_profile_name "$active_theme" gruvbox)
  font=$(active_profile_name "$active_font" meslo-lg)
  theme_config="$themes_dir/$theme/theme.conf"
  font_config="$fonts_dir/$font/font.conf"
  DISPLAY_NAME=$theme
  FONT_DISPLAY_NAME=$font
  if [[ -r $theme_config ]]; then
    # shellcheck disable=SC1090
    source "$theme_config"
  fi
  if [[ -r $font_config ]]; then
    # shellcheck disable=SC1090
    source "$font_config"
  fi

  theme_line=$(printf '󰏘  <b>%-9s</b>  %s  ' 'Theme' "$DISPLAY_NAME")
  font_line=$(printf '  <b>%-9s</b>  %s  ' 'Font' "$FONT_DISPLAY_NAME")
  selection=$(printf '%s\n' "$theme_line" "$font_line" | wofi --dmenu \
    --allow-markup --hide-search --cache-file /dev/null --prompt '󰏘  Appearance' \
    --style "$appearance_style" --width 680 --height 124 --location center) || return 1
  [[ -n $selection ]] || return 1

  case $selection in
    "$theme_line") printf 'themes\n'; return 0 ;;
    "$font_line") printf 'fonts\n'; return 0 ;;
  esac
  plain_selection=$(sed 's/<[^>]*>//g' <<< "$selection")
  case $plain_selection in
    *Theme*) printf 'themes\n' ;;
    *Font*) printf 'fonts\n' ;;
    *) printf 'Could not identify selected appearance category.\n' >&2; return 1 ;;
  esac
}

select_theme_menu() {
  local profile color line selection plain_selection index height
  local DISPLAY_NAME PREVIEW_COLORS current_theme
  local -a colors menu_lines=() menu_plain=() menu_profiles=()

  current_theme=$(active_profile_name "$active_theme" gruvbox)
  for profile in "$themes_dir"/*; do
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

    line=$(printf '󰏘  <b>%-22s</b>  ' "$DISPLAY_NAME")
    for color in "${colors[@]}"; do
      [[ $color =~ ^#[0-9A-Fa-f]{6}$ ]] || {
        printf 'Invalid preview color in theme %s: %s\n' \
          "${profile##*/}" "$color" >&2
        return 1
      }
      line+="<span foreground=\"$color\">●</span> "
    done
    [[ ${profile##*/} == "$current_theme" ]] && line+='  '
    menu_lines+=("$line")
    menu_profiles+=("${profile##*/}")
  done

  for line in "${menu_lines[@]}"; do
    menu_plain+=("$(sed 's/<[^>]*>//g' <<< "$line")")
  done
  height=$(menu_height "${#menu_lines[@]}")
  selection=$(printf '%s\n' "${menu_lines[@]}" | wofi --dmenu \
    --allow-markup --cache-file /dev/null --prompt '󰏘  Select theme' \
    --style "$appearance_style" --width 620 --height "$height" \
    --location center) || return 1
  [[ -n $selection ]] || return 1
  plain_selection=$(sed 's/<[^>]*>//g' <<< "$selection")

  for index in "${!menu_lines[@]}"; do
    if [[ $selection == "${menu_lines[index]}" ||
          $plain_selection == "${menu_plain[index]}" ]]; then
      printf '%s\n' "${menu_profiles[index]}"
      return 0
    fi
  done
  printf 'Could not identify selected theme.\n' >&2
  return 1
}

select_font_menu() {
  local profile line selection plain_selection index height
  local FONT_DISPLAY_NAME FONT_FAMILY current_font
  local -a menu_lines=() menu_plain=() menu_profiles=()

  current_font=$(active_profile_name "$active_font" meslo-lg)
  for profile in "$fonts_dir"/*; do
    [[ -d $profile && -r $profile/font.conf ]] || continue
    FONT_DISPLAY_NAME=''
    FONT_FAMILY=''
    # shellcheck disable=SC1090
    source "$profile/font.conf"
    line=$(printf '  <b>%-30s</b>  %s' "$FONT_DISPLAY_NAME" "$FONT_FAMILY")
    [[ ${profile##*/} == "$current_font" ]] && line+='  '
    menu_lines+=("$line")
    menu_profiles+=("${profile##*/}")
  done

  for line in "${menu_lines[@]}"; do
    menu_plain+=("$(sed 's/<[^>]*>//g' <<< "$line")")
  done
  height=$(menu_height "${#menu_lines[@]}")
  selection=$(printf '%s\n' "${menu_lines[@]}" | wofi --dmenu \
    --allow-markup --cache-file /dev/null --prompt '  Select font' \
    --style "$appearance_style" --width 720 --height "$height" \
    --location center) || return 1
  [[ -n $selection ]] || return 1
  plain_selection=$(sed 's/<[^>]*>//g' <<< "$selection")

  for index in "${!menu_lines[@]}"; do
    if [[ $selection == "${menu_lines[index]}" ||
          $plain_selection == "${menu_plain[index]}" ]]; then
      printf '%s\n' "${menu_profiles[index]}"
      return 0
    fi
  done
  printf 'Could not identify selected font.\n' >&2
  return 1
}

apply_font() {
  local font profile required FONT_DISPLAY_NAME FONT_FAMILY theme
  font=$(canonical_font_name "$1")
  profile="$fonts_dir/$font"
  for required in font.conf font.css sway.conf alacritty.toml; do
    [[ -r $profile/$required ]] || {
      printf 'Unknown or incomplete font profile: %s\nAvailable fonts:\n' "$font" >&2
      list_fonts >&2
      return 2
    }
  done

  # shellcheck disable=SC1090
  source "$profile/font.conf"
  command -v fc-list >/dev/null 2>&1 || {
    printf 'fontconfig is required to select a font.\n' >&2
    return 1
  }
  if ! fc-list --format '%{family}\n' | tr ',' '\n' |
       sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
       grep -Fqx -- "$FONT_FAMILY"; then
    printf '%s is not installed; run scripts/install-fedora-dependencies.sh.\n' \
      "$FONT_DISPLAY_NAME" >&2
    return 1
  fi
  [[ -L $active_theme ]] || {
    printf 'Active theme not found; run install.sh first.\n' >&2
    return 1
  }
  theme=$(active_profile_name "$active_theme" gruvbox)
  export DOTFILES_FONT_PROFILE=$font
  exec "$repo_dir/scripts/apply-theme.sh" "$theme"
}

case $# in
  0)
    command -v wofi >/dev/null 2>&1 || {
      printf 'Wofi is required for interactive appearance selection.\n' >&2
      usage >&2
      exit 1
    }
    prepare_appearance_style
    category=$(select_category_menu) || exit 0
    case $category in
      themes)
        theme=$(select_theme_menu) || exit 0
        exec "$repo_dir/scripts/apply-theme.sh" "$theme"
        ;;
      fonts)
        font=$(select_font_menu) || exit 0
        apply_font "$font"
        ;;
    esac
    ;;
  1)
    case $1 in
      -h|--help) usage ;;
      --list) list_themes ;;
      --list-fonts) list_fonts ;;
      *)
        theme=$1
        [[ $theme == grouvbox ]] && theme=gruvbox
        exec "$repo_dir/scripts/apply-theme.sh" "$theme"
        ;;
    esac
    ;;
  2)
    case $1 in
      --font) apply_font "$2" ;;
      *) usage >&2; exit 2 ;;
    esac
    ;;
  *) usage >&2; exit 2 ;;
esac
