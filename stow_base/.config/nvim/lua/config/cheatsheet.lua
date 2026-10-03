local M = {}

-- Define GNOME-style keycap highlight groups
local function setup_highlights()
  vim.api.nvim_set_hl(0, "KbdHeader", { fg = "#bb9af7", bold = true })
  vim.api.nvim_set_hl(0, "KbdDesc",   { fg = "#c0caf5" })
  vim.api.nvim_set_hl(0, "KbdKey",    { bg = "#283457", fg = "#7dcfff", bold = true })
  vim.api.nvim_set_hl(0, "KbdMod",    { bg = "#3b4261", fg = "#ff9e64", bold = true })
  vim.api.nvim_set_hl(0, "KbdPlus",   { fg = "#565f89", bold = true })
  vim.api.nvim_set_hl(0, "KbdBorder", { fg = "#7aa2f7" })
end

local shortcuts_data = {
  { category = "SPLITS & WINDOWS", items = {
    { desc = "Split Window Vertically",           keys = "[ ␣ Space ] [ s ] [ v ]" },
    { desc = "Split Window Horizontally",         keys = "[ ␣ Space ] [ s ] [ h ]" },
    { desc = "Equalize Split Sizes",              keys = "[ ␣ Space ] [ s ] [ e ]" },
    { desc = "Close Current Split Window",        keys = "[ ␣ Space ] [ s ] [ x ]" },
    { desc = "Maximize / Restore Split Toggle",   keys = "[ ␣ Space ] [ s ] [ m ]" },
    { desc = "Navigate Left / Down / Up / Right", keys = "[ 󰘵 Ctrl ] + [ h / j / k / l ]" },
    { desc = "Resize Split Height / Width",       keys = "[ 󰘵 Ctrl ] + [ ↑ / ↓ / ← / → ]" },
  }},
  { category = "FILES & FOLDERS", items = {
    { desc = "Edit Folder like Buffer (Oil)",     keys = "[ - ]  or  [ ␣ Space ] [ o ]" },
    { desc = "Fuzzy Find Files (Telescope)",      keys = "[ ␣ Space ] [ f ] [ f ]" },
    { desc = "Live Grep Search Across Project",   keys = "[ ␣ Space ] [ f ] [ g ]" },
    { desc = "Browse Recent Files",               keys = "[ ␣ Space ] [ f ] [ r ]" },
    { desc = "Interactive Folder Browser",        keys = "[ ␣ Space ] [ f ] [ b ]" },
    { desc = "Toggle Neo-tree Drawer",            keys = "[ ␣ Space ] [ e ]" },
  }},
  { category = "BUFFERS & TABS", items = {
    { desc = "Next / Previous Buffer",            keys = "[ ] ] [ b ]  /  [ [ ] [ b ]" },
    { desc = "Cycle Buffer Tabs",                 keys = "[ 󰌌 Tab ]  /  [ 󰘶 Shift ] [ 󰌌 Tab ]" },
    { desc = "Close Current Buffer",              keys = "[ ␣ Space ] [ b ] [ d ]" },
    { desc = "Close All Other Buffers",           keys = "[ ␣ Space ] [ b ] [ a ]" },
  }},
  { category = "MODAL EDITING", items = {
    { desc = "Move Selected Block Down / Up",     keys = "[ 󰘶 Shift ] + [ J / K ]" },
    { desc = "Scroll Half-Page (Centered)",       keys = "[ 󰘵 Ctrl ] + [ d / u ]" },
    { desc = "Next / Prev Search Match",          keys = "[ n ]  /  [ 󰘶 Shift ] [ N ]" },
    { desc = "Copy to System Clipboard",          keys = "[ 󰘵 Ctrl ] [ 󰘶 Shift ] + [ c ]" },
    { desc = "Paste from System Clipboard",       keys = "[ 󰘵 Ctrl ] [ 󰘶 Shift ] + [ v ]" },
    { desc = "Yank to System Clipboard",          keys = "[ ␣ Space ] [ y ]" },
    { desc = "Yank Line to System Clipboard",     keys = "[ ␣ Space ] [ Y ]" },
    { desc = "Paste Over (Preserve Register)",    keys = "[ ␣ Space ] [ p ]" },
    { desc = "Delete Char (No Register)",         keys = "[ x ]" },
    { desc = "Toggle Line Comment",               keys = "[ 󰘵 Ctrl ] + [ / ]" },
  }},
  { category = "LSP & CODE INTELLIGENCE", items = {
    { desc = "Go to Definition",                  keys = "[ g ] [ d ]" },
    { desc = "Go to Declaration",                 keys = "[ g ] [ D ]" },
    { desc = "Find References in Telescope",      keys = "[ g ] [ r ]" },
    { desc = "Go to Implementation",              keys = "[ g ] [ i ]" },
    { desc = "Hover Documentation",               keys = "[ 󰘶 Shift ] [ K ]" },
    { desc = "Trigger Code Actions",              keys = "[ ␣ Space ] [ c ] [ a ]" },
    { desc = "Smart Symbol Rename",               keys = "[ ␣ Space ] [ r ] [ n ]" },
    { desc = "Format Buffer (Official Standards)",keys = "[ ␣ Space ] [ c ] [ f ]" },
    { desc = "Show Line Diagnostic Details",      keys = "[ g ] [ l ]  or  [ ␣ Space ] [ d ]" },
    { desc = "Next / Previous Diagnostic",        keys = "[ ] ] [ d ]  /  [ [ ] [ d ]" },
    { desc = "Next / Prev Symbol Usage (Highlight)",keys = "[ ] ] [ ] ]  /  [ [ ] [ [ ]" },
    { desc = "Toggle Code Outline (Symbols)",     keys = "[ ␣ Space ] [ c ] [ o ]" },
    { desc = "Run Active Code File",              keys = "[ ␣ Space ] [ r ]" },
  }},
  { category = "SIDE PREVIEW & MINIMAP", items = {
    { desc = "Toggle Minimap (Rust code-minimap)", keys = "[ ␣ Space ] [ m ] [ m ]" },
    { desc = "Refresh Minimap Window",            keys = "[ ␣ Space ] [ m ] [ r ]" },
    { desc = "Close Minimap Window",              keys = "[ ␣ Space ] [ m ] [ c ]" },
    { desc = "Toggle Synchronized Code Side Preview", keys = "[ ␣ Space ] [ s ] [ p ]" },
    { desc = "Toggle Code Outline (Symbols)",         keys = "[ ␣ Space ] [ c ] [ o ]" },
  }},
  { category = "MARKDOWN & MEDIA", items = {
    { desc = "Toggle Live Browser Preview",       keys = "[ ␣ Space ] [ m ] [ p ]" },
    { desc = "Toggle In-Buffer Rendered Markdown",keys = "[ ␣ Space ] [ m ] [ r ]" },
    { desc = "Export Markdown to PDF (Pandoc)",   keys = "[ ␣ Space ] [ m ] [ e ] [ p ]" },
    { desc = "Export Markdown to HTML (Pandoc)",  keys = "[ ␣ Space ] [ m ] [ e ] [ h ]" },
    { desc = "Open Media under cursor in MPV",    keys = "[ ␣ Space ] [ o ] [ v ]" },
  }},
  { category = "UI & THEME TOGGLES", items = {
    { desc = "Toggle Auto-Suggestions (cmp)",     keys = "[ ␣ Space ] [ u ] [ a ]" },
    { desc = "Reload Pywal Wallpaper Tint",       keys = "[ ␣ Space ] [ u ] [ w ]" },
    { desc = "Toggle Wallpaper Tint (On/Off)",    keys = "[ ␣ Space ] [ u ] [ W ]" },
  }},
  { category = "TERMINAL", items = {
    { desc = "Toggle Floating Terminal",          keys = "[ 󰘵 Ctrl ] + [ \\ ]" },
    { desc = "Terminal Layouts (Float/Horiz/Vert)",keys = "[ ␣ Space ] [ t ] [ f / h / v / t ]" },
  }},
  { category = "WINDOW CONTROLS (DRAG & RESIZE)", items = {
    { desc = "Mouse: Drag Window Body",           keys = "[ Click & Drag ]" },
    { desc = "Mouse: Drag Bottom/Right Edge",     keys = "[ Drag Border / Corner ]" },
    { desc = "Keyboard: Move Window Position",    keys = "[ Alt ] + [ ↑ / ↓ / ← / → ]" },
    { desc = "Keyboard: Resize Window Size",      keys = "[ + / - ]  or  [ > / < ]" },
    { desc = "Keyboard: Re-center Window",        keys = "[ = ]" },
  }},
  { category = "CODE RUNNER", items = {
    { desc = "Run Code (Smart Detect)",           keys = "[ ␣ Space ] [ r ] [ r ]" },
    { desc = "Run Single File",                   keys = "[ ␣ Space ] [ r ] [ f ]" },
    { desc = "Run Project (Needs config)",        keys = "[ ␣ Space ] [ r ] [ p ]" },
    { desc = "Close Runner",                      keys = "[ ␣ Space ] [ r ] [ x ]" },
  }},
}

