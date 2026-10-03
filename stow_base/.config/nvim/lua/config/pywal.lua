local M = {}

local uv = vim.uv or vim.loop
local wal_cache = vim.fn.expand("~/.cache/wal/colors.json")

-- Helper: Convert Hex string to RGB numbers
local function hex_to_rgb(hex)
  hex = hex:gsub("#", "")
  if #hex == 3 then
    hex = hex:sub(1, 1):rep(2) .. hex:sub(2, 2):rep(2) .. hex:sub(3, 3):rep(2)
  end
  return tonumber(hex:sub(1, 2), 16) or 0, tonumber(hex:sub(3, 4), 16) or 0, tonumber(hex:sub(5, 6), 16) or 0
end

-- Helper: Convert RGB numbers to Hex string
local function rgb_to_hex(r, g, b)
  return string.format("#%02x%02x%02x",
    math.min(255, math.max(0, math.floor(r + 0.5))),
    math.min(255, math.max(0, math.floor(g + 0.5))),
    math.min(255, math.max(0, math.floor(b + 0.5)))
  )
end

-- Helper: Blend base color with tint color by weight (0.0 = base, 1.0 = tint)
local function blend(base, tint, weight)
  local r1, g1, b1 = hex_to_rgb(base)
  local r2, g2, b2 = hex_to_rgb(tint)
  local r = r1 * (1 - weight) + r2 * weight
  local g = g1 * (1 - weight) + g2 * weight
  local b = b1 * (1 - weight) + b2 * weight
  return rgb_to_hex(r, g, b)
end

-- State
M.enabled = true
M.last_checksum = nil
M.fs_watcher = nil

-- Read and parse ~/.cache/wal/colors.json
function M.read_wal()
  local f = io.open(wal_cache, "r")
  if not f then return nil end
  local content = f:read("*a")
  f:close()
  local ok, data = pcall(vim.json.decode, content)
  if ok and data then return data end
  return nil
end

-- Apply subtle wallpaper tint on top of TokyoNight
function M.apply_tint()
  if not M.enabled then return end
  local data = M.read_wal()
  if not data or not data.special or not data.colors then return end

  local wal_bg = data.special.background       -- wallpaper dominant dark tone
  local wal_fg = data.special.foreground       -- wallpaper text tone
  local accent1 = data.colors.color4 or "#7aa2f7" -- primary accent
  local accent2 = data.colors.color5 or "#bb9af7" -- secondary accent
  local accent3 = data.colors.color3 or "#e0af68" -- warm accent

  -- TokyoNight Night base references
  local tokyo_bg = "#16161e"
  local tokyo_bg_nc = "#14141b"
  local tokyo_float = "#1f2335"
  local tokyo_cursorline = "#1e2030"
  local tokyo_border = "#29a4bd"

  -- Subtle blended backgrounds (35% - 40% wallpaper tint)
  local bg_tinted = blend(tokyo_bg, wal_bg, 0.40)
  local bg_nc_tinted = blend(tokyo_bg_nc, wal_bg, 0.40)
  local float_tinted = blend(tokyo_float, wal_bg, 0.35)
  local cursorline_tinted = blend(tokyo_cursorline, wal_bg, 0.25)
  local border_tinted = blend(tokyo_border, accent1, 0.40)

  -- Core Editor Windows
  vim.api.nvim_set_hl(0, "Normal", { fg = tokyo_fg or "#c0caf5", bg = bg_tinted })
  vim.api.nvim_set_hl(0, "NormalNC", { bg = bg_nc_tinted })
  vim.api.nvim_set_hl(0, "SignColumn", { bg = bg_tinted })
  vim.api.nvim_set_hl(0, "EndOfBuffer", { fg = bg_tinted, bg = bg_tinted })
  vim.api.nvim_set_hl(0, "CursorLine", { bg = cursorline_tinted })
  vim.api.nvim_set_hl(0, "CursorLineNr", { fg = accent2, bold = true })

  -- Floating Windows & Popups
  vim.api.nvim_set_hl(0, "NormalFloat", { bg = float_tinted })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = border_tinted, bg = float_tinted })
  vim.api.nvim_set_hl(0, "WinSeparator", { fg = border_tinted })

  -- Telescope Windows
  vim.api.nvim_set_hl(0, "TelescopeNormal", { bg = float_tinted })
  vim.api.nvim_set_hl(0, "TelescopeBorder", { fg = border_tinted, bg = float_tinted })
  vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = accent1, bg = float_tinted })
  vim.api.nvim_set_hl(0, "TelescopeTitle", { fg = accent1, bold = true })

  -- Completion Menu
  vim.api.nvim_set_hl(0, "Pmenu", { bg = float_tinted })
  vim.api.nvim_set_hl(0, "PmenuBorder", { fg = border_tinted, bg = float_tinted })
  vim.api.nvim_set_hl(0, "PmenuSel", { bg = blend("#283457", accent1, 0.30) })

  -- Dashboard Highlights
  vim.api.nvim_set_hl(0, "AlphaNightMoon", { fg = accent3, bold = true })
  vim.api.nvim_set_hl(0, "AlphaNightStars", { fg = accent1, bold = true })
  vim.api.nvim_set_hl(0, "AlphaNightText", { fg = accent2, italic = true })
  vim.api.nvim_set_hl(0, "AlphaStats", { fg = accent1 })

  -- Treesitter sticky context
  vim.api.nvim_set_hl(0, "TreesitterContext", { bg = float_tinted })

  -- Minimap highlights (blends with wallpaper tint)
  vim.api.nvim_set_hl(0, "minimapBase", { fg = blend("#565f89", accent2, 0.20) })
  vim.api.nvim_set_hl(0, "minimapRange", { bg = blend("#24283b", accent1, 0.25), fg = "#c0caf5" })
  vim.api.nvim_set_hl(0, "minimapCursor", { bg = blend("#3d59a1", accent1, 0.40), fg = accent3, bold = true })
  vim.api.nvim_set_hl(0, "minimapDiffAdded", { fg = "#9ece6a" })
  vim.api.nvim_set_hl(0, "minimapDiffRemoved", { fg = "#f7768e" })
  vim.api.nvim_set_hl(0, "minimapDiffLine", { fg = accent2 })

  -- Variable & Function Reference Usage Highlights (vim-illuminate)
  vim.api.nvim_set_hl(0, "IlluminatedWordText", { bg = blend("#283457", accent1, 0.30), underline = true })
  vim.api.nvim_set_hl(0, "IlluminatedWordRead", { bg = blend("#283457", accent1, 0.30), underline = true })
  vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = blend("#3b4261", accent2, 0.35), underline = true, bold = true })

  M.last_checksum = data.checksum
