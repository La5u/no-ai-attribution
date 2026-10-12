#!/bin/sh
# Test suite: every way an AI tool could credit itself must be blocked,
# and ordinary commits must still go through. Runs in an isolated HOME.
set -u
root=$(cd "$(dirname "$0")/.." && pwd -P)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1 XDG_CONFIG_HOME="$tmp/home/.config"
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_DIR GIT_WORK_TREE
mkdir -p "$HOME"
git config --global user.name "Me"
git config --global user.email "me@example.com"
git config --global init.defaultBranch main
git config --global core.hooksPath "$root/hooks"
git config --global advice.detachedHead false

pass=0 failn=0
ok()  { pass=$((pass + 1)); }
bad() { failn=$((failn + 1)); echo "FAIL: $1"; }

new_repo() {
  rm -rf "$tmp/r" "$tmp/remote.git"
  git init -q --bare "$tmp/remote.git"
  git init -q "$tmp/r" && cd "$tmp/r" || exit 1
  git remote add origin "$tmp/remote.git"
  echo base > f && git add f && git commit -qm "Initial commit" && git push -q origin main 2>/dev/null
}
change() { echo "$RANDOM$$$(date +%s%N)" >> f; git add f; }

# commit message must be rejected by commit-msg
block() {
  change
  printf '%s' "$2" > "$tmp/msg"
  if git commit -q -F "$tmp/msg" 2>/dev/null; then bad "commit allowed: $1"; git reset -q --hard HEAD~1; else ok; fi
}
# commit message must be accepted
allow() {
  change
  printf '%s' "$2" > "$tmp/msg"
  if git commit -q -F "$tmp/msg" 2>/dev/null; then ok; else bad "commit blocked: $1"; git reset -q; fi
}
# commit made with --no-verify must then be refused by pre-push
push_block() {
  if git push -q origin "${2:-HEAD:main}" 2>/dev/null; then bad "push allowed: $1"; else ok; fi
}
push_allow() {
  if git push -q origin "${2:-HEAD:main}" 2>/dev/null; then ok; else bad "push blocked: $1"; fi
}
reset_to_remote() { git fetch -q origin; git reset -q --hard origin/main; }

S="Fix the parser

Handle empty input."

new_repo

# --- Trailers from real tools -------------------------------------------------
block "Claude Code trailer"      "$S

Co-Authored-By: Claude <noreply@anthropic.com>"
block "Claude Code model trailer" "$S

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
block "Claude Code footer"       "$S

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
block "Claude Code old footer"   "$S

