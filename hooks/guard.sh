# Shared checks for no-ai-attribution. Sourced by the hooks; POSIX sh.
#
# Config (git config, any scope):
#   attribution-guard.allow          email allowed in co-author trailers and as
#                                    author/committer (repeatable; user.email is
#                                    always allowed)
#   attribution-guard.strict         true: reject every co-author-style trailer
#                                    whose email is not allowed, not just AI ones
#   attribution-guard.checkIdentity  true: pre-push rejects commits whose author
#                                    or committer is not an allowed email

# AI tools, vendors and agents by name. Matched as whole words, case-insensitively.
AG_NAMED='claude|anthropic|codex|openai|chatgpt|gpt-?[0-9][a-z0-9.-]*|copilot|cursor|cursoragent|gemini|jules|bard|aider|devin|cognition|windsurf|codeium|opencode|amp|ampcode|sourcegraph|cody|junie|cline|roo|roocode|kilocode|tabnine|qwen|deepseek|mistral|grok|llama|sweep|coderabbit|lovable|replit|crush|codebuff|freebuff|droid|kiro|augment|augmentcode|goose|warp|qwen-coder|amazon q|q developer|gpt-engineer|openhands|opendevin|swe-agent|zed ai|tabby'
# Names safe to treat as an AI identity in author/committer/co-author fields
# (no common human names like Devin, Cody or Jules; those tools use bot emails).
AG_IDENT='claude|anthropic|codex|openai|chatgpt|gpt-?[0-9][a-z0-9.-]*|copilot|cursoragent|cursor agent|gemini|aider|windsurf|codeium|opencode|ampcode|sourcegraph|junie|roocode|roo code|kilocode|kilo code|tabnine|deepseek|qwen|grok|coderabbit|cursor|crush|codebuff|freebuff|factory droid|droid|warp agent|replit-agent|replit agent|gpt-engineer|amazon-q|amazon q|openhands|swe-agent'
# Generic words that only count in attribution context (trailers, "made with ...").
AG_GENERIC='ai|a\.i\.|llm|llms|bot|agent|assistant|chatbot|language model|machine learning'

# Email domains and addresses that belong to AI tools or bots.
AG_EMAILS='@anthropic\.com|@openai\.com|@cursor\.(com|sh)|@cursoragent|@ampcode\.com|@aider\.chat|@cognition(-labs)?\.(ai|com)|@devin\.ai|@codeium\.com|@windsurf\.com|@sourcegraph\.com|@tabnine\.com|@sst\.dev|@opencode\.ai|@google-labs|copilot@github\.com|@codebuff\.com|@charm\.land|@warp\.dev|junie@jetbrains\.com|qwen-coder@|@factory\.ai|@replit\.com|@lovable\.dev|@gptengineer|@all-hands\.dev|\[bot\]@|\+copilot|\+claude|\+codex|\+devin|bot@users\.noreply\.github\.com'

# Trailer keys that credit someone with a commit.
AG_KEYS='co-?authored-?by|co-?authors?|co-?developed-?by|assisted-?by|ai-?assisted(-?by)?|generated-?by|generated-?with|written-?by|created-?by|made-?with|made-?by|authored-?by|helped-?by|pair(ed)?-?with|with-?help-?from|signed-?off-?by|reviewed-?by|acked-?by|tested-?by|suggested-?by|reported-?by|agent-?logs-?url|tool|ai(-?tool|-?model)?|model'

ag_lc() { tr '[:upper:]' '[:lower:]'; }
ag_bool() { [ "$(git config --type=bool --get "$1" 2>/dev/null)" = true ]; }
ag_email() { printf '%s' "$1" | sed -nE 's/.*<([^>]*)>.*/\1/p'; }

# word-boundary match, portable across grep implementations
ag_word() { printf '(^|[^a-z0-9])(%s)([^a-z0-9]|$)' "$1"; }
ag_any_re=$(ag_word "$AG_NAMED|$AG_GENERIC")
ag_ident_re="$AG_EMAILS|$(ag_word "$AG_IDENT")|\\[bot\\]"
ag_credit_re="$AG_EMAILS|$(ag_word "$AG_IDENT|$AG_GENERIC")|\\[bot\\]"

# ag_matches RE TEXT -> 0 if lowercased TEXT matches RE
ag_matches() { printf '%s\n' "$2" | ag_lc | grep -qE "$1"; }

# ag_is_allowed EMAIL -> 0 if EMAIL is user.email or attribution-guard.allow
ag_is_allowed() {
  e=$(printf '%s' "$1" | ag_lc)
  [ -n "$e" ] && { git config --get user.email; git config --get-all attribution-guard.allow; } 2>/dev/null |
    ag_lc | grep -qxF "$e"
}

