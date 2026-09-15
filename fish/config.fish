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
    set -g fish_color_normal 3c3e34
    set -g fish_color_command 35666d --bold
    set -g fish_color_keyword 855669 --bold
    set -g fish_color_quote 53673d
    set -g fish_color_redirection 7c573c
    set -g fish_color_end a5543c
    set -g fish_color_error 943f32 --bold
    set -g fish_color_param 3c3e34
    set -g fish_color_option 7c573c
    set -g fish_color_comment 736f63 --italics
    set -g fish_color_operator a5543c
    set -g fish_color_escape 426b63
    set -g fish_color_autosuggestion 736f63
    set -g fish_color_valid_path 35666d --underline
    set -g fish_color_search_match 3c3e34 --background=d8d0b9
    set -g fish_color_cancel 943f32

    # Pager sans le bloc cyan peu lisible visible sur la capture.
    set -g fish_pager_color_background normal
    set -g fish_pager_color_progress 35666d --bold
    set -g fish_pager_color_prefix a5543c --bold --underline
    set -g fish_pager_color_completion 3c3e34
    set -g fish_pager_color_description 7c573c --italics
    set -g fish_pager_color_secondary_background normal
    set -g fish_pager_color_secondary_prefix $fish_pager_color_prefix
    set -g fish_pager_color_secondary_completion $fish_pager_color_completion
    set -g fish_pager_color_secondary_description $fish_pager_color_description
    set -g fish_pager_color_selected_background --background=d8d0b9
    set -g fish_pager_color_selected_prefix a5543c --bold --underline
    set -g fish_pager_color_selected_completion 3c3e34
    set -g fish_pager_color_selected_description 855669 --italics

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
