# OpenCode installs to ~/.opencode/bin and does not put itself on PATH.
if [ -d "$HOME/.opencode/bin" ]; then
    case ":$PATH:" in
        *":$HOME/.opencode/bin:"*) ;;
        *) export PATH="$HOME/.opencode/bin:$PATH" ;;
    esac
fi
