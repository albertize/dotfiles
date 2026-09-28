-- Native highlights resolved through the terminal's ANSI palette.
local M = { display_name = "ANSI" }

local palette = {
  rosewater = 15,
  flamingo = 7,
  pink = 13,
  mauve = 13,
  red = 1,
  maroon = 9,
  peach = 3,
  yellow = 11,
  green = 2,
  teal = 6,
  sky = 14,
  sapphire = 6,
  blue = 4,
  lavender = 13,
  text = 15,
  subtext1 = 7,
  subtext0 = 8,
  overlay2 = 8,
  overlay1 = 8,
  overlay0 = 8,
  surface2 = 8,
  surface1 = 8,
  surface0 = 0,
  base = 0,
  mantle = 0,
  crust = 0,
}

local function set_ansi_highlight(ns, name, opts)
  opts = vim.deepcopy(opts)

  if type(opts.fg) == "number" then
    opts.ctermfg = opts.fg
    opts.fg = nil
  end

  if type(opts.bg) == "number" then
    opts.ctermbg = opts.bg
    opts.bg = nil
  end

  -- Neovim accepts only RGB values for special underline colors.
  if type(opts.sp) == "number" then
    opts.sp = nil
  end

  vim.api.nvim_set_hl(ns, name, opts)
end

