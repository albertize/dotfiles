# Neovim Native IDE

An IDE configuration written entirely with Lua and native Neovim APIs: **no plugin manager and no third-party plugins**.
It requires Neovim 0.12 or later and has been tested with the installed Neovim 0.12.5.

## Included features

- Native Catppuccin Macchiato theme matching the terminal
- Automatic LSP startup for servers available in `PATH`
- Native LSP completion and snippet expansion
- Diagnostics, code actions, rename, hover and signature help
- Definitions, references, implementations and call hierarchy
- Semantic tokens, inlay hints, code lens and document highlights
- Format on save
- Native clickable buffer line that keeps the active buffer visible
- Native fuzzy picker for files, buffers and recent files
- Project search and quickfix integration with `ripgrep`
- Builds through `makeprg`
- Statusline with Git branch, diagnostics and active LSP clients
- Persistent undo, folding, buffer navigation and project-root detection

## Layout

The configuration is split by responsibility:

- `init.lua` — bootstrap and module loading
- `lua/config/options.lua` — editor options
- `lua/config/theme.lua` — native Catppuccin Macchiato theme
- `lua/config/autocmds.lua` — general autocommands
- `lua/config/statusline.lua` — statusline and Git branch
- `lua/config/tabline.lua` — clickable buffer line
- `lua/config/project.lua` — project root, pickers and grep
- `lua/config/diagnostics.lua` — diagnostic presentation and navigation
- `lua/config/lsp.lua` — language servers and LSP behavior
- `lua/config/keymaps.lua` — global keymaps

## Theme

The Catppuccin Macchiato palette is implemented directly with Neovim's highlight API in `lua/config/theme.lua`. It covers the editor UI, Vim syntax, Tree-sitter captures, LSP semantic tokens, diagnostics and terminal ANSI colors without requiring a theme plugin.

## Language servers

LSP servers are external processes, not Neovim plugins. The configuration only enables executables found in `PATH`. Check their status with:

```vim
:LspServers
:checkhealth vim.lsp
```

## Main keymaps

The leader key is `Space`.

| Key | Action |
|---|---|
| `<leader>p` / `<leader>ff` | file picker |
| `<leader>fb` | buffer picker |
| `<leader>fr` | recent files |
| `<leader>fg` | grep project |
| `<leader>fw` | grep word under cursor |
| `gd` / `gD` | definition / declaration |
| `gi` / `gr` / `gy` | implementations / references / type definition |
| `K` | LSP documentation |
| `<C-Space>` | LSP completion |
| `<leader>rn` | rename |
| `<leader>ca` | code action |
| `<leader>lf` | format |
| `<leader>ls` / `<leader>lS` | document / workspace symbols |
| `<leader>li` | toggle inlay hints |
| `<leader>lc` | run code lens |
| `<leader>lh` / `<leader>lH` | incoming / outgoing calls |
| `<leader>e` | diagnostics under cursor |
| `[d` / `]d` | previous / next diagnostic |
| `<leader>dq` | diagnostics in quickfix |
| `<leader>mm` | build with `makeprg` |
| `[b` / `]b` | previous / next buffer |
| `[q` / `]q` | previous / next quickfix item |

In the buffer line, left-click a label to open it or middle-click it to close the buffer. A dot marks modified buffers.
In a picker, type to filter, use `Ctrl-n`/`Ctrl-p` to move, `Enter` to open and `Esc` to close.

## Commands

- `:Files`, `:Buffers`, `:Oldfiles`, `:Grep [text]`
- `:ProjectRoot`
- `:FormatOnSave` — toggle for the current buffer
- `:LspServers`
- `:lsp status`, `:lsp restart`, `:lsp stop`

`ripgrep` (`rg`) is optional for the file picker because a Lua fallback is available, but it is required by `:Grep`.
