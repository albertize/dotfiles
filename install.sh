#!/usr/bin/env bash

# Create symbolic links for the dotfiles regardless of the directory
# from which this script is executed.
set -u

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 1
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
papirus_version=20260801
papirus_archive="$repo_dir/themes/archives/papirus-dark-violet-${papirus_version}.tar.xz"

links=(
  ".bash_profile|$HOME/.bash_profile"
  ".tmux.conf|$HOME/.tmux.conf"
  "alacritty/alacritty.toml|$config_home/alacritty/alacritty.toml"
  "nvim|$config_home/nvim"
  "sway|$config_home/sway"
  "waybar|$config_home/waybar"
  "wofi/config|$config_home/wofi/config"
  "xdg-desktop-portal/sway-portals.conf|$config_home/xdg-desktop-portal/sway-portals.conf"
  "systemd/user/dotfiles-sway-session.target|$config_home/systemd/user/dotfiles-sway-session.target"
  "gtk-3.0|$config_home/gtk-3.0"
  "gtk-4.0|$config_home/gtk-4.0"
  "Kvantum/catppuccin-macchiato-blue|$config_home/Kvantum/catppuccin-macchiato-blue"
  "KDE/color-schemes/CatppuccinMacchiato.colors|$data_home/color-schemes/CatppuccinMacchiato.colors"
  "KDE/color-schemes/GruvboxDark.colors|$data_home/color-schemes/GruvboxDark.colors"
  "environment.d/90-wayland-toolkits.conf|$config_home/environment.d/90-wayland-toolkits.conf"
  "themes/catppuccin-macchiato-blue-standard+default|$data_home/themes/catppuccin-macchiato-blue-standard+default"
  "themes/gruvbox-dark|$data_home/themes/Gruvbox-Dark"
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

install_papirus_icons() {
  local icons_home="$data_home/icons"
  local marker="$icons_home/.dotfiles-papirus-dark-violet.version"
  local answer tmp_dir

  if [[ -r $marker ]] && [[ $(<"$marker") == "$papirus_version" ]] &&
     [[ -d $icons_home/Papirus ]] && [[ -d $icons_home/Papirus-Dark ]]; then
    printf 'Papirus-Dark violet %s is already installed.\n' "$papirus_version"
    return 0
  fi

  if [[ -e $icons_home/Papirus || -L $icons_home/Papirus ||
        -e $icons_home/Papirus-Dark || -L $icons_home/Papirus-Dark ]]; then
    printf 'A Papirus icon theme already exists in "%s". Replace it? [y/N] ' "$icons_home"
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Skipped: Papirus icon theme\n'; return 0 ;;
    esac
  fi

  [[ -r $papirus_archive ]] || {
    printf 'Papirus archive not found: %s\n' "$papirus_archive" >&2
    return 1
  }

  mkdir -p -- "$icons_home" || return 1
  tmp_dir=$(mktemp -d "$icons_home/.papirus.XXXXXX") || return 1
  if ! tar -xJf "$papirus_archive" -C "$tmp_dir"; then
    rm -rf -- "$tmp_dir"
    return 1
  fi

  rm -rf -- "$icons_home/Papirus" "$icons_home/Papirus-Dark"
  mv -- "$tmp_dir/Papirus" "$tmp_dir/Papirus-Dark" "$icons_home/" || {
    rm -rf -- "$tmp_dir"
    return 1
  }
  rmdir -- "$tmp_dir"
  printf '%s\n' "$papirus_version" > "$marker"
  printf 'Installed Papirus-Dark violet %s in %s.\n' "$papirus_version" "$icons_home"
}

install_gruvbox_papirus_icons() {
  local icons_home="$data_home/icons"
  local destination="$icons_home/Papirus-Dark-Gruvbox"
  local marker="$destination/.dotfiles-version"
  local variant_version="${papirus_version}-brown-v2"
  local source relative target theme directory size scale answer
  local -a directories

  if [[ -r $marker ]] && [[ $(<"$marker") == "$variant_version" ]]; then
    printf 'Papirus-Dark Gruvbox %s is already installed.\n' "$variant_version"
    return 0
  fi
  [[ -d $icons_home/Papirus && -d $icons_home/Papirus-Dark ]] || {
    printf 'Papirus must be installed before its Gruvbox folder variant.\n' >&2
    return 1
  }
  if [[ ( -e $destination || -L $destination ) && ! -r $marker ]]; then
    printf 'An existing Papirus-Dark-Gruvbox theme will be replaced. Continue? [y/N] '
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Skipped: Papirus-Dark-Gruvbox icon theme\n'; return 0 ;;
    esac
  fi

  rm -rf -- "$destination"
  mkdir -p -- "$destination"

  # Override only violet folder assets and inherit every other icon. This keeps
  # the variant small while providing the official Papirus brown palette.
  for theme in Papirus Papirus-Dark; do
    while IFS= read -r -d '' source; do
      relative=${source#"$icons_home/$theme/"}
      target="$destination/$relative"
      mkdir -p -- "$(dirname -- "$target")"
      sed -e 's/#7e57c2/#ae8e6c/g' -e 's/#5d399b/#957552/g' \
        -e 's/#2c1e44/#3d3226/g' "$source" > "$target"
    done < <(find -L "$icons_home/$theme" -path '*/places/*.svg' -type f \
      -exec grep -IlZ -E '#(7e57c2|5d399b|2c1e44)' {} + 2>/dev/null || true)
  done

  mapfile -t directories < <(
    find "$destination" -type f -name '*.svg' -printf '%h\n' |
      sed "s|^$destination/||" | LC_ALL=C sort -u
  )
  {
    printf '[Icon Theme]\nName=Papirus-Dark-Gruvbox\n'
    printf 'Comment=Papirus-Dark with Gruvbox brown folders\n'
    printf 'Inherits=Papirus-Dark\nDirectories='
    (IFS=,; printf '%s\n' "${directories[*]}")
    for directory in "${directories[@]}"; do
      size=${directory%%x*}
      scale=1
      [[ $directory == *@2x/* ]] && scale=2
      printf '\n[%s]\nSize=%s\nScale=%s\nContext=Places\nType=Fixed\n' \
        "$directory" "$size" "$scale"
    done
  } > "$destination/index.theme"
  printf '%s\n' "$variant_version" > "$marker"
  printf 'Installed Papirus-Dark Gruvbox %s in %s.\n' "$variant_version" "$destination"
}

remove_legacy_theme_links() {
  local name destination target

  for name in alacritty wofi Kvantum; do
    destination="$config_home/$name"
    [[ -L $destination ]] || continue
    if [[ $(readlink -- "$destination") == "$repo_dir/$name" ]]; then
      rm -f -- "$destination"
      printf 'Removed obsolete directory link: %s\n' "$destination"
    fi
  done

  destination="$config_home/wofi/style.css"
  if [[ -L $destination ]] &&
     [[ $(readlink -- "$destination") == "$repo_dir/wofi/style.css" ]]; then
    rm -f -- "$destination"
    printf 'Removed obsolete stylesheet link: %s\n' "$destination"
  fi

  for name in dunst flameshot swaylock xsettingsd; do
    destination="$config_home/$name"
    [[ -L $destination ]] || continue
    target=$(readlink -- "$destination")
    if [[ $target == "$repo_dir/$name" ]]; then
      rm -f -- "$destination"
      printf 'Removed obsolete theme-specific link: %s\n' "$destination"
    fi
  done

  destination="$config_home/environment.d/90-catppuccin.conf"
  if [[ -L $destination ]] &&
     [[ $(readlink -- "$destination") == "$repo_dir/environment.d/90-catppuccin.conf" ]]; then
    rm -f -- "$destination"
    printf 'Removed obsolete theme-specific link: %s\n' "$destination"
  fi
}

install_gruvbox_kvantum_theme() {
  local directory="$config_home/Kvantum/gruvbox-dark"
  local marker="$directory/.dotfiles-version"
  local version='catppuccin-kvantum-71105d2-gruvbox-v1'
  local source="$repo_dir/Kvantum/catppuccin-macchiato-blue"
  local answer

  if [[ -r $marker ]] && [[ $(<"$marker") == "$version" ]]; then
    printf 'Gruvbox Kvantum theme is already installed.\n'
    return 0
  fi
  if [[ -e $directory || -L $directory ]]; then
    printf 'An existing Gruvbox Kvantum theme will be replaced. Continue? [y/N] '
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Skipped: Gruvbox Kvantum theme\n'; return 0 ;;
    esac
  fi

  rm -rf -- "$directory"
  mkdir -p -- "$directory"
  sed \
    -e 's/Catppuccin-Macchiato-Blue/Gruvbox-Dark/g' \
    -e 's/#24273A/#282828/g' -e 's/#1E2030/#1D2021/g' \
    -e 's/#363A4F/#3C3836/g' -e 's/#494D64/#504945/g' \
    -e 's/#5B6078/#665C54/g' -e 's/#6E738D/#7C6F64/g' \
    -e 's/#939AB7/#A89984/g' -e 's/#A5ADCB/#D5C4A1/g' \
    -e 's/#CAD3F5/#EBDBB2/g' -e 's/#8AADF4/#83A598/g' \
    -e 's/#809FE1/#458588/g' -e 's/#96B4F4/#8EC07C/g' \
    -e 's/#C6A0F6/#D3869B/g' -e 's/#ED8796/#FB4934/g' \
    "$source/catppuccin-macchiato-blue.kvconfig" \
    > "$directory/gruvbox-dark.kvconfig"
  sed \
    -e 's/#24273A/#282828/g' -e 's/#1E2030/#1D2021/g' \
    -e 's/#363A4F/#3C3836/g' -e 's/#494D64/#504945/g' \
    -e 's/#5B6078/#665C54/g' -e 's/#6E738D/#7C6F64/g' \
    -e 's/#939AB7/#A89984/g' -e 's/#A5ADCB/#D5C4A1/g' \
    -e 's/#CAD3F5/#EBDBB2/g' -e 's/#8AADF4/#83A598/g' \
    -e 's/#809FE1/#458588/g' -e 's/#96B4F4/#8EC07C/g' \
    -e 's/#C6A0F6/#D3869B/g' -e 's/#ED8796/#FB4934/g' \
    "$source/catppuccin-macchiato-blue.svg" \
    > "$directory/gruvbox-dark.svg"
  cp -- "$source/LICENSE" "$directory/LICENSE"
  printf '%s\n' "$version" > "$marker"
  printf 'Installed Gruvbox Kvantum theme in %s.\n' "$directory"
}

install_flameshot_runtime_theme() {
  local directory="$config_home/flameshot"
  local destination="$directory/flameshot.ini"
  local marker="$directory/.dotfiles-theme-managed"
  local source="$config_home/dotfiles-theme/flameshot.ini"
  local answer

  [[ -r $source ]] || {
    printf 'Active Flameshot theme not found: %s\n' "$source" >&2
    return 1
  }
  mkdir -p -- "$directory" || return 1
  if [[ -e $destination && ! -e $marker ]]; then
    printf '"%s" already exists. Replace it? [y/N] ' "$destination"
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Skipped: %s\n' "$destination"; return 0 ;;
    esac
  fi
  local font_config="$config_home/dotfiles-font/font.conf"
  local FONT_FAMILY
  [[ -r $font_config ]] || {
    printf 'Active font configuration not found: %s\n' "$font_config" >&2
    return 1
  }
  # shellcheck disable=SC1090
  source "$font_config"
  sed "s/^fontFamily=.*/fontFamily=$FONT_FAMILY/" "$source" > "$destination" || return 1
  printf '%s\n' 'Managed by the global dotfiles profile switchers.' > "$marker"
}

install_wofi_runtime_theme() {
  local directory="$config_home/wofi"
  local destination="$directory/theme.css"
  local marker="$directory/.dotfiles-theme-managed"
  local source="$config_home/dotfiles-theme/wofi.css"
  local answer

  [[ -r $source ]] || {
    printf 'Active Wofi theme not found: %s\n' "$source" >&2
    return 1
  }
  if [[ -e $destination && ! -e $marker ]]; then
    printf '"%s" already exists. Replace it? [y/N] ' "$destination"
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Skipped: %s\n' "$destination"; return 0 ;;
    esac
  fi
  local font_style="$config_home/dotfiles-font/font.css"
  [[ -r $font_style ]] || {
    printf 'Active font stylesheet not found: %s\n' "$font_style" >&2
    return 1
  }
  cat -- "$source" "$repo_dir/wofi/style.css" "$font_style" > "$destination" || return 1
  printf '%s\n' 'Managed by the global dotfiles profile switchers.' > "$marker"
}

install_alacritty_runtime_theme() {
  local directory="$config_home/alacritty"
  local destination="$directory/theme.toml"
  local marker="$directory/.dotfiles-theme-managed"
  local source="$config_home/dotfiles-theme/alacritty.toml"
  local answer

  [[ -r $source ]] || {
    printf 'Active Alacritty theme not found: %s\n' "$source" >&2
    return 1
  }
  if [[ -e $destination && ! -e $marker ]]; then
    printf '"%s" already exists. Replace it? [y/N] ' "$destination"
    read -r answer
    case $answer in
      y|Y) ;;
      *) printf 'Skipped: %s\n' "$destination"; return 0 ;;
    esac
  fi
  cat -- "$source" > "$destination" || return 1
  printf '%s\n' 'Managed by the global dotfiles profile switchers.' > "$marker"
}

install_alacritty_runtime_font() {
  local source="$config_home/dotfiles-font/alacritty.toml"
  local destination="$config_home/alacritty/font.toml"

  [[ -r $source ]] || {
    printf 'Active Alacritty font not found: %s\n' "$source" >&2
    return 1
  }
  cat -- "$source" > "$destination"
}

install_desktop_runtime_configs() {
  local theme_dir="$config_home/dotfiles-theme"
  local font_config="$config_home/dotfiles-font/font.conf"
  local runtime_dir="$config_home/dotfiles-runtime"
  local FONT_FAMILY

  [[ -r $theme_dir/xsettingsd.conf && -r $theme_dir/dunstrc ]] || {
    printf 'Active desktop theme configuration is incomplete.\n' >&2
    return 1
  }
  [[ -r $font_config ]] || {
    printf 'Active font configuration not found: %s\n' "$font_config" >&2
    return 1
  }
  # shellcheck disable=SC1090
  source "$font_config"
  mkdir -p -- "$runtime_dir"
  sed "s/^Gtk\/FontName .*/Gtk\/FontName \"$FONT_FAMILY 10\"/" \
    "$theme_dir/xsettingsd.conf" > "$runtime_dir/xsettingsd.conf"
  sed "s/^[[:space:]]*font = .*/    font = $FONT_FAMILY 10/" \
    "$theme_dir/dunstrc" > "$runtime_dir/dunstrc"
}

initialize_theme_profile() {
  local destination="$config_home/dotfiles-theme"
  local resolved

  if [[ -L $destination ]]; then
    resolved=$(readlink -f -- "$destination" 2>/dev/null || true)
    case $resolved in
      "$repo_dir/themes/profiles/"*)
        printf 'Active theme retained: %s\n' "${resolved##*/}"
        return 0
        ;;
    esac
  fi
  link_file 'themes/profiles/gruvbox' "$destination"
}

initialize_font_profile() {
  local destination="$config_home/dotfiles-font"
  local resolved

  if [[ -L $destination ]]; then
    resolved=$(readlink -f -- "$destination" 2>/dev/null || true)
    case $resolved in
      "$repo_dir/fonts/profiles/"*)
        printf 'Active font retained: %s\n' "${resolved##*/}"
        return 0
        ;;
    esac
  fi
  link_file 'fonts/profiles/meslo-lg' "$destination"
}

status=0
install_papirus_icons || status=1
install_gruvbox_papirus_icons || status=1
remove_legacy_theme_links
for entry in "${links[@]}"; do
  link_file "${entry%%|*}" "${entry#*|}" || status=1
done
install_gruvbox_kvantum_theme || status=1
initialize_theme_profile || status=1
initialize_font_profile || status=1
install_alacritty_runtime_theme || status=1
install_alacritty_runtime_font || status=1
install_desktop_runtime_configs || status=1
install_wofi_runtime_theme || status=1
install_flameshot_runtime_theme || status=1

# This can be disabled during tests or non-interactive installations.
if [[ ${DOTFILES_SKIP_THEME_APPLY:-0} != 1 ]]; then
  "$repo_dir/scripts/apply-theme.sh" || status=1
fi

exit "$status"
