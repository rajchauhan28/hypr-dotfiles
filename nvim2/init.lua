-- init.lua
-- Complete Neovim config with smear cursor, dressing.nvim, telescope extensions, and noise overlay

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
  { "hrsh7th/cmp-cmdline" },

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
      hide_cursor = true,
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
nvim.opt.number = true
nvim.opt.relativenumber = true

-- Remove trailing ~
local fillchars = vim.opt.fillchars:get()
fillchars.eob = " "
nvim.opt.fillchars = fillchars

require("lualine").setup({ options = { theme = "gruvbox" } })
require("nvim-tree").setup {
  on_attach = function(bufnr)
    local api = require "nvim-tree.api"
    api.config.mappings.default_on_attach(bufnr)

    local function opts(desc)
      return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
    end

    -- Remap Enter to open in a new tab
    vim.keymap.set('n', '<CR>', api.node.open.tab, opts('Open in New Tab'))
    vim.keymap.set('n', 's', api.node.open.vertical, opts('Open in Vertical Split'))
  end,
}
require("toggleterm").setup { direction = "horizontal", height = 15 }
require("aerial").setup({ backends = { "lsp", "treesitter", "markdown" }, layout = { min_width = 30 } })
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
local luasnip = require("luasnip")

-- cmp setup
cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
    ["<Tab>"] = cmp.mapping.select_next_item(),
    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp" },
    { name = "luasnip" },
  }, {
    { name = "buffer" },
  }),
})

-- cmdline setup
cmp.setup.cmdline("/", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = {
    { name = "buffer" },
  },
})

cmp.setup.cmdline(":", {
  mapping = cmp.mapping.preset.cmdline(),
  sources = cmp.config.sources({
    { name = "path" },
  }, {
    { name = "cmdline" },
  }),
})

-----------------------------------------------------
-- LSP setup
-----------------------------------------------------
require("mason").setup()
require("mason-lspconfig").setup {
  ensure_installed = { "pyright", "rust_analyzer", "omnisharp", "html", "cssls" }
}

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

for _, server in ipairs({ "pyright", "rust_analyzer", "omnisharp", "html", "cssls" }) do
  lspconfig[server].setup { capabilities = capabilities }
end

-----------------------------------------------------
-- Telescope setup
-----------------------------------------------------
local telescope = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", telescope.find_files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>fg", telescope.live_grep, { desc = "Live Grep" })
vim.keymap.set("n", "<leader>fb", telescope.buffers, { desc = "Buffers" })
vim.keymap.set("n", "<leader>fr", telescope.oldfiles, { desc = "Recent Files" })

-- Visual mode: grep selection
vim.keymap.set("v", "<leader>fs", function()
  local text = vim.fn.getreg("v")
  telescope.grep_string({ search = text })
end, { desc = "Search Selection", noremap = true, silent = true })

-----------------------------------------------------
-- Keymaps
-----------------------------------------------------
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "File Explorer" })
vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>", { desc = "Toggle Aerial Outline" })
vim.keymap.set("n", "<leader>t", ":ToggleTerm<CR>", { desc = "Toggle Terminal" })

-- Save / clipboard
vim.keymap.set({ "n", "v" }, "<C-s>", ":w<CR>", { noremap = true, desc = "Save" })
vim.keymap.set("v", "<C-c>", '"+y', { noremap = true, desc = "Copy to clipboard" })
vim.keymap.set("v", "<C-x>", '"+x', { noremap = true, desc = "Cut to clipboard" })
vim.keymap.set({ "n", "v" }, "<C-v>", '"+p', { noremap = true, desc = "Paste from clipboard" })
vim.keymap.set({ "n", "v" }, "<C-a>", "ggVG", { noremap = true, desc = "Select all" })

-- Word/line selection (Ctrl+Shift+Arrows)
vim.keymap.set({ "n", "v" }, "<C-S-Right>", "vE", { desc = "Select next word" })
vim.keymap.set({ "n", "v" }, "<C-S-Left>", "vB", { desc = "Select previous word" })
vim.keymap.set({ "n", "v" }, "<C-S-Down>", "vj", { desc = "Select down line" })
vim.keymap.set({ "n", "v" }, "<C-S-Up>", "vk", { desc = "Select up line" })

-----------------------------------------------------
-- Floating command-line noise overlay
-----------------------------------------------------
local noise_overlay = (function()
  local buf, win, timer
  local function gen_noise_line(len)
    local chars = {"░", "▒", "▓", "▖", "▗", "▘", "▝", "▚", "▞"}
    local line = {}
    for i = 1, len do line[i] = chars[math.random(#chars)] end
    return table.concat(line)
  end
  local function update_noise()
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local width = vim.o.columns
    local height = 3
    local lines = {}
    for _ = 1, height do table.insert(lines, gen_noise_line(width)) end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  local function create_overlay()
    local width, height = vim.o.columns, 3
    buf = vim.api.nvim_create_buf(false, true)
    win = vim.api.nvim_open_win(buf, false, {
      relative = "editor", width = width, height = height,
      row = vim.o.lines - height - 1, col = 0,
      style = "minimal", focusable = false, zindex = 50, noautocmd = true,
    })
    vim.api.nvim_win_set_option(win, "winhl", "Normal:Comment")
    timer = vim.loop.new_timer()
    timer:start(0, 100, vim.schedule_wrap(update_noise))
  end
  local function clear_overlay()
    if timer then timer:stop(); timer:close(); timer = nil end
    if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true); win = nil end
    if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }); buf = nil end
  end
  return { create = create_overlay, clear = clear_overlay }
end)()

local noise_toggle = false
vim.api.nvim_create_user_command("ToggleCmdNoise", function()
  if noise_toggle then noise_overlay.clear() else noise_overlay.create() end
  noise_toggle = not noise_toggle
end, { desc = "Toggle noise overlay behind command line" })