-- Attaches mouse dragging and keyboard resizing to any floating window
function M.attach_draggable(win, buf)
  local drag_mode = nil
  local last_mouse = nil

  local function on_click()
    local pos = vim.fn.getmousepos()
    last_mouse = { row = pos.screenrow, col = pos.screencol }
    local cfg = vim.api.nvim_win_get_config(win)
    local cur_row = type(cfg.row) == "number" and cfg.row or (type(cfg.row) == "table" and cfg.row[false] or 0)
    local cur_col = type(cfg.col) == "number" and cfg.col or (type(cfg.col) == "table" and cfg.col[false] or 0)
    local cur_w = type(cfg.width) == "number" and cfg.width or 80
    local cur_h = type(cfg.height) == "number" and cfg.height or 25

    -- Screen coordinates of the window's bottom and right edges (border included)
    local right_edge = cur_col + cur_w + 2
    local bottom_edge = cur_row + cur_h + 2

    local dist_to_bottom = math.abs(pos.screenrow - bottom_edge)
    local dist_to_right = math.abs(pos.screencol - right_edge)

    -- If clicked near bottom border or right border, or within 2 cells of inner bottom/right edge
    if dist_to_bottom <= 3 or dist_to_right <= 4 or (pos.winrow > 0 and pos.winrow >= cur_h - 2) or (pos.wincol > 0 and pos.wincol >= cur_w - 3) then
      drag_mode = "resize"
    else
      drag_mode = "move"
    end
  end

  local function on_drag()
    if not drag_mode or not last_mouse then return end
    local pos = vim.fn.getmousepos()
    local dr = pos.screenrow - last_mouse.row
    local dc = pos.screencol - last_mouse.col
    if dr == 0 and dc == 0 then return end
    last_mouse = { row = pos.screenrow, col = pos.screencol }

    local cfg = vim.api.nvim_win_get_config(win)
    local cur_row = type(cfg.row) == "number" and cfg.row or (type(cfg.row) == "table" and cfg.row[false] or 0)
    local cur_col = type(cfg.col) == "number" and cfg.col or (type(cfg.col) == "table" and cfg.col[false] or 0)
    local cur_w = type(cfg.width) == "number" and cfg.width or 80
    local cur_h = type(cfg.height) == "number" and cfg.height or 25

    if drag_mode == "move" then
      local new_row = math.max(0, math.min(vim.o.lines - 5, cur_row + dr))
      local new_col = math.max(0, math.min(vim.o.columns - 10, cur_col + dc))
      vim.api.nvim_win_set_config(win, {
        relative = "editor",
        row = new_row,
        col = new_col,
      })
    elseif drag_mode == "resize" then
      local new_h = math.max(8, math.min(vim.o.lines - 2, cur_h + dr))
      local new_w = math.max(35, math.min(vim.o.columns - 2, cur_w + dc))
      vim.api.nvim_win_set_config(win, {
        relative = "editor",
        row = cur_row,
        col = cur_col,
        width = new_w,
        height = new_h,
      })
    end
  end

  local function on_release()
    drag_mode = nil
    last_mouse = nil
  end

  local bopts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set({ "n", "v" }, "<LeftMouse>", on_click, bopts)
  vim.keymap.set({ "n", "v" }, "<LeftDrag>", on_drag, bopts)
  vim.keymap.set({ "n", "v" }, "<LeftRelease>", on_release, bopts)

  -- Keyboard repositioning (Alt + Arrows or Alt + h/j/k/l)
  local function move_win(dr, dc)
    local cfg = vim.api.nvim_win_get_config(win)
    local cur_row = type(cfg.row) == "number" and cfg.row or (type(cfg.row) == "table" and cfg.row[false] or 0)
    local cur_col = type(cfg.col) == "number" and cfg.col or (type(cfg.col) == "table" and cfg.col[false] or 0)
    local new_row = math.max(0, math.min(vim.o.lines - 5, cur_row + dr))
    local new_col = math.max(0, math.min(vim.o.columns - 10, cur_col + dc))
    vim.api.nvim_win_set_config(win, {
      relative = "editor",
      row = new_row,
      col = new_col,
    })
  end

  -- Keyboard resizing (+ / - / > / < or Ctrl + Arrows)
  local function resize_win(dh, dw)
    local cfg = vim.api.nvim_win_get_config(win)
    local cur_row = type(cfg.row) == "number" and cfg.row or (type(cfg.row) == "table" and cfg.row[false] or 0)
    local cur_col = type(cfg.col) == "number" and cfg.col or (type(cfg.col) == "table" and cfg.col[false] or 0)
    local cur_w = type(cfg.width) == "number" and cfg.width or 80
    local cur_h = type(cfg.height) == "number" and cfg.height or 25
    local new_h = math.max(8, math.min(vim.o.lines - 2, cur_h + dh))
    local new_w = math.max(35, math.min(vim.o.columns - 2, cur_w + dw))
    vim.api.nvim_win_set_config(win, {
      relative = "editor",
      row = cur_row,
      col = cur_col,
      width = new_w,
      height = new_h,
    })
  end

  -- Center window
  local function center_win()
    local cfg = vim.api.nvim_win_get_config(win)
    local cur_w = type(cfg.width) == "number" and cfg.width or 80
    local cur_h = type(cfg.height) == "number" and cfg.height or 25
    local r = math.floor((vim.o.lines - cur_h) / 2)
    local c = math.floor((vim.o.columns - cur_w) / 2)
    vim.api.nvim_win_set_config(win, {
      relative = "editor",
      row = r,
      col = c,
    })
  end

  vim.keymap.set("n", "<M-Up>",    function() move_win(-2, 0) end, bopts)
  vim.keymap.set("n", "<M-Down>",  function() move_win(2, 0) end, bopts)
  vim.keymap.set("n", "<M-Left>",  function() move_win(0, -3) end, bopts)
  vim.keymap.set("n", "<M-Right>", function() move_win(0, 3) end, bopts)
  vim.keymap.set("n", "<M-k>",     function() move_win(-2, 0) end, bopts)
  vim.keymap.set("n", "<M-j>",     function() move_win(2, 0) end, bopts)
  vim.keymap.set("n", "<M-h>",     function() move_win(0, -3) end, bopts)
  vim.keymap.set("n", "<M-l>",     function() move_win(0, 3) end, bopts)

  vim.keymap.set("n", "<C-Up>",    function() resize_win(2, 0) end, bopts)
  vim.keymap.set("n", "<C-Down>",  function() resize_win(-2, 0) end, bopts)
  vim.keymap.set("n", "<C-Right>", function() resize_win(0, 3) end, bopts)
  vim.keymap.set("n", "<C-Left>",  function() resize_win(0, -3) end, bopts)
  vim.keymap.set("n", "+",         function() resize_win(2, 0) end, bopts)
  vim.keymap.set("n", "-",         function() resize_win(-2, 0) end, bopts)
  vim.keymap.set("n", ">",         function() resize_win(0, 3) end, bopts)
  vim.keymap.set("n", "<",         function() resize_win(0, -3) end, bopts)
  vim.keymap.set("n", "=",         center_win, bopts)