🤖 Generated with [Claude Code](https://claude.ai/code)"
block "Codex trailer"            "$S

Co-authored-by: Codex <codex@openai.com>"
block "Codex link"               "$S

https://chatgpt.com/codex/tasks/task_e_68a1"
block "Copilot coding agent"     "$S

Co-authored-by: copilot-swe-agent[bot] <198982749+Copilot@users.noreply.github.com>"
block "Copilot trailer"          "$S

Co-authored-by: Copilot <175728472+Copilot@users.noreply.github.com>"
block "Cursor agent"             "$S

Co-authored-by: Cursor Agent <cursoragent@cursor.com>"
block "Aider trailer"            "$S

Co-authored-by: aider (anthropic/claude-sonnet-4) <noreply@aider.chat>"
block "Aider subject prefix"     "aider: Fix the parser"
block "Jules trailer"            "$S

Co-authored-by: google-labs-jules[bot] <161369871+google-labs-jules[bot]@users.noreply.github.com>"
block "Gemini trailer"           "$S

Co-authored-by: gemini-code-assist[bot] <176961590+gemini-code-assist[bot]@users.noreply.github.com>"
block "Devin trailer"            "$S

Co-Authored-By: Devin AI <158243242+devin-ai-integration[bot]@users.noreply.github.com>"
block "Amp trailers"             "$S

Amp-Thread-ID: https://ampcode.com/threads/T-1234
Co-authored-by: Amp <amp@ampcode.com>"
block "Amp thread only"          "$S

Amp-Thread-ID: https://ampcode.com/threads/T-1234"
block "OpenCode trailer"         "$S

Co-authored-by: opencode <noreply@opencode.ai>"
block "Generic AI co-author"     "$S

Co-authored-by: AI Assistant <ai@example.com>"
block "Signed-off-by Claude"     "$S

Signed-off-by: Claude <noreply@anthropic.com>"
block "Assisted-by trailer"      "$S

Assisted-by: Claude Sonnet"
block "Generated-by trailer"     "$S

Generated-by: ChatGPT"
block "AI-assisted trailer"      "$S

AI-assisted: yes"
block "Claude-Session trailer"   "$S

Claude-Session-Id: 9f1c2e"

# --- Formatting tricks ---------------------------------------------------------
block "lowercase key"            "$S

co-authored-by: claude <noreply@anthropic.com>"
block "uppercase key"            "$S

CO-AUTHORED-BY: CLAUDE <NOREPLY@ANTHROPIC.COM>"
block "space before colon"       "$S

Co-authored-by : Claude <noreply@anthropic.com>"
block "no space after colon"     "$S

Co-authored-by:Claude <noreply@anthropic.com>"
block "indented trailer"         "$S

    Co-authored-by: Claude <noreply@anthropic.com>"
block "quoted trailer"           "$S

> Co-authored-by: Claude <noreply@anthropic.com>"
block "no hyphens key"           "$S

Coauthored-by: Claude <noreply@anthropic.com>"
block "Co-author key"            "$S

Co-author: Claude"
block "Unicode hyphens"          "$S

Co‑authored‑by: Claude <noreply@anthropic.com>"
block "zero-width in key"        "$S

Co​-authored-by: Claude <noreply@anthropic.com>"
block "zero-width in name"       "$S

Co-authored-by: Cl​aude <noreply@anthropic.com>"
block "CRLF line endings"        "$(printf 'Fix the parser\r\n\r\nCo-authored-by: Claude <noreply@anthropic.com>\r\n')"
block "only email, no name"      "$S

Co-authored-by: noreply@anthropic.com"
block "name only"                "$S

Co-authored-by: Claude"
block "AI email in body"         "$S

Thanks noreply@anthropic.com"
block "HTML comment footer"      "$S

<!-- Generated by Claude Code -->"
block "markdown bold footer"     "$S

**Generated with Claude**"

# --- Prose credit ---------------------------------------------------------------
block "Generated with Claude Code" "$S

Generated with Claude Code"
block "Written by ChatGPT"       "$S

Written by ChatGPT."
block "made with help of Copilot" "$S

Made with the help of Copilot"
block "Created using Cursor"     "$S

Created using Cursor"
block "made with heart by Claude" "$S

Made with ❤️ by Claude"
block "partly generated with AI" "$S

Partly generated with AI."
block "assisted by an LLM"       "$S

Assisted by an LLM"
block "built with Gemini"        "$S

Built with Gemini 2.5 Pro"
block "via Codex in subject"     "Fix parser (generated via Codex)"
block "robot emoji + tool"       "$S

🤖 Claude"
block "thanks to GPT-5"          "$S

Implemented thanks to GPT-5"

# --- More tools (research, Oct 2026) --------------------------------------------
block "Claude web session"       "$S

Claude-Session: https://claude.ai/code/session_01abc"
block "Codex noreply"            "$S

Co-authored-by: Codex <noreply@openai.com>"
block "Copilot VS Code"          "$S

Co-authored-by: Copilot <copilot@github.com>"
block "Copilot agent logs"       "$S

Agent-Logs-Url: https://github.com/me/repo/sessions/0b1c"
block "Cursor Made-with"         "$S

Made-with: Cursor"
block "Cursor PR footer"         "$S

Made with Cursor"
block "Aider email"              "$S

Co-authored-by: aider (gpt-4o) <aider@aider.chat>"
block "Devin footer"             "$S

Generated with [Devin](https://devin.ai)"
block "Qwen Code"                "$S

Co-authored-by: Qwen-Coder <qwen-coder@alibabacloud.com>"
block "Crush trailer"            "$S

Assisted-by: Crush:claude-sonnet-4"
block "Crush footer"             "$S

💘 Generated with Crush"
block "Crush co-author"          "$S

Co-authored-by: Crush <crush@charm.land>"
block "Codebuff footer"          "$S

🤖 Generated with Codebuff"
block "Codebuff co-author"       "$S

Co-authored-by: Codebuff <noreply@codebuff.com>"
block "freebuff"                 "$S

Generated with freebuff"
block "Replit trailers"          "$S

Replit-Commit-Author: Agent
Replit-Commit-Session-Id: 3c2e"
block "Amazon Q"                 "$S

Co-authored-by: amazon-q-developer[bot] <208079219+amazon-q-developer[bot]@users.noreply.github.com>"
block "Factory Droid"            "$S

Co-authored-by: Droid"
block "Warp agent"               "$S

Co-authored-by: Warp Agent <agent@warp.dev>"
block "Junie"                    "$S

Co-authored-by: Junie <junie@jetbrains.com>"
block "Sweep bot"                "$S

Co-authored-by: sweep-ai[bot] <128439645+sweep-ai[bot]@users.noreply.github.com>"
block "OpenCode footer"          "$S

🤖 Generated with [opencode](https://opencode.ai)"
block "Ultraworked"              "$S

Ultraworked with Sisyphus agent"
block "CodeRabbit marker"        "$S

<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
block "Qwen review marker"       "$S

<!-- qwen-review critical -->"
change
if git commit -qm "x" --author="lovable-dev[bot] <lovable-dev[bot]@users.noreply.github.com>" 2>/dev/null; then bad "Lovable bot author"; git reset -q --hard HEAD~1; else ok; fi
change
if git -c user.name=replit-agent -c user.email=me@example.com commit -qm "x" 2>/dev/null; then bad "Replit agent author"; git reset -q --hard HEAD~1; else ok; fi
change
if git commit -qm "x" --author="Jules <161369871+google-labs-jules[bot]@users.noreply.github.com>" 2>/dev/null; then bad "Jules bot author"; git reset -q --hard HEAD~1; else ok; fi

# --- Identities -------------------------------------------------------------------
change
if git -c user.name=Claude -c user.email=noreply@anthropic.com commit -qm "x" 2>/dev/null; then bad "author via config"; git reset -q --hard HEAD~1; else ok; fi
change
if git commit -qm "x" --author="Claude <noreply@anthropic.com>" 2>/dev/null; then bad "author via --author"; git reset -q --hard HEAD~1; else ok; fi
change
if GIT_AUTHOR_NAME=Codex GIT_AUTHOR_EMAIL=codex@openai.com git commit -qm "x" 2>/dev/null; then bad "author via env"; git reset -q --hard HEAD~1; else ok; fi
change
if GIT_COMMITTER_NAME=Claude GIT_COMMITTER_EMAIL=noreply@anthropic.com git commit -qm "x" 2>/dev/null; then bad "committer via env"; git reset -q --hard HEAD~1; else ok; fi
change
if git commit -qm "x" --author="Copilot <198982749+Copilot@users.noreply.github.com>" 2>/dev/null; then bad "Copilot bot author"; git reset -q --hard HEAD~1; else ok; fi
change
if git -c user.name="Me (aider)" commit -qm "x" 2>/dev/null; then bad "aider author name"; git reset -q --hard HEAD~1; else ok; fi

# --- Must still be allowed ------------------------------------------------------
allow "plain"                    "$S"
allow "mentions Claude API"      "Fix Claude API client timeout"
allow "copilot keybinding"       "Add Copilot keybinding to settings"
allow "sphinx generated"         "Generated docs with Sphinx"
allow "bump openai"              "Bump openai from 1.2.0 to 1.3.0"
allow "claude.ai link"           "Update link to claude.ai docs"
allow "human co-author"          "$S

Co-authored-by: Jane Doe <jane@example.com>"
allow "own signoff"              "$S

Signed-off-by: Me <me@example.com>"
allow "AI module"                "Refactor AI module"
allow "made with love"           "Made with love in Paris"
allow "cursor position"          "Fix cursor position after paste"
allow "warp drive"               "Add warp drive animation"
allow "crush bug"                "Crush the off-by-one bug in pagination"
allow "droid build"              "Update Android droid build script"
allow "augment parser"           "Augment the parser with error recovery"
allow "made with canvas"         "Chart made with canvas instead of SVG"
allow "goose game"               "Add goose sprite"
allow "human reviewed-by"        "$S

Reviewed-by: Jane Doe <jane@example.com>"
allow "openai bullet"            "Update deps

- openai: bump to 1.3
- anthropic: bump to 0.40"
allow "devin human co-author"    "$S

Co-authored-by: Devin Smith <devin@example.com>"
change
if git -c user.name="Devin Smith" -c user.email=devin@example.com commit -qm "Human named Devin" 2>/dev/null; then ok; else bad "human author named Devin"; fi
change
if git -c user.name="Ai Tanaka" -c user.email=ai@example.com commit -qm "Human named Ai" 2>/dev/null; then ok; else bad "human author named Ai"; fi
push_allow "normal commits"

# --- Bypasses caught at push ------------------------------------------------------
reset_to_remote
change; git commit -q --no-verify -m "x

Co-authored-by: Claude <noreply@anthropic.com>"
push_block "--no-verify trailer"
reset_to_remote

change; git -c user.name=Claude -c user.email=noreply@anthropic.com commit -q --no-verify -m "x"
push_block "--no-verify AI author"
reset_to_remote

change; tree=$(git write-tree)
c=$(printf 'x\n\nCo-authored-by: Claude <noreply@anthropic.com>\n' | git commit-tree "$tree" -p HEAD)
git reset -q --hard "$c"
push_block "commit-tree plumbing"
reset_to_remote

change; git commit -qm "clean"; git commit -q --amend --no-verify -m "clean

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
push_block "amend --no-verify"
reset_to_remote

git checkout -q -b feature; change; git commit -qm "feature work"; git checkout -q main
if git merge -q --no-ff feature -m "Merge feature

Co-authored-by: Claude <noreply@anthropic.com>" 2>/dev/null; then bad "merge message allowed"; else ok; fi
git merge --abort 2>/dev/null; git reset -q --hard origin/main
git merge -q --no-ff --no-verify feature -m "Merge feature

Co-authored-by: Claude <noreply@anthropic.com>" 2>/dev/null
push_block "merge --no-verify"
reset_to_remote

git checkout -q -b foreign; change
git -c user.name=Codex -c user.email=codex@openai.com commit -q --no-verify -m "foreign"
git checkout -q main; git cherry-pick foreign >/dev/null 2>&1 || bad "cherry-pick setup failed"
push_block "cherry-picked AI commit"
reset_to_remote

change; git commit -qm "clean for rebase"; git commit -q --amend --no-verify -m "reworded

Co-authored-by: Claude <noreply@anthropic.com>"
git checkout -q -B newbranch
push_block "new branch" "newbranch"
git checkout -q main; reset_to_remote

change; git commit -qm "tagged"; git push -q origin HEAD:main 2>/dev/null
git tag -a v1 -m "Release v1

Generated with Claude Code"
push_block "annotated tag message" "v1"
git tag -d v1 >/dev/null
git -c user.name=Claude -c user.email=noreply@anthropic.com tag -a v2 -m "Release v2"
push_block "tag by AI tagger" "v2"
git tag -d v2 >/dev/null
git tag -a v3 -m "Release v3"
push_allow "clean tag" "v3"

git notes add -m "Co-authored-by: Claude <noreply@anthropic.com>" HEAD
push_block "git notes" "refs/notes/commits"
git notes --ref=ai add -m '{"schema_version":"authorship/3.0.0"}' HEAD
push_block "git-ai notes ref" "refs/notes/ai"
git notes --ref=ai-attribution add -m "lines 1-20" HEAD
push_block "Qwen attribution notes" "refs/notes/ai-attribution"

change; git commit -q --no-verify -m "x

Co-authored-by: Claude <noreply@anthropic.com>"
if git push -q --all origin 2>/dev/null; then bad "push --all allowed"; else ok; fi
reset_to_remote

# --- Strict mode and identity check -----------------------------------------------
git config attribution-guard.strict true
block "strict: human co-author"  "$S

Co-authored-by: Jane Doe <jane@example.com>"
allow "strict: own co-author"    "$S

Co-authored-by: Me <me@example.com>"
git config --add attribution-guard.allow me@work.example
allow "strict: allowed address"  "$S

Co-authored-by: Me at work <me@work.example>"
git config --unset attribution-guard.strict
reset_to_remote

git config attribution-guard.checkIdentity true
change; git -c user.name=Jane -c user.email=jane@example.com commit -q --no-verify -m "by Jane"
push_block "checkIdentity: other author"
reset_to_remote
change; git -c user.email=me@work.example commit -qm "from work address"
push_allow "checkIdentity: allowed address"
git config --unset attribution-guard.checkIdentity

# --- scrub-history.sh ----------------------------------------------------------
attributed_history() {
  new_repo
  change; git commit -q --no-verify -m "$S

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
  change; git -c user.name="Me (aider)" commit -q --no-verify -m "aider: add thing"
}
attributed_history
git tag -a v1 -m v1; git notes --ref=ai add -m x HEAD
before=$(git rev-parse HEAD)
out=$("$root/scrub-history.sh")
case "$out" in *"2 commit(s)"*"--apply"*) ok ;; *) bad "scrub dry run: $out" ;; esac
[ "$(git rev-parse HEAD)" = "$before" ] && ok || bad "scrub dry run changed history"
echo dirty >> f
"$root/scrub-history.sh" --apply >/dev/null 2>&1 && bad "scrub ran on a dirty tree" || ok
git checkout -q f
"$root/scrub-history.sh" --apply >/dev/null 2>&1 || bad "scrub --apply failed"
log=$(git log --format='%an <%ae> %cn%n%B' --branches --tags)
[ "$log" = "$(git log --format='%an <%ae> %cn%n%B' --branches)" ] && ok || bad "scrub left tag on old commit"
case "$log" in *[Cc]laude*|*aider*) bad "scrub left attribution: $log" ;; *) ok ;; esac
case "$log" in *"Handle empty input."*"Initial commit"*) ok ;; *) bad "scrub lost message text: $log" ;; esac
git rev-parse -q --verify refs/notes/ai >/dev/null && bad "scrub kept AI notes" || ok
git rev-parse -q --verify refs/original/refs/heads/main >/dev/null && ok || bad "scrub dropped backup without --deep"
case "$("$root/scrub-history.sh")" in "No AI attribution found.") ok ;; *) bad "scrub not idempotent" ;; esac