function M.setup()
  M.palette = palette

  local c = palette
  local set = set_ansi_highlight

  vim.opt.termguicolors = false
  vim.o.background = "dark"
  vim.cmd("highlight clear")

  if vim.fn.exists("syntax_on") == 1 then
    vim.cmd("syntax reset")
  end

  vim.g.colors_name = "ansi"

  local groups = {
    -- Editor UI.
    Normal = { fg = c.text, bg = c.base },
    NormalNC = { fg = c.subtext1, bg = c.base },
    NormalFloat = { fg = c.text, bg = c.mantle },
    FloatBorder = { fg = c.surface2, bg = c.mantle },
    FloatTitle = { fg = c.lavender, bg = c.mantle, bold = true },

    Cursor = { fg = c.base, bg = c.rosewater },
    lCursor = { fg = c.base, bg = c.rosewater },
    CursorIM = { fg = c.base, bg = c.rosewater },

    -- Avoid painting or underlining the full terminal row. Picker windows use
    -- a dedicated selection group where a stronger marker is useful.
    CursorLine = { bold = true },
    CursorColumn = { reverse = true },
    ColorColumn = { reverse = true },

    LineNr = { fg = c.overlay0, bg = c.base },
    CursorLineNr = {
      fg = c.lavender,
      bg = c.surface0,
      bold = true,
    },

    SignColumn = { fg = c.surface2, bg = c.base },
    FoldColumn = { fg = c.overlay0, bg = c.base },
    Folded = { reverse = true },

    WinSeparator = { fg = c.overlay0, bg = c.base },
    VertSplit = { fg = c.overlay0, bg = c.base },

    -- Stateful UI elements follow Vim's default strategy: reverse the normal
    -- terminal colors instead of assuming a particular ANSI foreground and
    -- background combination.
    StatusLine = { reverse = true },
    StatusLineNC = { reverse = true },

    TabLine = { fg = c.subtext1, bg = c.mantle },
    TabLineFill = { bg = c.crust },
    TabLineSel = { reverse = true },

    WinBar = { fg = c.subtext1, bg = c.base, bold = true },
    WinBarNC = { fg = c.overlay0, bg = c.base },

    Pmenu = { fg = c.subtext1, bg = c.mantle },
    PmenuSel = { reverse = true, underline = true },

    PmenuKind = { fg = c.mauve, bg = c.mantle },
    PmenuKindSel = { reverse = true },

    PmenuExtra = { fg = c.overlay1, bg = c.mantle },
    PmenuExtraSel = { reverse = true },

    PmenuMatch = { fg = c.blue, bg = c.mantle, bold = true },
    PmenuMatchSel = { reverse = true, underline = true },

    PmenuSbar = { bg = c.surface0 },
    PmenuThumb = { bg = c.surface2 },

    ComplMatchIns = { fg = c.blue },

    Search = { reverse = true },
    CurSearch = { reverse = true, underline = true },
    IncSearch = { reverse = true, underline = true },
    Substitute = { reverse = true },

    Visual = { reverse = true },
    VisualNOS = { reverse = true },

    MatchParen = { reverse = true },

    Whitespace = { fg = c.surface1 },
    NonText = { fg = c.surface1 },
    SpecialKey = { fg = c.surface2 },
    EndOfBuffer = { fg = c.base },

    Directory = { fg = c.blue, bold = true },
    Title = { fg = c.lavender, bold = true },

    ErrorMsg = { fg = c.red, bold = true },
    WarningMsg = { fg = c.peach, bold = true },
    MoreMsg = { fg = c.teal },
    Question = { fg = c.green },
    ModeMsg = { fg = c.yellow, bold = true },

    WildMenu = { reverse = true },

    QuickFixLine = { reverse = true },

    -- Native picker selection. This is mapped from CursorLine only in picker
    -- windows, so regular source lines retain their syntax foregrounds.
    NativePickerSelection = { reverse = true },

    -- Native home page.
    NativeHomeHeader = { fg = c.mauve, bold = true },
    NativeHomeTitle = { fg = c.blue, bold = true },
    NativeHomeKey = { fg = c.peach, bold = true },
    NativeHomeAction = { fg = c.text },
    NativeHomeMuted = { fg = c.overlay0, italic = true },

    -- Command summary.
    NativeHelpTitle = { fg = c.mauve, bold = true },
    NativeHelpKey = { fg = c.peach, bold = true },
    NativeHelpText = { fg = c.text },
    NativeHelpMuted = { fg = c.overlay0, italic = true },

    -- Native search matches.
    NativePickerMatch = {
      fg = c.peach,
      bold = true,
      underline = true,
    },

    NativeGrepMatch = {
      fg = c.peach,
      bold = true,
      underline = true,
    },

    -- Diff and spelling.
    DiffAdd = { fg = c.green, bg = c.surface0 },
    DiffChange = { fg = c.yellow, bg = c.surface0 },
    DiffDelete = { fg = c.red, bg = c.surface0 },

    DiffText = {
      fg = c.blue,
      bg = c.surface1,
      bold = true,
    },

    Added = { fg = c.green },
    Changed = { fg = c.yellow },
    Removed = { fg = c.red },

    SpellBad = { sp = c.red, undercurl = true },
    SpellCap = { sp = c.yellow, undercurl = true },
    SpellLocal = { sp = c.blue, undercurl = true },
    SpellRare = { sp = c.green, undercurl = true },

    -- Vim syntax groups.
    Comment = { fg = c.overlay0, italic = true },

    Constant = { fg = c.peach },
    String = { fg = c.green },
    Character = { fg = c.teal },
    Number = { fg = c.peach },
    Boolean = { fg = c.peach, bold = true },
    Float = { fg = c.peach },

    Identifier = { fg = c.text },
    Function = { fg = c.blue },

    Statement = { fg = c.mauve },
    Conditional = { fg = c.mauve },
    Repeat = { fg = c.mauve },
    Label = { fg = c.sapphire },
    Operator = { fg = c.sky },
    Keyword = { fg = c.mauve, italic = true },
    Exception = { fg = c.red },

    PreProc = { fg = c.pink },
    Include = { fg = c.mauve },
    Define = { fg = c.pink },
    Macro = { fg = c.pink },
    PreCondit = { fg = c.pink },

    Type = { fg = c.yellow },
    StorageClass = { fg = c.yellow },
    Structure = { fg = c.yellow },
    Typedef = { fg = c.yellow },

    Special = { fg = c.pink },
    SpecialChar = { fg = c.peach },
    Tag = { fg = c.lavender },
    Delimiter = { fg = c.overlay2 },

    SpecialComment = {
      fg = c.overlay1,
      italic = true,
    },

    Debug = { fg = c.red },

    Underlined = {
      fg = c.blue,
      underline = true,
    },

    Ignore = { fg = c.overlay0 },
    Error = { fg = c.red, bold = true },

    Todo = {
      fg = c.base,
      bg = c.yellow,
      bold = true,
    },

    -- Diagnostics and native LSP UI.
    DiagnosticError = { fg = c.red },
    DiagnosticWarn = { fg = c.peach },
    DiagnosticInfo = { fg = c.sky },
    DiagnosticHint = { fg = c.teal },
    DiagnosticOk = { fg = c.green },

    DiagnosticVirtualTextError = {
      fg = c.red,
      bg = c.mantle,
    },

    DiagnosticVirtualTextWarn = {
      fg = c.peach,
      bg = c.mantle,
    },

    DiagnosticVirtualTextInfo = {
      fg = c.sky,
      bg = c.mantle,
    },

    DiagnosticVirtualTextHint = {
      fg = c.teal,
      bg = c.mantle,
    },

    DiagnosticUnderlineError = {
      sp = c.red,
      undercurl = true,
    },

    DiagnosticUnderlineWarn = {
      sp = c.peach,
      undercurl = true,
    },

    DiagnosticUnderlineInfo = {
      sp = c.sky,
      undercurl = true,
    },

    DiagnosticUnderlineHint = {
      sp = c.teal,
      undercurl = true,
    },

    DiagnosticFloatingError = {
      fg = c.red,
      bg = c.mantle,
    },

    DiagnosticFloatingWarn = {
      fg = c.peach,
      bg = c.mantle,
    },

    DiagnosticFloatingInfo = {
      fg = c.sky,
      bg = c.mantle,
    },

    DiagnosticFloatingHint = {
      fg = c.teal,
      bg = c.mantle,
    },

    LspReferenceText = { bg = c.surface1 },
    LspReferenceRead = { bg = c.surface1 },

    LspReferenceWrite = {
      bg = c.surface1,
      underline = true,
    },

    LspInlayHint = {
      fg = c.overlay0,
      bg = c.surface0,
      italic = true,
    },

    LspCodeLens = {
      fg = c.overlay0,
      italic = true,
    },

    LspCodeLensSeparator = { fg = c.surface2 },

    LspSignatureActiveParameter = {
      fg = c.peach,
      bold = true,
      underline = true,
    },

    LspInfoBorder = {
      fg = c.surface2,
      bg = c.mantle,
    },

    -- Keep every statusline section neutral and consistent with StatusLine.
    User1 = { link = "StatusLine" },
    User2 = { link = "StatusLine" },
    User3 = { link = "StatusLine" },
    User4 = { link = "StatusLine" },
    User5 = { link = "StatusLine" },
  }

  for name, value in pairs(groups) do
    set(0, name, value)
  end

  local links = {
    -- Tree-sitter captures.
    ["@comment"] = "Comment",
    ["@comment.documentation"] = "SpecialComment",
    ["@comment.error"] = "DiagnosticError",
    ["@comment.warning"] = "DiagnosticWarn",
    ["@comment.todo"] = "Todo",

    ["@constant"] = "Constant",
    ["@constant.builtin"] = "Constant",
    ["@constant.macro"] = "Macro",

    ["@string"] = "String",
    ["@string.documentation"] = "String",
    ["@string.escape"] = "SpecialChar",
    ["@string.regexp"] = "SpecialChar",
    ["@string.special"] = "Special",

    ["@character"] = "Character",
    ["@character.special"] = "SpecialChar",

    ["@boolean"] = "Boolean",

    ["@number"] = "Number",
    ["@number.float"] = "Float",

    ["@variable"] = "Identifier",
    ["@variable.builtin"] = "Special",
    ["@variable.parameter"] = "Identifier",
    ["@variable.member"] = "Identifier",

    ["@module"] = "Include",
    ["@label"] = "Label",

    ["@function"] = "Function",
    ["@function.builtin"] = "Function",
    ["@function.call"] = "Function",
    ["@function.macro"] = "Macro",
    ["@function.method"] = "Function",
    ["@function.method.call"] = "Function",

    ["@constructor"] = "Special",

    ["@operator"] = "Operator",

    ["@keyword"] = "Keyword",
    ["@keyword.coroutine"] = "Keyword",
    ["@keyword.function"] = "Keyword",
    ["@keyword.operator"] = "Operator",
    ["@keyword.import"] = "Include",
    ["@keyword.type"] = "Keyword",
    ["@keyword.modifier"] = "Keyword",
    ["@keyword.repeat"] = "Repeat",
    ["@keyword.return"] = "Keyword",
    ["@keyword.debug"] = "Debug",
    ["@keyword.exception"] = "Exception",
    ["@keyword.conditional"] = "Conditional",
    ["@keyword.directive"] = "PreProc",

    ["@type"] = "Type",
    ["@type.builtin"] = "Type",
    ["@type.definition"] = "Typedef",

    ["@attribute"] = "PreProc",
    ["@property"] = "Identifier",

    ["@punctuation.delimiter"] = "Delimiter",
    ["@punctuation.bracket"] = "Delimiter",
    ["@punctuation.special"] = "Special",

    ["@markup.strong"] = "Bold",
    ["@markup.italic"] = "Italic",
    ["@markup.strikethrough"] = "Strikethrough",
    ["@markup.underline"] = "Underlined",
    ["@markup.heading"] = "Title",
    ["@markup.quote"] = "SpecialComment",
    ["@markup.math"] = "Special",
    ["@markup.link"] = "Underlined",
    ["@markup.link.label"] = "Label",
    ["@markup.link.url"] = "Underlined",
    ["@markup.raw"] = "String",
    ["@markup.list"] = "Special",

    ["@diff.plus"] = "Added",
    ["@diff.minus"] = "Removed",
    ["@diff.delta"] = "Changed",

    ["@tag"] = "Tag",
    ["@tag.attribute"] = "PreProc",
    ["@tag.delimiter"] = "Delimiter",

    -- LSP semantic token groups.
    ["@lsp.type.class"] = "@type",
    ["@lsp.type.comment"] = "@comment",
    ["@lsp.type.decorator"] = "@attribute",
    ["@lsp.type.enum"] = "@type",
    ["@lsp.type.enumMember"] = "@constant",
    ["@lsp.type.event"] = "@type",
    ["@lsp.type.function"] = "@function",
    ["@lsp.type.interface"] = "@type",
    ["@lsp.type.keyword"] = "@keyword",
    ["@lsp.type.macro"] = "@constant.macro",
    ["@lsp.type.method"] = "@function.method",
    ["@lsp.type.modifier"] = "@keyword.modifier",
    ["@lsp.type.namespace"] = "@module",
    ["@lsp.type.number"] = "@number",
    ["@lsp.type.operator"] = "@operator",
    ["@lsp.type.parameter"] = "@variable.parameter",
    ["@lsp.type.property"] = "@property",
    ["@lsp.type.regexp"] = "@string.regexp",
    ["@lsp.type.string"] = "@string",
    ["@lsp.type.struct"] = "@type",
    ["@lsp.type.type"] = "@type",
    ["@lsp.type.typeParameter"] = "@type.definition",
    ["@lsp.type.variable"] = "@variable",
  }

  for name, target in pairs(links) do
    set(0, name, { link = target })
  end

  -- Core formatting groups used as Tree-sitter link targets.
  set(0, "Bold", { bold = true })
  set(0, "Italic", { italic = true })
  set(0, "Strikethrough", { strikethrough = true })

  -- Let terminal buffers inherit ANSI colors 0-15 from the host terminal.
  for index = 0, 15 do
    vim.g["terminal_color_" .. index] = nil
  end
end

return M
