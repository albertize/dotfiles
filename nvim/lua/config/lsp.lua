-- Native LSP server definitions, buffer actions and format-on-save.
local group = vim.api.nvim_create_augroup("NativeIDELsp", { clear = true })

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.resolveSupport = {
  properties = { "documentation", "detail", "additionalTextEdits" },
}
capabilities.textDocument.semanticTokens.multilineTokenSupport = true
vim.lsp.config("*", { capabilities = capabilities, root_markers = { ".git" } })

local servers = {
  {
    name = "clangd", executable = "clangd",
    config = {
      cmd = { "clangd", "--background-index", "--clang-tidy", "--completion-style=detailed", "--header-insertion=iwyu" },
      filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
      root_markers = {
        ".clangd", ".clang-tidy", ".clang-format", "compile_commands.json",
        "compile_flags.txt", ".git",
      },
    },
  },
  {
    name = "lua_ls", executable = "lua-language-server",
    config = {
      cmd = { "lua-language-server" },
      filetypes = { "lua" },
      root_markers = { { ".luarc.json", ".luarc.jsonc" }, ".git" },
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } },
          workspace = {
            checkThirdParty = false,
            library = { vim.env.VIMRUNTIME, "${3rd}/luv/library" },
          },
          telemetry = { enable = false },
        },
      },
    },
  },
  {
    name = "basedpyright", executable = "basedpyright-langserver",
    config = {
      cmd = { "basedpyright-langserver", "--stdio" },
      filetypes = { "python" },
      root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    },
  },
  {
    name = "pyright", executable = "pyright-langserver", alternative = "basedpyright-langserver",
    config = {
      cmd = { "pyright-langserver", "--stdio" },
      filetypes = { "python" },
      root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    },
  },
  {
    name = "ts_ls", executable = "typescript-language-server",
    config = {
      cmd = { "typescript-language-server", "--stdio" },
      filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
      root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
    },
  },
  {
    name = "rust_analyzer", executable = "rust-analyzer",
    config = {
      cmd = { "rust-analyzer" },
      filetypes = { "rust" },
      root_markers = { "Cargo.toml", "rust-project.json", ".git" },
      settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
    },
  },
  {
    name = "gopls", executable = "gopls",
    config = {
      cmd = { "gopls" },
      filetypes = { "go", "gomod", "gowork", "gotmpl" },
      root_markers = { "go.work", "go.mod", ".git" },
    },
  },
  {
    name = "bashls", executable = "bash-language-server",
    config = {
      cmd = { "bash-language-server", "start" },
      filetypes = { "bash", "sh" },
      root_markers = { ".git" },
    },
  },
  {
    name = "jsonls", executable = "vscode-json-language-server",
    config = {
      cmd = { "vscode-json-language-server", "--stdio" },
      filetypes = { "json", "jsonc" },
      root_markers = { "package.json", ".git" },
    },
  },
  {
    name = "yamlls", executable = "yaml-language-server",
    config = {
      cmd = { "yaml-language-server", "--stdio" },
      filetypes = { "yaml" },
      root_markers = { ".git" },
    },
  },
  {
    name = "html", executable = "vscode-html-language-server",
    config = {
      cmd = { "vscode-html-language-server", "--stdio" },
      filetypes = { "html", "templ" },
      root_markers = { "package.json", ".git" },
    },
  },
  {
    name = "cssls", executable = "vscode-css-language-server",
    config = {
      cmd = { "vscode-css-language-server", "--stdio" },
      filetypes = { "css", "scss", "less" },
      root_markers = { "package.json", ".git" },
    },
  },
  {
    name = "marksman", executable = "marksman",
    config = {
      cmd = { "marksman", "server" },
      filetypes = { "markdown", "markdown.mdx" },
      root_markers = { ".marksman.toml", ".git" },
    },
  },
  {
    name = "texlab", executable = "texlab",
    config = {
      cmd = { "texlab" },
      filetypes = { "tex", "plaintex", "bib" },
      root_markers = { ".latexmkrc", "latexmkrc", ".git" },
    },
  },
  {
    name = "nil_ls", executable = "nil",
    config = {
      cmd = { "nil" },
      filetypes = { "nix" },
      root_markers = { "flake.nix", ".git" },
    },
  },
  {
    name = "zls", executable = "zls",
    config = {
      cmd = { "zls" },
      filetypes = { "zig" },
      root_markers = { "build.zig", ".git" },
    },
  },
}

