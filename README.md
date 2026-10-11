# no-ai-attribution

Git hooks that stop AI coding tools from crediting themselves in your commits.

Claude Code, Codex, Copilot, Cursor, Aider, Jules, Devin, Amp, Crush, Codebuff,
Qwen Code, Replit and others add `Co-authored-by:` trailers, "Generated with …"
footers, session and thread links, checkpoint trailers, bot authors, `(aider)`
name suffixes or attribution `git notes` to commits. Most have a setting to turn it
off, but every tool has a different one, new tools keep appearing, and agents
don't always respect them. These hooks enforce it in one place, for every tool,
in every repository on your machine.

Works with any tool that commits through your local git. Plain POSIX `sh`, no
dependencies.

## Install

```sh
git clone https://github.com/La5u/no-ai-attribution
cd no-ai-attribution
./install.sh
```

This copies the hooks to `~/.config/git/no-ai-attribution` and points
`core.hooksPath` there, so it covers every repository. Existing per-repo hooks in
`.git/hooks/` still run after these.

Options:

| Flag | Effect |
| --- | --- |
| `--strict` | Reject every co-author-style trailer (`Co-authored-by`, `Signed-off-by`, `Reviewed-by`, …) unless it's one of your addresses, not just AI ones |
| `--check-identity` | Refuse to push commits authored or committed by anyone but you |
| `--allow EMAIL` | Another address of yours (repeatable). `user.email` is always allowed |
| `--repo [path]` | Install into one repository's `.git/hooks` instead of globally |
| `--force` | Replace an existing global `core.hooksPath` |

Solo developer who wants nothing but their own name on their commits:

```sh
./install.sh --strict --check-identity --allow me@work.example
```

Uninstall with `./uninstall.sh`.

## What it blocks

**`commit-msg`** rejects the commit when the message or identity credits an AI:

- Credit trailers naming an AI tool, model or bot: `Co-authored-by`, `Co-author`,
  `Coauthored-by`, `Co-developed-by`, `Assisted-by`, `Generated-by`,
  `AI-assisted`, `Signed-off-by`, `Reviewed-by` and similar
- Tool-specific trailers: `Amp-Thread-ID:`, `Claude-Session:`, `Agent-Logs-Url:`,
  `Made-with: Cursor`, `Replit-Commit-*:`, `Assisted-by: Crush:…`
- Review-bot markers left in messages: `<!-- … coderabbit.ai -->`, `<!-- qwen-review … -->`
- Prose credit: "Generated with Claude Code", "Written by ChatGPT", "Made with ❤️
  by Claude", "Partly generated with AI", "Built with Gemini", "Ultraworked with …"
- 🤖 / 💘 footers, task/thread/session links (`claude.com/claude-code`,
  `chatgpt.com/codex`, `ampcode.com/threads`, …) and AI or bot email addresses
- Aider's `aider:` subject prefix and `Your Name (aider)` author name
- AI or bot identities as author or committer (`noreply@anthropic.com`,
  `…+Copilot@users.noreply.github.com`, `cursoragent@cursor.com`,
  `…[bot]@users.noreply.github.com`, …), whether set by config, `--author` or
  environment variables

Matching is case-insensitive and ignores the usual tricks: Unicode hyphens,
zero-width characters, CRLF, indentation, quoting, missing or extra spaces
around the colon.

**`pre-push`** re-checks everything that's about to leave your machine, so
commits that skipped `commit-msg` are still caught: `--no-verify`, `git
commit-tree`, cherry-picks, merges, rebases, commits made elsewhere, annotated
tag messages and taggers, and `git notes`. AI authorship notes refs
(`refs/notes/ai`, `refs/notes/ai-attribution`, used by git-ai and Qwen Code) are
refused outright.

It doesn't block ordinary mentions: "Fix Claude API client", "Bump openai to
1.3", "Add Copilot keybinding", "Fix cursor position", a human co-author named
Devin, or an author named Ai all go through.

## Tests

```sh
sh tests/run.sh
```

Runs every case above in throwaway repositories with an isolated `HOME`.

## Limits

- `git push --no-verify` skips hooks entirely. Nothing client-side can prevent
  that; it has to be deliberate.
- Repositories that set their own `core.hooksPath` (husky, lefthook, …) don't use
  the global hooks. Copy `hooks/` into their hooks directory or call them from
  there.
- It doesn't rewrite history that already has attribution.
  `git filter-branch --msg-filter` or `git filter-repo` can.
- Contributing to someone else's project? Follow its rules. Some projects ask for
  AI-assisted changes to be disclosed. This is for your own repositories.

## Turning it off at the source

Worth doing as well, so the hooks rarely have to fire:

| Tool | Setting |
| --- | --- |
| Claude Code | `"attribution": {"commit": "", "pr": ""}` in `~/.claude/settings.json` |
| Codex CLI | `commit_attribution = ""` in `~/.codex/config.toml` |
| Copilot (VS Code) | `"git.addAICoAuthor": "off"` |
| Cursor | Settings → Agents → Attribution |
| Aider | `--no-attribute-author --no-attribute-committer --no-attribute-co-authored-by` |
| Amp | `amp.git.commit.ampThread.enabled: false`, `amp.git.commit.coauthor.enabled: false` |
| Crush | `attribution-trailer-style: none`, `attribution-generated-with: false` |
| Qwen Code | `general.gitCoAuthor.commit: false`, `general.gitCoAuthor.pr: false` |
| Factory Droid | `includeCoAuthoredByDroid: false` |

Hosted agents (Copilot coding agent, Cursor background agents, Jules, Devin,
Lovable, Replit) commit on their own servers as bot accounts, so these hooks only
see their commits when you pull them and push again.

## License

MIT
