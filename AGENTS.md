# Repository Guidelines

## Purpose

This repository contains reproducible, symlink-based personal configuration
for a minimal Wayland/Sway desktop and terminal development environment. Keep
changes portable, reviewable, and safe to apply repeatedly.

## Core principles

1. **Reproducibility:** every persistent configuration change must live in this
   repository and be installed through `install.sh` or a documented setup
   script. Keep privileged system configuration separate from the user-level
   installer.
2. **Idempotence:** rerunning installation and theme application must be safe.
3. **Portability:** prefer freedesktop standards and desktop-independent tools.
   For example, use NetworkManager through `nmcli` rather than a Plasma-only
   network UI.
4. **Minimalism:** avoid unnecessary dependencies, background services, visual
   decoration, and duplicated configuration.
5. **Consistency:** use Catppuccin Macchiato with the Blue accent throughout the
   desktop. Keep Waybar square, compact, and visually uniform.
6. **Safety:** never store secrets in the repository. Confirm destructive power
   actions and avoid silently overwriting existing user files.
7. **Clear language:** all documentation and code/configuration comments must be
   written in English. User-facing desktop labels may follow the configured
   locale.

## Repository layout

- `install.sh`: central symbolic-link installer.
- `scripts/`: repository-wide setup and application scripts.
- `sway/`, `waybar/`, `wofi/`, `swaylock/`: Wayland desktop configuration.
- `dunst/`, `flameshot/`, `xdg-desktop-portal/`: notifications, screenshots,
  and portal backend selection.
- `systemd/system/`: managed system-level templates such as the tty1 getty override.
- `systemd/user/`: user-session targets needed by desktop services.
- `gtk-3.0/`, `gtk-4.0/`, `Kvantum/`, `xsettingsd/`: toolkit theming.
- `themes/`: pinned upstream theme assets and provenance.
- `alacritty/`, `nvim/`, `.tmux.conf`, `promptrc`: terminal and development
  environment configuration.

## Installation rules

- Add every new user-level managed configuration path to the `links` array in
  `install.sh`. Install privileged system configuration through a documented
  setup script.
- Respect `XDG_CONFIG_HOME` and `XDG_DATA_HOME`; do not hardcode the user's home
  directory.
- Preserve the installer's confirmation prompt for conflicting destinations.
- Keep `DOTFILES_SKIP_THEME_APPLY=1` working for tests and link-only installs.
- Do not install system packages or invoke privileged commands without explicit
  user approval. Privileged setup scripts must show what they change and ask
  for confirmation by default.
- Scripts invoked by configuration files must be executable.

## Shell scripting rules

- Use Bash when arrays or Bash-specific features are needed and start scripts
  with `#!/usr/bin/env bash`.
- Enable at least `set -u`; use `set -e` and `pipefail` when their failure
  semantics are appropriate.
- Quote variable expansions and use `--` before path operands where supported.
- Check optional commands before invoking them and provide a useful fallback or
  error message.
- Do not print, log, or persist Wi-Fi passwords or other credentials.
- Keep machine-readable command output locale-independent with `LC_ALL=C` when
  parsing it.

## Desktop configuration rules

- Keep output-specific settings documented and localized in `sway/config`.
- Preserve manual lock actions, but do not enable automatic session locking
  unless explicitly requested.
- Keep the automatic golden-ratio/Fibonacci tiling script independent of
  application-specific rules and ignore floating windows.
- Waybar modules should remain functional without a full desktop environment.
- Keep notifications and screenshots desktop-agnostic through Dunst, Flameshot,
  and the appropriate freedesktop portal backend.
- Use GNOME Keyring only through its standard Secret Service and portal APIs;
  do not require a GNOME desktop session.
- Wofi is the common launcher for interactive menus and should retain app icons
  in `drun` mode.
- Keep GTK and Qt palette/background/foreground combinations readable; verify
  both dark backgrounds and light text when changing toolkit themes.

## Vendored assets

- Do not manually edit generated files under the vendored GTK or Kvantum theme
  directories.
- Record the upstream URL, release or commit, and license whenever a vendored
  asset is added or updated.
- Keep theme names synchronized across settings files, environment variables,
  Kvantum configuration, and installer destinations.

## Validation checklist

Run the checks relevant to the files changed:

```sh
bash -n install.sh scripts/*.sh sway/scripts/*.sh waybar/scripts/*.sh
python3 -m json.tool waybar/config >/dev/null
WLR_BACKENDS=headless WLR_RENDERER=pixman sway -C -c sway/config
git diff --check
```

For an installer smoke test, use isolated XDG directories and avoid changing
live settings:

```sh
sandbox=$(mktemp -d)
HOME="$sandbox/home" \
XDG_CONFIG_HOME="$sandbox/config" \
XDG_DATA_HOME="$sandbox/data" \
DOTFILES_SKIP_THEME_APPLY=1 \
./install.sh
rm -rf "$sandbox"
```

Also verify that newly created links resolve, scripts have executable mode, and
no documentation or comments were introduced in a language other than English.
