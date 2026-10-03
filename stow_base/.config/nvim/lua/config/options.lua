vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Line Numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Mouse & Clipboard
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"

-- Indentation defaults (dynamically refined per-project by guess-indent.nvim)
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.autoindent = true

-- Search settings
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Appearance & UI
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.smoothscroll = true
vim.opt.pumheight = 10

-- Split behavior (intuitive splits)
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Performance & Undo
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.undofile = true
vim.opt.swapfile = false

-- Native EditorConfig integration
vim.g.editorconfig = true

-- Clean end-of-buffer indicator
vim.opt.fillchars = { eob = " " }
-- Toggle Auto Suggestions (nvim-cmp)
vim.api.nvim_create_user_command("ToggleAutoSuggest", function()
  if vim.g.cmp_enabled == false then
    vim.g.cmp_enabled = true
    vim.notify("Auto-suggestions ENABLED", vim.log.levels.INFO, { title = "Completion" })
  else
    vim.g.cmp_enabled = false
    vim.notify("Auto-suggestions DISABLED (Press <C-Space> to manually trigger)", vim.log.levels.WARN, { title = "Completion" })
  end
end, { desc = "Toggle automatic popup for autocomplete" })
