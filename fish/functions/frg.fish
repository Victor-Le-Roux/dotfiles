function frg --description 'Chercher du texte avec ripgrep et fzf'
    if test (count $argv) -eq 0
        echo 'usage : frg <motif>' >&2
        return 1
    end

    set -l selected (
        rg --line-number --no-heading --color=never --hidden \
            --glob '!.git/*' (string join ' ' $argv) |
        fzf --delimiter ':' --nth=3.. \
            --preview 'bat --style=numbers --color=always {1} --highlight-line {2}' \
            --preview-window 'right,60%,border-left'
    )
    test -n "$selected"; or return

    set -l parts (string split -m 2 ':' "$selected")
    $EDITOR "+$parts[2]" "$parts[1]"
end
