-- init.lua
-- Complete Neovim config with smear cursor, dressing.nvim, and noise overlay toggle

-----------------------------------------------------
-- Bootstrap lazy.nvim
-----------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  local success, T = pcall(vim.fn.system, {
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
  if not success then
    vim.api.nvim_err_writeln("Error cloning lazy.nvim: " .. T)
    return
  end
end
vim.opt.rtp:prepend(lazypath)

-- Leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-----------------------------------------------------
-- Plugin Setup
-----------------------------------------------------
require("lazy").setup({
  -- UI plugins
  { "nvim-tree/nvim-web-devicons" },
  { "nvim-lualine/lualine.nvim" },
  { "nvim-tree/nvim-tree.lua" },
  { "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
  { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
  { "goolord/alpha-nvim" },
  { "akinsho/toggleterm.nvim", version = "*" },
  { "folke/which-key.nvim", opts = {} },
  { "lukas-reineke/indent-blankline.nvim", main = "ibl", opts = {} },
  { "utilyre/barbecue.nvim", dependencies = { "SmiteshP/nvim-navic", "nvim-tree/nvim-web-devicons" } },
  { "Bekaboo/dropbar.nvim" },
  { "akinsho/bufferline.nvim", version = "*", dependencies = "nvim-tree/nvim-web-devicons" },
  { "folke/noice.nvim", dependencies = { "MunifTanjim/nui.nvim", "rcarriga/nvim-notify" } },

  -- LSP + completion
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip" },

  -- Code outline
  { "stevearc/aerial.nvim" },

  -- Smear cursor effect
  {
    "sphamba/smear-cursor.nvim",
    opts = {
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      smear_insert_mode = true,
      hide_target_hack = true,
      hide_cursor = true, -- Correct option to hide the cursor
    },
  },

  -- Dressing for command-line UI popups
  {
    "stevearc/dressing.nvim",
    opts = {
      input = { enabled = true },
      select = { enabled = true },
    },
  },

  -- Colorscheme
  { "ellisonleao/gruvbox.nvim" },
})

-----------------------------------------------------
-- Set Colorscheme
-----------------------------------------------------
vim.cmd("colorscheme gruvbox")

-----------------------------------------------------
-- Basic UI settings
-----------------------------------------------------
vim.opt.number = true
vim.opt.relativenumber = true

-- Remove trailing ~
local fillchars = vim.opt.fillchars:get()
fillchars.eob = " "
vim.opt.fillchars = fillchars

require("lualine").setup({ options = { theme = "gruvbox" } })
require("nvim-tree").setup {
  on_attach = function(bufnr)
    local api = require "nvim-tree.api"
    local function opts(desc)
      return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    -- Default mappings
    api.config.mappings.default_on_attach(bufnr)

    -- Remap Enter to open in a new tab
    vim.keymap.set('n', '<CR>', api.node.open.tab, opts('Open in New Tab'))

    -- Add keybinding for vertical split
    vim.keymap.set('n', 's', api.node.open.vertical, opts('Open in Vertical Split'))
  end,
}
require("toggleterm").setup { direction = "horizontal", height = 15 }
require("aerial").setup {}
require("ibl").setup {}
require("dropbar").setup({ menu_highlights = true })
require("bufferline").setup({})
require("noice").setup({})


-----------------------------------------------------
-- Welcome Screen using alpha
-----------------------------------------------------
local alpha = require("alpha")
local dashboard = require("alpha.themes.dashboard")

local function fortune()
  local handle = io.popen("fortune")
  local fortune = handle:read("*a")
  handle:close()
  return fortune
end

dashboard.section.header.val = {
  "██████╗  █████╗      ██╗ ██████╗██╗  ██╗ █████╗ ██╗   ██╗██╗  ██╗ █████╗ ███╗   ██╗██████╗  █████╗     ███╗   ██╗██╗   ██╗██╗███╗   ███╗",
  "██╔══██╗██╔══██╗     ██║██╔════╝██║  ██║██╔══██╗██║   ██║██║  ██║██╔══██╗████╗  ██║╚════██╗██╔══██╗    ████╗  ██║██║   ██║██║████╗ ████║",
  "██████╔╝███████║     ██║██║     ███████║███████║██║   ██║███████║███████║██╔██╗ ██║ █████╔╝╚█████╔╝    ██╔██╗ ██║██║   ██║██║██╔████╔██║",
  "██╔══██╗██╔══██║██   ██║██║     ██╔══██║██╔══██║██║   ██║██╔══██║██╔══██║██║╚██╗██║██╔═══╝ ██╔══██╗    ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║",
  "██║  ██║██║  ██║╚█████╔╝╚██████╗██║  ██║██║  ██║╚██████╔╝██║  ██║██║  ██║██║ ╚████║███████╗╚█████╔╝    ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║",
  "╚═╝  ╚═╝╚═╝  ╚═╝ ╚════╝  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚════╝     ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

dashboard.section.buttons.val = {
  dashboard.button("n", "  New File", ":ene <BAR> startinsert<CR>"),
  dashboard.button("f", "󰈞  Find File", ":Telescope find_files<CR>"),
  dashboard.button("o", "  Open Folder", ":NvimTreeToggle<CR>"),
  dashboard.button("r", "  Recent Files", ":Telescope oldfiles<CR>"),
  dashboard.button("u", "  Update Plugins", ":Lazy sync<CR>"),
  dashboard.button("q", "  Quit", ":qa<CR>"),
}

dashboard.section.footer.val = fortune()

alpha.setup(dashboard.opts)

-----------------------------------------------------
-- Completion setup (cmp)
-----------------------------------------------------
local cmp = require("cmp")
cmp.setup({
  snippet = { expand = function(args) require("luasnip").lsp_expand(args.body) end },
  mapping = cmp.mapping.preset.insert({ ["<CR>"] = cmp.mapping.confirm({ select = true }) }),
  sources = cmp.config.sources({ { name = "nvim_lsp" }, { name = "luasnip" } }),
})

-----------------------------------------------------
-- LSP setup
-----------------------------------------------------
require("mason").setup()
require("mason-lspconfig").setup { ensure_installed = { "pyright", "rust_analyzer", "omnisharp" } }

local lspconfig = require("lspconfig")
local on_attach = function(client, bufnr)
  local opts = { noremap = true, silent = true }
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gD", "<cmd>lua vim.lsp.buf.declaration()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gd", "<cmd>lua vim.lsp.buf.definition()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "K", "<cmd>lua vim.lsp.buf.hover()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gi", "<cmd>lua vim.lsp.buf.implementation()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<C-k>", "<cmd>lua vim.lsp.buf.signature_help()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>D", "<cmd>lua vim.lsp.buf.type_definition()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>rn", "<cmd>lua vim.lsp.buf.rename()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>ca", "<cmd>lua vim.lsp.buf.code_action()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "gr", "<cmd>lua vim.lsp.buf.references()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "[d", "<cmd>lua vim.diagnostic.goto_prev()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "]d", "<cmd>lua vim.diagnostic.goto_next()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>q", "<cmd>lua vim.diagnostic.setloclist()<CR>", opts)
  vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>f", "<cmd>lua vim.lsp.buf.formatting()<CR>", opts)
end

lspconfig.pyright.setup { on_attach = on_attach }
lspconfig.rust_analyzer.setup { on_attach = on_attach }
lspconfig.omnisharp.setup { cmd = { "omnisharp" }, on_attach = on_attach }

-----------------------------------------------------
-- Keymaps
-----------------------------------------------------
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "File Explorer" })
vim.keymap.set("n", "<leader>f", "<cmd>Telescope find_files<CR>", { desc = "Find Files" })
vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>", { desc = "Toggle Aerial Outline" })

vim.keymap.set("n", "<leader>t", ":ToggleTerm<CR>", { desc = "Toggle Terminal" })
vim.keymap.set("n", "<leader>vs", ":vsplit | terminal<CR>", { desc = "Vertical Terminal" })
vim.keymap.set("n", "<leader>hs", ":split | terminal<CR>", { desc = "Horizontal Terminal" })

vim.keymap.set({ "n", "v" }, "<C-s>", ":w<CR>", { noremap = true, desc = "Save" })
vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, desc = "Copy to clipboard" })
vim.keymap.set("v", "<C-x>", '"+x', { noremap = true, desc = "Cut to clipboard" })
vim.keymap.set({ "n", "v" }, "<C-v>", '"+p', { noremap = true, desc = "Paste from clipboard" })
vim.keymap.set({ "n", "v" }, "<C-a>", "ggVG", { noremap = true, desc = "Select all" })

