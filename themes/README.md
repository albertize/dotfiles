# Vendored themes

The files under `profiles/` are hand-written desktop profiles. Each profile
contains Sway, Waybar, Wofi, Swaylock, Alacritty, tmux, Neovim, Pi, Dunst,
Flameshot, VS Code, toolkit, icon, and wallpaper settings. `gruvbox` uses the
canonical [Gruvbox](https://github.com/morhetz/gruvbox) dark palette and the
Papirus brown folder colors; `catppuccin-macchiato` preserves the previous
configuration; and `everforest` uses the default-contrast Everforest Dark
palette with a green accent and green Papirus folders.

Each profile's `vscode.json` is consumed by the local extension in
`vscode/dotfiles-theme`. The installer installs
`vscode/dotfiles-theme-1.0.1.vsix` through every detected editor's CLI, and the
application script overwrites its stable runtime theme file whenever the
global profile changes. Build the package with
`scripts/build-vscode-theme-extension.sh`, which pins `@vscode/vsce`. The
selected theme is always named `Dotfiles`; no Marketplace color-theme
extension is required.

- `gruvbox-dark`: the complete dark GTK 3/4 theme generated from
  [Fausto-Korpsvart/Gruvbox-GTK-Theme](https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme)
  at commit `578cd220b5ff6e86b078a6111d26bb20ec8c733f` (GPL-3.0). It uses the
  upstream medium color scheme for the canonical `#282828` Gruvbox background.
  Regenerate this vendored output with `scripts/update-gruvbox-gtk-theme.sh`;
  the script pins Dart Sass and stores the upstream license with the theme.
- `catppuccin-macchiato-blue-standard+default`: Catppuccin GTK v1.0.3,
  downloaded from the [official release](https://github.com/catppuccin/gtk/releases/tag/v1.0.3).
- `everforest-green-dark`: the green-accented, default-contrast dark GTK 3/4
  theme generated from
  [Fausto-Korpsvart/Everforest-GTK-Theme](https://github.com/Fausto-Korpsvart/Everforest-GTK-Theme)
  at commit `9b8be4d6648ae9eaae3dd550105081f8c9054825` (GPL-3.0). Regenerate it with
  `scripts/update-everforest-gtk-theme.sh`; the script pins Dart Sass and keeps
  the upstream license with the generated theme.
- `Kvantum/catppuccin-macchiato-blue`: the official
  [catppuccin/Kvantum](https://github.com/catppuccin/Kvantum) theme at commit
  `71105d224fef95dd023691303477ce3eea487457`. The installer derives a
  `gruvbox-dark` and `everforest-dark` Kvantum variants by reproducibly mapping
  their palettes while retaining the upstream engine geometry and license.
- `archives/papirus-dark-violet-20260801.tar.xz`: the `Papirus` and
  `Papirus-Dark` themes from the official
  [Papirus icon theme 20260801 release](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme/releases/tag/20260801).
  Violet folders were selected with the official
  [papirus-folders v1.14.0](https://github.com/PapirusDevelopmentTeam/papirus-folders/releases/tag/v1.14.0)
  tool. The installer derives the small `Papirus-Dark-Gruvbox` inheritance
  theme from this archive by replacing the violet folder colors with Papirus's
  included brown palette. It also builds `Papirus-Dark-Everforest` by mapping
  the same folder assets to the Everforest green palette. The archive SHA-256 is
  `e0f4e91bdf3d63c79c8102260818f7835d6e0a598a9bf6c1d5b4e0181b6d6a05`;
  its GPL-3.0 license is stored as `Papirus-LICENSE`.

The corresponding licenses are stored alongside the themes. Treat these files
as vendored upstream assets: update them from their original sources rather
than editing generated theme files manually.

## Adding a desktop theme

A theme is a profile plus any external toolkit assets it references. The Wofi
appearance menu discovers profile directories automatically, so no switcher
code or static theme list is needed.

1. **Define the palette and provenance.** Choose one stable lowercase profile
   slug, a display name, dark backgrounds, readable foregrounds, and semantic
   accent, success, warning, and error colors. Record upstream URLs, pinned
   versions or commits, and licenses in this file. Add the wallpaper to
   `media/`, document its author/source/license in `media/README.md`, and keep
   its filename stable.
2. **Create `themes/profiles/SLUG/`.** Start from the closest existing profile
   and provide every file required by `scripts/apply-theme.sh`:
   `theme.conf`, `alacritty.toml`, `dunstrc`, `flameshot.ini`, `nvim.lua`,
   `pi.json`, `sway.conf`, `swaylock.conf`, `tmux.conf`, `vscode.json`, `waybar.css`,
   `waybar.sed`, `wofi.css`, and `xsettingsd.conf`. Keep fonts out of theme
   profiles; the font switcher injects the active font at runtime.
3. **Fill in `theme.conf`.** Set the GTK, icon, Kvantum, KDE, and wallpaper
   identifiers exactly as they are installed. `PREVIEW_COLORS` must
   contain space-separated `#RRGGBB` values. Use quoted scalar assignments
   only because the profile is sourced by shell scripts.
4. **Apply the palette consistently.** `waybar.css` and `wofi.css` expose the
   shared semantic color names. `waybar.sed` maps the Catppuccin colors still
   embedded in `waybar/config` command output. Update terminal ANSI colors,
   Sway borders and fallback background, lock indicators, notifications,
   screenshot controls, tmux, Neovim, Pi, and the local VS Code theme. Check
   contrast on both the main and elevated dark surfaces.
5. **Install toolkit assets.** Prefer a pinned upstream GTK theme and add a
   reproducible `scripts/update-*-gtk-theme.sh` instead of hand-editing
   generated CSS or images. Add its destination to the `links` array in
   `install.sh`. Add a managed KDE `.colors` file and link it there as well.
   If the profile needs derived Kvantum or Papirus colors, generate them in an
   idempotent installer function with a version marker, preserving the source
   license.
6. **Document user-facing support.** Update the root `README.md` when the
   available profiles, managed editor integration, links, or wallpaper
   behavior changes. The profile becomes selectable as
   `theme-switcher.sh SLUG` and appears in `theme-switcher.sh --list`.
7. **Validate before applying it live.** Run the repository validation
   checklist, validate every profile JSON file, smoke-test installation in
   isolated XDG directories, and confirm that generated links resolve. Then
   run `scripts/apply-theme.sh SLUG` in a graphical session and inspect GTK
   3/4, Qt/KDE, Sway, Waybar, Wofi, Dunst, Swaylock, Alacritty, tmux, Neovim,
   Pi, Flameshot, and the wallpaper.

The minimum non-graphical checks for a new theme are:

```sh
bash -n install.sh scripts/*.sh sway/scripts/*.sh waybar/scripts/*.sh
for file in themes/profiles/*/{pi,vscode}.json; do jq empty "$file"; done
WLR_BACKENDS=headless WLR_RENDERER=pixman sway -C -c sway/config
sandbox=$(mktemp -d)
HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/config" \
  XDG_DATA_HOME="$sandbox/data" DOTFILES_SKIP_THEME_APPLY=1 ./install.sh
rm -rf -- "$sandbox"
```
