-- Native Neovim home page shown when the editor starts without a file.
local M = {}
local namespace = vim.api.nvim_create_namespace("NativeIDEHome")
local group = vim.api.nvim_create_augroup("NativeIDEHome", { clear = true })

local state = {
  buf = nil,
  win = nil,
  window_options = nil,
  action_rows = {},
  action_cols = {},
  actions = {},
}

local logo = {
  "███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗",
  "████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║",
  "██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║",
  "██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

local menu = {
  { key = "f", label = "Find file", action = function() require("config.project").files() end },
  { key = "r", label = "Recent files", action = function() vim.cmd("Oldfiles") end },
  { key = "g", label = "Grep project", action = function() require("config.project").grep() end },
  { key = "b", label = "Open buffers", action = function() vim.cmd("Buffers") end },
  { key = "n", label = "New file", action = function() vim.cmd("enew") end },
  { key = "q", label = "Quit", action = function() vim.cmd("quit") end },
}

local function is_home(buf)
  return vim.api.nvim_buf_is_valid(buf) and vim.b[buf].native_ide_home == true
end

local function add_line(content, segments)
  content[#content + 1] = segments
end

local function render(buf)
  if not is_home(buf) then return end

  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end

  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)
  local content = {}

  for _, line in ipairs(logo) do
    add_line(content, { { text = line, hl = "NativeHomeHeader" } })
  end
  add_line(content, {})
  add_line(content, { { text = "Native IDE · Catppuccin Macchiato", hl = "NativeHomeTitle" } })
  add_line(content, { { text = "No plugins. Just Neovim.", hl = "NativeHomeMuted" } })
  add_line(content, {})

  local menu_label_width = 0
  for _, item in ipairs(menu) do
    menu_label_width = math.max(menu_label_width, vim.fn.strdisplaywidth(item.label))
  end

  local action_content_indexes = {}
  for index, item in ipairs(menu) do
    action_content_indexes[index] = #content + 1
    local trailing = string.rep(" ", menu_label_width - vim.fn.strdisplaywidth(item.label))
    add_line(content, {
      { text = "[" .. item.key .. "]  ", hl = "NativeHomeKey" },
      { text = item.label, hl = "NativeHomeAction" },
      { text = trailing },
    })
  end

  add_line(content, {})
  add_line(content, { { text = vim.fn.getcwd(), hl = "NativeHomeMuted" } })

  local top = math.max(1, math.floor((height - #content) / 2))
  local lines = {}
  for _ = 1, top do lines[#lines + 1] = "" end

  local highlights = {}
  state.action_rows = {}
  state.action_cols = {}
  state.actions = {}

  for content_index, segments in ipairs(content) do
    local text = ""
    for _, segment in ipairs(segments) do text = text .. segment.text end
    local display_width = vim.fn.strdisplaywidth(text)
    local padding = string.rep(" ", math.max(0, math.floor((width - display_width) / 2)))
    local row = #lines
    lines[#lines + 1] = padding .. text

    local byte_col = #padding
    for _, segment in ipairs(segments) do
      local end_col = byte_col + #segment.text
      if segment.hl and segment.text ~= "" then
        highlights[#highlights + 1] = {
          row = row,
          start_col = byte_col,
          end_col = end_col,
          hl = segment.hl,
        }
      end
      byte_col = end_col
    end

    for action_index, source_index in pairs(action_content_indexes) do
      if source_index == content_index then
        state.action_rows[#state.action_rows + 1] = row + 1
        state.action_cols[row + 1] = #padding
        state.actions[row + 1] = menu[action_index].action
      end
    end
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
  for _, highlight in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(buf, namespace, highlight.row, highlight.start_col, {
      end_col = highlight.end_col,
      hl_group = highlight.hl,
    })
  end
  vim.bo[buf].modifiable = false

  if #state.action_rows > 0 then
    local row = state.action_rows[1]
    pcall(vim.api.nvim_win_set_cursor, win, { row, state.action_cols[row] or 0 })
  end
end

local function run_action(buf)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local action = state.actions[row]
  if action and is_home(buf) then action() end
end

local function move(buf, direction)
  if not is_home(buf) or #state.action_rows == 0 then return end
  local current = vim.api.nvim_win_get_cursor(0)[1]
  local selected = 1
  for index, row in ipairs(state.action_rows) do
    if row == current then selected = index break end
  end
  selected = ((selected - 1 + direction) % #state.action_rows) + 1
  local row = state.action_rows[selected]
  vim.api.nvim_win_set_cursor(0, { row, state.action_cols[row] or 0 })
end

function M.open()
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified or (vim.api.nvim_buf_get_name(buf) ~= "" and not is_home(buf)) then
    vim.cmd("enew")
    buf = vim.api.nvim_get_current_buf()
  end

  local win = vim.api.nvim_get_current_win()
  state.win = win
  state.window_options = {
    number = vim.wo[win].number,
    relativenumber = vim.wo[win].relativenumber,
    signcolumn = vim.wo[win].signcolumn,
    foldcolumn = vim.wo[win].foldcolumn,
    colorcolumn = vim.wo[win].colorcolumn,
    cursorline = vim.wo[win].cursorline,
    wrap = vim.wo[win].wrap,
  }

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = false
  vim.bo[buf].filetype = "native-home"
  vim.b[buf].native_ide_home = true
  pcall(vim.api.nvim_buf_set_name, buf, "native-ide://home")

  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.foldcolumn = "0"
  vim.wo.colorcolumn = ""
  vim.wo.cursorline = true
  vim.wo.wrap = false

  state.buf = buf
  render(buf)

  local function bmap(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buf = buf, silent = true, nowait = true })
  end
  for _, item in ipairs(menu) do bmap(item.key, item.action) end
  bmap("<CR>", function() run_action(buf) end)
  bmap("<2-LeftMouse>", function() run_action(buf) end)
  bmap("j", function() move(buf, 1) end)
  bmap("<Down>", function() move(buf, 1) end)
  bmap("k", function() move(buf, -1) end)
  bmap("<Up>", function() move(buf, -1) end)
end

vim.api.nvim_create_user_command("Home", M.open, { desc = "Open the Native IDE home page" })

vim.api.nvim_create_autocmd("VimEnter", {
  group = group,
  once = true,
  callback = function()
    local buf = vim.api.nvim_get_current_buf()
    local argc = vim.fn.argc()
    local directory = argc == 1 and vim.fn.isdirectory(vim.fn.argv(0)) == 1

    if directory then
      local path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.argv(0), ":p"))
      vim.cmd.cd(vim.fn.fnameescape(path))
      vim.cmd("enew")
      local home_buf = vim.api.nvim_get_current_buf()
      if buf ~= home_buf and vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
      M.open()
      return
    end

    local empty = vim.api.nvim_buf_line_count(buf) == 1
      and (vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or "") == ""
    if argc == 0 and vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) == "" and empty then
      M.open()
    end
  end,
})

vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    if state.buf and is_home(state.buf) then render(state.buf) end
  end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(ev)
    if ev.buf ~= state.buf or not state.window_options then return end
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      for option, value in pairs(state.window_options) do
        vim.wo[state.win][option] = value
      end
    end
    state.buf = nil
    state.win = nil
    state.window_options = nil
  end,
})

return M