vim.keymap.set("n", "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<CR>", { desc = "Fuzzy Find in Current Buffer" })

vim.keymap.set("n", "<leader>*", function()
  require("telescope.builtin").current_buffer_fuzzy_find({ default_text = vim.fn.expand("<cword>") })
end, { desc = "Fuzzy Find Word Under Cursor" })

vim.keymap.set("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Fuzzy Grep Project" })

-- Bufferline keymaps
vim.keymap.set("n", "<leader>bn", ":BufferLineCycleNext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bp", ":BufferLineCyclePrev<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "<leader>bd", ":BufferLineClose<CR>", { desc = "Close buffer" })
vim.keymap.set("n", "<leader>bN", ":tabnew | enew<CR>", { desc = "New empty buffer in new tab" })


-----------------------------------------------------
-- Floating command-line noise overlay
-----------------------------------------------------
local noise_overlay = (function()
  local buf = nil
  local win = nil
  local timer = nil

  local function gen_noise_line(len)
    local chars = {"░", "▒", "▓", "▖", "▗", "▘", "▝", "▚", "▞"}
    local line = {}
    for i = 1, len do
      line[i] = chars[math.random(#chars)]
    end
    return table.concat(line)
  end

  local function update_noise()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local width = vim.o.columns
    local height = 3
    local lines = {}
    for _ = 1, height do
      table.insert(lines, gen_noise_line(width))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  local function create_overlay()
    local width = vim.o.columns
    local height = 3
    buf = vim.api.nvim_create_buf(false, true)
    win = vim.api.nvim_open_win(buf, false, {
      relative = "editor",
      width = width,
      height = height,
      row = vim.o.lines - height - 1,
      col = 0,
      style = "minimal",
      focusable = false,
      zindex = 50,
      noautocmd = true,
    })
    vim.api.nvim_win_set_option(win, "winhl", "Normal:Comment")

    timer = vim.loop.new_timer()
    timer:start(0, 100, vim.schedule_wrap(update_noise))
  end

  local function clear_overlay()
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      win = nil
    end
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
      buf = nil
    end
  end

  return {
    create = create_overlay,
    clear = clear_overlay,
  }
end)()

local noise_toggle = false
vim.api.nvim_create_user_command("ToggleCmdNoise", function()
  if noise_toggle then
    noise_overlay.clear()
  else
    noise_overlay.create()
  end
  noise_toggle = not noise_toggle
end, { desc = "Toggle noise overlay behind command line" })