end

-- Hot-reload watcher using libuv fs_event
function M.start_watcher()
  if M.fs_watcher then
    M.fs_watcher:stop()
    M.fs_watcher = nil
  end

  local handle = uv.new_fs_event()
  if not handle then return end

  local debounce_timer = nil

  handle:start(wal_cache, {}, function(err, filename)
    if err then return end
    if debounce_timer then debounce_timer:stop() end
    debounce_timer = uv.new_timer()
    debounce_timer:start(120, 0, vim.schedule_wrap(function()
      local data = M.read_wal()
      if data and data.checksum ~= M.last_checksum then
        M.apply_tint()
        local wp = data.wallpaper and vim.fn.fnamemodify(data.wallpaper, ":t") or "new wallpaper"
        vim.notify("🎨 Pywal hot-reloaded: " .. wp, vim.log.levels.INFO, { title = "Wallpaper Tint" })
      end
    end))
  end)

  M.fs_watcher = handle
end

-- Toggle tint on/off
function M.toggle()
  M.enabled = not M.enabled
  if M.enabled then
    M.apply_tint()
    vim.notify("Wallpaper tint enabled", vim.log.levels.INFO)
  else
    vim.cmd("colorscheme tokyonight-night")
    vim.notify("Wallpaper tint disabled (Pure TokyoNight)", vim.log.levels.INFO)
  end
end

-- Main setup
function M.setup()
  -- Apply initial tint
  M.apply_tint()

  -- Re-apply tint if colorscheme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = function()
      if M.enabled then
        vim.schedule(M.apply_tint)
      end
    end,
  })

  -- Check for updates when switching back to Neovim window
  vim.api.nvim_create_autocmd("FocusGained", {
    callback = function()
      local data = M.read_wal()
      if data and data.checksum ~= M.last_checksum then
        M.apply_tint()
      end
    end,
  })

  -- Start filesystem watcher for instantaneous hot-reloading
  M.start_watcher()

  -- User commands
  vim.api.nvim_create_user_command("PywalReload", function()
    M.apply_tint()
    vim.notify("Pywal colors reloaded manually", vim.log.levels.INFO)
  end, { desc = "Reload Pywal wallpaper tint" })

  vim.api.nvim_create_user_command("PywalToggle", function()
    M.toggle()
  end, { desc = "Toggle Pywal wallpaper tint" })
end

return M
