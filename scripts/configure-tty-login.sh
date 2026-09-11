#!/usr/bin/env bash

# Configure a password-authenticated tty1 login for one fixed user.
set -euo pipefail

repo_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readonly repo_dir
readonly template="$repo_dir/systemd/system/getty@tty1.service.d/override.conf.in"
readonly override='/etc/systemd/system/getty@tty1.service.d/override.conf'
readonly login_defs='/etc/login.defs'
readonly login_retries_comment='# Managed by dotfiles: restart the fixed-user getty after one failed password.'
readonly lightdm_config='/etc/lightdm/lightdm.conf.d/50-dotfiles.conf'
readonly greeter_config='/etc/lightdm/lightdm-gtk-greeter.conf'
readonly greeter_backup='/etc/lightdm/lightdm-gtk-greeter.conf.before-dotfiles'
readonly theme_name='catppuccin-macchiato-blue-standard+default'
readonly wallpaper_name='leaves_line_neon_139772_2560x1600.jpg'
readonly system_theme="/usr/share/themes/$theme_name"
readonly system_wallpaper="/usr/share/backgrounds/dotfiles/$wallpaper_name"
readonly system_font='/usr/local/share/fonts/JetBrainsMonoNerdFont'

login_user=${SUDO_USER:-${USER:-}}
assume_yes=false
check_only=false

usage() {
  printf 'Usage: %s [--check] [--yes] [--user USER]\n' "${0##*/}"
  printf '  --check      Verify the managed configuration without changing it.\n'
  printf '  --yes        Skip the confirmation prompt.\n'
  printf '  --user USER  Set the account used by the tty1 password prompt.\n'
}

