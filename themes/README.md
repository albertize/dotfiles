# Vendored themes

The files under `profiles/` are hand-written desktop profiles. Each profile
contains Sway, Waybar, Wofi, Swaylock, Alacritty, tmux, Neovim, Pi, Dunst,
Flameshot, VS Code, toolkit, icon, and wallpaper settings. `gruvbox` uses the
canonical [Gruvbox](https://github.com/morhetz/gruvbox) dark palette and the
Papirus brown folder colors; `catppuccin-macchiato` preserves the previous
configuration.

- `gruvbox-dark`: the complete dark GTK 3/4 theme generated from
  [Fausto-Korpsvart/Gruvbox-GTK-Theme](https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme)
  at commit `578cd220b5ff6e86b078a6111d26bb20ec8c733f` (GPL-3.0). It uses the
  upstream medium color scheme for the canonical `#282828` Gruvbox background.
  Regenerate this vendored output with `scripts/update-gruvbox-gtk-theme.sh`;
  the script pins Dart Sass and stores the upstream license with the theme.
- `catppuccin-macchiato-blue-standard+default`: Catppuccin GTK v1.0.3,
  downloaded from the [official release](https://github.com/catppuccin/gtk/releases/tag/v1.0.3).
- `Kvantum/catppuccin-macchiato-blue`: the official
  [catppuccin/Kvantum](https://github.com/catppuccin/Kvantum) theme at commit
  `71105d224fef95dd023691303477ce3eea487457`. The installer derives a
  `gruvbox-dark` Kvantum variant by reproducibly mapping its palette while
  retaining the upstream engine geometry and license.
- `archives/papirus-dark-violet-20260801.tar.xz`: the `Papirus` and
  `Papirus-Dark` themes from the official
  [Papirus icon theme 20260801 release](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/releases/tag/20260801).
  Violet folders were selected with the official
  [papirus-folders v1.14.0](https://github.com/PapirusDevelopmentTeam/papirus-folders/releases/tag/v1.14.0)
  tool. The installer derives the small `Papirus-Dark-Gruvbox` inheritance
  theme from this archive by replacing the violet folder colors with Papirus's
  included brown palette. The archive SHA-256 is
  `e0f4e91bdf3d63c79c8102260818f7835d6e0a598a9bf6c1d5b4e0181b6d6a05`;
  its GPL-3.0 license is stored as `Papirus-LICENSE`.
The corresponding licenses are stored alongside the themes. Treat these files
as vendored upstream assets: update them from their original sources rather
than editing generated theme files manually.
