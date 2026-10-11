#!/bin/sh
# Remove the global install of no-ai-attribution (leaves per-repo installs alone).
set -eu
dest="${XDG_CONFIG_HOME:-$HOME/.config}/git/no-ai-attribution"
[ "$(git config --global --get core.hooksPath || true)" = "$dest" ] && git config --global --unset core.hooksPath
rm -rf "$dest"
echo "Removed $dest"
