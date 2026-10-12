#!/bin/sh
# Install no-ai-attribution.
#   ./install.sh                     every repository on this machine (core.hooksPath)
#   ./install.sh --repo [path]       one repository only (.git/hooks)
#   --strict          reject every co-author trailer except your own addresses
#   --check-identity  reject pushing commits authored or committed by anyone else
#   --allow EMAIL     another address of yours (repeatable)
#   --force           replace an existing global core.hooksPath
set -eu
src=$(cd "$(dirname "$0")/hooks" && pwd -P)
mode=global repo=. force=no scope=--global opts= allow=
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) mode=repo; scope=--local; [ $# -gt 1 ] && case "$2" in -*) ;; *) repo=$2; shift;; esac ;;
    --strict) opts="$opts strict" ;;
    --check-identity) opts="$opts checkIdentity" ;;
    --allow) shift; allow="$allow $1" ;;
    --force) force=yes ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ $mode = global ]; then
  dest="${XDG_CONFIG_HOME:-$HOME/.config}/git/no-ai-attribution"
  current=$(git config --global --get core.hooksPath || true)
  if [ -n "$current" ] && [ "$current" != "$dest" ] && [ $force = no ]; then
    echo "core.hooksPath is already set to $current. Use --force to replace it, or --repo." >&2
    exit 1
  fi
  mkdir -p "$dest"
else
  cd "$repo"
  hp=$(git config --get core.hooksPath || true)
  [ -n "$hp" ] && { echo "This repository uses core.hooksPath=$hp; copy hooks/ there instead." >&2; exit 1; }
  dest=$(git rev-parse --git-dir)/hooks
  for h in commit-msg pre-push; do
    if [ -e "$dest/$h" ] && ! grep -q no-ai-attribution "$dest/$h"; then
      echo "$dest/$h already exists; not overwriting." >&2; exit 1
    fi
  done
fi

cp "$src/guard.sh" "$src/commit-msg" "$src/pre-push" "$dest/"
chmod +x "$dest/commit-msg" "$dest/pre-push"
[ $mode = global ] && git config --global core.hooksPath "$dest"
for o in $opts; do git config $scope "attribution-guard.$o" true; done
for a in $allow; do git config $scope --add attribution-guard.allow "$a"; done
echo "Installed into $dest"
