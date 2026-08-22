function temp --description 'Ouvrir un fichier temporaire dans Neovim'
    set -l temporary_file (mktemp); or return
    nvim -c 'autocmd VimLeavePre * call delete(expand("%"))' "$temporary_file"
end
