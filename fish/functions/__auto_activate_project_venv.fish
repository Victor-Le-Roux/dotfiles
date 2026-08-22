function __auto_activate_project_venv --on-variable PWD \
        --description 'Activer automatiquement le venv local prévu par le projet'
    if test -f activate_venv.sh; and test -f .venv/bin/activate.fish
        if not set -q VIRTUAL_ENV; or test "$VIRTUAL_ENV" != "$PWD/.venv"
            source .venv/bin/activate.fish
        end
    end
end
