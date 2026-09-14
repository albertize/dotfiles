#!/usr/bin/env bash

# Select and apply a repository-managed desktop theme without a full desktop
# settings service. With no argument, keep the current profile or use Gruvbox.
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
pi_agent_dir=${PI_CODING_AGENT_DIR:-"$HOME/.pi/agent"}
pi_settings="$pi_agent_dir/settings.json"
alacritty_theme="$config_home/alacritty/theme.toml"
alacritty_marker="$config_home/alacritty/.dotfiles-theme-managed"
wofi_theme="$config_home/wofi/theme.css"
wofi_marker="$config_home/wofi/.dotfiles-theme-managed"
flameshot_config="$config_home/flameshot/flameshot.ini"
flameshot_marker="$config_home/flameshot/.dotfiles-theme-managed"
active_theme="$config_home/dotfiles-theme"
theme=${1:-}

if [[ -z $theme && -L $active_theme ]]; then
  theme=$(basename -- "$(readlink -f -- "$active_theme")")
fi
theme=${theme:-gruvbox}
[[ $theme == grouvbox ]] && theme=gruvbox
profile="$repo_dir/themes/profiles/$theme"

[[ -d $profile && -r $profile/theme.conf ]] || {
  printf 'Unknown theme: %s\nAvailable themes:\n' "$theme" >&2
  find "$repo_dir/themes/profiles" -mindepth 1 -maxdepth 1 -type d \
    -printf '  %f\n' | LC_ALL=C sort >&2
  exit 2
}
required_files=(
  alacritty.toml dunstrc nvim.lua pi.json sway.conf swaylock.conf tmux.conf
  flameshot.ini waybar.css waybar.sed wofi.css xsettingsd.conf
)
for required in "${required_files[@]}"; do
  [[ -r $profile/$required ]] || {
    printf 'Theme profile is incomplete: %s\n' "$profile/$required" >&2
    exit 1
  }
done

# The profiles are repository-managed and contain quoted scalar values only.
# shellcheck disable=SC1090
source "$profile/theme.conf"
: "${DISPLAY_NAME:?}" "${GTK_THEME:?}" "${GSETTINGS_ACCENT:?}" \
  "${ICON_THEME:?}" "${QT_STYLE_OVERRIDE+x}" "${KVANTUM_THEME+x}" \
  "${KDE_COLOR_SCHEME:?}" "${KDE_ACCENT:?}" "${PREVIEW_COLORS:?}" \
  "${VSCODE_EXTENSION:?}" "${VSCODE_THEME:?}" "${WALLPAPER:?}"
data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
wallpaper="$data_home/backgrounds/dotfiles/$WALLPAPER"
[[ -r $wallpaper ]] || {
  printf 'Theme wallpaper not found: %s\n' "$wallpaper" >&2
  exit 1
}
if [[ ! -e $alacritty_marker || ! -e $wofi_marker || ! -e $flameshot_marker ]]; then
  printf 'Runtime themes are not initialized; run install.sh first.\n' >&2
  exit 1
fi
if [[ -n $KVANTUM_THEME ]] &&
   [[ ! -r $config_home/Kvantum/$KVANTUM_THEME/$KVANTUM_THEME.kvconfig ]]; then
  printf 'Kvantum theme is not installed: %s\n' "$KVANTUM_THEME" >&2
  printf 'Run install.sh before applying this profile.\n' >&2
  exit 1
fi
if [[ ! -r $data_home/color-schemes/$KDE_COLOR_SCHEME.colors ]]; then
  printf 'KDE color scheme is not installed: %s\n' "$KDE_COLOR_SCHEME" >&2
  printf 'Run install.sh before applying this profile.\n' >&2
  exit 1
fi
if [[ -e $pi_settings ]]; then
  command -v jq >/dev/null 2>&1 || {
    printf 'jq is required to preserve Pi settings.\n' >&2
    exit 1
  }
  jq empty "$pi_settings" || {
    printf 'Pi settings are not valid JSON: %s\n' "$pi_settings" >&2
    exit 1
  }
fi

mkdir -p -- "$config_home"
if [[ -e $active_theme && ! -L $active_theme ]]; then
  printf 'Refusing to replace non-symlink theme path: %s\n' "$active_theme" >&2
  exit 1
fi
temporary_link="$config_home/.dotfiles-theme.$$"
trap 'rm -f -- "$temporary_link"' EXIT
ln -s -- "$profile" "$temporary_link"
mv -Tf -- "$temporary_link" "$active_theme"
trap - EXIT

# Keep the imported path stable and modify its contents so Alacritty's file
# watcher reloads colors in existing windows, including windows running tmux.
cat -- "$profile/alacritty.toml" > "$alacritty_theme"
cat -- "$profile/wofi.css" "$repo_dir/wofi/style.css" > "$wofi_theme"
cat -- "$profile/flameshot.ini" > "$flameshot_config"

# Pi watches the active custom theme file and reloads it in running sessions.
mkdir -p -- "$pi_agent_dir/themes"
pi_theme="$pi_agent_dir/themes/dotfiles.json"
if [[ ! -r $pi_theme ]] || ! cmp -s -- "$profile/pi.json" "$pi_theme"; then
  temporary_pi_theme="$pi_agent_dir/themes/.dotfiles.json.$$"
  cp -- "$profile/pi.json" "$temporary_pi_theme"
  mv -f -- "$temporary_pi_theme" "$pi_theme"