# ag_check_message < message -> prints offending lines, returns 1 if any
ag_check_message() {
  strict=no; ag_bool attribution-guard.strict && strict=yes
  bad=0
  n=0
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    # lowercase, drop CR and zero-width/soft-hyphen characters, fold Unicode
    # hyphens/colons/spaces to ASCII
    lc=$(printf '%s' "$line" | ag_lc | tr -d '\r' | sed 's/​//g; s/‌//g; s/‍//g; s/⁠//g; s/﻿//g; s/­//g; s/᠎//g; s/‐/-/g; s/‑/-/g; s/‒/-/g; s/–/-/g; s/—/-/g; s/−/-/g; s/：/:/g; s/ / /g; s/ / /g')
    # strip leading whitespace, quote markers and list bullets
    body=$(printf '%s' "$lc" | sed -E 's/^[[:space:]>*_-]*//')
    hit=
    # 1. credit trailers: "Key: Name <email>" (also "Key :", "Key=", missing space)
    if printf '%s' "$body" | grep -qE "^($AG_KEYS)[[:space:]]*[:=]"; then
      email=$(ag_email "$body")
      [ -z "$email" ] && email=$(printf '%s' "$body" | grep -oE '[^[:space:]<>:=]+@[^[:space:]<>]+' | head -n1)
      if ag_is_allowed "$email"; then :
      elif [ "$strict" = yes ]; then hit=1
      elif ag_matches "$ag_credit_re" "$body"; then hit=1
      fi
    fi
    # 2. "Generated/written/... with/by/using <tool>" anywhere in the line
    if [ -z "$hit" ] && printf '%s' "$body" | grep -qE "(^|[^a-z])(generated|written|created|made|authored|produced|built|coded|drafted|assisted|powered|co-?written|co-?authored|helped|crafted|done|implemented|developed|ultraworked|vibe-?coded)[[:space:]]+(entirely[[:space:]]+|partly[[:space:]]+|partially[[:space:]]+|mostly[[:space:]]+|in[[:space:]]+part[[:space:]]+)?(with|by|using|via|through|from|thanks[[:space:]]+to)([[:space:]]+[^[:space:]]+){0,3}[[:space:]]*[[(\"'*_]*($AG_NAMED|$AG_GENERIC)([^a-z0-9]|\$)"; then hit=1; fi
    # 3. trailers keyed by a tool (Amp-Thread-ID:, Claude-Session:, ...) and aider's "aider:" subject
    if [ -z "$hit" ] && [ $n -gt 1 ] && printf '%s' "$lc" | grep -qE "^[a-z0-9-]*-($AG_NAMED)(-[a-z0-9-]*)?[[:space:]]*:|^($AG_NAMED)-[a-z0-9-]+[[:space:]]*:"; then hit=1; fi
    if [ -z "$hit" ] && [ $n -eq 1 ] && printf '%s' "$body" | grep -qE '^aider[[:space:]]*:'; then hit=1; fi
    # 4. robot emoji, tool links and AI addresses anywhere
    if [ -z "$hit" ] && printf '%s' "$body" | grep -qE "(🤖|💘|💖|✨).*($ag_any_re|generated)"; then hit=1; fi
    if [ -z "$hit" ] && printf '%s' "$body" | grep -qE 'claude\.(com|ai)/(claude-)?code|chatgpt\.com/codex|openai\.com/codex|ampcode\.com/threads|devin\.ai/sessions|jules\.google(\.com)?/(task|session)|cursor\.com/(agents|background-agent)|opencode\.ai/s/|devin\.ai|coderabbit\.ai|qwen-review|auto-generated comment|authorship/[0-9]'; then hit=1; fi
    if [ -z "$hit" ] && printf '%s' "$body" | grep -qE "$AG_EMAILS"; then hit=1; fi
    if [ -n "$hit" ]; then
      printf '  line %s: %s\n' "$n" "$line" >&2
      bad=1
    fi
  done
  return $bad
}

# ag_check_ident ROLE "Name <email>" -> 0 if acceptable
ag_check_ident() {
  e=$(ag_email "$2")
  # checked before the allow list: aider keeps your email but renames you "Name (aider)"
  if ag_matches "$ag_ident_re" "$2"; then
    printf '  %s is an AI tool: %s\n' "$1" "$2" >&2
    return 1
  fi
  if ag_is_allowed "$e"; then return 0; fi
  if ag_bool attribution-guard.checkIdentity; then
    [ "$1" = committer ] && [ "$e" = noreply@github.com ] && return 0
    printf '  %s is not you: %s\n' "$1" "$2" >&2
    return 1
  fi
  return 0
}

# Run the repository's own hook of the same name, if any.
ag_chain() {
  name=$1; shift
  gd=$(git rev-parse --git-dir 2>/dev/null) || return 0
  hook="$gd/hooks/$name"
  [ -x "$hook" ] || return 0
  # installed per repository: the repo hook is this hook, don't run it twice
  [ "$(cd "$(dirname "$hook")" && pwd -P)/$name" = "$(cd "$(dirname "$0")" && pwd -P)/$(basename "$0")" ] && return 0
  "$hook" "$@"
}
