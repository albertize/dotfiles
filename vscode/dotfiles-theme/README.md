# Dotfiles Theme

This local VS Code extension exposes the active repository profile as the
`Dotfiles` color theme. `install.sh` installs the repository-built VSIX through
each editor's CLI, then synchronizes its runtime theme file from
`${XDG_CONFIG_HOME:-~/.config}/dotfiles-theme/vscode.json`.

Do not edit the runtime extension directory. Edit each profile's `vscode.json`
in `themes/profiles/` instead. After changing the extension manifest, license,
README, or packaged default theme, rebuild the VSIX with:

```sh
./scripts/build-vscode-theme-extension.sh
```

The build script pins `@vscode/vsce` and uses Catppuccin Macchiato only as the
initial packaged palette; `scripts/apply-theme.sh` replaces it with the active
profile after installation. The theme contribution enables VS Code's native
color-theme file watcher so running windows reload palette changes directly.
