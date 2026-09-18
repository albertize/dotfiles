# Dotfiles

Personal configuration files for:

- [Neovim](nvim)
- [tmux](.tmux.conf)
- [Alacritty](alacritty)
- [Sway](sway)
- [Waybar](waybar)
- [Wofi](wofi)
- [Swaylock](swaylock)
- [Dunst](dunst), [Flameshot](flameshot), and a password-authenticated tty1 login
- [GTK 3/4](gtk-3.0), [Qt 5/6](Kvantum), and optional VS Code synchronization

The desktop has switchable Gruvbox Dark and Catppuccin Macchiato profiles.
Gruvbox is selected on the first installation and uses brown Papirus folders;
Catppuccin uses its Blue accent and violet Papirus folders. A profile changes
Sway, Waybar, Wofi, Alacritty, tmux, Neovim, Pi, Dunst, Flameshot, Swaylock,
GTK/Qt, VS Code, the desktop and lock-screen wallpaper, and the published icon theme
together. Window borders and gaps are set to
three logical pixels through `$border` and `$gaps` in `sway/config`. The built-in `eDP-1` display uses 125%
scaling and is centered below the external display, which may be connected
through either `HDMI-A-1` or `DP-3`. Its position is calculated from the active
monitor's logical size to keep the outputs contiguous and non-overlapping after
mode changes. Waybar prefers the upper external display and automatically moves
to the laptop panel when the external display is disconnected. In laptop-only
mode, the panel is moved back to the global origin so screenshot tools receive
valid capture geometry. Use
`swaymsg -t get_outputs` to find the
correct output names on a different machine.

## Sway requirements

- `sway`, `swayidle`, `swaylock`, `waybar`, `wofi`, and `dunst`
- `alacritty`, PipeWire/WirePlumber, `pulseaudio-utils` (`pactl`),
  `brightnessctl`, `jq`, and `nmcli`
- `openconnect`, `procps-ng`, and `sudo` for the optional VPN applet
- BlueZ (`bluetoothctl`) and `rfkill` for Bluetooth and device management
- `cliphist` and `wl-clipboard` for clipboard history
- `gnome-keyring`, `gnome-keyring-pam`, and `libsecret` for secret storage
- `flameshot`, `xdg-desktop-portal`, `xdg-desktop-portal-wlr`, and
  `xdg-desktop-portal-gtk`
- util-linux (`agetty` and `login`) for the password-authenticated tty1 login
- MesloLGS and JetBrainsMono Nerd Fonts for selectable text and icons
- Kvantum and GTK 3 platform-theme plugins for Qt 5 and Qt 6
- The Adwaita cursor theme and `xsettingsd`
- Optionally, VS Code; `jdinhlife.gruvbox` and `catppuccin.catppuccin-vsc`
  enable matching editor-theme synchronization

The official Catppuccin GTK and Kvantum themes and the Papirus-Dark icon theme
are vendored in this repository. The installer links the toolkit themes,
extracts the pinned Papirus archive into `XDG_DATA_HOME/icons`, and builds a
small inheriting Papirus theme with the official brown folder palette for
Gruvbox. The repository also provides a complete Gruvbox GTK theme and
builds a matching Kvantum palette from the pinned Catppuccin engine assets.
Managed KDE color schemes keep Qt/KDE application palettes synchronized with
Kvantum. Sway passes
the selected theme variables to new applications explicitly, while the theme
application script publishes them to the systemd and D-Bus user environments. A managed systemd user target registers Sway as a graphical
session so portal-based screenshots work even when Sway is started manually.
See [`themes/README.md`](themes/README.md) for versions, upstream sources, and
licenses.
The selected dark theme, Papirus icons, Adwaita cursor, selected Nerd Font,
DPI, and antialiasing values are published through GSettings and XSettings so
applications do not need application-specific overrides. The theme application
script also updates the color scheme, accent, widget style, icon, and font keys
in `kdeglobals` for KDE applications such as Gwenview and Dolphin. Detected
VS Code installations receive the selected font for both the editor and
integrated terminal. It republishes
the toolkit environment and restarts the GTK portal backend so Electron file
pickers adopt the active theme.

