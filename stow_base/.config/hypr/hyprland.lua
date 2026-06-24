-- Reign's Hyprland Lua Configuration
-- Ported from hyprland.conf to native Lua API (introduced in Hyprland v0.55+)

--------------------------
---- COLOR GENERATOR -----
--------------------------
local function load_colors(file_path)
    local colors = {}
    local file = io.open(file_path, "r")
    if not file then return colors end
    for line in file:lines() do
        local var, val = line:match("^%s*$(%w+)%s*=%s*(.-)%s*$")
        if var and val then
            colors[var] = val
        end
    end
    file:close()
    return colors
end

local colors = load_colors("/home/reign/.cache/wal/colors-hyprland.conf")

------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.monitor({
    output   = "HDMI-A-1",
    mode     = "1920x1080@60",
    position = "auto",
    scale    = 1,
})

---------------------
---- MY PROGRAMS ----
---------------------
local terminal           = "ghostty"
local fileManager        = "dolphin"
local menu               = "wofi -n"
local browser            = "brave"
local waybarHider        = "/home/reign/.config/hypr/waybar_hider.sh"
local wallpaperSwitcher  = "/home/reign/.config/hypr/wallpaper_switcher.sh"
local mainMod            = "SUPER"

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "20")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("XDG_MENU_PREFIX", "arch-")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("GBM_BACKEND", "nvidia-drm")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user start walllust-daemon.service")
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sleep 1 && waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("pypr")
    hl.exec_cmd("swaync-client -df")
    hl.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ 0")
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd(wallpaperSwitcher)
    hl.exec_cmd("XDG_MENU_PREFIX=arch- kbuildsycoca6")
    hl.exec_cmd("/home/reign/.config/hypr/mpvpaper-stop.sh &")
    hl.exec_cmd("hyprpm update")
    hl.exec_cmd("kbuildsycoca6")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("libinput-gestures-setup start")
    hl.exec_cmd("export XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("/usr/lib/pam_kwallet_init")
    hl.exec_cmd("/home/reign/.config/hypr/smart_gpu.py")
end)

----------------------
---- WINDOW RULES ----
----------------------
hl.window_rule({
    name  = "bluetuith-float",
    match = { class = "^(bluetuith)$" },
    float = true,
    move  = "10% 2%",
    size  = "80% 30%",
    workspace = "special silent",
    no_anim = true,
})

hl.window_rule({
    name  = "clipse-float",
    match = { title = "^(clipse)$" },
    float = true,
    center = true,
    size  = "800 650",
})

hl.window_rule({
    name  = "system-stats-float",
    match = { title = "^(System Stats)$" },
    float = true,
    center = true,
    move  = "1490 50",
})

hl.window_rule({
    name  = "waybar-clock-popup",
    match = { class = "^(org.waybar.clock_popup)$" },
    float = true,
    move  = "1500 50",
    size  = "250 250",
})

hl.window_rule({
    name  = "search-window",
    match = { title = "^(Search)$" },
    move  = "750 100",
})

hl.window_rule({
    name  = "font-manager",
    match = { class = "^(font-manager)$" },
    float = true,
    size  = "900 600",
})

-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 5,
        border_size = 0,
        col = {
            active_border   = colors.color9 or "rgba(33ccffee)",
            inactive_border = colors.color5 or "rgba(595959aa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 10,
        active_opacity = 0.95,
        inactive_opacity = 0.7,
        fullscreen_opacity = 1.0,

        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            new_optimizations = true,
            ignore_opacity = true,
            xray = false,
            popups = true,
        },

        shadow = {
            enabled = true,
            range = 15,
            render_power = 3,
            color = "rgba(0,0,0,0.5)",
        },
    },

    animations = {
        enabled = true,
    },
})

--------------------
---- ANIMATIONS ----
--------------------
hl.curve("fluid", { type = "bezier", points = { {0.15, 0.85}, {0.25, 1} } })
hl.curve("snappy", { type = "bezier", points = { {0.3, 1}, {0.4, 1} } })

hl.animation({ leaf = "windows",         enabled = true, speed = 3,   bezier = "fluid",  style = "popin 5%" })
hl.animation({ leaf = "windowsOut",      enabled = true, speed = 2.5, bezier = "snappy" })
hl.animation({ leaf = "fade",            enabled = true, speed = 4,   bezier = "snappy" })
hl.animation({ leaf = "workspaces",      enabled = true, speed = 1.7, bezier = "snappy", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4,   bezier = "fluid",  style = "slidefadevert -35%" })
hl.animation({ leaf = "layers",          enabled = true, speed = 2,   bezier = "snappy", style = "popin 70%" })

---------------------------
---- INPUT & GESTURES -----
---------------------------
hl.config({
    cursor = {
        no_warps = true,
    },
    input = {
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            scroll_factor = 1.0,
        },
    },
    dwindle = {
        preserve_split = true,
    },
    misc = {
        force_default_wallpaper = -1,
        disable_hyprland_logo   = true,
        focus_on_activate       = true,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(wallpaperSwitcher))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("pkill waybar"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("waybar &"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 1 }))

-- Navigation
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Move Windows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))

-- Move Window to Monitor
hl.bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ monitor = "left" }))
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ monitor = "right" }))

-- Focus Monitor
hl.bind(mainMod .. " + bracketleft",  hl.dsp.focus({ monitor = "left" }))
hl.bind(mainMod .. " + bracketright", hl.dsp.focus({ monitor = "right" }))

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Media & Brightness (locked = true, repeating = true)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("brightnessctl s 10%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("brightnessctl s 10%-"), { locked = true, repeating = true })

-- Media Controls (locked = true)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86Launch1",    hl.dsp.exec_cmd("DAMX"), { locked = true })

-- Screenshots
hl.bind("Print",             hl.dsp.exec_cmd("/home/reign/.config/hypr/screenshot.sh region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("/home/reign/.config/hypr/screenshot.sh output"))

-- Pyprland & Special Workspaces
hl.bind(mainMod .. " + slash",     hl.dsp.exec_cmd("/home/reign/.config/keybinds_gui.py"))
hl.bind(mainMod .. " + l",         hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd("pypr toggle term"))
hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd("pypr toggle music"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd("pypr toggle taskbar"))
hl.bind(mainMod .. " + ALT + G",   hl.dsp.exec_cmd("/home/reign/.config/hypr/gamemode.sh"))
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd("/home/reign/.config/hypr/gpu_switcher.sh"))

-- Mouse Binds (mouse = true)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Session Binds
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("wlogout -b 2"))
hl.bind("ALT + Escape",        hl.dsp.exec_cmd("wlogout -b 2"))
hl.bind("ALT + R",             hl.dsp.exec_cmd("/home/reign/.config/swaync/refresh.sh"))
hl.bind(mainMod .. " + M",       hl.dsp.exit())
