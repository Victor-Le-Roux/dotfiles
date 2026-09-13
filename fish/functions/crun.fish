function crun --description 'Compiler et lancer le projet CMake courant'
    if not test -f CMakeLists.txt
        echo 'crun : lance cette commande à la racine du projet CMake.' >&2
        return 1
    end

    set -l build_dir "$PWD/build"
    cmake -S "$PWD" -B "$build_dir"
    or return 1

    if test (count $argv) -gt 0
        cmake --build "$build_dir" --target "$argv[1]"
    else
        cmake --build "$build_dir"
    end
    or return 1

    set -l executables
    while read -lz candidate
        if test (count $argv) -eq 0
            set -a executables "$candidate"
        else if test (path basename "$candidate") = "$argv[1]"
            set -a executables "$candidate"
        end
    end < (find "$build_dir" -type d -name CMakeFiles -prune -o -type f -executable ! -name '*.so' ! -name '*.so.*' ! -name '*.sh' -print0 | psub)

    if test (count $executables) -ne 1
        echo 'crun : impossible de sélectionner un exécutable unique.' >&2
        printf '  %s\n' $executables >&2
        echo 'Utilisation : crun [nom_de_la_cible] [arguments du programme…]' >&2
        return 1
    end

    if test (count $argv) -gt 0
        set -e argv[1]
    end
    "$executables[1]" $argv
end