## Desktop behavior

- Getty on tty1 uses a fixed account name, requests its password through the
  standard `login` PAM service, and starts Sway from the login shell. It clears
  boot messages before displaying the prompt. A failed password attempt
  restarts the same fixed-user prompt instead of requesting a username. Other
  virtual terminals remain available for maintenance.
- The console PAM stack does not unlock GNOME Keyring automatically. GNOME
  Keyring still exposes the standard Secret Service API and may request its
  password when an application first accesses the login keyring.
- `Mod+d` opens Wofi with application icons. The minimal application-grid icon
  at the left of Waybar provides the same launcher.
- Waybar's palette button opens a compact appearance applet with separate
  Themes and Fonts submenus. Each submenu marks the active choice, and the
  theme submenu includes color previews. The lists grow automatically as new
  profiles are added.
- Waybar renders workspace names without a background. The focused workspace
  uses the same strong foreground color as the Sway application-launcher icon,
  while the others remain compact and dimmed.
- `Mod+l` locks the session manually; `Mod+Right` moves focus to the right.
- Automatic locking is disabled; idle displays turn off after ten minutes.
- The active profile's vendored wallpaper is applied to every output and to
  Swaylock with `fill` scaling. Gruvbox uses
  `media/luca-bravo-zAjdgNXsMeg.jpg`.
- New windows use an automatic Fibonacci layout with equal nested splits:
  two windows are side by side, then the right half is split vertically, and
  subsequent splits continue alternating.
- Audio and brightness keys show replaceable Dunst progress indicators. Clicking
  Waybar's audio indicator opens a Wofi menu for selecting output and input
  devices, hardware ports, and audio-card profiles such as analog, HDMI,
  A2DP, and HFP/HSP. Active application streams can be moved between devices
  or have their volume and mute state adjusted independently.
- `Print` opens Flameshot's region editor; `Shift+Print` copies all outputs.
  Flameshot uses automatic Qt scaling without its magnifier to avoid zoomed
  capture geometry on fractionally scaled Wayland outputs.
- `Mod+n` restores the last notification, `Mod+Shift+n` clears notifications,
  and `Mod+Ctrl+n` persistently pauses or resumes Dunst. Waybar's notification
  button opens a Wofi menu for browsing, restoring, deleting, or clearing
  notification history.
- Waybar's clipboard button opens history with Wofi; right-click deletes one
  entry and middle-click clears the entire history.
- Right-clicking Waybar's battery indicator opens a Wofi menu for selecting the
  battery-save, balanced, or performance power profile.
- Waybar's power button provides lock, suspend, logout, restart, and power-off
  actions, plus hibernation when logind reports it as available. Restart and
  power-off actions require confirmation.
- Clicking Waybar's network indicator opens a Wofi and `nmcli` menu that can
  toggle Wi-Fi, scan, connect to visible or hidden networks, request a password,
  and disconnect. Networks are sorted by signal strength and show active,
  security, and signal indicators. A separate submenu can activate, disconnect,
  or forget saved NetworkManager Wi-Fi profiles.
- Waybar's VPN indicator reports whether OpenConnect is running. Clicking it
  executes `VPN_SCRIPT` to connect or runs `sudo pkill -x openconnect` to
  disconnect; administrator authentication uses a masked Wofi prompt.
- Waybar shows the Bluetooth state and connected-device count; clicking it opens
  a Wofi and `bluetoothctl` menu that can toggle Bluetooth, scan, pair, connect,
  reconnect, disconnect, trust, or remove devices. Device entries show paired,
  trusted, connected, battery, and signal details when BlueZ provides them.
  An event-driven monitor refreshes connection state immediately instead of
  waiting for a polling interval. Bluetooth power, notification pause,
  and idle-inhibitor choices are stored under
  `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles` and restored after Sway,
  Dunst, or Waybar restarts.

## Installation

On Fedora, install all system dependencies and the pinned MesloLGS and
JetBrainsMono Nerd Fonts first. The script lists missing packages and asks for
confirmation before invoking `sudo dnf`:

```sh
./scripts/install-fedora-dependencies.sh
```

Use `./scripts/install-fedora-dependencies.sh --check` for a read-only check.
Then run the dotfile installer from any directory. In addition to creating
links, it selects the default Gruvbox profile, applies the GTK and icon themes,
selects Kvantum, and updates the systemd and D-Bus user environments without
relying on KDE or another desktop environment:

```sh
./install.sh
```

Press `Mod+Shift+t` or click Waybar's palette button to open the Wofi
appearance applet, then enter the Themes or Fonts submenu. The same applet
retains command-line operations for automation:

```sh
~/.config/sway/scripts/theme-switcher.sh --list
~/.config/sway/scripts/theme-switcher.sh gruvbox
~/.config/sway/scripts/theme-switcher.sh --list-fonts
~/.config/sway/scripts/theme-switcher.sh --font meslo-lg
```

MesloLGS (the small-line-gap MesloLG variant) is the default font. The common
`meslo`, `meslolg`, and `jetbrains` font aliases are also accepted.

The active profile is stored as the replaceable
`${XDG_CONFIG_HOME:-~/.config}/dotfiles-theme` symlink, while the font uses
`${XDG_CONFIG_HOME:-~/.config}/dotfiles-font`. Switching either reloads Sway,
so the wallpaper and running desktop components update immediately. Running
tmux and Pi sessions are refreshed as well, Neovim reloads its palette when it
regains focus, and VS Code applies the selected editor and terminal font plus
any matching installed theme extension live. Other existing GUI applications
may need to be restarted.

The installer asks before replacing an existing `~/.bash_profile`. Its managed
profile retains the standard `~/.bashrc` loading behavior and starts Sway only
from tty1. Configure tty1 for the current user and select it for the next boot:

```sh
./scripts/configure-tty-login.sh
```

The setup script installs a `getty@tty1` override under `/etc/systemd/system`,
configures a fixed account name so only its password is requested, sets the
console login retry count to one in `/etc/login.defs`, disables LightDM without
stopping the active session, and selects `multi-user.target`.
It asks for confirmation before using `sudo`. Use
`./scripts/configure-tty-login.sh --check` for read-only verification, or
`--user USER` to configure another local account.

It creates these managed links and runtime files:

- `~/.bash_profile` → `.bash_profile`
- `~/.tmux.conf` → `.tmux.conf`
- `${XDG_CONFIG_HOME:-~/.config}/alacritty/alacritty.toml` →
  `alacritty/alacritty.toml`; the adjacent generated `theme.toml` and
  `font.toml` remain at stable paths so Alacritty detects live updates
- `${XDG_CONFIG_HOME:-~/.config}/nvim` → `nvim/`
- `${XDG_CONFIG_HOME:-~/.config}/sway` → `sway/`
- `${XDG_CONFIG_HOME:-~/.config}/waybar` → `waybar/`
- `${XDG_CONFIG_HOME:-~/.config}/wofi/config` → `wofi/config`; the generated
  `theme.css` combines the active palette with the repository stylesheet
- `${XDG_CONFIG_HOME:-~/.config}/flameshot/flameshot.ini` is generated from the
  active profile so D-Bus activation reads the same theme
- `${XDG_CONFIG_HOME:-~/.config}/xdg-desktop-portal/sway-portals.conf` →
  `xdg-desktop-portal/sway-portals.conf`
- `${XDG_CONFIG_HOME:-~/.config}/systemd/user/dotfiles-sway-session.target` →
  `systemd/user/dotfiles-sway-session.target`
- `${XDG_CONFIG_HOME:-~/.config}/gtk-{3,4}.0` → `gtk-{3,4}.0/`
- `${XDG_DATA_HOME:-~/.local/share}/color-schemes/{CatppuccinMacchiato,GruvboxDark}.colors`
  → managed KDE color schemes
- `${XDG_CONFIG_HOME:-~/.config}/Kvantum/catppuccin-macchiato-blue` → the
  vendored Kvantum theme; the adjacent Gruvbox variant is generated by the
  installer
