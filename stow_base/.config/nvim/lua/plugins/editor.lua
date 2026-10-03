return {
  -- Auto-close brackets and quotes
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
      check_ts = true,
      ts_config = {
        lua = { "string" },
        javascript = { "template_string" },
      },
    },
  },

  -- Commenting motions (gcc, gc in visual)
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- Learn indentation dynamically from existing codebase (Tabs vs Spaces, 2 vs 4 vs 8)
  {
    "NMAC427/guess-indent.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {},
  },

  -- Live Markdown Browser Preview with Real-time Sync
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
  },

  -- Official Standard Code Formatting (Ruff/Black for PEP8, rustfmt, clang-format, prettier)
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    opts = {
      formatters_by_ft = {
        python = { "ruff_format", "black", stop_after_first = true },
        rust = { "rustfmt" },
        javascript = { "prettier", "biome", stop_after_first = true },
        typescript = { "prettier", "biome", stop_after_first = true },
        javascriptreact = { "prettier", "biome", stop_after_first = true },
        typescriptreact = { "prettier", "biome", stop_after_first = true },
        html = { "prettier" },
        css = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        cs = { "csharpier" },
        lua = { "stylua" },
        sh = { "shfmt" },
      },
      format_on_save = function(bufnr)
        if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
        end
        return { timeout_ms = 800, lsp_fallback = true }
      end,
    },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = { "n", "v" },
        desc = "Format Buffer",
      },
    },
  },

  -- Git Gutter signs & hunk operations
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local function map(mode, l, r, opts)
          opts = opts or {}
          opts.buffer = bufnr
          vim.keymap.set(mode, l, r, opts)
        end

        map("n", "]h", function()
          if vim.wo.diff then return "]h" end
          vim.schedule(function() gs.next_hunk() end)
          return "<Ignore>"
        end, { expr = true, desc = "Next Git Hunk" })

        map("n", "[h", function()
          if vim.wo.diff then return "[h" end
          vim.schedule(function() gs.prev_hunk() end)
          return "<Ignore>"
        end, { expr = true, desc = "Prev Git Hunk" })

        map("n", "<leader>gp", gs.preview_hunk, { desc = "Preview Git Hunk" })
        map("n", "<leader>gb", function() gs.blame_line({ full = true }) end, { desc = "Git Blame Line" })
        map("n", "<leader>gr", gs.reset_hunk, { desc = "Reset Git Hunk" })
      end,
    },
  },

  -- Image & GIF viewing inside Ghostty (Kitty Graphics Protocol)
  {
    "3rd/image.nvim",
    event = "VeryLazy",
    opts = {
      backend = "kitty",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" },
        },
      },
      max_width = 100,
      max_height = 20,
      max_width_window_percentage = math.huge,
      max_height_window_percentage = math.huge,
      window_overlap_clear_enabled = false,
    },
  },

  -- Variable, Function & Symbol Usage Reference Highlighter
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      delay = 120,
      large_file_cutoff = 2000,
      large_file_overrides = {
        providers = { "lsp" },
      },
      filetypes_denylist = {
        "dirvish",
        "fugitive",
        "alpha",
        "NvimTree",
        "neo-tree",
        "lazy",
        "mason",
        "TelescopePrompt",
        "gnome_shortcuts",
      },
    },
    config = function(_, opts)
      require("illuminate").configure(opts)

      -- Define clear, elegant reference highlight colors
      vim.api.nvim_set_hl(0, "IlluminatedWordText",  { bg = "#283457", underline = true })
      vim.api.nvim_set_hl(0, "IlluminatedWordRead",  { bg = "#283457", underline = true })
      vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = "#3b4261", underline = true, bold = true })

      local function map(key, dir)
        vim.keymap.set("n", key, function()
          require("illuminate")["goto_" .. dir .. "_reference"](false)
        end, { desc = dir:sub(1, 1):upper() .. dir:sub(2) .. " Symbol Reference" })
      end

      -- Jump between symbol occurrences with ]] and [[
      map("]]", "next")
      map("[[", "prev")
    end,
    keys = {
      { "]]", desc = "Next Symbol Reference" },
      { "[[", desc = "Previous Symbol Reference" },
    },
  },
}

