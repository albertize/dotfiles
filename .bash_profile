# Load the interactive Bash configuration for console login shells.
if [[ -f $HOME/.bashrc ]]; then
  source "$HOME/.bashrc"
fi

# A password-authenticated login on tty1 starts the graphical session. Other
# virtual terminals remain available for maintenance.
if [[ -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]] &&
   [[ $(tty 2>/dev/null) == /dev/tty1 ]] && command -v sway >/dev/null 2>&1; then
  exec sway
fi
