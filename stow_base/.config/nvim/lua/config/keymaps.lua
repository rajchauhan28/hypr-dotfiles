local map = vim.keymap.set

map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Explorer" })
map("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit" })
map("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear highlights" })
map("n", "<leader>?", "<cmd>WhichKey<cr>", { desc = "Show Keymaps" })

-- -- Standard Editor Shortcuts -- --

-- Save (Ctrl+S)
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr><esc>", { desc = "Save File" })

-- Select All (Ctrl+A)
map("n", "<C-a>", "gg<S-v>G", { desc = "Select All" })

-- Copy (Ctrl+C)
map("v", "<C-c>", '"+y', { desc = "Copy to Clipboard" })

-- Paste (Ctrl+V) - Overwrites Visual Block Mode
map("n", "<C-v>", '"+p', { desc = "Paste from Clipboard" })
map("i", "<C-v>", '<C-r>+', { desc = "Paste from Clipboard" })
map("c", "<C-v>", '<C-r>+', { desc = "Paste in Command Line" })

-- Duplicate Line/Selection (Ctrl+D)
map("n", "<C-d>", "yyp", { desc = "Duplicate Line" })
map("i", "<C-d>", "<Esc>yypgi", { desc = "Duplicate Line" })
map("v", "<C-d>", "yP", { desc = "Duplicate Selection" })

-- Find File (Ctrl+P)
map("n", "<C-p>", "<cmd>Telescope find_files<cr>", { desc = "Find File" })


-- -- Caret Selection & Movement (Ctrl/Shift + Arrows) -- --

-- Move by word (Ctrl+Arrows)
map("n", "<C-Left>", "b", { desc = "Move Word Back" })
map("n", "<C-Right>", "w", { desc = "Move Word Forward" })
map("i", "<C-Left>", "<C-o>b", { desc = "Move Word Back" })
map("i", "<C-Right>", "<C-o>w", { desc = "Move Word Forward" })

-- Select with Shift+Arrows
map("n", "<S-Up>", "v<Up>", { desc = "Select Up" })
map("n", "<S-Down>", "v<Down>", { desc = "Select Down" })
map("n", "<S-Left>", "v<Left>", { desc = "Select Left" })
map("n", "<S-Right>", "v<Right>", { desc = "Select Right" })
map("i", "<S-Up>", "<Esc>v<Up>", { desc = "Select Up" })
map("i", "<S-Down>", "<Esc>v<Down>", { desc = "Select Down" })
map("i", "<S-Left>", "<Esc>v<Left>", { desc = "Select Left" })
map("i", "<S-Right>", "<Esc>v<Right>", { desc = "Select Right" })

map("v", "<S-Up>", "<Up>", { desc = "Select Up" })
map("v", "<S-Down>", "<Down>", { desc = "Select Down" })
map("v", "<S-Left>", "<Left>", { desc = "Select Left" })
map("v", "<S-Right>", "<Right>", { desc = "Select Right" })

-- Select Word with Ctrl+Shift+Arrows
map("n", "<C-S-Left>", "v<C-Left>", { desc = "Select Word Back" })
map("n", "<C-S-Right>", "v<C-Right>", { desc = "Select Word Forward" })
map("i", "<C-S-Left>", "<Esc>v<C-Left>", { desc = "Select Word Back" })
map("i", "<C-S-Right>", "<Esc>v<C-Right>", { desc = "Select Word Forward" })
map("v", "<C-S-Left>", "<C-Left>", { desc = "Select Word Back" })
map("v", "<C-S-Right>", "<C-Right>", { desc = "Select Word Forward" })

-- -- Tabs / Buffers -- --
map("n", "<Tab>", "<cmd>BufferLineCycleNext<cr>", { desc = "Next Buffer" })
map("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", { desc = "Prev Buffer" })
map("n", "<leader>x", "<cmd>bdelete<cr>", { desc = "Close Buffer" })

-- -- Comments -- --
-- Ctrl + / to toggle comment
map("n", "<C-/>", function() require("Comment.api").toggle.linewise.current() end, { desc = "Toggle Comment" })
map("v", "<C-/>", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", { desc = "Toggle Comment" })
-- Fix for some terminals mapping C-/ to C-_
map("n", "<C-_>", function() require("Comment.api").toggle.linewise.current() end, { desc = "Toggle Comment" })
map("v", "<C-_>", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", { desc = "Toggle Comment" })

-- -- Run Code -- --
map("n", "<leader>r", function()
  local filetype = vim.bo.filetype
  local cmd = ""

  if filetype == "python" then
    cmd = "python3 " .. vim.fn.expand("%")
  elseif filetype == "javascript" then
    cmd = "node " .. vim.fn.expand("%")
  elseif filetype == "typescript" then
    cmd = "ts-node " .. vim.fn.expand("%")
  elseif filetype == "lua" then
    cmd = "lua " .. vim.fn.expand("%")
  elseif filetype == "rust" then
    cmd = "cargo run"
  elseif filetype == "go" then
    cmd = "go run " .. vim.fn.expand("%")
  elseif filetype == "sh" then
    cmd = "bash " .. vim.fn.expand("%")
  elseif filetype == "c" then
    cmd = "gcc " .. vim.fn.expand("%") .. " -o " .. vim.fn.expand("%:r") .. " && ./" .. vim.fn.expand("%:r")
  elseif filetype == "cpp" then
    cmd = "g++ " .. vim.fn.expand("%") .. " -o " .. vim.fn.expand("%:r") .. " && ./" .. vim.fn.expand("%:r")
  else
    print("No run command defined for " .. filetype)
    return
  end

  vim.cmd("w") -- Save before running
  vim.cmd("TermExec cmd='" .. cmd .. "' direction=float")
end, { desc = "Run File" })


-- -- Terminal Management -- --

-- Toggle specific terminal instances (Create/Switch/Close)
map("n", "<leader>t1", "<cmd>1ToggleTerm<cr>", { desc = "Toggle Terminal 1" })
map("n", "<leader>t2", "<cmd>2ToggleTerm<cr>", { desc = "Toggle Terminal 2" })
map("n", "<leader>t3", "<cmd>3ToggleTerm<cr>", { desc = "Toggle Terminal 3" })

-- Toggle all terminals
map("n", "<leader>ta", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle All Terminals" })

-- Open terminal in different layouts
map("n", "<leader>tt", "<cmd>ToggleTerm direction=tab<cr>", { desc = "Terminal in New Tab" })
map("n", "<leader>tf", "<cmd>ToggleTerm direction=float<cr>", { desc = "Terminal Float" })
map("n", "<leader>th", "<cmd>ToggleTerm direction=horizontal<cr>", { desc = "Terminal Horizontal" })
map("n", "<leader>tv", "<cmd>ToggleTerm direction=vertical<cr>", { desc = "Terminal Vertical" })
