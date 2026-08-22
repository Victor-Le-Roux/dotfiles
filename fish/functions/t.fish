function t --description 'Choisir un fichier puis rejoindre son dossier'
    set -l roots $argv
    if test (count $roots) -eq 0
        set roots $TZF_SEARCH_DIRS
    end

    set -l valid_roots
    for root in $roots
        if test -d "$root"
            set -a valid_roots (realpath "$root")
        else
            echo "tzf : dossier ignoré car introuvable : $root" >&2
        end
    end
    test (count $valid_roots) -gt 0; or return 1

    set -l selected (
        find $valid_roots \
            -type d \( -name .git -o -name node_modules -o -name build \) -prune \
            -o -type f -print 2>/dev/null |
        fzf
    )
    test -n "$selected"; or return
    cd (dirname "$selected")
end
