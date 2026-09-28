# Dotfiles

Minimal configuration for:

- [Neovim](nvim) 0.12 or later
- [tmux](.tmux.conf)
- [Alacritty](alacritty/alacritty.toml)

Neovim and tmux use ANSI color indexes, so their appearance follows the terminal palette. Alacritty provides the normal, bright, and dim colors from Konsole's Breeze scheme.

## Installation

Run:

```sh
./install.sh
```

The installer creates these symbolic links:

- `~/.tmux.conf` → `.tmux.conf`
- `${XDG_CONFIG_HOME:-~/.config}/alacritty/alacritty.toml` → `alacritty/alacritty.toml`
- `${XDG_CONFIG_HOME:-~/.config}/nvim` → `nvim/`

It is safe to run repeatedly. Before replacing an existing file or directory, it asks for confirmation.

Alacritty starts by attaching to an existing tmux session, or by creating one if none exists.
