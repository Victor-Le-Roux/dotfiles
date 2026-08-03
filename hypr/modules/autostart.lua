local settings = require("modules.settings")
local scripts = settings.paths.scripts

local function shell_quote(value)
    return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local function run_if_available(binary, command, rules)
    hl.exec_cmd(
        "if command -v "
            .. shell_quote(binary)
            .. " >/dev/null 2>&1; then exec "
            .. command
            .. "; fi",
        rules
    )
end

local function start_once(binary, command)
    hl.exec_cmd(
        "if command -v "
            .. shell_quote(binary)
            .. " >/dev/null 2>&1 && ! pgrep -x "
            .. shell_quote(binary)
            .. " >/dev/null 2>&1; then exec "
            .. command
            .. "; fi"
    )
end

local function restore_aoc_transform()
    local command = scripts .. "/restore_aoc_transform.sh"
    hl.exec_cmd(
        "if [ -x " .. shell_quote(command) .. " ]; then exec " .. shell_quote(command) .. "; fi"
    )
end

local function start_session()
    run_if_available(
        "dbus-update-activation-environment",
        "dbus-update-activation-environment --systemd HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    )
    start_once("waybar", "waybar")
    start_once("mako", "mako")
    start_once("awww-daemon", "awww-daemon")
    hl.exec_cmd(
        "if command -v awww >/dev/null 2>&1; then "
            .. "for i in $(seq 1 50); do awww query >/dev/null 2>&1 && break; sleep 0.1; done; "
            .. "awww query >/dev/null 2>&1 && exec awww img "
            .. "--transition-type none --transition-duration 0 "
            .. shell_quote(settings.paths.wallpaper)
            .. "; fi"
    )
    restore_aoc_transform()
    run_if_available("signal-desktop", settings.apps.signal, { workspace = "4 silent" })
    hl.exec_cmd(
        "if command -v pactl >/dev/null 2>&1; then "
            .. "for i in $(seq 1 20); do pactl info >/dev/null 2>&1 && break; sleep 0.5; done; "
            .. "pactl info >/dev/null 2>&1 && "
            .. "pactl set-sink-volume \"$(pactl get-default-sink)\" 90%; fi"
    )
end

hl.on("hyprland.start", start_session)

hl.on("monitor.added", function(monitor)
    if monitor == nil then
        return
    end

    local description = string.lower(monitor.description or "")
    if monitor.name == settings.monitors.secondary.output or string.find(description, "aoc", 1, true) then
        restore_aoc_transform()
    end
end)
