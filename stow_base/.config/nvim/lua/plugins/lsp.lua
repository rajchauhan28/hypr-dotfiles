return {
  -- Neovim setup for Lua development
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },

  -- Treesitter: Highlighting, Indentation & Syntax Awareness
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "master",
    build = ":TSUpdate",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-context",
    },
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = {
          -- User Core Requirements
          "python",
          "rust",
          "c",
          "cpp",
          "c_sharp",
          "asm",
          "javascript",
          "typescript",
          "tsx",
          "html",
          "css",
          -- Prominent & Utilities
          "lua",
          "vim",
          "vimdoc",
          "bash",
          "json",
          "yaml",
          "markdown",
          "markdown_inline",
          "query",
          "regex",
        },
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
      })

      -- Sticky function & class headers while scrolling
      require("treesitter-context").setup({
        max_lines = 3,
        multiline_threshold = 1,
      })
    end,
  },

  -- Mason: Package manager for LSPs, Formatters & Linters
  {
    "williamboman/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    },
  },

  -- LSP Configuration & Autocompletion Engine
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/nvim-cmp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-cmdline",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim",
    },
    config = function()
      local lspconfig = require("lspconfig")
      local mason_lspconfig = require("mason-lspconfig")
      local cmp = require("cmp")
      local lspkind = require("lspkind")
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      -- Setup LSP diagnostics visuals
      local signs = { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
      for type, icon in pairs(signs) do
        local hl = "DiagnosticSign" .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
      end

      vim.diagnostic.config({
        virtual_text = {
          prefix = "●",
          spacing = 4,
        },
        float = {
          border = "rounded",
          source = "always",
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      })

      -- Attach keybindings when LSP connects to a buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("UserLspConfig", {}),
        callback = function(ev)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = "LSP: " .. desc })
          end

          map("n", "gd", "<cmd>Telescope lsp_definitions<cr>", "Go to Definition")
          map("n", "gD", vim.lsp.buf.declaration, "Go to Declaration")
          map("n", "gr", "<cmd>Telescope lsp_references<cr>", "Find References")
          map("n", "gi", "<cmd>Telescope lsp_implementations<cr>", "Go to Implementation")
          map("n", "K", vim.lsp.buf.hover, "Hover Documentation")
          map("n", "<leader>ca", vim.lsp.buf.code_action, "Code Action")
          map("n", "<leader>rn", vim.lsp.buf.rename, "Smart Rename")
          map("n", "[d", vim.diagnostic.goto_prev, "Previous Diagnostic")
          map("n", "]d", vim.diagnostic.goto_next, "Next Diagnostic")
          map("n", "gl", vim.diagnostic.open_float, "Line Diagnostics")
          map("n", "<leader>d", vim.diagnostic.open_float, "Line Diagnostics")
          map("n", "<leader>D", "<cmd>Telescope diagnostics bufnr=0<cr>", "Buffer Diagnostics")
        end,
      })

      -- Mason LSP Setup
      mason_lspconfig.setup({
        ensure_installed = {
          "pyright",       -- Python typing & definition
          "ruff",          -- Python official fast linter / PEP8
          "rust_analyzer", -- Rust
          "clangd",        -- C / C++
          "csharp_ls",     -- C#
          "asm_lsp",       -- Assembly
          "ts_ls",         -- JS / TS
          "html",          -- HTML
          "cssls",         -- CSS
          "emmet_ls",      -- HTML/CSS rapid expansion
          "lua_ls",        -- Lua
          "bashls",        -- Bash / Shell
          "jsonls",        -- JSON
          "marksman",      -- Markdown
        },
        handlers = {
          function(server_name)
            lspconfig[server_name].setup({
              capabilities = capabilities,
            })
          end,
          -- Custom configuration for Lua
          ["lua_ls"] = function()
            lspconfig.lua_ls.setup({
              capabilities = capabilities,
              settings = {
                Lua = {
                  diagnostics = {
                    globals = { "vim" },
                  },
                  workspace = {
                    checkThirdParty = false,
                  },
                },
              },
            })
          end,
        },
      })

      -- Autocomplete (nvim-cmp) - Fast, precise, zero full-line AI ghost text
      cmp.setup({
        enabled = function()
          return vim.g.cmp_enabled ~= false
        end,
        snippet = {
          expand = function(args)
            require("luasnip").lsp_expand(args.body)
          end,
        },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-k>"] = cmp.mapping.select_prev_item(),
          ["<C-j>"] = cmp.mapping.select_next_item(),
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          -- Select = false ensures Enter only confirms if you intentionally picked an item
          ["<CR>"] = cmp.mapping.confirm({ select = false }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "lazydev", group_index = 0 },
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "path" },
        }, {
          { name = "buffer", keyword_length = 3 },
        }),
        formatting = {
          format = lspkind.cmp_format({
            mode = "symbol_text",
            maxwidth = 50,
            ellipsis_char = "...",
          }),
        },
      })

      -- Cmdline search (/)
      cmp.setup.cmdline({ "/", "?" }, {
        mapping = cmp.mapping.preset.cmdline(),
        sources = {
          { name = "buffer" }
        }
      })

      -- Cmdline commands (:)
      cmp.setup.cmdline(":", {
        mapping = cmp.mapping.preset.cmdline(),
        sources = cmp.config.sources({
          { name = "path" }
        }, {
          { name = "cmdline" }
        }),
        matching = { disallow_symbol_nonprefix_matching = false }
      })
    end,
  },
}
