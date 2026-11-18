-- Reign's Hyprland Lua Configuration
-- Ported from hyprland.conf to native Lua API (introduced in Hyprland v0.55+)

-- The config must work for any user, so nothing below may hardcode a home
-- directory. HOME is always set in a Hyprland session; the empty fallback
-- keeps the file parseable if it somehow is not.
local HOME = os.getenv("HOME") or ""

-- Hardware profile written by Install.sh (detect_hardware). It reports what
-- this machine actually has -- vendor, GPUs, battery -- so nothing below has
-- to assume an Acer Predator with an NVIDIA Optimus GPU. A missing file gives
-- an empty table, which switches every vendor-specific extra OFF: the shell
-- still comes up fully on hardware the installer never saw.
local hw = (function()
    local ok, profile = pcall(dofile, HOME .. "/.config/hypr/hardware.lua")
    if ok and type(profile) == "table" then return profile end
    return {}
end)()

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

local colors = load_colors(HOME .. "/.cache/wal/colors-hyprland.conf")

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
local browser            = "brave"
local wallpaperSwitcher  = HOME .. "/.config/hypr/wallpaper_switcher.sh"
local mainMod            = "SUPER"

-- The leftbar changes its layer-surface width when a horizontal drawer opens.
-- Keep Hyprland's layer animation from leaving that persistent surface at
-- zero alpha after launch or resize.
hl.layer_rule({
    name = "leftbar-no-animation",
    match = { namespace = "^leftbar$" },
    no_anim = true,
})

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "20")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_MENU_PREFIX", "arch-")
hl.env("XDG_SESSION_TYPE", "wayland")

-- ~/.local/bin holds qs-dmenu, walllust-cli, damx-driver-manager and the
-- AuraLink binaries, but a display-manager login does not read ~/.zshrc, so
-- nothing Hyprland spawned could find them: applying a wallpaper from the
-- carousel or dashboard failed with FileNotFoundError. Guarded so a config
-- reload (which re-runs this file) does not prepend it again each time.
do
    local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
    local localbin = HOME .. "/.local/bin"
    if not (":" .. path .. ":"):find(":" .. localbin .. ":", 1, true) then
        hl.env("PATH", localbin .. ":" .. path)
    end
end

-- Hardware-video-decode driver. Setting the wrong one here is worse than
-- setting none: iHD on an AMD box breaks decode in every Electron app.
if hw.igpu == "intel" then
    hl.env("LIBVA_DRIVER_NAME", "iHD")
elseif hw.igpu == "amd" then
    hl.env("LIBVA_DRIVER_NAME", "radeonsi")
elseif hw.gpu_nvidia and not hw.igpu then
    -- NVIDIA-only machine: no integrated GPU to hand decode to.
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("GBM_BACKEND", "nvidia-drm")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
end

if hw.gpu_nvidia then
    hl.env("NVD_BACKEND", "direct")
end

-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    -- hyprland-session.target (shipped in systemd/user/) binds
    -- graphical-session.target, which is what cliphist-*, hypridle and
    -- pyprland are WantedBy. HYPRLAND_INSTANCE_SIGNATURE is imported too:
    -- pypr and the `hyprctl` calls hypridle makes cannot reach Hyprland from a
    -- systemd unit without it. The walllust restart is `;`, not `&&`: walllust
    -- is optional and must not depend on the session target succeeding.
    hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE && systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE && systemctl --user start hyprland-session.target; systemctl --user restart walllust-daemon.service")
    -- Clipboard history is cliphist now (cliphist-text/image.service), driven
    -- by the Quickshell launcher panel. Nothing to start here.
    -- hypridle and pypr each ship a user unit too, and Install.sh enables
    -- hypridle.service. Start the bare binary only when the unit is not
    -- enabled, or both run: two idle daemons fire every lock and DPMS twice.
    hl.exec_cmd("systemctl --user -q is-enabled hypridle.service || hypridle")
    -- Consolidated shell: topbar + leftbar + sidepanel + dock + desktop_clock
    -- + notifications all live in ~/.config/quickshell/shell.qml (one process).
    -- start.sh runs `qs -d` (the default config) and retries if it dies on startup.
    hl.exec_cmd(HOME .. "/.config/quickshell/start.sh &")
    -- The lockscreen stays its OWN process on purpose: reloading the bars must
    -- not be able to drop an active lock. See quickshell/lock/lock.sh.
    hl.exec_cmd("qs -d -p " .. HOME .. "/.config/quickshell/lock &")
    hl.exec_cmd("systemctl --user -q is-enabled pyprland.service || pypr")
    hl.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ 0")
    -- (No hyprpm: this Hyprland package does not ship it. The only plugin,
    -- hyprglass, is loaded and version-checked by glass.lua.)
    hl.exec_cmd(wallpaperSwitcher)
    hl.exec_cmd(HOME .. "/.config/hypr/mpvpaper-stop.sh &")
    -- Once. XDG_MENU_PREFIX=arch- is already in the environment (hl.env above),
    -- so the second, prefix-less run was the same rebuild done concurrently.
    hl.exec_cmd("kbuildsycoca6")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("command -v libinput-gestures-setup >/dev/null && libinput-gestures-setup start")
    hl.exec_cmd("test -x /usr/lib/pam_kwallet_init && /usr/lib/pam_kwallet_init")
    -- Refresh-rate/governor tuning against AC vs battery. Skipped on a
    -- desktop, where the daemon has nothing to react to.
    if hw.battery then
        hl.exec_cmd(HOME .. "/.config/hypr/smart_gpu.py")
    end
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
    name  = "system-stats-float",
    match = { title = "^(System Stats)$" },
    float = true,
    center = true,
    move  = "1490 50",
})