while (( $# > 0 )); do
  case $1 in
    --check) check_only=true ;;
    --yes) assume_yes=true ;;
    --user)
      (( $# >= 2 )) || { printf 'Missing argument for --user.\n' >&2; exit 2; }
      login_user=$2
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

[[ $login_user =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || {
  printf 'Invalid login user: %s\n' "$login_user" >&2
  exit 1
}
command -v getent >/dev/null 2>&1 || {
  printf 'Missing command: getent\n' >&2
  exit 1
}
id "$login_user" >/dev/null 2>&1 || {
  printf 'User does not exist: %s\n' "$login_user" >&2
  exit 1
}
passwd_entry=$(getent passwd "$login_user")
login_home=$(cut -d: -f6 <<< "$passwd_entry")
login_shell=$(cut -d: -f7 <<< "$passwd_entry")
[[ -n $login_home && -d $login_home ]] || {
  printf 'Home directory does not exist for %s.\n' "$login_user" >&2
  exit 1
}
[[ ${login_shell##*/} == bash ]] || {
  printf 'The managed login startup requires Bash; %s uses %s.\n' \
    "$login_user" "$login_shell" >&2
  exit 1
}
readonly login_home login_shell
[[ -r $template ]] || {
  printf 'Missing getty template: %s\n' "$template" >&2
  exit 1
}
[[ -r $login_defs ]] || {
  printf 'Missing login configuration: %s\n' "$login_defs" >&2
  exit 1
}
if grep -Eq '^[[:space:]]*LOGIN_RETRIES[[:space:]]+' "$login_defs" &&
   ! grep -Eq '^[[:space:]]*LOGIN_RETRIES[[:space:]]+1([[:space:]]|$)' "$login_defs"; then
  printf 'An unmanaged LOGIN_RETRIES setting already exists in %s; not replacing it.\n' \
    "$login_defs" >&2
  exit 1
fi

render_override() {
  sed "s/@USER@/$login_user/g" "$template"
}

check_configuration() {
  local status=0 expected
  expected=$(mktemp)
  render_override > "$expected"

  [[ -r $override ]] && cmp -s "$expected" "$override" || {
    printf 'The tty1 getty override is not installed or differs.\n' >&2
    status=1
  }
  rm -f -- "$expected"

  grep -Eq '^[[:space:]]*LOGIN_RETRIES[[:space:]]+1([[:space:]]|$)' "$login_defs" || {
    printf 'LOGIN_RETRIES is not set to 1 in %s.\n' "$login_defs" >&2
    status=1
  }
  [[ -e $login_home/.bash_profile && $login_home/.bash_profile -ef $repo_dir/.bash_profile ]] || {
    printf '%s is not linked to the repository; run ./install.sh first.\n' \
      "$login_home/.bash_profile" >&2
    status=1
  }
  systemctl is-enabled getty@tty1.service >/dev/null 2>&1 || {
    printf 'getty@tty1.service is not enabled.\n' >&2
    status=1
  }
  if systemctl is-enabled lightdm.service >/dev/null 2>&1; then
    printf 'LightDM is still enabled.\n' >&2
    status=1
  fi
  [[ $(systemctl get-default) == multi-user.target ]] || {
    printf 'The default systemd target is not multi-user.target.\n' >&2
    status=1
  }

  return "$status"
}

if $check_only; then
  check_configuration
  printf 'The tty1 password login is configured for %s.\n' "$login_user"
  exit 0
fi

for command in agetty login systemctl; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Missing command: %s\n' "$command" >&2
    exit 1
  }
done
[[ -e $login_home/.bash_profile && $login_home/.bash_profile -ef $repo_dir/.bash_profile ]] || {
  printf '%s is not linked to the repository; run ./install.sh first.\n' \
    "$login_home/.bash_profile" >&2
  exit 1
}

if ! $assume_yes; then
  printf 'This will configure tty1 to request the password for user "%s" without asking for a username.\n' "$login_user"
  printf '%s\n' 'It will clear boot messages before the prompt and restart the fixed-user prompt after one failed password.'
  printf '%s\n' 'It will disable LightDM at the next boot and make multi-user.target the default.'
  printf '%s\n' 'The active graphical session will not be stopped.'
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
    printf 'sudo is required to configure the tty login.\n' >&2
    exit 1
  }
  sudo_command=(sudo)
fi

tmp_override=$(mktemp)
trap 'rm -f -- "$tmp_override"' EXIT
render_override > "$tmp_override"
"${sudo_command[@]}" install -D -m 0644 -- "$tmp_override" "$override"

if ! grep -Eq '^[[:space:]]*LOGIN_RETRIES[[:space:]]+1([[:space:]]|$)' "$login_defs"; then
  if grep -Eq '^[[:space:]]*LOGIN_RETRIES[[:space:]]+' "$login_defs"; then
    printf 'An unmanaged LOGIN_RETRIES setting already exists in %s; not replacing it.\n' \
      "$login_defs" >&2
    exit 1
  fi
  tmp_login_defs=$(mktemp)
  trap 'rm -f -- "$tmp_override" "$tmp_login_defs"' EXIT
  cp -- "$login_defs" "$tmp_login_defs"
  printf '\n%s\nLOGIN_RETRIES 1\n' "$login_retries_comment" >> "$tmp_login_defs"
  "${sudo_command[@]}" install -m 0644 -- "$tmp_login_defs" "$login_defs"
fi

if command -v restorecon >/dev/null 2>&1; then
  "${sudo_command[@]}" restorecon -F "$override" "$login_defs"
fi

# Restore the distribution greeter file and remove assets installed by the old
# managed LightDM setup. Unrelated LightDM configuration is left untouched.
"${sudo_command[@]}" rm -f -- "$lightdm_config"
if [[ -e $greeter_backup ]]; then
  "${sudo_command[@]}" mv -f -- "$greeter_backup" "$greeter_config"
fi
"${sudo_command[@]}" rm -rf -- "$system_theme" "$system_wallpaper" "$system_font"
if command -v fc-cache >/dev/null 2>&1; then
  "${sudo_command[@]}" fc-cache -f >/dev/null
fi

"${sudo_command[@]}" systemctl daemon-reload
"${sudo_command[@]}" systemctl disable lightdm.service >/dev/null 2>&1 || true
"${sudo_command[@]}" systemctl enable getty@tty1.service >/dev/null
"${sudo_command[@]}" systemctl set-default multi-user.target >/dev/null

check_configuration
printf 'The tty1 password login is configured for %s. Reboot to use it.\n' "$login_user"
printf '%s\n' 'Keep swaylock installed to lock the graphical session securely.'
