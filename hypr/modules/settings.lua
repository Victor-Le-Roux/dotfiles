local home = assert(os.getenv("HOME"), "HOME is not set")

return {
    home = home,

    apps = {
        terminal = "ghostty",
        terminal_tmux = "ghostty -e tmux new -A -s main",
        terminal_fallback = "foot",
        terminal_nushell = "ghostty -e nu",
        file_manager = "thunar",
        launcher = home .. "/.config/rofi/launcher_2.sh",
        browser = "/usr/bin/thorium-browser",
        signal = "signal-desktop",
        power_menu = home .. "/.local/bin/wlogout",
    },

    monitors = {
        primary = {
            output = "desc:Microstep MAG 272URDF",
            mode = "3840x2160@160",
            position = "0x0",
            scale = 1.5,
        },
        secondary = {
            output = "HDMI-A-1",
            mode = "1920x1080@60",
            position = "2560x0",
            scale = 1,
        },
    },

    paths = {
        scripts = home .. "/.config/hypr/scripts",
        screenshots = home .. "/Pictures/Screenshots",
        wallpaper = home .. "/Pictures/wallpapers/kawase_hasui_kawarahata_gunma_1955.jpg",
    },
}
