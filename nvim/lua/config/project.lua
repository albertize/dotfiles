-- Project-root detection, native fuzzy pickers and project-wide search.
local M = {}
local picker_match_namespace = vim.api.nvim_create_namespace("NativePickerMatch")

local root_markers = {
  ".git", ".hg", "Makefile", "CMakeLists.txt", "package.json", "pyproject.toml",
  "Cargo.toml", "go.mod", ".luarc.json",
}

function M.root()
  local source = vim.b.native_ide_home and vim.fn.getcwd() or 0
  return vim.fs.root(source, root_markers) or vim.fn.getcwd()
end

local function native_picker(items, title, on_choice)
  if #items == 0 then
    vim.notify("No items", vim.log.levels.INFO)
    return
  end

  local origin = vim.api.nvim_get_current_win()
  local width = math.min(math.max(50, math.floor(vim.o.columns * 0.72)), vim.o.columns - 4)
  local height = math.min(18, math.max(5, vim.o.lines - 8))
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height - 3) / 2)
  local list_buf = vim.api.nvim_create_buf(false, true)
  local input_buf = vim.api.nvim_create_buf(false, true)
  local list_win = vim.api.nvim_open_win(list_buf, false, {
    relative = "editor", row = row, col = col, width = width, height = height,
    style = "minimal", border = "rounded", title = " " .. title .. " ", title_pos = "center",
  })
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor", row = row + height + 2, col = col, width = width, height = 1,
    style = "minimal", border = "rounded",
  })

  vim.wo[list_win].cursorline = true
  vim.wo[list_win].wrap = false
  vim.bo[list_buf].buftype = "nofile"
  vim.bo[list_buf].bufhidden = "wipe"
  vim.bo[input_buf].buftype = "prompt"
  vim.bo[input_buf].bufhidden = "wipe"
  vim.fn.prompt_setprompt(input_buf, " Search > ")

  local filtered = {}
  local filtered_positions = {}
  local selected = 1
  local picker_group = vim.api.nvim_create_augroup("NativePicker" .. input_buf, { clear = true })
  local closed = false

  local function close()
    if closed then return end
    closed = true
    pcall(vim.api.nvim_del_augroup_by_id, picker_group)
    if vim.api.nvim_win_is_valid(input_win) then vim.api.nvim_win_close(input_win, true) end
    if vim.api.nvim_win_is_valid(list_win) then vim.api.nvim_win_close(list_win, true) end
    if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
  end

  local function render()
    local query = ""
    if vim.api.nvim_buf_is_valid(input_buf) then
      local line = vim.api.nvim_buf_get_lines(input_buf, 0, 1, false)[1] or ""
      local prompt = vim.fn.prompt_getprompt(input_buf)
      query = vim.startswith(line, prompt) and line:sub(#prompt + 1) or line
    end
    if query == "" then
      filtered = vim.list_slice(items, 1, math.min(#items, 500))
      filtered_positions = {}
    else
      local fuzzy = vim.fn.matchfuzzypos(items, query)
      filtered = vim.list_slice(fuzzy[1], 1, 500)
      filtered_positions = vim.list_slice(fuzzy[2], 1, 500)
    end
    selected = math.max(1, math.min(selected, math.max(1, #filtered)))

    local display = #filtered > 0 and filtered or { "  No results" }
    vim.bo[list_buf].modifiable = true
    vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, display)
    vim.api.nvim_buf_clear_namespace(list_buf, picker_match_namespace, 0, -1)
    for row, positions in ipairs(filtered_positions) do
      local text = filtered[row]
      for _, char_position in ipairs(positions) do
        local start_col = vim.fn.byteidx(text, char_position)
        local end_col = vim.fn.byteidx(text, char_position + 1)
        if start_col >= 0 then
          vim.api.nvim_buf_set_extmark(list_buf, picker_match_namespace, row - 1, start_col, {
            end_col = end_col >= 0 and end_col or #text,
            hl_group = "NativePickerMatch",
          })
        end
      end
    end
    vim.bo[list_buf].modifiable = false
    if vim.api.nvim_win_is_valid(list_win) then
      vim.api.nvim_win_set_cursor(list_win, { selected, 0 })
    end
  end

  local function move(delta)
    if #filtered == 0 then return end
    selected = ((selected - 1 + delta) % #filtered) + 1
    vim.api.nvim_win_set_cursor(list_win, { selected, 0 })
  end

  local function choose()
    local choice = filtered[selected]
    close()
    if choice then on_choice(choice) end
  end

  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = picker_group,
    buf = input_buf,
    callback = function()
      selected = 1
      render()
    end,
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    group = picker_group,
    buf = input_buf,
    once = true,
    callback = function() vim.schedule(close) end,
  })

  local function pmap(modes, lhs, rhs)
    vim.keymap.set(modes, lhs, rhs, { buf = input_buf, nowait = true, silent = true })
  end
  pmap({ "i", "n" }, "<C-n>", function() move(1) end)
  pmap({ "i", "n" }, "<Down>", function() move(1) end)
  pmap({ "i", "n" }, "<C-p>", function() move(-1) end)
  pmap({ "i", "n" }, "<Up>", function() move(-1) end)
  pmap({ "i", "n" }, "<CR>", choose)
  pmap("i", "<Esc>", close)
  pmap("n", "<Esc>", close)
  pmap({ "i", "n" }, "<C-c>", close)

  render()
  vim.cmd.startinsert()
end

local ignored_dirs = {
  [".git"] = true,
  node_modules = true,
  target = true,
  dist = true,
  build = true,
  ["__pycache__"] = true,
}

local function lua_files(root)
  local files = {}
  local function walk(dir, prefix)
    if #files >= 20000 then return end
    local ok, iterator = pcall(vim.fs.dir, dir)
    if not ok then return end

    for name, kind in iterator do
      local rel = prefix == "" and name or (prefix .. "/" .. name)
      if kind == "directory" and not ignored_dirs[name] then
        walk(vim.fs.joinpath(dir, name), rel)
      elseif kind == "file" then
        files[#files + 1] = rel
      end
      if #files >= 20000 then return end
    end
  end

  walk(root, "")
  table.sort(files)
  return files
end

function M.files()
  local root = M.root()
  local files
  if vim.fn.executable("rg") == 1 then
    local result = vim.system({
      "rg", "--files", "--hidden", "-g", "!.git", "-g", "!node_modules",
      "-g", "!target", "-g", "!dist", "-g", "!build", "-g", "!__pycache__",
    }, { cwd = root, text = true }):wait()
    files = result.code == 0
      and vim.split(result.stdout or "", "\n", { trimempty = true })
      or lua_files(root)
  else
    files = lua_files(root)
  end

  native_picker(files, "File · " .. vim.fs.basename(root), function(choice)
    vim.cmd.edit(vim.fn.fnameescape(vim.fs.joinpath(root, choice)))
  end)
end

function M.grep(default)
  if vim.fn.executable("rg") == 0 then
    vim.notify("Live grep requires the 'rg' (ripgrep) executable", vim.log.levels.ERROR)
    return
  end

  vim.ui.input({ prompt = "Grep > ", default = default or "" }, function(query)
    if not query or query == "" then return end

    local root = M.root()
    local result = vim.system({
      "rg", "--vimgrep", "--smart-case", "--hidden", "-g", "!.git", "-g", "!node_modules", query, ".",
    }, { cwd = root, text = true }):wait()
    local lines = vim.split(result.stdout or "", "\n", { trimempty = true })
    if #lines == 0 then
      vim.notify("No results for: " .. query)
      return
    end

    vim.fn.setqflist({}, " ", {
      title = "Grep: " .. query,
      lines = lines,
      efm = "%f:%l:%c:%m",
    })
    vim.cmd("copen")
  end)
end

vim.api.nvim_create_user_command("ProjectRoot", function()
  local root = M.root()
  vim.cmd.lcd(vim.fn.fnameescape(root))
  vim.notify("Root: " .. root)
end, { desc = "Set the local working directory to the project root" })

vim.api.nvim_create_user_command("Files", M.files, { desc = "Native fuzzy file picker" })

vim.api.nvim_create_user_command("Buffers", function()
  local items, by_label = {}, {}
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local name = info.name ~= "" and vim.fn.fnamemodify(info.name, ":~:.") or "[No Name]"
    local label = string.format("%3d %s%s", info.bufnr, info.changed == 1 and "[+] " or "    ", name)
    items[#items + 1], by_label[label] = label, info.bufnr
  end
  native_picker(items, "Buffer", function(choice)
    vim.cmd.buffer(by_label[choice])
  end)
end, { desc = "Native fuzzy buffer picker" })

vim.api.nvim_create_user_command("Oldfiles", function()
  local items = {}
  for _, file in ipairs(vim.v.oldfiles) do
    if vim.fn.filereadable(file) == 1 then
      items[#items + 1] = vim.fn.fnamemodify(file, ":~")
    end
  end
  native_picker(items, "Recent files", function(choice)
    vim.cmd.edit(vim.fn.fnameescape(vim.fn.expand(choice)))
  end)
end, { desc = "Recent files" })

vim.api.nvim_create_user_command("Grep", function(opts)
  M.grep(opts.args)
end, { nargs = "?", desc = "Search project text with ripgrep" })

return M
