# Dotfiles

Personal configuration files for:

- [Neovim](nvim)
- [tmux](.tmux.conf)
- [Alacritty](alacritty)
- [Sway](sway)
- [Waybar](waybar)
- [Wofi](wofi)
- [Swaylock](swaylock)
- [Dunst](dunst), [Flameshot](flameshot), and [LightDM](lightdm)
- [GTK 3/4](gtk-3.0) and [Qt 5/6](Kvantum)
- [Shell prompt](promptrc) — not installed automatically

Sway, Waybar, Wofi, Swaylock, GTK, and Qt use Catppuccin Macchiato with the
Blue accent. Window borders and gaps are set to three logical pixels through
`$border` and `$gaps` in `sway/config`. The built-in `eDP-1` display uses 125%
scaling; use `swaymsg -t get_outputs` to find the correct output name on a
different machine.

## Sway requirements

- `sway`, `swayidle`, `swaylock`, `waybar`, `wofi`, and `dunst`
- `alacritty`, PipeWire/WirePlumber, `brightnessctl`, `jq`, and `nmcli`
- `cliphist` and `wl-clipboard` for clipboard history
- `flameshot`, `xdg-desktop-portal`, `xdg-desktop-portal-wlr`, and
  `xdg-desktop-portal-gtk`
- `lightdm`, `lightdm-gtk`, and `xorg-x11-server-Xorg` for the login manager
- JetBrainsMono Nerd Font for text and icons
- `pavucontrol` optionally, for the volume module's right-click action
- Kvantum and GTK 3 platform-theme plugins for Qt 5 and Qt 6
- Noto Sans and the Adwaita icon/cursor theme

The official Catppuccin GTK and Kvantum themes are vendored in this
repository and linked by the installer. Sway passes the theme variables to new
applications explicitly, while `environment.d` makes them globally available
from the next login. A managed systemd user target registers Sway as a graphical
session so portal-based screenshots work even when Sway is started manually.
See [`themes/README.md`](themes/README.md) for versions,
upstream sources, and licenses.

## Desktop behavior

- LightDM GTK provides the login screen with the same wallpaper, Catppuccin
  theme, Adwaita icons, Noto Sans font, and Sway as the default session.
- `Mod+d` opens Wofi with application icons.
- `Mod+Ctrl+l` locks the session manually.
- Automatic locking is disabled; idle displays turn off after ten minutes.
- The vendored `media/leaves_line_neon_139772_2560x1600.jpg` image is applied
  to every output with `fill` scaling.
- New windows use an automatic Fibonacci layout with 61.8%/38.2% proportions.
- Audio and brightness keys show replaceable Dunst progress indicators.
- `Print` opens Flameshot's region editor; `Shift+Print` copies all outputs.
- `Mod+n` restores the last notification, `Mod+Shift+n` clears notifications,
  and `Mod+Ctrl+n` pauses or resumes Dunst.
- Waybar's clipboard button opens history with Wofi; right-click deletes one
  entry and middle-click clears the entire history.
- Waybar's power button provides lock, logout, and power-off actions.
- Clicking Waybar's network indicator opens a Wofi and `nmcli` menu that can
  toggle Wi-Fi, scan, connect to visible or hidden networks, request a password,
  and disconnect.

## Installation

On Fedora, install all system dependencies and the pinned JetBrainsMono Nerd
Font first. The script lists missing packages and asks for confirmation before
invoking `sudo dnf`:

```sh
./scripts/install-fedora-dependencies.sh
```

Use `./scripts/install-fedora-dependencies.sh --check` for a read-only check.
Install the managed LightDM configuration and enable it for the next boot with:

```sh
./scripts/configure-lightdm.sh
```

This copies the wallpaper and GTK theme to system-readable locations, installs
the LightDM drop-in and GTK greeter configuration under `/etc/lightdm`, and
asks for confirmation before using `sudo`. The original greeter configuration
is backed up once. It does not stop the active graphical session. Use
`./scripts/configure-lightdm.sh --check` for a read-only verification.

Then run the dotfile installer from any directory. In addition to creating
links, it applies the GTK theme, selects Kvantum, and updates the systemd and
D-Bus user environments without relying on KDE or another desktop environment:

```sh
./install.sh
```

It creates these symbolic links:

- `~/.tmux.conf` → `.tmux.conf`
- `${XDG_CONFIG_HOME:-~/.config}/alacritty` → `alacritty/`
- `${XDG_CONFIG_HOME:-~/.config}/nvim` → `nvim/`
- `${XDG_CONFIG_HOME:-~/.config}/sway` → `sway/`
- `${XDG_CONFIG_HOME:-~/.config}/waybar` → `waybar/`
- `${XDG_CONFIG_HOME:-~/.config}/wofi` → `wofi/`
- `${XDG_CONFIG_HOME:-~/.config}/swaylock` → `swaylock/`
- `${XDG_CONFIG_HOME:-~/.config}/dunst` → `dunst/`
- `${XDG_CONFIG_HOME:-~/.config}/flameshot` → `flameshot/`
- `${XDG_CONFIG_HOME:-~/.config}/xdg-desktop-portal/sway-portals.conf` →
  `xdg-desktop-portal/sway-portals.conf`
- `${XDG_CONFIG_HOME:-~/.config}/systemd/user/dotfiles-sway-session.target` →
  `systemd/user/dotfiles-sway-session.target`
- `${XDG_CONFIG_HOME:-~/.config}/gtk-{3,4}.0` → `gtk-{3,4}.0/`
- `${XDG_CONFIG_HOME:-~/.config}/Kvantum` → `Kvantum/`
- `${XDG_CONFIG_HOME:-~/.config}/environment.d/90-catppuccin.conf` →
  `environment.d/90-catppuccin.conf`
- `${XDG_DATA_HOME:-~/.local/share}/themes/catppuccin-macchiato-blue-standard+default`
  → the vendored GTK theme
- `${XDG_DATA_HOME:-~/.local/share}/backgrounds/dotfiles` → `media/`

If a destination already exists, the installer asks for confirmation before
replacing it. Set `DOTFILES_SKIP_THEME_APPLY=1` to create links without changing
the live GTK, Qt, systemd, or D-Bus settings.
