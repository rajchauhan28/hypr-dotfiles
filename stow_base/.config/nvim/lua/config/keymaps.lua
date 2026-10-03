local map = vim.keymap.set

-- ---------------------------------------------------------------------------
-- General & Navigation Essentials
-- ---------------------------------------------------------------------------
local cheatsheet = require("config.cheatsheet")

vim.api.nvim_create_user_command("Keymaps", cheatsheet.open, { desc = "Show GNOME-style Keyboard Shortcuts" })
vim.api.nvim_create_user_command("CheatSheet", cheatsheet.open, { desc = "Show GNOME-style Keyboard Shortcuts" })

map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save File" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit Window" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear Search Highlights" })
map("n", "<leader>k", cheatsheet.open, { desc = "Keyboard Shortcuts (GNOME Style)" })
map("n", "<leader>?", cheatsheet.open, { desc = "Keyboard Shortcuts (GNOME Style)" })
map("n", "<leader>fk", cheatsheet.open, { desc = "Keyboard Shortcuts (GNOME Style)" })



-- Keep cursor centered when scrolling half-pages
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll Down & Center" })
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll Up & Center" })

-- Keep search results centered
map("n", "n", "nzzzv", { desc = "Next Match & Center" })
map("n", "N", "Nzzzv", { desc = "Prev Match & Center" })

-- Delete character without overwriting clipboard register
map("n", "x", '"_x', { desc = "Delete Character (No Register)" })

-- Move selected block up and down in Visual mode with auto-indent
map("v", "J", ":m '>+1<cr>gv=gv", { desc = "Move Block Down" })
map("v", "K", ":m '<-2<cr>gv=gv", { desc = "Move Block Up" })

-- Paste over selection without losing current paste register
map("v", "<leader>p", '"_d"+P', { desc = "Paste Over (Preserve Register)" })

-- Explicit System Clipboard Yanking & VS Code Style Copy/Paste
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Yank to System Clipboard" })
map("n", "<leader>Y", '"+Y', { desc = "Yank Line to System Clipboard" })

-- Ctrl+Shift+C and Ctrl+Shift+V for Copy and Paste
map("v", "<C-S-c>", '"+y', { desc = "Copy to System Clipboard" })
map("n", "<C-S-v>", '"+p', { desc = "Paste from System Clipboard" })
map("v", "<C-S-v>", '"_d"+P', { desc = "Paste Over (Preserve Register)" })
map("i", "<C-S-v>", '<C-R>+', { desc = "Paste from System Clipboard" })
map("c", "<C-S-v>", '<C-R>+', { desc = "Paste from System Clipboard" })

-- ---------------------------------------------------------------------------
-- Window Split Management
-- ---------------------------------------------------------------------------
-- Split creation
map("n", "<leader>sv", "<C-w>v", { desc = "Split Window Vertically" })
map("n", "<leader>sh", "<C-w>s", { desc = "Split Window Horizontally" })
map("n", "<leader>se", "<C-w>=", { desc = "Equalize Split Sizes" })
map("n", "<leader>sx", "<cmd>close<cr>", { desc = "Close Split" })
map("n", "<leader>sm", "<cmd>MaximizerToggle<cr>", { desc = "Maximize/Restore Split" })

-- Synchronized Code Side Preview (Real Letters & Exact Line Tracking)
local side_preview_win = nil
local function toggle_side_preview()
  if side_preview_win and vim.api.nvim_win_is_valid(side_preview_win) then
    vim.api.nvim_win_close(side_preview_win, true)
    side_preview_win = nil
    return
  end
  local cur_win = vim.api.nvim_get_current_win()
  vim.cmd("rightbelow vsplit")
  side_preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(side_preview_win, 32)
  vim.wo[side_preview_win].number = false
  vim.wo[side_preview_win].relativenumber = false
  vim.wo[side_preview_win].signcolumn = "no"
  vim.wo[side_preview_win].wrap = false
  vim.wo[side_preview_win].cursorline = true
  vim.wo[side_preview_win].winhighlight = "Normal:MiniMapNormal,NormalNC:MiniMapNormal"
  vim.wo[cur_win].scrollbind = true
  vim.wo[side_preview_win].scrollbind = true
  vim.api.nvim_set_current_win(cur_win)