- `${XDG_CONFIG_HOME:-~/.config}/environment.d/90-wayland-toolkits.conf` →
  `environment.d/90-wayland-toolkits.conf`
- `${XDG_CONFIG_HOME:-~/.config}/dotfiles-theme` → the active profile under
  `themes/profiles/`
- `${XDG_CONFIG_HOME:-~/.config}/dotfiles-font` → the active profile under
  `fonts/profiles/`
- `${XDG_DATA_HOME:-~/.local/share}/themes/catppuccin-macchiato-blue-standard+default`
  → the vendored GTK theme
- `${XDG_DATA_HOME:-~/.local/share}/themes/Gruvbox-Dark` → the maintained
  Gruvbox GTK theme
- `${XDG_DATA_HOME:-~/.local/share}/backgrounds/dotfiles` → `media/`

If a destination already exists, the installer asks for confirmation before
replacing it. Set `DOTFILES_SKIP_THEME_APPLY=1` to create links without changing
the live GTK, Qt, systemd, or D-Bus settings.

## OpenConnect VPN applet

The Waybar VPN applet uses exactly one applet-specific setting: `VPN_SCRIPT`,
the path of the existing connection script. The applet does not pass arguments
or credentials to it. Put the machine-specific absolute path in a local
environment file; do not add the script or its details to this repository:

```ini
# ~/.config/environment.d/95-vpn.conf
VPN_SCRIPT=/absolute/path/to/private-vpn-script
```

Environment files do not expand `~`. Log out and back in after creating the
file, or reload the user manager's environment and Sway:

```sh
systemctl --user daemon-reload
swaymsg reload
```

When OpenConnect is not running, clicking the indicator opens a Wofi
confirmation and executes `VPN_SCRIPT` without arguments through
`sudo --askpass --preserve-env`. The existing script remains responsible for VPN
credentials and connection. Variables defined in `.bashrc` are available to it
when they use `export` and Sway/Waybar was started after they were defined. Log
out and back in after changing those exports so the graphical session inherits
them.

When OpenConnect is running, the action instead disconnects it with
`sudo pkill -x openconnect`. This stops every process whose exact name is
`openconnect`. A separate masked Wofi prompt is shown whenever administrator
authentication is needed. The indicator is green while an `openconnect` process
is running and dimmed otherwise.

Since the configured file is deliberately executed with administrator
privileges and receives the exported user environment, `VPN_SCRIPT` must be an
absolute path to a trusted executable and must not point to an untrusted or
group-writable file. `sudo` still removes variables that its security policy
forbids even when `--preserve-env` is used.

## Proxy handling

Chromium-based applications choose where to read the proxy configuration from
based on the desktop they detect: GNOME-like sessions read the
`org.gnome.system.proxy` GSettings schema, KDE reads `kioslaverc`, and any other
session — Sway included — falls back to the `http_proxy`/`https_proxy`
environment variables. Under Sway those variables are therefore the supported
channel, but they are normally exported only by interactive shells, so
applications started from the launcher inherit no proxy at all.

`scripts/proxy-env.sh` is the single place that resolves the proxy state, and
`scripts/with-proxy` runs any command with the result applied:

```sh
scripts/with-proxy chromium-browser
```

The state is evaluated per invocation instead of being imported once into the
session environment, because a VPN is connected and disconnected while the
session keeps running, and Chromium does not fall back to a direct connection
when a configured PAC URL becomes unreachable — it fails every request instead.
Restarting the application is enough to pick up the new state.

Site-specific host names are not stored in this repository. Copy
`scripts/proxy-env.conf.example` to `${XDG_CONFIG_HOME:-~/.config}/proxy-env.conf`
and set the values for your network; without that file no proxy is used, so the
helpers are harmless on machines outside a corporate network.

Application launchers that need the wrapper stay outside this repository when the
application is installed on a single machine. Wrap the command in the local
`.desktop` entry instead:

```
Exec=/path/to/dotfiles/scripts/with-proxy /usr/bin/some-application %U
```
