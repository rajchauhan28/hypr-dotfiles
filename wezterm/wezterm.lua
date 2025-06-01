local wezterm = require 'wezterm'

return {
    -- Set default shell to Zsh
    default_prog = { "/bin/zsh" },

    -- Set default window size (approximate, based on font size)
    initial_cols = 140,  -- Adjust for width
    initial_rows = 30,  -- Adjust for height

    -- Enable window resizing
    window_decorations = "RESIZE",

    -- Set window transparency
    window_background_opacity = 0.8,  -- Adjust this value (0.0 is fully transparent, 1.0 is opaque)

    -- Key bindings
    keys = {
        -- Bind Ctrl+V to paste from clipboard
        {key="v", mods="CTRL", action=wezterm.action.PasteFrom("Clipboard")},
    }
}
