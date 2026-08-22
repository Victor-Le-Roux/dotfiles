function cdf --description 'Choisir un fichier avec fzf puis rejoindre son dossier'
    set -l selected (find . -type f 2>/dev/null | fzf)
    test -n "$selected"; or return
    cd (dirname "$selected")
end