end

vim.api.nvim_create_user_command("SidePreview", toggle_side_preview, { desc = "Toggle Synchronized Code Side Preview" })
map("n", "<leader>sp", toggle_side_preview, { desc = "Toggle Synchronized Code Side Preview" })

-- Navigate between splits (seamless modal jumping)
map("n", "<C-h>", "<C-w>h", { desc = "Go to Left Window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to Lower Window" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to Upper Window" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to Right Window" })

-- Resize splits with arrow keys
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase Split Height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease Split Height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease Split Width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase Split Width" })

-- ---------------------------------------------------------------------------
-- Buffer & Tab Management
-- ---------------------------------------------------------------------------
map("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
map("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
map("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next Buffer Tab" })
map("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev Buffer Tab" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete Buffer" })
map("n", "<leader>ba", "<cmd>%bd|e#|bd#<cr>", { desc = "Close Other Buffers" })

-- ---------------------------------------------------------------------------
-- File & Directory Exploration (Oil & Telescope)
-- ---------------------------------------------------------------------------
map("n", "-", "<cmd>Oil<cr>", { desc = "Open Parent Directory (Oil)" })
map("n", "<leader>o", "<cmd>Oil<cr>", { desc = "Open File Manager (Oil)" })
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle Neo-tree" })
map("n", "<leader>fb", "<cmd>Telescope file_browser<cr>", { desc = "Browse Folders (Telescope)" })
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>", { desc = "Find Files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>", { desc = "Search Text Across Project" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>", { desc = "Recent Files" })

-- ---------------------------------------------------------------------------
-- Markdown Tools, Previews & Exporters
-- ---------------------------------------------------------------------------
map("n", "<leader>mp", "<cmd>MarkdownPreviewToggle<cr>", { desc = "Toggle Live Markdown Browser Preview" })
map("n", "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", { desc = "Toggle In-Buffer Markdown Rendering" })

-- Export Markdown to PDF (Pandoc + Headless Browser Engine)
map("n", "<leader>mep", function()
  local file = vim.fn.expand("%:p")
  if vim.bo.filetype ~= "markdown" then
    vim.notify("Active buffer is not Markdown", vim.log.levels.WARN)
    return
  end
  local pdf = vim.fn.expand("%:p:r") .. ".pdf"
  local tmp_html = vim.fn.tempname() .. ".html"
  vim.cmd("w")
  local cmd = string.format("pandoc %s -s -o %s && brave --headless --no-sandbox --print-to-pdf=%s %s && rm %s",
    vim.fn.shellescape(file),
    vim.fn.shellescape(tmp_html),
    vim.fn.shellescape(pdf),
    vim.fn.shellescape(tmp_html),
    vim.fn.shellescape(tmp_html)
  )
  vim.notify("Exporting PDF...", vim.log.levels.INFO)
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("PDF exported successfully: " .. pdf, vim.log.levels.INFO)
      else
        vim.notify("PDF export failed with code " .. exit_code, vim.log.levels.ERROR)
      end
    end,
  })
end, { desc = "Export Markdown to PDF" })

-- Export Markdown to Standalone HTML (Pandoc)
map("n", "<leader>meh", function()
  local file = vim.fn.expand("%:p")
  if vim.bo.filetype ~= "markdown" then
    vim.notify("Active buffer is not Markdown", vim.log.levels.WARN)
    return
  end
  local html = vim.fn.expand("%:p:r") .. ".html"
  vim.cmd("w")
  local cmd = string.format("pandoc %s -s --self-contained -o %s", vim.fn.shellescape(file), vim.fn.shellescape(html))
  vim.notify("Exporting HTML...", vim.log.levels.INFO)
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("HTML exported successfully: " .. html, vim.log.levels.INFO)
      else
        vim.notify("HTML export failed with code " .. exit_code, vim.log.levels.ERROR)
      end
    end,
  })