local enabled_servers = {}
for _, server in ipairs(servers) do
  local available = vim.fn.executable(server.executable) == 1
  local alternative_absent = not server.alternative or vim.fn.executable(server.alternative) == 0
  if available and alternative_absent then
    vim.lsp.config(server.name, server.config)
    vim.lsp.enable(server.name)
    enabled_servers[#enabled_servers + 1] = server.name
  end
end

vim.api.nvim_create_user_command("LspServers", function()
  local lines = { "Language servers (✓ enabled, · not installed):" }
  for _, server in ipairs(servers) do
    local enabled = vim.tbl_contains(enabled_servers, server.name)
    lines[#lines + 1] = string.format(
      "%s %-18s %s",
      enabled and "✓" or "·",
      server.name,
      server.executable
    )
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Native IDE" })
end, { desc = "List detected language servers" })

vim.api.nvim_create_autocmd("LspAttach", {
  group = group,
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then return end

    vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })

    local function bmap(modes, lhs, rhs, desc)
      vim.keymap.set(modes, lhs, rhs, {
        buf = ev.buf,
        silent = true,
        desc = "LSP: " .. desc,
      })
    end

    bmap("n", "gd", vim.lsp.buf.definition, "definition")
    bmap("n", "gD", vim.lsp.buf.declaration, "declaration")
    bmap("n", "gi", vim.lsp.buf.implementation, "implementation")
    bmap("n", "gr", vim.lsp.buf.references, "references")
    bmap("n", "gy", vim.lsp.buf.type_definition, "type definition")
    bmap("n", "K", function() vim.lsp.buf.hover({ border = "rounded" }) end, "documentation")
    bmap("i", "<C-k>", vim.lsp.buf.signature_help, "signature help")
    bmap("n", "<leader>rn", vim.lsp.buf.rename, "rename")
    bmap({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "code action")
    bmap("n", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "format buffer")
    bmap("x", "<leader>lf", function() vim.lsp.buf.format({ async = true }) end, "format selection")
    bmap("n", "<leader>ls", vim.lsp.buf.document_symbol, "document symbols")
    bmap("n", "<leader>lS", function()
      vim.ui.input({ prompt = "Workspace symbol > " }, function(query)
        if query then vim.lsp.buf.workspace_symbol(query) end
      end)
    end, "workspace symbols")
    bmap("n", "<leader>li", function()
      local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf })
      vim.lsp.inlay_hint.enable(not enabled, { bufnr = ev.buf })
    end, "toggle inlay hints")
    bmap("n", "<leader>lc", vim.lsp.codelens.run, "run code lens")
    bmap("n", "<leader>lh", vim.lsp.buf.incoming_calls, "incoming calls")
    bmap("n", "<leader>lH", vim.lsp.buf.outgoing_calls, "outgoing calls")

    if client:supports_method("textDocument/documentHighlight", ev.buf) then
      local highlight_group = vim.api.nvim_create_augroup("LspHighlight" .. ev.buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = highlight_group,
        buf = ev.buf,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
        group = highlight_group,
        buf = ev.buf,
        callback = vim.lsp.buf.clear_references,
      })
    end

    if client:supports_method("textDocument/codeLens", ev.buf) then
      vim.lsp.codelens.enable(true, { bufnr = ev.buf, client_id = client.id })
    end
  end,
})

vim.g.native_format_on_save = true
vim.api.nvim_create_user_command("FormatOnSave", function()
  local inherited = vim.b.native_format_on_save
  if inherited == nil then inherited = vim.g.native_format_on_save end
  vim.b.native_format_on_save = not inherited
  vim.notify("Format on save: " .. (vim.b.native_format_on_save and "ON" or "OFF"))
end, { desc = "Toggle format on save for the current buffer" })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  callback = function(ev)
    local enabled = vim.b[ev.buf].native_format_on_save
    if enabled == nil then enabled = vim.g.native_format_on_save end
    if enabled and #vim.lsp.get_clients({
      bufnr = ev.buf,
      method = "textDocument/formatting",
    }) > 0 then
      vim.lsp.buf.format({ bufnr = ev.buf, timeout_ms = 2000 })
    end
  end,
})
