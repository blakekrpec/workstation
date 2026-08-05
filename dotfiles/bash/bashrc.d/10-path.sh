# PATH additions. Guarded so re-sourcing the file is a no-op.
_ws_path_prepend() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

_ws_path_prepend "$HOME/.local/bin"
export PATH
unset -f _ws_path_prepend
