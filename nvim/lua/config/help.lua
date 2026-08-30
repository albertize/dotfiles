-- Floating command and keymap summary.
local M = {}
local namespace = vim.api.nvim_create_namespace("NativeIDECommandSummary")

local sections = {
  {
    title = "GENERAL",
    entries = {
      { "<leader>w", "Save file" },
      { "<leader>q", "Quit window" },
      { "<leader>bd", "Delete buffer" },
      { "[b / ]b", "Previous / next buffer" },
      { "Ctrl-h/j/k/l", "Move between windows" },
      { "Esc", "Clear search highlights" },
    },
  },
  {
    title = "FILES AND PROJECT",
    entries = {
      { "<leader>p / ff", "Find file" },
      { "<leader>fb", "Find buffer" },
      { "<leader>fr", "Recent files" },
      { "<leader>fg", "Grep project" },
      { "<leader>fw", "Grep word under cursor" },
      { ":Home", "Open home page" },
      { ":ProjectRoot", "Use detected project root" },
    },
  },
  {
    title = "LSP",
    entries = {
      { "gd / gD", "Definition / declaration" },
      { "gi / gr / gy", "Implementation / references / type" },
      { "K", "Hover documentation" },
      { "Ctrl-Space", "Completion" },
      { "<leader>rn", "Rename symbol" },
      { "<leader>ca", "Code action" },
      { "<leader>lf", "Format buffer or selection" },
      { "<leader>ls / lS", "Document / workspace symbols" },
      { "<leader>li", "Toggle inlay hints" },
      { "<leader>lc", "Run code lens" },
      { "<leader>lh / lH", "Incoming / outgoing calls" },
      { ":LspServers", "Show detected language servers" },
      { ":FormatOnSave", "Toggle format on save" },
    },
  },
  {
    title = "DIAGNOSTICS, QUICKFIX AND BUILD",
    entries = {
      { "<leader>e", "Diagnostic under cursor" },
      { "[d / ]d", "Previous / next diagnostic" },
      { "<leader>dq", "Diagnostics in quickfix" },
      { "<leader>dt", "Toggle diagnostics" },
      { "[q / ]q", "Previous / next quickfix item" },
      { "<leader>co / cc", "Open / close quickfix" },
      { "<leader>mm", "Build with makeprg" },
    },
  },
  {
    title = "HOME PAGE",
    entries = {
      { "f / r", "Files / recent files" },
      { "g / b", "Project grep / buffers" },
      { "n / q", "New file / quit" },
      { "j/k or arrows", "Select an action" },
      { "Enter", "Run selected action" },
    },
  },
}

local function build_content()
  local lines = {}
  local highlights = {}
  local key_width = 20

  for section_index, section in ipairs(sections) do
    if section_index > 1 then lines[#lines + 1] = "" end
    local title_row = #lines
    lines[#lines + 1] = section.title
    highlights[#highlights + 1] = {
      row = title_row,
      start_col = 0,
      end_col = #section.title,
      hl = "NativeHelpTitle",
    }

    for _, entry in ipairs(section.entries) do
      local key = entry[1]
      local description = entry[2]
      local padding = string.rep(" ", math.max(1, key_width - vim.fn.strdisplaywidth(key)))
      local line = "  " .. key .. padding .. description
      local row = #lines
      lines[#lines + 1] = line
      highlights[#highlights + 1] = {
        row = row,
        start_col = 2,
        end_col = 2 + #key,
        hl = "NativeHelpKey",
      }
      highlights[#highlights + 1] = {
        row = row,
        start_col = 2 + #key + #padding,
        end_col = #line,
        hl = "NativeHelpText",
      }
    end
  end

  lines[#lines + 1] = ""
  local footer = "q / Esc: close    j/k: scroll"
  local footer_row = #lines
  lines[#lines + 1] = footer
  highlights[#highlights + 1] = {
    row = footer_row,
    start_col = 0,
    end_col = #footer,
    hl = "NativeHelpMuted",
  }

  return lines, highlights
end

function M.open()
  local lines, highlights = build_content()
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(math.max(58, max_width + 4), math.max(20, vim.o.columns - 4))
  local height = math.min(#lines, math.max(8, vim.o.lines - 6))
  local row = math.max(0, math.floor((vim.o.lines - height - 2) / 2))
  local col = math.max(0, math.floor((vim.o.columns - width) / 2))
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = " Command Summary ",
    title_pos = "center",
  })

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "native-help"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = false

  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(buf, namespace, highlight.row, highlight.start_col, {
      end_col = highlight.end_col,
      hl_group = highlight.hl,
    })
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  vim.keymap.set("n", "q", close, { buf = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close, { buf = buf, silent = true, nowait = true })
end

vim.api.nvim_create_user_command("Commands", M.open, { desc = "Open the command summary" })

return M