hl.window_rule({
    name  = "search-window",
    match = { title = "^(Search)$" },
    move  = "750 100",
})

-- Float the shell settings rather than tiling it: it is a dialog you open,
-- change one thing in, and close.
hl.window_rule({
    name  = "shell-settings",
    match = { title = "^(Shell Settings)$" },
    float = true,
    center = true,
    size  = "900 660",
})

hl.window_rule({
    name  = "font-manager",
    match = { class = "^(font-manager)$" },
    float = true,
    size  = "900 600",
})

hl.window_rule({
    name  = "capcut",
    match = { class = "^(capcut\\.exe)$" },
    suppress_event = "fullscreen maximize",
    opacity = "1.0 override 1.0 override",
})

-------------------------------
---- FOCUS NEW WINDOWS --------
-------------------------------
-- Single-instance apps (e.g. ghostty with gtk-single-instance) open new
-- windows from their already-running process without a valid activation
-- token, so Hyprland marks them urgent instead of focusing them. Focus
-- any window that opens on the active workspace.
hl.on("window.open", function(w)
    local aws = hl.get_active_workspace()
    if aws and w.workspace and w.workspace.id == aws.id then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
    end
end)

-----------------------
---- LOOK AND FEEL ----
-----------------------
-- Blur and shadow as configured. smart_gpu.py's Max Battery mode switches both
-- off at runtime and restores these values when it leaves, so this table is
-- the one place to change them. Global on purpose: `hyprctl eval` reads it.
POWER_BASE = { blur = true, shadow = true }

hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 10,
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

        -- Tuned for the Alder Lake iGPU, which drives everything here (the
        -- RTX 4050 sits idle). Blur cost is per-pass, per-frame, and every
        -- window on this setup is translucent, so the old settings had the
        -- compositor re-blurring the full screen 165 times a second and the
        -- GPU pinned at its 1500 MHz ceiling.
        --
        -- xray is the big one: with it off, the blur behind a window has to
        -- composite every window BEHIND it too, so cost grew with the stack
        -- depth. On it, windows blur the desktop only.
        blur = {
            enabled = POWER_BASE.blur,
            size = 4,
            passes = 1,
            new_optimizations = true,
            -- Off so a window that is already opaque is not blurred behind
            -- for nothing.
            ignore_opacity = false,
            xray = true,
            -- Menus and tooltips are small, short-lived, and constantly
            -- re-created; blurring them buys very little.
            popups = false,
        },

        shadow = {
            enabled = POWER_BASE.shadow,
            range = 15,
            -- render_power is an exponent on the shadow falloff; 2 is
            -- visually near-identical here and noticeably cheaper.
            render_power = 2,
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
        -- If the Quickshell lock daemon crashes while locked, Hyprland keeps
        -- the session locked but, without this, refuses a new lock client:
        -- the only way out was a TTY. lock.sh's cold path relies on it.
        allow_session_lock_restore = true,
    },
    render = {
        -- Let a fullscreen window hand its buffer straight to the display
        -- controller instead of going through composition. hyprctl monitors
        -- was reporting directScanoutBlockedBy: ["USER", ...] -- USER being
        -- this option sitting at its default of off.
        direct_scanout = true,
    },
})

