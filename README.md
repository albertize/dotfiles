# Dotfiles

Personal configuration files for:

- [Neovim](nvim)
- [tmux](.tmux.conf)
- [Alacritty](alacritty)
- [Shell prompt](promptrc) — not installed automatically

## Installation

Run the installer from any directory:

```sh
./install.sh
```

It creates the following symbolic links:

- `~/.tmux.conf` → `.tmux.conf`
- `${XDG_CONFIG_HOME:-~/.config}/alacritty` → `alacritty/`
- `${XDG_CONFIG_HOME:-~/.config}/nvim` → `nvim/`

If a destination already exists, the installer asks for confirmation before replacing it.
