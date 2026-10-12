# no-ai-attribution

Git hooks that stop AI coding tools from crediting themselves in your commits.

Claude Code, Codex, Copilot, Cursor, Aider, Amp and others add `Co-authored-by:`
trailers, "Generated with …" footers, session links, bot authors or attribution
notes to commits. Each has its own setting to turn that off, and agents don't
always respect it. These hooks enforce it once, for every tool and every repository.
Plain POSIX `sh`, no dependencies.

## Install

```sh
git clone https://github.com/La5u/no-ai-attribution
cd no-ai-attribution
./install.sh
```

This sets the global `core.hooksPath`. Existing per-repo hooks in `.git/hooks/`
still run. Uninstall with `./uninstall.sh`.

| Flag | Effect |
| --- | --- |
| `--strict` | Reject every co-author-style trailer that isn't one of your addresses |
| `--check-identity` | Refuse to push commits authored or committed by anyone but you |
| `--allow EMAIL` | Another address of yours (repeatable). `user.email` is always allowed |
| `--repo [path]` | Install into one repository instead of globally |
| `--force` | Replace an existing global `core.hooksPath` |

## What it does

- **`commit-msg`** rejects AI credit trailers, "Generated with …" lines, robot
  emoji footers, tool session links, AI or bot emails, and AI author/committer
  identities. Unicode and whitespace tricks don't get around it.
- **`pre-push`** checks the same things again for commits that skipped
  `commit-msg` (`--no-verify`, rebases, commits made elsewhere), plus tags and
  `git notes`. AI attribution notes refs (`refs/notes/ai*`) are refused.

Ordinary mentions like "Fix Claude API client" or "Fix cursor position" are fine.
Run `sh tests/run.sh` to see every case.

## Cleaning existing history

The hooks only stop new attribution. To remove it from a repository's past:

```sh
./scrub-history.sh path/to/repo                   # dry run: show what would change
./scrub-history.sh --apply path/to/repo           # strip attribution lines, delete AI notes refs
./scrub-history.sh --apply --authors path/to/repo # also replace AI/bot authors with you
```

This rewrites every local branch and tag, so commit hashes change. It never
pushes: run `git push --force-with-lease --all` yourself, and expect anyone with
a clone to need to re-clone. Originals stay under `refs/original/` until you
delete them.

## Limits

- `git push --no-verify` skips all hooks.
- Repositories with their own `core.hooksPath` (husky, lefthook) need the hooks copied in.
