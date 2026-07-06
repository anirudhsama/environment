#!/usr/bin/env bash
# Watches nothing itself — launchd (WatchPaths on ~/DevboxDrop) runs this on
# any change. Ships dropped files to devbox:~/inbox, copies the remote path
# to the clipboard, notifies, then moves the local file into .sent/.
set -uo pipefail
DROP="$HOME/DevboxDrop"
mkdir -p "$DROP/.sent"
shopt -s nullglob

for f in "$DROP"/*; do
  name=$(basename "$f")
  # let Finder finish writing before shipping
  while [ "$(( $(date +%s) - $(stat -f %m "$f") ))" -lt 2 ]; do sleep 1; done
  if scp -rq -- "$f" ani@devbox:inbox/; then
    printf '~/inbox/%s' "$name" | pbcopy
    osascript -e "display notification \"~/inbox/$name — path copied\" with title \"Sent to devbox\"" 2>/dev/null || true
    mv -f -- "$f" "$DROP/.sent/"
  else
    osascript -e "display notification \"FAILED: $name (is Tailscale up?)\" with title \"Devbox drop\"" 2>/dev/null || true
  fi
done