---------------------
---- KEYBINDINGS ----
---------------------
-- Every bind carries a "Group: Label" description. `hyprctl binds -j` reports
-- it, and the Super+/ cheatsheet (quickshell/cheatsheet/) is built from that
-- live list, so it always matches what is actually bound -- add a description
-- to a new bind and it shows up there under its group.
local function d(text, opts)
    opts = opts or {}
    opts.description = text
    return opts
end

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal), d("Apps: Terminal"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager), d("Apps: File manager"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), d("Apps: Browser"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), d("Windows: Close window"))
-- Wallpaper carousel; picking one runs `walllust-cli set`, the same call
-- wallpaper_switcher.sh makes (which still runs once at login).
-- Shell toggles are Quickshell global shortcuts (GlobalShortcut in each panel):
-- the running bars get the key straight from Hyprland, with no `qs ipc call`
-- process per press (~21 ms each). Volume/brightness stay on `qs ipc` below so
-- holding the key still repeats.
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.global("quickshell:wallpaper"), d("Shell: Wallpaper picker"))
hl.bind(mainMod .. " + W", hl.dsp.global("quickshell:wallpaper"), d("Shell: Wallpaper picker"))
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd(HOME .. "/.config/hypr/toggle_overview.sh"), d("Shell: Workspace overview"))
-- Quick settings, for when reaching the right-edge hotspot is inconvenient.
hl.bind(mainMod .. " + I", hl.dsp.global("quickshell:sidepanel"), d("Shell: Side panel"))
hl.bind(mainMod .. " + D", hl.dsp.global("quickshell:dock"), d("Shell: Dock"))
-- Settings for the shell itself: dock apps, panel geometry, palette.
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(HOME .. "/.config/quickshell/settings/launch.sh"), d("Shell: Settings"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd(HOME .. "/.config/quickshell/reload.sh"), d("Shell: Reload Quickshell"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd(HOME .. "/.config/quickshell/reload.sh"), d("Shell: Reload Quickshell"))
hl.bind(mainMod .. " + slash", hl.dsp.global("quickshell:cheatsheet"), d("Shell: Keybind cheatsheet"))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }), d("Windows: Float / unfloat"))
hl.bind(mainMod .. " + C", hl.dsp.global("quickshell:launcher-clipboard"), d("Shell: Clipboard search"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.global("quickshell:clipboard"), d("Shell: Clipboard panel"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.global("quickshell:launcher-files"), d("Shell: File search"))
hl.bind(mainMod .. " + R", hl.dsp.global("quickshell:launcher-apps"), d("Shell: App launcher  (= calc, > run, ? search)"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), d("Windows: Pseudo-tile"))
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), d("Windows: Swap split direction"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(), d("Windows: Fullscreen"))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 1 }), d("Windows: Maximise"))

-- Navigation
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }), d("Windows: Focus left"))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), d("Windows: Focus right"))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }), d("Windows: Focus up"))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }), d("Windows: Focus down"))

-- Move Windows
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }), d("Windows: Move left"))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }), d("Windows: Move right"))
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }), d("Windows: Move up"))
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }), d("Windows: Move down"))

-- Move Window to Monitor
hl.bind(mainMod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ monitor = "left" }), d("Monitors: Move window to left monitor"))
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ monitor = "right" }), d("Monitors: Move window to right monitor"))

-- Focus Monitor
hl.bind(mainMod .. " + bracketleft",  hl.dsp.focus({ monitor = "left" }), d("Monitors: Focus left monitor"))
hl.bind(mainMod .. " + bracketright", hl.dsp.focus({ monitor = "right" }), d("Monitors: Focus right monitor"))

hl.bind(mainMod .. " + N", hl.dsp.global("quickshell:notification-centre"), d("Shell: Notification centre"))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }), d("Workspaces: Go to workspace " .. i))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), d("Workspaces: Move window to workspace " .. i))
end

