hl.window_rule({
    name = "thorium-eink",
    match = { class = "^(thorium-browser)$" },
    no_anim = true,
    no_blur = true,
    no_shadow = true,
})

hl.window_rule({
    name = "rofi-borderless",
    match = { class = "^(Rofi)$" },
    border_size = 0,
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.layer_rule({
    name = "waybar-eink",
    match = { namespace = "^waybar$" },
    no_anim = true,
    blur = false,
})

hl.layer_rule({
    name = "awww-background",
    match = { namespace = "^awww-daemon$" },
    no_anim = true,
})
