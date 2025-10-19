# ~/.zshrc — entièrement réécrit
# -------------------------------------------------------------
# 1.  Fonctions utilitaires
# -------------------------------------------------------------
# Préfixe PATH seulement si le chemin n’y est pas déjà présent
typeset -gA CDMARKS=(
  ppc   "$PPROOT/projets/coding"
  ppw   "$PPROOT/projets/web"
  ppp   "$PPROOT/projets/personal"
  ppcfg "$PPROOT/ressources/configs"
  ppdoc "$PPROOT/ressources/docs"
  pptool "$PPROOT/ressources/tools"
  pparch "$PPROOT/ressources/archives"
  ppm   "$PPROOT/centres_interet/manhwa"
  ppl   "$PPROOT/centres_interet/lua"
)

autoload -U add-zsh-hook
pathprepend() {
  case ":$PATH:" in
    *":$1:"*) ;; # déjà présent
    *) PATH="$1:$PATH" ;;
  esac
}

# Override de la commande `cd` pour activer un venv local
function cd() {
  emulate -L zsh
  setopt localoptions no_shwordsplit

  if (( $# == 0 )); then
    builtin cd || return
  else
    local target="$1"
    # si ce n’est pas un switch (-), ni absolu (/), ni déjà ~expanded
    if [[ "$target" != -* && "$target" != /* && "$target" != ~* ]]; then
      local head="${target%%/*}"
      local tail=""
      [[ "$target" == */* ]] && tail="/${target#*/}"
      if [[ -n ${CDMARKS[$head]} ]]; then
        target="${CDMARKS[$head]}$tail"
      fi
    fi
    builtin cd -- "$target" || return
  fi

  [[ -f "activate_venv.sh" ]] && source "activate_venv.sh"
}

# -------------------------------------------------------------
# 2.  PATH — ordre : ccache → user bins → dotnet → fini
# -------------------------------------------------------------
pathprepend "/usr/lib/ccache/bin"    # wrappers gcc/g++/…
pathprepend "$HOME/.local/bin"       # pipx, npm, cargo install …
pathprepend "$HOME/bin"              # scripts persos

# Dotnet ajoute deux répertoires
export DOTNET_ROOT="/usr/share/dotnet"
pathprepend "$DOTNET_ROOT"
pathprepend "$DOTNET_ROOT/tools"

export PATH  # rend la variable globale visible

# -------------------------------------------------------------
# 3.  Variables d’environnement diverses
# -------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
export SYSTEMD_EDITOR="vim"
export WLR_NO_HARDWARE_CURSORS=1
export LIBVA_DRIVER_NAME="nvidia"
export XDG_SESSION_TYPE="wayland"
export GBM_BACKEND="nvidia-drm"
export __GLX_VENDOR_LIBRARY_NAME="nvidia"
export WLR_DRM_DEVICES="/dev/dri/card1:/dev/dri/card0"

# -------------------------------------------------------------
# 4.  Oh‑My‑Zsh
# -------------------------------------------------------------
ZSH_THEME="simple"
plugins=(
  git
  archlinux
  zsh-autosuggestions
  zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# -------------------------------------------------------------
# 5.  Alias généraux
# -------------------------------------------------------------
# Navigation rapide
alias hr='cd ~/.config/hypr'
alias nvim_config='cd ~/.config/nvim'

# Editor
alias vim='nvim'

# Contrôle Spotify personnalisé
alias middle_of_the_song='$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 1'
alias next_song='$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 2'
alias like_the_song='$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 3'
alias repeat_the_song='$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 4'
alias stop_music_repeat='$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 5'
alias pause_and_play='$HOME/my_personnal_spotify_config/spotify_control_terminal.sh 6'

# Temp file in nvim (scratch buffer)
alias temp='nvim -c '\''autocmd VimLeavePre * call delete(expand("%"))'\'' "$(mktemp)"'
# -------------------------------------------------------------
# 6.  Projets personnels
# -------------------------------------------------------------
export PPROOT="$HOME/personal_project"

# Racine
alias pp='cd "$PPROOT"'

# Projets
alias ppc='cd "$PPROOT/projets/coding"'
alias ppw='cd "$PPROOT/projets/web"'
alias ppp='cd "$PPROOT/projets/personal"'

# Ressources
alias ppcfg='cd "$PPROOT/ressources/configs"'
alias ppdoc='cd "$PPROOT/ressources/docs"'
alias pptool='cd "$PPROOT/ressources/tools"'
alias pparch='cd "$PPROOT/ressources/archives"'

# Centres d’intérêt
alias ppm='cd "$PPROOT/centres_interet/manhwa"'
alias ppl='cd "$PPROOT/centres_interet/lua"'

# Aide
alias pphelp='glow "$PPROOT/README.md"'