-- Media & Brightness (locked = true, repeating = true)
-- The OSD pill (quickshell/osd/) applies the change and shows the result.
-- Mute toggles are not repeating: holding the key would flap mute on and off.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("qs ipc call osd volume 1"), d("Media: Volume up", { locked = true, repeating = true }))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("qs ipc call osd volume -1"), d("Media: Volume down", { locked = true, repeating = true }))
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("qs ipc call osd muteSink"), d("Media: Mute speakers", { locked = true }))
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("qs ipc call osd muteSource"), d("Media: Mute microphone", { locked = true }))
hl.bind("XF86MonBrightnessUp",  hl.dsp.exec_cmd("qs ipc call osd brightness 1"), d("Media: Brightness up", { locked = true, repeating = true }))
hl.bind("XF86MonBrightnessDown",hl.dsp.exec_cmd("qs ipc call osd brightness -1"), d("Media: Brightness down", { locked = true, repeating = true }))

-- Media Controls (locked = true)
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"), d("Media: Next track", { locked = true }))
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), d("Media: Play / pause", { locked = true }))
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), d("Media: Play / pause", { locked = true }))
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"), d("Media: Previous track", { locked = true }))
-- The Predator/Nitro turbo key. Only Acer gaming laptops have it, and DAMX
-- only exists once the acer-wmi driver has been installed.
if hw.acer_gaming then
    hl.bind("XF86Launch1", hl.dsp.exec_cmd("DAMX"), d("System: DAMX (fan / performance)", { locked = true }))
end

-- Screenshots
hl.bind("Print",             hl.dsp.exec_cmd(HOME .. "/.config/hypr/screenshot.sh region"), d("System: Screenshot a region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(HOME .. "/.config/hypr/screenshot.sh output"), d("System: Screenshot this monitor"))

-- Pyprland & Special Workspaces
hl.bind(mainMod .. " + l",         hl.dsp.exec_cmd(HOME .. "/.config/quickshell/lock/lock.sh"), d("System: Lock screen"))
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"), d("Workspaces: Show / hide scratch workspace"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }), d("Workspaces: Send window to scratch workspace"))
hl.bind(mainMod .. " + SPACE",     hl.dsp.exec_cmd("pypr toggle term"), d("Pop-ups: Terminal"))
hl.bind(mainMod .. " + G",         hl.dsp.exec_cmd("pypr toggle music"), d("Pop-ups: Audio mixer"))
hl.bind(mainMod .. " + T",         hl.dsp.exec_cmd("pypr toggle taskbar"), d("Pop-ups: System monitor"))
hl.bind(mainMod .. " + ALT + G",   hl.dsp.exec_cmd(HOME .. "/.config/hypr/gamemode.sh"), d("System: Game mode"))
-- gpu_switcher.sh drops its envycontrol entries by itself on a machine
-- without NVIDIA, so the binding stays useful everywhere: on a non-Optimus
-- laptop it is just the battery/performance tweak menu.
hl.bind(mainMod .. " + SHIFT + G", hl.dsp.exec_cmd(HOME .. "/.config/hypr/gpu_switcher.sh"), d("System: Power & GPU modes"))

-- Mouse Binds (mouse = true)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), d("Windows: Move window (drag)", { mouse = true }))
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), d("Windows: Resize window (drag)", { mouse = true }))

-- Session Binds
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("wlogout -b 2"), d("System: Power menu"))
hl.bind("ALT + Escape",        hl.dsp.exec_cmd("wlogout -b 2"), d("System: Power menu"))
-- Asks first: a bare exit() here closed every app on one stray keypress.
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(HOME .. "/.config/hypr/confirm-exit.sh"), d("System: Exit Hyprland (asks first)"))

-------------------------
---- LIQUID GLASS -------
-------------------------
-- Compositor-side glass for the Quickshell "glass" theme (hyprglass plugin).
-- glass.lua loads the plugin behind a crash sentinel and reads the theme
-- from quickshell/settings.json. A Lua error in it must not take the rest of
-- this config with it, hence pcall.
do
    local ok, err = pcall(dofile, HOME .. "/.config/hypr/glass.lua")
    if not ok then
        hl.notification.create({ text = "glass.lua: " .. tostring(err), duration = 10000 })
    end
end

-------------------------
---- POWER MODE ---------
-------------------------
-- smart_gpu.py writes the active power mode's refresh rate and blur/shadow to
-- this file. Loading it last means a config reload keeps Max Battery instead
-- of snapping back to the full refresh rate with blur on. It does not exist
-- until the daemon has run once in this login.
do
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    local path = runtime and (runtime .. "/power-mode/overrides.lua")
    local f = path and io.open(path, "r")
    if f then
        f:close()
        local ok, err = pcall(dofile, path)
        if not ok then
            hl.notification.create({ text = "power mode: " .. tostring(err), duration = 10000 })
        end
    end
end
