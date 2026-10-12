#!/bin/sh
# Remove AI attribution from a repository's existing history (all local branches and tags).
#   ./scrub-history.sh [path]          dry run: list what would change
#   ./scrub-history.sh --apply [path]  strip attribution lines, replace AI/bot authors and
#                                      committers with you, delete AI notes refs
#   --keep-authors                     leave authors and committers alone
#   --deep                             also clean tag messages, taggers and notes, rewrite
#                                      remote-only branches, list AI config files, and with
#                                      --apply drop the backups (refs/original, reflog)
# Rewriting changes commit hashes. Nothing is pushed; force-push afterwards yourself.
set -eu
guard=$(cd "$(dirname "$0")/hooks" && pwd -P)/guard.sh
apply=no authors=yes deep=no repo=.
for a; do
  case "$a" in
    --apply) apply=yes ;;
    --keep-authors) authors=no ;;
    --deep) deep=yes ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    -*) echo "unknown option: $a" >&2; exit 2 ;;
    *) repo=$a ;;
  esac
done
cd "$repo"
. "$guard"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/map"
write=no
me="$(git config user.name) <$(git config user.email)>"

# remote branches with no local branch of the same name: "branch refs/remotes/remote/branch"
remote_only() {
  git for-each-ref --format='%(refname:lstrip=3) %(refname)' refs/remotes/ |
    while read -r b r; do
      [ "$b" = HEAD ] || git show-ref -q --verify "refs/heads/$b" || echo "$b $r"
    done
}

# clean_tag REF -> prints problems with an annotated tag, returns 1 if none;
# rewrites the tag when write=yes
clean_tag() {
  t=$(git cat-file tag "$1")
  hdr=$(printf '%s\n' "$t" | sed '/^$/,$d')
  msg=$(printf '%s\n' "$t" | sed '1,/^$/d' | sed '/^-----BEGIN [A-Z ]*SIGNATURE-----$/,$d')
  tagger=$(printf '%s\n' "$hdr" | sed -n 's/^tagger //p')
  ident=$(printf '%s' "$tagger" | sed -E 's/ [0-9]+ [-+][0-9]{4}$//')
  out=$(printf '%s\n' "$msg" | ag_check_message 2>&1) || true
  if [ $authors = yes ] && [ -n "$ident" ] && ag_matches "$ag_ident_re" "$ident"; then
    out="$out
  tagger: $ident"
    hdr=$(printf '%s\n' "$hdr" | awk -v t="tagger $me ${tagger#"$ident" }" '/^tagger /{ $0 = t } 1')
  fi
  [ -z "$out" ] && return 1
  echo "tag ${1#refs/tags/}"; printf '%s\n' "$out"
  [ $write = yes ] || return 0
  new=$( { printf '%s\n\n' "$hdr"; printf '%s\n' "$msg" | ag_scrub_message; } | git mktag)
  git update-ref "$1" "$new"
}

# clean_notes REF -> prints notes that credit an AI tool, returns 1 if none;
# when write=yes, rebuilds the ref with cleaned notes on the rewritten commits
clean_notes() {
  bad=no moved=no
  : > "$tmp/tree"
  git notes --ref="$1" list > "$tmp/notes"
  while read -r blob obj; do
    new=$(sed -n "s/^$obj //p" "$tmp/map" | head -n1)
    if [ -n "$new" ] && [ "$new" != "$obj" ]; then moved=yes; else new=$obj; fi
    text=$(git cat-file blob "$blob")
    if ! out=$(printf '%s\n' "$text" | ag_check_message 2>&1); then
      echo "notes ${1#refs/notes/} on $(git rev-parse --short "$obj")"; printf '%s\n' "$out"
      bad=yes
      text=$(printf '%s\n' "$text" | ag_scrub_message)
      [ -z "$text" ] && continue
      blob=$(printf '%s\n' "$text" | git hash-object -w --stdin)
    fi
    printf '100644 blob %s\t%s\n' "$blob" "$new" >> "$tmp/tree"
  done < "$tmp/notes"
  [ $write = yes ] && { [ $bad = yes ] || [ $moved = yes ]; } || { [ $bad = yes ]; return; }
  if [ -s "$tmp/tree" ]; then
    git update-ref "$1" "$(git commit-tree -m "Notes cleaned by scrub-history.sh" "$(git mktree < "$tmp/tree")")"
  else
    git update-ref -d "$1"
  fi
}

