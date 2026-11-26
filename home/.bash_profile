[[ -f ~/.bashrc ]] && . ~/.bashrc

# Remote SSH sends its bootstrap over a non-interactive login shell, where
# fish cannot parse it. Keep that path in bash and use fish for interactive SSH
# logins and Rex terminals, which start the passwd shell with TERM_PROGRAM=rex.
# Herdr's login Bash panes stay Bash so they can load ~/.bashrc.
if [[ $- == *i* ]] && [[ -t 0 ]] && { [[ -n ${SSH_CONNECTION:-} ]] || [[ ${TERM_PROGRAM:-} == rex ]]; } && command -v fish >/dev/null 2>&1; then
    fish_bin="$(command -v fish)"
    export SHELL="$fish_bin"
    exec "$fish_bin"
fi
