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
mode=global repo=. force=no scope=--global
opts=""
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) mode=repo; scope=--local; [ $# -gt 1 ] && case "$2" in -*) ;; *) repo=$2; shift;; esac ;;
    --strict) opts="$opts strict" ;;
    --check-identity) opts="$opts checkIdentity" ;;
    --allow) shift; allow="${allow:-} $1" ;;
    --force) force=yes ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ $mode = global ]; then
  dest="${XDG_CONFIG_HOME:-$HOME/.config}/git/no-ai-attribution"
  current=$(git config --global --get core.hooksPath || true)
  if [ -n "$current" ] && [ "$current" != "$dest" ] && [ $force = no ]; then
    echo "core.hooksPath is already set to $current." >&2
    echo "Re-run with --force to replace it, or use --repo per repository." >&2
    exit 1
  fi
  mkdir -p "$dest"
  cp "$src/guard.sh" "$src/commit-msg" "$src/pre-push" "$dest/"
  chmod +x "$dest/commit-msg" "$dest/pre-push"
  git config --global core.hooksPath "$dest"
  echo "Installed for all repositories: core.hooksPath=$dest"
  echo "Repositories that set their own core.hooksPath (e.g. husky) are not covered; use --repo there."
else
  cd "$repo"
  gd=$(git rev-parse --git-dir)
  hp=$(git config --get core.hooksPath || true)
  [ -n "$hp" ] && { echo "This repository uses core.hooksPath=$hp; copy hooks/ there instead." >&2; exit 1; }
  for h in commit-msg pre-push; do
    if [ -e "$gd/hooks/$h" ] && ! grep -q no-ai-attribution "$gd/hooks/$h"; then
      echo "$gd/hooks/$h already exists; not overwriting." >&2; exit 1
    fi
  done
  cp "$src/guard.sh" "$src/commit-msg" "$src/pre-push" "$gd/hooks/"
  chmod +x "$gd/hooks/commit-msg" "$gd/hooks/pre-push"
  echo "Installed in $(pwd)"
fi

for o in $opts; do git config $scope "attribution-guard.$o" true; done
for a in ${allow:-}; do git config $scope --add attribution-guard.allow "$a"; done
