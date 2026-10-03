return {
  -- TokyoNight Theme (Configured for "night" variant - deep, soothing palette)
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = false,
      styles = {
        sidebars = "dark",
        floats = "dark",
      },
    },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd([[colorscheme tokyonight-night]])
    end,
  },

  -- Icons
  { "nvim-tree/nvim-web-devicons", lazy = true },

  -- Oil.nvim: The modern way to browse and edit filesystem like a normal text buffer
  {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    cmd = { "Oil" },
    keys = {
      { "-", "<cmd>Oil<cr>", desc = "Open Parent Directory (Oil)" },
      { "<leader>o", "<cmd>Oil<cr>", desc = "Open Oil File Manager" },
    },
    opts = {
      default_file_explorer = false,
      delete_to_trash = true,
      skip_confirm_for_simple_edits = true,
      view_options = {
        show_hidden = true,
        natural_order = true,
      },
      float = {
        padding = 2,
        max_width = 90,
        max_height = 30,
        border = "rounded",
      },
    },
  },

  -- Window Maximizer (Toggle split fullscreen & restore layout)
  {
    "szw/vim-maximizer",
    cmd = { "MaximizerToggle" },
  },

  -- In-buffer Markdown Rendering (Headers, Checkboxes, Tables, Callouts)
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = {
      heading = {
        enabled = true,
        sign = true,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      bullet = {
        icons = { "●", "○", "◆", "◇" },
      },
      checkbox = {
        unchecked = { icon = "󰄱 " },
        checked = { icon = "󰄵 " },
      },
    },
  },

  -- File Explorer (Neo-tree fallback)
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    opts = {
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },

  -- Command Palette, floating popups & notifications
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      lsp = {
        override = {
          ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
          ["vim.lsp.util.stylize_markdown"] = true,
          ["cmp.entry.get_documentation"] = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = true,
        long_message_to_split = true,
        inc_rename = false,
        lsp_doc_border = true,
      },
    },
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    },
  },

  -- Which-Key with categorized mnemonic groups
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>s", group = "Splits & Windows" },
        { "<leader>f", group = "Find / Telescope" },
        { "<leader>m", group = "Markdown Tools" },
        { "<leader>c", group = "Code & LSP" },
        { "<leader>g", group = "Git" },
        { "<leader>t", group = "Terminal" },
        { "<leader>b", group = "Buffers" },
        { "<leader>u", group = "UI & Wallpaper Tint" },
      },
    },
  },

  -- Soothing Midnight Dashboard for Night Developers
  {
    "goolord/alpha-nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local dashboard = require("alpha.themes.dashboard")

      -- Define custom twilight highlight groups
      vim.api.nvim_set_hl(0, "AlphaNightStars", { fg = "#7aa2f7", bold = true })
      vim.api.nvim_set_hl(0, "AlphaNightMoon",  { fg = "#ffc777", bold = true })
      vim.api.nvim_set_hl(0, "AlphaNightMtn",   { fg = "#565f89" })
      vim.api.nvim_set_hl(0, "AlphaNightText",  { fg = "#bb9af7", italic = true })
      vim.api.nvim_set_hl(0, "AlphaStats",      { fg = "#7dcfff" })

      -- Peaceful night horizon ASCII art
      dashboard.section.header.val = {
        [[                  *    .  *       .             *  ]],
        [[               *          .    .                .  ]],
        [[        .               .        .        .   *    ]],
        [[                .       .---.            .         ]],
        [[               .       /     \  .      *           ]],
        [[                      |   ()  |    .               ]],
        [[              *        \     /          .          ]],
        [[                        '---'     *                ]],
        [[              .   /\          .         .   /\     ]],
        [[                 /  \   /\             /\  /  \    ]],
        [[                /    \ /  \   /\      /  \/    \   ]],
        [[               /  /\  /    \ /  \    /          \  ]],
        [[              /  /  \/      /    \  /            \ ]],
        [[      _______/__/___/______/______\/______________\]],
      }
      dashboard.section.header.opts.hl = "AlphaNightMoon"

      -- Dynamic time-based greeting for night dev
      local hour = tonumber(os.date("%H"))
      local greeting = "🌙 Midnight Coding • Quiet Hours, Deep Focus"
      if hour >= 5 and hour < 12 then
        greeting = "🌅 Peaceful Dawn • Fresh Thoughts, Clean Code"
      elseif hour >= 12 and hour < 18 then
        greeting = "☀️ Afternoon Flow • Deep in the Zone"
      elseif hour >= 18 and hour < 22 then
        greeting = "🌆 Serene Twilight • Crafting in Peace"
      end

      local greet_section = {
        type = "text",
        val = { "", greeting, "" },
        opts = {
          position = "center",
          hl = "AlphaNightText",
        },
      }

      dashboard.section.buttons.val = {
        dashboard.button("f", "     Find File", ":Telescope find_files <CR>"),
        dashboard.button("r", "     Recent Files", ":Telescope oldfiles <CR>"),
        dashboard.button("g", "     Find Text (Live Grep)", ":Telescope live_grep <CR>"),
        dashboard.button("o", "  󰉋   File Manager (Oil)", ":Oil <CR>"),
        dashboard.button("b", "     Folder Browser", ":Telescope file_browser <CR>"),
        dashboard.button("k", "     Keymaps & Shortcuts", ":CheatSheet <CR>"),
        dashboard.button("n", "     New File", ":ene <BAR> startinsert <CR>"),
        dashboard.button("u", "  󰚰   Sync Plugins", ":Lazy sync <CR>"),
        dashboard.button("q", "     Quit", ":qa<CR>"),
      }

      -- Clear footer explaining on-demand plugins and startup speed
      local function stats_footer()
        local stats = require("lazy").stats()
        local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
        return "⚡ All " .. stats.count .. " plugins ready (" .. ms .. "ms startup) • Press 'f', 'o', or 'k'"
      end

      dashboard.section.footer.val = stats_footer()
      dashboard.section.footer.opts.hl = "AlphaStats"

      dashboard.config.layout = {
        { type = "padding", val = 2 },
        dashboard.section.header,
        greet_section,
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      }

      require("alpha").setup(dashboard.config)
    end,
  },

  -- Telescope Fuzzy Finder + File Browser + Native C Sorter
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
      "nvim-telescope/telescope-file-browser.nvim",
    },
    config = function()
      local telescope = require("telescope")
      telescope.setup({
        defaults = {
          prompt_prefix = "   ",
          selection_caret = "  ",
          sorting_strategy = "ascending",
          layout_config = {
            horizontal = {
              prompt_position = "top",
              preview_width = 0.55,
            },
            width = 0.87,
            height = 0.80,
          },
        },
        extensions = {
          file_browser = {
            theme = "ivy",
            hijack_netrw = false,
            hidden = true,
          },
        },
      })
      pcall(telescope.load_extension, "fzf")
      pcall(telescope.load_extension, "file_browser")
    end,
  },

  -- Buffer Tabs
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        mode = "buffers",
        separator_style = "slant",
        show_buffer_close_icons = true,
        show_close_icon = false,
        always_show_bufferline = true,
        diagnostics = "nvim_lsp",
      },
    },
  },

  -- Floating Terminal
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    opts = {
      size = 20,
      open_mapping = [[<c-\>]],
      hide_numbers = true,
      shade_terminals = false,
      start_in_insert = true,
      direction = "float",
      close_on_exit = true,
      float_opts = {
        border = "curved",
        winblend = 0,
      },
    },
  },

  -- Status Line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        theme = "tokyonight",
        component_separators = "|",
        section_separators = { left = "", right = "" },
      },
      sections = {
        lualine_a = {
          { "mode", separator = { left = "" }, right_padding = 2 },
        },
        lualine_b = { "filename", "branch", "diff" },
        lualine_c = { "diagnostics" },
        lualine_x = { "filetype" },
        lualine_y = { "progress" },
        lualine_z = {
          { "location", separator = { right = "" }, left_padding = 2 },
        },
      },
    },
  },

  -- Indent Guides
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {
      indent = {
        char = "│",
      },
      scope = {
        enabled = true,
        show_start = false,
        show_end = false,
      },
    },
  },

  -- VS Code Style Minimap (powered by Rust code-minimap)
  {
    "wfxr/minimap.vim",
    cmd = { "Minimap", "MinimapClose", "MinimapToggle", "MinimapRefresh", "MinimapUpdateHighlight" },
    init = function()
      vim.g.minimap_width = 14
      vim.g.minimap_auto_start = 0
      vim.g.minimap_auto_start_win_enter = 0
      vim.g.minimap_highlight_range = 1
      vim.g.minimap_git_colors = 1
      vim.g.minimap_highlight_search = 1
      vim.g.minimap_enable_highlight_colorgroup = 1

      -- Custom colors matching TokyoNight + Pywal
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "*",
        callback = function()
          vim.api.nvim_set_hl(0, "minimapRange", { bg = "#283457", fg = "#c0caf5" })
          vim.api.nvim_set_hl(0, "minimapCursor", { bg = "#3d59a1", fg = "#ff9e64", bold = true })
          vim.api.nvim_set_hl(0, "minimapDiffAdded", { fg = "#9ece6a" })
          vim.api.nvim_set_hl(0, "minimapDiffRemoved", { fg = "#f7768e" })
          vim.api.nvim_set_hl(0, "minimapDiffLine", { fg = "#e0af68" })
          vim.api.nvim_set_hl(0, "minimapBase", { fg = "#565f89" })
        end,
      })
      vim.g.minimap_base_highlight = "minimapBase"
    end,
    keys = {
      { "<leader>mm", "<cmd>MinimapToggle<cr>", desc = "Toggle Minimap (code-minimap)" },
      { "<leader>mr", "<cmd>MinimapRefresh<cr>", desc = "Refresh Minimap" },
      { "<leader>mc", "<cmd>MinimapClose<cr>", desc = "Close Minimap" },
    },
  },



  -- VS Code Style Symbol & Function Outline Sidebar
  {
    "hedyhli/outline.nvim",
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<leader>co", "<cmd>Outline<cr>", desc = "Toggle Code Outline (Symbols)" },
      { "<leader>cs", "<cmd>Outline<cr>", desc = "Toggle Code Symbols" },
    },
    opts = {
      outline_window = {
        position = "right",
        width = 28,
      },
    },
  },
}

