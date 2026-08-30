-- Native clickable buffer line displayed in Neovim's tabline.
local group = vim.api.nvim_create_augroup("NativeIDETabline", { clear = true })

local function buffer_name(buf, duplicate_names)
  if vim.bo[buf].buftype == "terminal" then
    return "Terminal " .. buf
  end

  local path = vim.api.nvim_buf_get_name(buf)
  if path == "" then
    return "[No Name]"
  end

  local name = vim.fs.basename(path)
  if duplicate_names[name] and duplicate_names[name] > 1 then
    name = vim.fs.basename(vim.fs.dirname(path)) .. "/" .. name
  end
  if vim.fn.strdisplaywidth(name) > 28 then
    local length = vim.fn.strchars(name)
    name = "…" .. vim.fn.strcharpart(name, math.max(0, length - 26), 26)
  end
  return name
end

_G.NativeIDEBufferClick = function(buf, _, button)
  if not vim.api.nvim_buf_is_valid(buf) then return end

  if button == "m" then
    local ok, err = pcall(vim.api.nvim_buf_delete, buf, { force = false })
    if not ok then vim.notify(err, vim.log.levels.WARN) end
    return
  end

  if button == "l" and vim.bo[buf].buflisted then
    local ok, err = pcall(vim.api.nvim_set_current_buf, buf)
    if not ok then vim.notify(err, vim.log.levels.ERROR) end
  end
end

_G.NativeIDETabline = function()
  local buffers = {}
  local duplicate_names = {}

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      buffers[#buffers + 1] = buf
      local path = vim.api.nvim_buf_get_name(buf)
      local name = path == "" and "[No Name]" or vim.fs.basename(path)
      duplicate_names[name] = (duplicate_names[name] or 0) + 1
    end
  end
  table.sort(buffers)

  if #buffers == 0 then
    return "%#TabLineFill#%="
  end

  local current = vim.api.nvim_get_current_buf()
  local current_index = 1
  local labels, widths = {}, {}
  for index, buf in ipairs(buffers) do
    if buf == current then current_index = index end
    local modified = vim.bo[buf].modified and " ●" or ""
    labels[index] = string.format(" %d:%s%s ", buf, buffer_name(buf, duplicate_names), modified)
    widths[index] = vim.fn.strdisplaywidth(labels[index])
  end

  local budget = math.max(20, vim.o.columns - 18)
  local shown = { [current_index] = true }
  local used = widths[current_index]
  local left, right = current_index - 1, current_index + 1
  while left >= 1 or right <= #buffers do
    local added = false
    if left >= 1 and used + widths[left] <= budget then
      shown[left], used, left, added = true, used + widths[left], left - 1, true
    end
    if right <= #buffers and used + widths[right] <= budget then
      shown[right], used, right, added = true, used + widths[right], right + 1, true
    end
    if not added then break end
  end

  local first, last = current_index, current_index
  for index = 1, #buffers do
    if shown[index] then
      first, last = math.min(first, index), math.max(last, index)
    end
  end

  local result = {}
  if first > 1 then
    result[#result + 1] = "%#TabLine# ‹" .. (first - 1) .. " "
  end
  for index = first, last do
    if shown[index] then
      local buf = buffers[index]
      result[#result + 1] = buf == current and "%#TabLineSel#" or "%#TabLine#"
      result[#result + 1] = string.format("%%%d@v:lua.NativeIDEBufferClick@", buf)
      result[#result + 1] = labels[index]:gsub("%%", "%%%%")
      result[#result + 1] = "%X"
    end
  end
  if last < #buffers then
    result[#result + 1] = "%#TabLine# " .. (#buffers - last) .. "› "
  end
  result[#result + 1] = "%#TabLineFill#%=" .. #buffers .. " buffers "
  return table.concat(result)
end

vim.o.tabline = "%!v:lua.NativeIDETabline()"

vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufModifiedSet", "BufEnter" }, {
  group = group,
  callback = function()
    vim.cmd("redrawtabline")
  end,
})