fi
if [[ -e $pi_settings ]]; then
  temporary_pi_settings="$pi_agent_dir/.settings.json.$$"
  jq '.theme = "dotfiles"' "$pi_settings" > "$temporary_pi_settings"
  chmod --reference="$pi_settings" "$temporary_pi_settings"
  mv -f -- "$temporary_pi_settings" "$pi_settings"
else
  printf '{\n  "theme": "dotfiles"\n}\n' > "$pi_settings"
fi

# VS Code reloads workbench.colorTheme when its settings file changes. Update
# only installations that have the profile's corresponding extension enabled.
vscode_installations=(
  'code|Code'
  'code-insiders|Code - Insiders'
  'codium|VSCodium'
)
for installation in "${vscode_installations[@]}"; do
  vscode_command=${installation%%|*}
  vscode_config=${installation#*|}
  command -v "$vscode_command" >/dev/null 2>&1 || continue
  if "$vscode_command" --list-extensions 2>/dev/null |
     grep -Fqix "$VSCODE_EXTENSION"; then
    command -v python3 >/dev/null 2>&1 || {
      printf 'python3 is required to synchronize the VS Code theme.\n' >&2
      exit 1
    }
    "$repo_dir/scripts/update-vscode-theme.py" \
      "$config_home/$vscode_config/User/settings.json" "$VSCODE_THEME"
  fi
done

if command -v gsettings >/dev/null 2>&1 &&
   gsettings list-schemas | grep -qx 'org.gnome.desktop.interface'; then
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" || true
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
  if gsettings writable org.gnome.desktop.interface accent-color >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface accent-color "$GSETTINGS_ACCENT" || true
  fi
  gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" || true
  gsettings set org.gnome.desktop.interface cursor-theme 'Adwaita' || true
  gsettings set org.gnome.desktop.interface font-name 'JetBrainsMono Nerd Font 10' || true
fi

kconfig=()
if command -v kwriteconfig6 >/dev/null 2>&1; then
  kconfig=(kwriteconfig6 --file kdeglobals --notify)
elif command -v kwriteconfig5 >/dev/null 2>&1; then
  kconfig=(kwriteconfig5 --file kdeglobals --notify)
fi
if (( ${#kconfig[@]} > 0 )); then
  kde_scheme_file="$data_home/color-schemes/$KDE_COLOR_SCHEME.colors"
  section=
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    case $line in
      \[*\]) section=${line#\[}; section=${section%\]} ;;
      *=*)
        case $section in
          ColorEffects:*|Colors:*|KDE|WM)
            key=${line%%=*}
            value=${line#*=}
            "${kconfig[@]}" --group "$section" --key "$key" "$value" || true
            ;;
        esac
        ;;
    esac
  done < "$kde_scheme_file"

  "${kconfig[@]}" --group Icons --key Theme "$ICON_THEME" || true
  "${kconfig[@]}" --group General --key ColorScheme "$KDE_COLOR_SCHEME" || true
  "${kconfig[@]}" --group General --key AccentColor "$KDE_ACCENT" || true
  "${kconfig[@]}" --group General --key LastUsedCustomAccentColor "$KDE_ACCENT" || true
  "${kconfig[@]}" --group General --key widgetStyle "$QT_STYLE_OVERRIDE" || true
  "${kconfig[@]}" --group General --key ColorSchemeHash --delete '' || true
  for key in font fixed menuFont toolBarFont activeFont smallestReadableFont; do
    "${kconfig[@]}" --group General --key "$key" \
      'JetBrainsMono Nerd Font,10,-1,5,50,0,0,0,0,0' || true
  done
fi

if [[ -n $KVANTUM_THEME ]] && command -v kvantummanager >/dev/null 2>&1; then
  QT_QPA_PLATFORM=offscreen kvantummanager --set "$KVANTUM_THEME" >/dev/null 2>&1 || true
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload 2>/dev/null || true
  systemctl --user set-environment \
    "GTK_THEME=$GTK_THEME" \
    'GTK_USE_PORTAL=1' \
    "QT_STYLE_OVERRIDE=$QT_STYLE_OVERRIDE" \
    'QT_QPA_PLATFORMTHEME=gtk3' \
    'QT_QPA_PLATFORM=wayland;xcb' 2>/dev/null || true
fi
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
  dbus-update-activation-environment --systemd \
    "GTK_THEME=$GTK_THEME" \
    'GTK_USE_PORTAL=1' \
    "QT_STYLE_OVERRIDE=$QT_STYLE_OVERRIDE" \
    'QT_QPA_PLATFORMTHEME=gtk3' \
    'QT_QPA_PLATFORM=wayland;xcb' 2>/dev/null || true
fi

# The GTK portal keeps its theme for the lifetime of the process. Restart it
# after publishing the environment so Electron file pickers use the new theme.
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user try-restart xdg-desktop-portal-gtk.service 2>/dev/null || true
fi

# Reload components that can adopt a theme without restarting their clients.
if command -v tmux >/dev/null 2>&1 && tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf"
fi
pkill -x flameshot 2>/dev/null || true
# Reloading Sway also refreshes the wallpaper, Waybar, Dunst, and XSettings.
if command -v swaymsg >/dev/null 2>&1 && swaymsg -t get_version >/dev/null 2>&1; then
  swaymsg reload >/dev/null
fi

printf 'Applied global theme: %s\n' "$DISPLAY_NAME"
