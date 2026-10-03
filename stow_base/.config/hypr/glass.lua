-- Liquid glass behind the Quickshell panels, for the shell's "glass" theme.
--
-- The panels cannot draw this themselves: a layer surface never sees the
-- pixels under it, so frosting and edge refraction of the windows behind a
-- panel have to happen in the compositor. That is the hyprglass plugin
-- (github.com/hyprnux/hyprglass), built by build-hyprglass.sh against the
-- installed Hyprland headers.
--
-- The theme itself lives in ~/.config/quickshell/settings.json
-- ({"theme": {"mode": "glass"}}); this file reads it on every config
-- evaluation, and the shell re-evaluates it on a theme change. Dark and light
-- leave the plugin loaded but idle: layer glass off, window glass off.
--
-- Crash guard: a sentinel file is written before the plugin is loaded and
-- removed 30 s after Hyprland survived it. If Hyprland died while loading
-- (an ABI mismatch after an update, say), the next start finds the sentinel
-- and skips the plugin instead of crash-looping the session. Glass mode then
-- degrades to a very translucent dark theme. To retry after rebuilding:
--     rm ~/.cache/hyprglass.loading

local HOME = os.getenv("HOME") or ""
local SO = HOME .. "/.local/lib/hyprland/hyprglass.so"
local SENTINEL = HOME .. "/.cache/hyprglass.loading"
local SETTINGS = HOME .. "/.config/quickshell/settings.json"

local function exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

local function theme_mode()
    local f = io.open(SETTINGS, "r")
    if not f then
        return "dark"
    end
    local text = f:read("*a")
    f:close()
    local mode = text:match('"theme"%s*:%s*{[^}]-"mode"%s*:%s*"(%a+)"')
    if mode == "light" or mode == "glass" then
        return mode
    end
    return "dark"
end

if not hl.plugin.hyprglass and exists(SO) and not exists(SENTINEL) then
    local f = io.open(SENTINEL, "w")
    if f then
        f:write(os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        f:close()
    end
    hl.plugin.load(SO)
    if not hl.plugin.hyprglass then
        -- Seen on 0.56.2: during a live config reload hl.plugin.load returns
        -- without loading anything, while hyprctl's loader works. The reload
        -- after it re-runs this file with the plugin present, which applies
        -- the config below. If the plugin is already loaded, `plugin load`
        -- fails and the && stops it from reloading in a loop.
        hl.exec_cmd("sh -c 'hyprctl plugin load " .. SO .. " && hyprctl reload'")
    end
    hl.exec_cmd("sh -c 'sleep 30; rm -f " .. SENTINEL .. "'")
end

if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    local glass = theme_mode() == "glass"

    hg.config({
        -- App windows never get glass; only the shell's own layers do.
        enabled = false,
        default_theme = "dark",
        default_preset = "shell",
        layers = {
            enabled = glass,
            preset = "shell_layer",
            live_resample = true,
            live_resample_fps = 30,
        },
    })

    -- Two presets, because the plugin draws its rim, bevel and edge
    -- refraction against the WHOLE surface with square corners on a layer
    -- (corner radius 0 in GlassLayerSurface.cpp). Our panels sit inside
    -- larger layer surfaces that touch the screen edges, so on layers that rim
    -- landed on the screen edge as a hard white line. Layers therefore get
    -- frost only, and each panel draws its own lit rim on its real rounded
    -- shape (quickshell/common/GlassRim.qml). Windows have a true rounded
    -- shape, so the settings window keeps a subtle plugin rim.
    hg.preset("shell", {
        blur_strength = 1.4,
        blur_iterations = 2,
        refraction_strength = 0.6,
        refraction_spread = 0.35,
        chromatic_aberration = 0.2,
        fresnel_strength = 0.25,
        specular_strength = 0.3,
        bevel_strength = 0.18,
        bevel_size = 1.5,
        edge_thickness = 0.035,
        lens_distortion = 0.12,
        tint_color = 0xffffff00,
        dark = { brightness = 0.95, contrast = 0.95, saturation = 1.0, adaptive_dim = 0.25 },
    })

    hg.preset("shell_layer", {
        blur_strength = 1.4,
        blur_iterations = 2,
        refraction_strength = 0.0,
        chromatic_aberration = 0.0,
        fresnel_strength = 0.0,
        specular_strength = 0.0,
        bevel_strength = 0.0,
        lens_distortion = 0.0,
        edge_thickness = 0.0,
        tint_color = 0xffffff00,
        dark = { brightness = 0.95, contrast = 0.95, saturation = 1.05, adaptive_dim = 0.25 },
    })

    -- Every Quickshell layer that paints a panel. The desktop clock is left
    -- out on purpose: it is bare text on the wallpaper, not a panel.
    -- A threshold of 0.1 keeps antialiased fringes and faint washes from
    -- growing glass of their own; the glass panelBg is ~0.14 alpha.
    local layers = {
        "quickshell-topbar",
        "leftbar",
        "quickshell-dock",
        "quickshell-sidepanel",
        "quickshell-notifications",
        "quickshell-launcher",
        "quickshell-overview",
        "quickshell-lyrics",
        "quickshell-floating-clock",
    }
    for _, ns in ipairs(layers) do
        hg.layer(ns, { mask_threshold = 0.1 })
    end

    -- The settings app is a normal window: tag it for window glass while the
    -- glass theme is on.
    hl.window_rule({
        name = "shell-settings-glass",
        enabled = glass,
        match = { title = "^(Shell Settings)$" },
        tag = "+hyprglass_enabled",
        -- The glass is the see-through part; the global active/inactive
        -- opacity would also fade the text and swatches drawn on it.
        opacity = "1.0 override 1.0 override",
    })
end
