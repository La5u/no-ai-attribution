#!/bin/sh
# Remove AI attribution from a repository's existing history (all local branches and tags).
#   ./scrub-history.sh [path]            dry run: list what would change
#   ./scrub-history.sh --apply [path]    rewrite commit messages, delete AI notes refs
#   --authors                            also replace AI/bot authors and committers with you
# Rewriting changes commit hashes. Nothing is pushed; force-push afterwards yourself.
set -eu
guard=$(cd "$(dirname "$0")/hooks" && pwd -P)/guard.sh
apply=no authors=no repo=.
for a; do
  case "$a" in
    --apply) apply=yes ;;
    --authors) authors=yes ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    -*) echo "unknown option: $a" >&2; exit 2 ;;
    *) repo=$a ;;
  esac
done
cd "$repo"
. "$guard"

found=0
for c in $(git rev-list --branches --tags); do
  out=$(git log -1 --format=%B "$c" | ag_check_message 2>&1) || true
  if [ $authors = yes ]; then
    for f in '%an <%ae>' '%cn <%ce>'; do
      i=$(git log -1 --format="$f" "$c")
      ag_matches "$ag_ident_re" "$i" && out="$out
  identity: $i"
    done
  fi
  [ -z "$out" ] && continue
  found=$((found + 1))
  git log -1 --format='%h %s' "$c"; printf '%s\n' "$out"
done
notes=$(git for-each-ref --format='%(refname)' refs/notes/ | while read -r r; do
  case "$r" in refs/notes/ai|refs/notes/ai-*|refs/notes/*attribution*) echo "$r" ;; esac
done)
for r in $notes; do echo "notes ref: $r"; done

if [ $found = 0 ] && [ -z "$notes" ]; then echo "No AI attribution found."; exit 0; fi
if [ $apply = no ]; then
  echo "$found commit(s) to rewrite. Re-run with --apply to do it."
  exit 0
fi

git diff-index --quiet HEAD -- || { echo "Commit or stash your changes first." >&2; exit 1; }
export AG_GUARD="$guard" AG_NAME="$(git config user.name)" AG_MAIL="$(git config user.email)"
set -- --msg-filter '. "$AG_GUARD"; ag_scrub_message' --tag-name-filter cat
[ $authors = yes ] && set -- "$@" --env-filter '
  if (. "$AG_GUARD"; ag_matches "$ag_ident_re" "$GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>"); then
    export GIT_AUTHOR_NAME="$AG_NAME" GIT_AUTHOR_EMAIL="$AG_MAIL"; fi
  if (. "$AG_GUARD"; ag_matches "$ag_ident_re" "$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>"); then
    export GIT_COMMITTER_NAME="$AG_NAME" GIT_COMMITTER_EMAIL="$AG_MAIL"; fi'
[ $found -gt 0 ] && FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f "$@" -- --branches --tags
for r in $notes; do git update-ref -d "$r"; done

echo "Done. Originals are kept under refs/original/ until you delete them:"
echo "  git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin"
echo "Then publish with: git push --force-with-lease --all && git push --force-with-lease --tags"
