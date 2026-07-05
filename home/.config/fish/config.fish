# Enable homebrew (macOS only)
if test (uname) = Darwin
    eval "$(/opt/homebrew/bin/brew shellenv)"
end

# Disable the fish greeting message
set fish_greeting ""

set -gx EDITOR nvim

# Set vi mode
set -g fish_key_bindings fish_hybrid_key_bindings
set -g fish_cursor_default block
set -g fish_cursor_insert line blink
set -g fish_cursor_replace_one underscore blink
set -g fish_cursor_replace underscore blink
set -g fish_cursor_external line
set -g fish_cursor_visual block blink
set -g fish_vi_force_cursor true

if status is-interactive
    # Commands to run in interactive sessions can go here

    # Disable fzf for history since we are using atuin for that
    if functions -q fzf_configure_bindings
        fzf_configure_bindings --history=
    end

    if command -q atuin
        set -x ATUIN_NOBIND true
        atuin init fish | source

        bind \cr _atuin_search
        bind up _atuin_bind_up
        bind \eOA _atuin_bind_up
        bind \e\[A _atuin_bind_up

        if bind -M insert >/dev/null 2>&1
            bind -M insert \cr _atuin_search
            bind -M insert up _atuin_bind_up
            bind -M insert \eOA _atuin_bind_up
            bind -M insert \e\[A _atuin_bind_up
        end
    end
end

if test (uname) = Darwin
    alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
end
alias cat="bat"
alias vi="nvim"
alias vim="nvim"

# agents, full-autonomy mode
alias yolo="claude --dangerously-skip-permissions"
alias yolox="codex -c model_reasoning_effort=high --dangerously-bypass-approvals-and-sandbox -c model_reasoning_summary=detailed -c model_supports_reasoning_summaries=true"

# mise (dev runtimes: node, bun, fnox, ...)
if command -q mise
    mise activate fish | source
end

# macOS-only integrations
if test (uname) = Darwin
    # Added by LM Studio CLI (lms)
    set -gx PATH $PATH /Users/ani/.cache/lm-studio/bin

    # Added by OrbStack: command-line tools and integration
    source ~/.orbstack/shell/init.fish 2>/dev/null || :

    # opencode
    fish_add_path /Users/ani/.opencode/bin
end

# amp
fish_add_path ~/.local/bin

# fnox shell integration
if status is-interactive
    if command -q fnox
        fnox activate fish | source
    end
end

# Machine-local config (secrets, host-specific overrides) — never committed.
# e.g. the psql dev/prod connection function lives here on the Mac.
if test -f $__fish_config_dir/local.fish
    source $__fish_config_dir/local.fish
end
