[[ -f ~/.bashrc ]] && . ~/.bashrc

# Remote SSH sends its bootstrap over a non-interactive login shell, where
# fish cannot parse it. Keep that path in bash and use fish for terminal logins.
if [[ $- == *i* ]] && [[ -t 0 ]] && command -v fish >/dev/null 2>&1; then
    exec fish
fi
