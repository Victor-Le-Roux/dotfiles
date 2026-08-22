function ff --description 'Ouvrir un fichier du projet avec fzf'
    set -l selected (
        rg --files --hidden --glob '!.git/*' |
        fzf --preview 'bat --style=numbers --color=always {}' \
            --preview-window 'right,60%,border-left'
    )
    test -n "$selected"; or return
    $EDITOR "$selected"
end
