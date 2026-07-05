# Fnox decrypts age-backed secrets with this private key.
# Run `fnox-unlock` once to make the key available to all fish sessions.
function fnox-unlock
    if set -q FNOX_AGE_KEY
        echo "fnox: FNOX_AGE_KEY is already set"
        return
    end

    if not command -q op
        echo "fnox: 1Password CLI `op` was not found" >&2
        return 1
    end

    set -l fnox_age_key (op read "op://Private/Fnox Age Key/private")
    if test $status -ne 0; or test -z "$fnox_age_key"
        echo "fnox: could not read age key from 1Password" >&2
        set -e fnox_age_key
        return 1
    end

    set -Ux FNOX_AGE_KEY "$fnox_age_key"
    set -e fnox_age_key
    echo "fnox: unlocked for all fish sessions"
end

function fnox-lock
    set -e FNOX_AGE_KEY
    set -eU FNOX_AGE_KEY
    echo "fnox: locked"
end