end



function M.open()
  setup_highlights()

  local lines = {}
  local highlights = {}

  local col_desc_width = 44

  table.insert(lines, "")

  for _, cat in ipairs(shortcuts_data) do
    table.insert(lines, "  " .. cat.category)
    local cat_line_idx = #lines - 1
    table.insert(highlights, { line = cat_line_idx, start_col = 2, end_col = #lines[#lines], hl = "KbdHeader" })

    for _, item in ipairs(cat.items) do
      local pad = string.rep(" ", math.max(2, col_desc_width - #item.desc))
      local row_str = "    " .. item.desc .. pad .. item.keys
      table.insert(lines, row_str)
      local row_line_idx = #lines - 1

      -- Highlight description
      table.insert(highlights, {
        line = row_line_idx,
        start_col = 4,
        end_col = 4 + #item.desc,
        hl = "KbdDesc",
      })

      -- Highlight keycaps [ ... ]
      local keys_start_col = 4 + #item.desc + #pad
      for b_start, b_content, b_end in item.keys:gmatch("()(%b[])()") do
        local abs_start = keys_start_col + b_start - 1
        local abs_end = keys_start_col + b_end - 1
        local is_modifier = b_content:find("Ctrl") or b_content:find("Shift") or b_content:find("Space") or b_content:find("Alt") or b_content:find("Tab") or b_content:find("Drag") or b_content:find("Click")
        local hl_grp = is_modifier and "KbdMod" or "KbdKey"
        table.insert(highlights, {
          line = row_line_idx,
          start_col = abs_start,
          end_col = abs_end,
          hl = hl_grp,
        })
      end

      -- Highlight plus separators
      for p_start in item.keys:gmatch("()%+") do
        local abs_col = keys_start_col + p_start - 1
        table.insert(highlights, {
          line = row_line_idx,
          start_col = abs_col,
          end_col = abs_col + 1,
          hl = "KbdPlus",
        })
      end
    end
    table.insert(lines, "")
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "gnome_shortcuts"

  -- Apply syntax highlights
  local ns = vim.api.nvim_create_namespace("gnome_cheatsheet")
  for _, h in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, ns, h.hl, h.line, h.start_col, h.end_col)
  end

  -- Calculate geometry
  local win_width = 82
  local win_height = math.min(#lines + 2, math.floor(vim.o.lines * 0.85))
  local row = math.floor((vim.o.lines - win_height) / 2)
  local col = math.floor((vim.o.columns - win_width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = "    Keyboard Shortcuts ",
    title_pos = "center",
    footer = " 󰍽 Drag to Move • Drag Edge/+ - to Resize • [=] Center • [q/Esc] Close ",
    footer_pos = "center",
  })

  -- Window settings
  vim.wo[win].cursorline = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"

  -- Attach dragging and resizing engine (Mouse + Keyboard)
  M.attach_draggable(win, buf)

  -- Close bindings
  local close_cmd = "<cmd>close<cr>"
  vim.keymap.set("n", "q", close_cmd, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close_cmd, { buffer = buf, silent = true, nowait = true })
end

return M
