-- Core editor behavior inherited from ~/.vimrc plus IDE conveniences.
local opt = vim.opt

opt.encoding = "utf-8"
opt.history = 1000
opt.backspace = { "indent", "eol", "start" }
opt.number = true
opt.relativenumber = false
opt.ruler = true
opt.showmode = true
opt.laststatus = 3
opt.showtabline = 2
opt.termguicolors = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.colorcolumn = ""
opt.scrolloff = 5
opt.sidescrolloff = 8
opt.wrap = false
opt.linebreak = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true
opt.incsearch = true
opt.hlsearch = true
opt.ignorecase = true
opt.smartcase = true
opt.wildmenu = true
opt.wildmode = { "longest:full", "full" }
opt.completeopt = { "menu", "menuone", "noselect", "popup" }
opt.pumheight = 12
opt.splitbelow = true
opt.splitright = true
opt.mouse = "a"
opt.undofile = true
opt.swapfile = false
opt.updatetime = 300
opt.timeoutlen = 400
opt.confirm = true
opt.autoread = true
opt.hidden = true
opt.foldmethod = "indent"
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.path:append("**")
opt.wildignore:append({
  ".git", "node_modules", "target", "dist", "build", "__pycache__", "*.o", "*.pyc",
})
opt.shortmess:append("I")

vim.cmd("syntax enable")
vim.cmd("filetype plugin indent on")
