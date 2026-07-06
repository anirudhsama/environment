function send --description "Copy files to devbox:~/inbox and put the remote path on the clipboard"
    if test (count $argv) -eq 0
        echo "usage: send <file> [more files...]" >&2
        return 1
    end
    scp -rq -- $argv ani@devbox:inbox/
    or begin
        echo "send: scp failed" >&2
        return 1
    end
    set -l paths
    for f in $argv
        set -a paths "~/inbox/"(path basename -- $f)
    end
    printf '%s\n' $paths
    if command -q pbcopy
        printf '%s\n' $paths | pbcopy
        echo "(copied to clipboard)"
    end
end