refs="--branches --tags"
[ $deep = yes ] && refs="$refs $(remote_only | cut -d" " -f2)"
found=0
for c in $(git rev-list $refs); do
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

notes= other_notes=
for r in $(git for-each-ref --format='%(refname)' refs/notes/); do
  case "$r" in
    refs/notes/ai|refs/notes/ai-*|refs/notes/*attribution*) notes="$notes $r"; echo "notes ref: $r" ;;
    *) other_notes="$other_notes $r" ;;
  esac
done

extra=0
if [ $deep = yes ]; then
  for t in $(git for-each-ref --format='%(objecttype) %(refname)' refs/tags/ | sed -n 's/^tag //p'); do
    clean_tag "$t" && extra=$((extra + 1))
  done
  for r in $other_notes; do clean_notes "$r" && extra=$((extra + 1)); done
  remote_only | while read -r b r; do echo "remote-only branch: ${r#refs/remotes/} (rewritten as local branch $b)"; done
  git log $refs --name-only --format= | sort -u |
    grep -E '(^|/)(CLAUDE\.md|AGENTS\.md|GEMINI\.md|\.claude/|\.cursor/|\.cursorrules|\.aider|\.windsurfrules|\.clinerules|\.roo/|\.github/copilot-instructions\.md)' |
    sed 's/^/AI config file in history (not removed): /' || true
fi

if [ $found = 0 ] && [ $extra = 0 ] && [ -z "$notes" ]; then echo "No AI attribution found."; exit 0; fi
if [ $apply = no ]; then
  echo "$found commit(s) to rewrite. Re-run with --apply to do it."
  [ $deep = yes ] && echo "--deep --apply also deletes the backups (refs/original, reflog), so there is no undo."
  exit 0
fi

git diff-index --quiet HEAD -- || { echo "Commit or stash your changes first." >&2; exit 1; }
write=yes
if [ $deep = yes ]; then
  remote_only | while read -r b r; do
    git show-ref -q --verify "refs/heads/$b" || git branch -q --no-track "$b" "$r"
  done
fi
export AG_GUARD="$guard" AG_NAME="$(git config user.name)" AG_MAIL="$(git config user.email)" AG_MAP="$tmp/map"
set -- --msg-filter '. "$AG_GUARD"; ag_scrub_message' --tag-name-filter cat \
  --commit-filter 'n=$(git commit-tree "$@") && echo "$GIT_COMMIT $n" >> "$AG_MAP" && echo "$n"'
[ $authors = yes ] && set -- "$@" --env-filter '
  if (. "$AG_GUARD"; ag_matches "$ag_ident_re" "$GIT_AUTHOR_NAME <$GIT_AUTHOR_EMAIL>"); then
    export GIT_AUTHOR_NAME="$AG_NAME" GIT_AUTHOR_EMAIL="$AG_MAIL"; fi
  if (. "$AG_GUARD"; ag_matches "$ag_ident_re" "$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>"); then
    export GIT_COMMITTER_NAME="$AG_NAME" GIT_COMMITTER_EMAIL="$AG_MAIL"; fi'
[ $found -gt 0 ] && FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f "$@" -- --branches --tags >/dev/null
for r in $notes; do git update-ref -d "$r"; done

if [ $deep = yes ]; then
  for t in $(git for-each-ref --format='%(objecttype) %(refname)' refs/tags/ | sed -n 's/^tag //p'); do
    clean_tag "$t" >/dev/null || true
  done
  for r in $other_notes; do clean_notes "$r" >/dev/null || true; done
  git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin
  git reflog expire --expire=now --all
  git gc -q --prune=now
  echo "Done. Old commits are gone from this repository, except where remote-tracking"
  echo "branches (origin/...) still point at them until you force-push."
else
  echo "Done. Originals are kept under refs/original/ until you delete them:"
  echo "  git for-each-ref --format='delete %(refname)' refs/original | git update-ref --stdin"
fi
echo "Publish with: git push --force-with-lease --all && git push --force-with-lease --tags"
[ -n "$other_notes$notes" ] && echo "Notes: git push --force origin 'refs/notes/*' (and delete removed notes refs on the remote)"
echo "Existing clones and forks keep the old history. GitHub can still serve old commits"
echo "by hash and from pull request refs; ask GitHub Support to purge them if needed."
