-- Neovim IDE configuration without third-party plugins.
-- Requires Neovim >= 0.12 and the desired language servers in PATH.

if vim.fn.has("nvim-0.12") == 0 then
  error("This configuration requires Neovim >= 0.12")
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.theme").setup()
require("config.autocmds")
require("config.statusline")
require("config.tabline")
require("config.project")
require("config.diagnostics")
require("config.lsp")
require("config.keymaps")