end, { desc = "Export Markdown to HTML" })

-- ---------------------------------------------------------------------------
-- Media Viewer (Launch video/gif/audio under cursor in MPV)
-- ---------------------------------------------------------------------------
map("n", "<leader>ov", function()
  local cfile = vim.fn.expand("<cfile>")
  if cfile == "" then
    vim.notify("No file under cursor", vim.log.levels.WARN)
    return
  end
  vim.notify("Opening in MPV: " .. cfile, vim.log.levels.INFO)
  vim.fn.jobstart({ "mpv", cfile }, { detach = true })
end, { desc = "Open Media under cursor in MPV" })

-- ---------------------------------------------------------------------------
-- Code Comments
-- ---------------------------------------------------------------------------
map("n", "<C-/>", function() require("Comment.api").toggle.linewise.current() end, { desc = "Toggle Comment" })
map("v", "<C-/>", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", { desc = "Toggle Comment" })
map("n", "<C-_>", function() require("Comment.api").toggle.linewise.current() end, { desc = "Toggle Comment" })
map("v", "<C-_>", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", { desc = "Toggle Comment" })

-- ---------------------------------------------------------------------------
-- Quick Polyglot Code Runner (<leader>r)
-- ---------------------------------------------------------------------------
map("n", "<leader>r", function()
  local filetype = vim.bo.filetype
  local file = vim.fn.expand("%")
  local fileroot = vim.fn.expand("%:r")
  local cmd = ""

  if filetype == "python" then
    cmd = "python3 " .. file
  elseif filetype == "rust" then
    cmd = "cargo run"
  elseif filetype == "javascript" then
    cmd = "node " .. file
  elseif filetype == "typescript" then
    cmd = "ts-node " .. file
  elseif filetype == "c" then
    cmd = "gcc " .. file .. " -o " .. fileroot .. " && ./" .. fileroot
  elseif filetype == "cpp" then
    cmd = "g++ " .. file .. " -o " .. fileroot .. " && ./" .. fileroot
  elseif filetype == "cs" then
    cmd = "dotnet run"
  elseif filetype == "asm" or filetype == "nasm" then
    cmd = "nasm -f elf64 " .. file .. " -o " .. fileroot .. ".o && ld " .. fileroot .. ".o -o " .. fileroot .. " && ./" .. fileroot
  elseif filetype == "lua" then
    cmd = "lua " .. file
  elseif filetype == "go" then
    cmd = "go run " .. file
  elseif filetype == "sh" then
    cmd = "bash " .. file
  else
    vim.notify("No execution rule for filetype: " .. filetype, vim.log.levels.WARN)
    return
  end

  vim.cmd("w")
  vim.cmd("TermExec cmd='" .. cmd .. "' direction=float")
end, { desc = "Run Current File" })

-- ---------------------------------------------------------------------------
-- Terminal Toggles
-- ---------------------------------------------------------------------------
map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Floating Terminal" })
map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Horizontal Terminal" })
map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", { desc = "Vertical Terminal" })
map("n", "<leader>tt", "<cmd>ToggleTerm direction=tab<cr>", { desc = "Tab Terminal" })
map("n", "<leader>ta", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle All Terminals" })

-- ---------------------------------------------------------------------------
-- Wallpaper & Pywal Dynamic Theme Controls
-- ---------------------------------------------------------------------------
map("n", "<leader>uw", "<cmd>PywalReload<cr>", { desc = "Reload Pywal Wallpaper Tint" })
map("n", "<leader>uW", "<cmd>PywalToggle<cr>", { desc = "Toggle Wallpaper Tint (On/Off)" })


-- Toggle Auto-Suggestions
map("n", "<leader>ua", "<cmd>ToggleAutoSuggest<cr>", { desc = "Toggle Auto Suggestions" })
