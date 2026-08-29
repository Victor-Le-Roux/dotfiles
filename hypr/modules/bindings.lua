local settings = require("modules.settings")
local apps = settings.apps
local scripts = settings.paths.scripts
local mod = "SUPER"

local function bind(keys, dispatcher, options)
    hl.bind(keys, dispatcher, options)
end

bind(mod .. " + Return", hl.dsp.exec_cmd(apps.terminal))
bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(apps.terminal_tmux))
bind(mod .. " + ALT + Return", hl.dsp.exec_cmd(apps.terminal_fallback))
bind(mod .. " + CTRL + SHIFT + Return", hl.dsp.exec_cmd(apps.terminal_nushell))
bind(mod .. " + Q", hl.dsp.window.close())
bind(mod .. " + E", hl.dsp.exec_cmd(apps.file_manager))
bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
bind(mod .. " + R", hl.dsp.exec_cmd(apps.launcher))
bind(mod .. " + F", hl.dsp.exec_cmd(apps.launcher))
bind(mod .. " + B", hl.dsp.exec_cmd(apps.browser))
bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))
bind(mod .. " + J", hl.dsp.layout("togglesplit"))
bind(mod .. " + SPACE", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

local directions = {
    left = "l",
    right = "r",
    up = "u",
    down = "d",
}

for key, direction in pairs(directions) do
    bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
    bind(
        mod .. " + CTRL + " .. key,
        hl.dsp.exec_cmd(scripts .. "/smart_move.sh " .. direction)
    )
end

local resize = {
    left = { x = -50, y = 0 },
    right = { x = 50, y = 0 },
    up = { x = 0, y = -50 },
    down = { x = 0, y = 50 },
}

for key, delta in pairs(resize) do
    bind(
        mod .. " + SHIFT + " .. key,
        hl.dsp.window.resize({ x = delta.x, y = delta.y, relative = true }),
        { repeating = true }
    )
end

for workspace = 1, 10 do
    local key = workspace % 10
    bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
    bind(
        mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({ workspace = workspace })
    )
end

bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 0.90 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true }
)
bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true }
)
bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true }
)
bind(
    "XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true }
)
bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("brightnessctl set 10%+"),
    { locked = true, repeating = true }
)
bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("brightnessctl set 10%-"),
    { locked = true, repeating = true }
)

bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
bind(mod .. " + ALT + left", hl.dsp.exec_cmd("playerctl previous"))
bind(mod .. " + ALT + right", hl.dsp.exec_cmd("playerctl next"))

bind(mod .. " + SHIFT + D", hl.dsp.exec_cmd("systemctl poweroff"))

bind(
    "Print",
    hl.dsp.exec_cmd("hyprshot -m output --clipboard-only")
)
bind(
    "SHIFT + Print",
    hl.dsp.exec_cmd("hyprshot -m region --clipboard-only")
)
bind(
    "CTRL + Print",
    hl.dsp.exec_cmd("hyprshot -m window --clipboard-only")
)
