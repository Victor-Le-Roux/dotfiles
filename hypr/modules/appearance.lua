hl.config({
    general = {
        gaps_in = 2,
        gaps_out = 5,
        border_size = 2,
        col = {
            active_border = "rgb(1b1f2a)",
            inactive_border = "rgb(bdb7a6)",
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },

    decoration = {
        rounding = 0,
        rounding_power = 2,
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,
        shadow = {
            enabled = false,
        },
        blur = {
            enabled = false,
            size = 3,
            passes = 1,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
        smart_resizing = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
    },
})

hl.curve("eink", {
    type = "bezier",
    points = {
        { 0.0, 0.0 },
        { 1.0, 1.0 },
    },
})

hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "eink", style = "popin 100%" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2, bezier = "eink", style = "popin 100%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "eink", style = "popin 100%" })
hl.animation({ leaf = "windowsMove", enabled = false, speed = 0, bezier = "eink" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "eink" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "eink" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2, bezier = "eink" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 2, bezier = "eink" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "eink" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "eink", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "eink", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "eink", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2.5, bezier = "eink", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.5, bezier = "eink", style = "fade" })
