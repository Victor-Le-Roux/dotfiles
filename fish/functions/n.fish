function n --description 'Formater des fichiers C selon la Norme 42'
    if test (count $argv) -eq 0
        echo 'usage : n fichier1.c [fichier2.c ...]' >&2
        return 1
    end
    c_formatter_42 $argv
end
