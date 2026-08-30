-- Statusline and asynchronous Git branch detection.
local group = vim.api.nvim_create_augroup("NativeIDEStatusline", { clear = true })

local function update_git_branch(buf)
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local dir = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()
  vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(result)
    local branch = ""
    if result.code == 0 then
      branch = (result.stdout or ""):gsub("%s+$", "")
    end
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.b[buf].git_branch = branch ~= "" and ("git[" .. branch .. "]") or ""
        vim.cmd("redrawstatus")
      end
    end)
  end)
end

vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePost", "FocusGained" }, {
  group = group,
  callback = function(ev)
    update_git_branch(ev.buf)
  end,
})

_G.NativeIDEStatusline = function()
  local buf = vim.api.nvim_get_current_buf()
  local counts = vim.diagnostic.count(buf)
  local severity = vim.diagnostic.severity
  local diagnostics = string.format(
    " E:%d W:%d I:%d ",
    counts[severity.ERROR] or 0,
    counts[severity.WARN] or 0,
    counts[severity.INFO] or 0
  )

  local names = {}
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    names[#names + 1] = client.name
  end

  local lsp = #names > 0 and (" LSP[" .. table.concat(names, ",") .. "] ") or " LSP[-] "
  local branch = vim.b[buf].git_branch or ""
  local filetype = vim.bo[buf].filetype ~= "" and vim.bo[buf].filetype or "noft"

  return table.concat({
    "%#User1# %n ",
    "%#User5#", vim.bo[buf].fileformat, " ",
    "%#User3#", filetype, " ",
    "%#User4# %<%F ",
    "%#User2#%m",
    "%#User3#", diagnostics,
    "%#User4#", lsp,
    "%=",
    "%#User5#%l/%L ",
    "%#User2#%4v ",
    "%#User4# ", branch, " ",
  })
end

vim.o.statusline = "%!v:lua.NativeIDEStatusline()"