attributed_history
"$root/scrub-history.sh" --apply --keep-authors >/dev/null 2>&1 || bad "scrub --keep-authors failed"
case "$(git log -1 --format='%an %B')" in "Me (aider) add thing"*) ok ;; *) bad "scrub --keep-authors changed author" ;; esac

# --deep: tags, taggers, notes, remote-only branches, AI files, backups
attributed_history
mkdir -p .cursor && echo x > .cursor/rules && echo x > CLAUDE.md && git add -A && git commit -q --no-verify -m "Add rules"
git notes add -m "Reviewed.

Co-authored-by: Claude <noreply@anthropic.com>" HEAD
git notes add -m "Plain note" HEAD~1
git -c user.name=Claude -c user.email=noreply@anthropic.com tag -a v2 -m "Release

Generated with Claude Code" HEAD~1
git checkout -q -b side && change && git commit -q --no-verify -m "Side work

Co-authored-by: Codex <codex@openai.com>" && git push -q --no-verify origin side 2>/dev/null
git checkout -q main && git branch -q -D side && git fetch -q origin
out=$("$root/scrub-history.sh" --deep)
for want in "tag v2" "tagger: Claude" "notes commits on" "remote-only branch: origin/side" \
  "AI config file in history (not removed): CLAUDE.md" "AI config file in history (not removed): .cursor/rules" "no undo"; do
  case "$out" in *"$want"*) ok ;; *) bad "scrub --deep dry run missing '$want': $out" ;; esac
