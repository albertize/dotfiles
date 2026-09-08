#!/usr/bin/env bash

# Install the managed LightDM configuration and select it for the next boot.
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly repo_dir
readonly theme_name='catppuccin-macchiato-blue-standard+default'
readonly wallpaper_name='leaves_line_neon_139772_2560x1600.jpg'
readonly lightdm_config='/etc/lightdm/lightdm.conf.d/50-dotfiles.conf'
readonly greeter_config='/etc/lightdm/lightdm-gtk-greeter.conf'
readonly greeter_config_backup='/etc/lightdm/lightdm-gtk-greeter.conf.before-dotfiles'
readonly old_greeter_dropin='/etc/lightdm/lightdm-gtk-greeter.conf.d/50-dotfiles.conf'
readonly system_theme="/usr/share/themes/$theme_name"
readonly system_wallpaper="/usr/share/backgrounds/dotfiles/$wallpaper_name"
readonly data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
readonly font_source="$data_home/fonts/JetBrainsMonoNerdFont"
readonly system_font='/usr/local/share/fonts/JetBrainsMonoNerdFont'

assume_yes=false
check_only=false

usage() {
  printf 'Usage: %s [--check] [--yes]\n' "${0##*/}"
  printf '  --check  Verify the managed system configuration without changing it.\n'
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

check_configuration() {
  local status=0

  command -v lightdm >/dev/null 2>&1 || {
    printf 'Missing command: lightdm\n' >&2
    status=1
  }
  command -v lightdm-gtk-greeter >/dev/null 2>&1 || {
    printf 'Missing command: lightdm-gtk-greeter\n' >&2
    status=1
  }
  [[ -r $lightdm_config ]] && cmp -s "$repo_dir/lightdm/lightdm.conf" "$lightdm_config" || {
    printf 'LightDM configuration is not installed or differs.\n' >&2
    status=1
  }
  [[ -r $greeter_config ]] && cmp -s "$repo_dir/lightdm/lightdm-gtk-greeter.conf" "$greeter_config" || {
    printf 'LightDM GTK greeter configuration is not installed or differs.\n' >&2
    status=1
  }
  [[ -r $system_wallpaper ]] &&
    cmp -s "$repo_dir/media/$wallpaper_name" "$system_wallpaper" || {
    printf 'The LightDM wallpaper is not installed or differs.\n' >&2
    status=1
  }
  [[ -r $system_theme/gtk-3.0/gtk.css ]] || {
    printf 'The system-wide GTK theme is not installed.\n' >&2
    status=1
  }
  [[ -r $system_font/JetBrainsMonoNerdFont-Regular.ttf ]] || {
    printf 'The system-wide JetBrainsMono Nerd Font is not installed.\n' >&2
    status=1
  }
  systemctl is-enabled lightdm.service >/dev/null 2>&1 || {
    printf 'LightDM is not enabled.\n' >&2
    status=1
  }

  return "$status"
}

if $check_only; then
  check_configuration
  printf 'LightDM configuration is complete.\n'
  exit 0
fi

for command in fc-cache lightdm lightdm-gtk-greeter; do
  command -v "$command" >/dev/null 2>&1 || {
    printf '%s is missing; run scripts/install-fedora-dependencies.sh first.\n' \
      "$command" >&2
    exit 1
  }
done

[[ -r $font_source/JetBrainsMonoNerdFont-Regular.ttf ]] || {
  printf 'JetBrainsMono Nerd Font is missing; run scripts/install-fedora-dependencies.sh first.\n' >&2
  exit 1
}

if ! $assume_yes; then
  printf '%s\n' 'This will install files under /etc, /usr/share, and /usr/local/share;'
  printf '%s\n' 'replace the managed theme and greeter configuration; and enable LightDM.'
  printf '%s\n' 'The original greeter configuration is backed up before replacement.'
  printf 'Continue? [y/N] '
  read -r answer
  case $answer in
    y|Y) ;;
    *) printf 'Cancelled.\n'; exit 0 ;;
  esac
fi

if (( EUID == 0 )); then
  sudo_command=()
else
  command -v sudo >/dev/null 2>&1 || {
    printf 'sudo is required to configure LightDM.\n' >&2
    exit 1
  }
  sudo_command=(sudo)
fi

# Remove files and quiet-boot arguments installed by the previous greetd
# experiment. This is conditional so unrelated greetd installations are left
# untouched.
legacy_greetd_dropin='/etc/systemd/system/greetd.service.d/10-catppuccin-console.conf'
if [[ -e $legacy_greetd_dropin ]]; then
  "${sudo_command[@]}" rm -f -- "$legacy_greetd_dropin" \
    /etc/greetd/catppuccin-vtrgb
  if command -v grubby >/dev/null 2>&1; then
    "${sudo_command[@]}" grubby --update-kernel=ALL \
      --remove-args='loglevel=0 systemd.show_status=false rd.systemd.show_status=false'
  fi
  "${sudo_command[@]}" systemctl daemon-reload
fi

"${sudo_command[@]}" install -D -m 0644 \
  "$repo_dir/lightdm/lightdm.conf" "$lightdm_config"
# The greeter loads its main file after conf.d, so the main file must carry
# the managed background. Preserve the distribution file on the first run.
if [[ -e $greeter_config && ! -e $greeter_config_backup ]]; then
  "${sudo_command[@]}" cp -a -- "$greeter_config" "$greeter_config_backup"
fi
"${sudo_command[@]}" install -D -m 0644 \
  "$repo_dir/lightdm/lightdm-gtk-greeter.conf" "$greeter_config"
"${sudo_command[@]}" rm -f -- "$old_greeter_dropin"
"${sudo_command[@]}" install -D -m 0644 \
  "$repo_dir/media/$wallpaper_name" "$system_wallpaper"

"${sudo_command[@]}" rm -rf -- "$system_theme"
"${sudo_command[@]}" cp -a -- \
  "$repo_dir/themes/$theme_name" "$system_theme"
"${sudo_command[@]}" chown -R root:root -- "$system_theme"

"${sudo_command[@]}" install -d -m 0755 -- "$(dirname -- "$system_font")"
"${sudo_command[@]}" rm -rf -- "$system_font"
"${sudo_command[@]}" cp -a -- "$font_source" "$system_font"
"${sudo_command[@]}" chown -R root:root -- "$system_font"
"${sudo_command[@]}" fc-cache -f "$system_font" >/dev/null

if command -v restorecon >/dev/null 2>&1; then
  "${sudo_command[@]}" restorecon -RF \
    "$lightdm_config" "$greeter_config" "$system_wallpaper" "$system_theme" \
    "$system_font"
fi

current_manager=$(basename -- "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)")
if [[ -n $current_manager && $current_manager != lightdm.service ]]; then
  "${sudo_command[@]}" systemctl disable "$current_manager" >/dev/null 2>&1 || true
fi
"${sudo_command[@]}" systemctl enable --force lightdm.service
"${sudo_command[@]}" systemctl set-default graphical.target >/dev/null

check_configuration
printf 'LightDM is configured. Reboot to use the new login manager.\n'
