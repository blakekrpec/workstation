# starship — cross-shell prompt. Config is symlinked to ~/.config/starship.toml.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi
