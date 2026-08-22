# Environnement commun
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SYSTEMD_EDITOR nvim
set -gx SHELL /usr/bin/fish
set -gx TERMINAL ghostty
set -gx TERMINAL_FALLBACK foot
set -gx PPROOT "$HOME/personal_project"
set -gx STARSHIP_CONFIG "$HOME/.config/starship.toml"
set -gx DOTNET_ROOT /usr/share/dotnet
set -g TZF_SEARCH_DIRS "$PPROOT"
set -gx NVIM_SEARCH_DIRS (string join : $TZF_SEARCH_DIRS)

fish_add_path --global --prepend \
    /usr/lib/ccache/bin \
    "$HOME/.local/bin" \
    "$HOME/bin" \
    "$HOME/go/bin" \
    "$HOME/.npm-global/bin" \
    "$DOTNET_ROOT" \
    "$DOTNET_ROOT/tools"

set -gx FZF_DEFAULT_COMMAND 'rg --files --hidden --glob "!.git/*"'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_DEFAULT_OPTS '--height=80% --layout=reverse --border'
if command -q fd
    set -gx FZF_ALT_C_COMMAND 'fd --type d --hidden --exclude .git'
end

if status is-interactive
    set -g fish_greeting

    # Palette Kawase Hasui commune à Ghostty, foot, Kitty, tmux et Starship.
    set -g fish_color_normal 0a0d14
    set -g fish_color_command 135a6a --bold
    set -g fish_color_keyword 55284a --bold
    set -g fish_color_quote 2d5520
    set -g fish_color_redirection 866428
    set -g fish_color_end 8a2210
    set -g fish_color_error a3321a --bold
    set -g fish_color_param 0a0d14
    set -g fish_color_option 866428
    set -g fish_color_comment 58524a --italics
    set -g fish_color_operator 8a2210
    set -g fish_color_escape 1e6058
    set -g fish_color_autosuggestion 58524a
    set -g fish_color_valid_path 135a6a --underline
    set -g fish_color_search_match 0a0d14 --background=b0cdd2
    set -g fish_color_cancel a3321a

    # Pager sans le bloc cyan peu lisible visible sur la capture.
    set -g fish_pager_color_background normal
    set -g fish_pager_color_progress 135a6a --bold
    set -g fish_pager_color_prefix 8a2210 --bold --underline
    set -g fish_pager_color_completion 0a0d14
    set -g fish_pager_color_description 866428 --italics
    set -g fish_pager_color_secondary_background normal
    set -g fish_pager_color_secondary_prefix $fish_pager_color_prefix
    set -g fish_pager_color_secondary_completion $fish_pager_color_completion
    set -g fish_pager_color_secondary_description $fish_pager_color_description
    set -g fish_pager_color_selected_background --background=b0cdd2
    set -g fish_pager_color_selected_prefix 8a2210 --bold --underline
    set -g fish_pager_color_selected_completion 0a0d14
    set -g fish_pager_color_selected_description 55284a --italics

    command -q starship; and starship init fish | source
    command -q zoxide; and zoxide init fish | source
    command -q direnv; and direnv hook fish | source
    __auto_activate_project_venv

    abbr --add hr 'cd ~/.config/hypr'
    abbr --add nvim_config 'cd ~/.config/nvim'
    abbr --add pp 'cd $PPROOT'
    abbr --add ppc 'cd $PPROOT/projets/coding'
    abbr --add ppw 'cd $PPROOT/projets/web'
    abbr --add ppp 'cd $PPROOT/projets/personal'
    abbr --add ppcfg 'cd $PPROOT/ressources/configs'
    abbr --add ppdoc 'cd $PPROOT/ressources/docs'
    abbr --add pptool 'cd $PPROOT/ressources/tools'
    abbr --add pparch 'cd $PPROOT/ressources/archives'
    abbr --add ppm 'cd $PPROOT/centres_interet/manhwa'
    abbr --add ppl 'cd $PPROOT/centres_interet/lua'
	abbr --add l 'ls -lah'
    abbr --add pphelp 'glow $PPROOT/README.md'
    abbr --add tms tmux-sessionizer
    abbr --add middle_of_the_song '$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 1'
    abbr --add next_song '$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 2'
    abbr --add like_the_song '$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 3'
    abbr --add repeat_the_song '$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 4'
    abbr --add stop_music_repeat '$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 5'
    abbr --add pause_and_play '$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 6'
end
function multicd
    echo cd (string repeat -n (math (string length -- $argv[1]) - 1) ../)
end

abbr --add dotdot --regex '^\.\.+$' --function multicd
