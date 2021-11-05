local present1, lspconfig = pcall(require, "lspconfig")
local present2, lspinstall = pcall(require, "lspinstall")
local saga = require "lspsaga"
vim.cmd "colorscheme rose-pine"

require("flutter-tools").setup {} -- use defaults

saga.init_lsp_saga {}

vim.api.nvim_set_keymap("n", "K", "<cmd>lua require('lspsaga.hover').render_hover_doc()<CR>", { silent = true })
vim.api.nvim_set_keymap(
   "n",
   "<C-k>",
   "<cmd>lua require('lspsaga.signaturehelp').signature_help()<CR>",
   { silent = true }
)

vim.api.nvim_set_keymap(
   "n",
   "<C-m>",
   [[<cmd>lua require('rose-pine.functions').toggle_variant()<cr>]],
   { noremap = true, silent = true }
)
if not (present1 or present2) then
   return
end

local function on_attach(_, bufnr)
   local function buf_set_keymap(...)
      vim.api.nvim_buf_set_keymap(bufnr, ...)
   end
   local function buf_set_option(...)
      vim.api.nvim_buf_set_option(bufnr, ...)
   end

   -- Enable completion triggered by <c-x><c-o>
   buf_set_option("omnifunc", "v:lua.vim.lsp.omnifunc")

   -- Mappings.
   local opts = { noremap = true, silent = true }

   -- See `:help vim.lsp.*` for documentation on any of the below functions
   buf_set_keymap("n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
   buf_set_keymap("n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
   buf_set_keymap("n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
   buf_set_keymap("n", "gk", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
   buf_set_keymap("n", "<space>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
   buf_set_keymap("n", "<space>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
   buf_set_keymap("n", "<space>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
   buf_set_keymap("n", "<space>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
   buf_set_keymap("n", "<space>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
   buf_set_keymap("n", "<space>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
   buf_set_keymap("n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
   buf_set_keymap("n", "<space>e", "<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>", opts)
   buf_set_keymap("n", "[d", "<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>", opts)
   buf_set_keymap("n", "]d", "<cmd>lua vim.lsp.diagnostic.goto_next()<CR>", opts)
   buf_set_keymap("n", "<space>q", "<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>", opts)
   buf_set_keymap("n", "<space>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
   buf_set_keymap("v", "<space>ca", "<cmd>lua vim.lsp.buf.range_code_action()<CR>", opts)
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.textDocument.completion.completionItem.documentationFormat = { "markdown", "plaintext" }
capabilities.textDocument.completion.completionItem.snippetSupport = true
capabilities.textDocument.completion.completionItem.preselectSupport = true
capabilities.textDocument.completion.completionItem.insertReplaceSupport = true
capabilities.textDocument.completion.completionItem.labelDetailsSupport = true
capabilities.textDocument.completion.completionItem.deprecatedSupport = true
capabilities.textDocument.completion.completionItem.commitCharactersSupport = true
capabilities.textDocument.completion.completionItem.tagSupport = { valueSet = { 1 } }
capabilities.textDocument.completion.completionItem.resolveSupport = {
   properties = {
      "documentation",
      "detail",
      "additionalTextEdits",
   },
}

-- lspInstall + lspconfig stuff

local function setup_servers()
   lspinstall.setup()
   local servers = lspinstall.installed_servers()

   for _, lang in pairs(servers) do
      if lang ~= "lua" then
         lspconfig[lang].setup {
            on_attach = on_attach,
            capabilities = capabilities,
            flags = {
               debounce_text_changes = 500,
            },
            -- root_dir = vim.loop.cwd,
         }
      elseif lang == "lua" then
         lspconfig[lang].setup {
            on_attach = on_attach,
            capabilities = capabilities,
            flags = {
               debounce_text_changes = 500,
            },
            settings = {
               Lua = {
                  diagnostics = {
                     globals = { "vim" },
                  },
                  workspace = {
                     library = {
                        [vim.fn.expand "$VIMRUNTIME/lua"] = true,
                        [vim.fn.expand "$VIMRUNTIME/lua/vim/lsp"] = true,
                     },
                     maxPreload = 100000,
                     preloadFileSize = 10000,
                  },
                  telemetry = {
                     enable = false,
                  },
               },
            },
         }
      end
   end
end

setup_servers()

-- Automatically reload after `:LspInstall <server>` so we don't have to restart neovim
lspinstall.post_install_hook = function()
   setup_servers() -- reload installed servers
   vim.cmd "bufdo e"
end

-- replace the default lsp diagnostic symbols
local function lspSymbol(name, icon)
   vim.fn.sign_define("LspDiagnosticsSign" .. name, { text = icon, numhl = "LspDiagnosticsDefaul" .. name })
end

lspSymbol("Error", "")
lspSymbol("Information", "")
lspSymbol("Hint", "")
lspSymbol("Warning", "")

vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
   virtual_text = {
      prefix = "",
      spacing = 0,
   },
   signs = true,
   underline = true,
   update_in_insert = false, -- update diagnostics insert mode
})
vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
   border = "single",
})
vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
   border = "single",
})

-- suppress error messages from lang servers
vim.notify = function(msg, log_level, _opts)
   if msg:match "exit code" then
      return
   end
   if log_level == vim.log.levels.ERROR then
      vim.api.nvim_err_writeln(msg)
   else
      vim.api.nvim_echo({ { msg } }, true, {})
   end
end

local eslint = {
   lintCommand = "eslint_d -f unix --stdin --stdin-filename ${INPUT}",
   lintStdin = true,
   lintFormats = { "%f:%l:%c: %m" },
   lintIgnoreExitCode = true,
   formatCommand = "eslint_d --fix-to-stdout --stdin --stdin-filename=${INPUT}",
   formatStdin = true,
}

lspconfig.tsserver.setup {
   on_attach = function(client)
      if client.config.flags then
         client.config.flags.allow_incremental_sync = true
      end
      client.resolved_capabilities.document_formatting = true
      --    set_lsp_config(client)
   end,
}

lspconfig.efm.setup {
   on_attach = function(client)
      client.resolved_capabilities.document_formatting = true
      client.resolved_capabilities.goto_definition = false
      --    set_lsp_config(client)
   end,
   settings = {
      languages = {
         javascript = { eslint },
         javascriptreact = { eslint },
         ["javascript.jsx"] = { eslint },
         typescript = { eslint },
         ["typescript.tsx"] = { eslint },
         typescriptreact = { eslint },
      },
   },
   filetypes = {
      "javascript",
      "javascriptreact",
      "javascript.jsx",
      "typescript",
      "typescript.tsx",
      "typescriptreact",
   },
}