done
"$root/scrub-history.sh" --deep --apply >/dev/null 2>&1 || bad "scrub --deep --apply failed"
case "$(git cat-file tag v2)" in *[Cc]laude*|*anthropic*) bad "scrub --deep left tag attribution" ;; *"tagger Me <me@example.com>"*Release*) ok ;; *) bad "scrub --deep broke tag: $(git cat-file tag v2)" ;; esac
[ "$(git rev-parse v2^{commit})" = "$(git rev-parse HEAD~1)" ] && ok || bad "scrub --deep tag points at old commit"
[ "$(git notes show HEAD)" = "Reviewed." ] && ok || bad "scrub --deep notes: $(git notes show HEAD 2>&1)"
[ "$(git notes show HEAD~1)" = "Plain note" ] && ok || bad "scrub --deep lost note on rewritten commit"
case "$(git log -1 --format=%B side 2>&1)" in "Side work") ok ;; *) bad "scrub --deep remote-only branch: $(git log -1 --format=%B side 2>&1)" ;; esac
[ -z "$(git for-each-ref refs/original)" ] && ok || bad "scrub --deep kept refs/original"
case "$("$root/scrub-history.sh" --deep)" in *"No AI attribution found.") ok ;; *) bad "scrub --deep not idempotent: $("$root/scrub-history.sh" --deep)" ;; esac

echo "$pass passed, $failn failed"
[ "$failn" = 0 ]
