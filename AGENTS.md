# Repository Guidelines

This repository manages configuration only for Neovim, tmux, and Alacritty.

- Keep installation reproducible and idempotent through `install.sh`.
- Respect `XDG_CONFIG_HOME`; do not hardcode the user's home directory.
- Preserve the confirmation prompt before replacing existing files.
- Keep Neovim and tmux colors based on ANSI indexes from the terminal.
- Keep Alacritty's palette synchronized with Konsole's Breeze color scheme.
- Do not add secrets or machine-specific data.
- Write documentation and comments in English.

Validate relevant changes with:

```sh
bash -n install.sh
nvim --headless '+quit'
python3 -c 'import tomllib; tomllib.load(open("alacritty/alacritty.toml", "rb"))'
# Use an isolated tmux server when checking .tmux.conf.
git diff --check
```
