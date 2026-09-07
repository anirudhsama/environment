# mise comes from the vendor installer on both platforms.
export PATH="$HOME/.local/bin:$PATH"

# Local additions run before mise so noninteractive commands prefer its shims.
[[ -f ~/.bashrc.local ]] && . ~/.bashrc.local

if command -v mise >/dev/null 2>&1; then
    if [[ $- == *i* ]]; then
        eval "$(mise activate bash)"
    else
        eval "$(mise activate bash --shims)"
    fi
fi
