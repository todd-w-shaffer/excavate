# excavate

Code archaeology for Claude Code — reconstructs the *why* behind a file, symbol, or commit. Pairs with LSP plugins (gopls-lsp, ts-lsp, etc.) to add a historical dimension to symbol navigation.

## What it does

Language servers tell you *what* the code is — where a symbol is defined, who calls it, what its type is. They don't tell you *why* it exists in this shape. Excavate fills that gap.

Type `/excavate <path>` (or a symbol, or a commit SHA) and you get a one-page provenance report: when this came into the codebase and on what stated rationale, the inflection points that bent its shape, what's been changing lately, and what history *can't* tell you. Every claim cites a SHA so you can verify.

It also installs a `PostToolUse` hook on the `LSP` tool. So when the agent uses any LSP plugin to resolve a definition or find references, excavate quietly attaches a 4-line git digest to the LSP response. The agent sees both the "what" and a head start on the "why" — without an extra tool round-trip.

## For whom

Solo and small-team engineers who keep returning to code they wrote 3+ months ago and want to recover their own past reasoning. Also: senior engineers in their first 30 days at a 5+ year codebase, where the dominant onboarding pain is reconstructing intent.

Works on any git repo. Opportunistically uses `gh` for PR/issue context when the remote is GitHub and you're logged in.

## Quick start

```bash
git clone https://github.com/todd-w-shaffer/excavate.git
cd excavate
claude plugin marketplace add .
claude plugin install excavate@archaeology
```

Restart Claude Code, then in any git repo:

```
/excavate scripts/gate.sh
/excavate compute_cap
/excavate 89e72bf
```

## Example output

Run on a file in [coolant](https://github.com/todd-w-shaffer/coolant):

```
/excavate scripts/gate.sh
```

```markdown
# Provenance: scripts/gate.sh

**Scope:** file  •  **Repo:** coolant  •  **History depth:** 5 commits, 1 author

## Origin
Introduced 2026-04-04 in 8645a86 as a new PreToolUse hook for Claude Code.
Stated goal: "Build an extensible PreToolUse gating system that suppresses
expensive CLI tools during parallel mode." First incarnation was a single
check_gate function pattern-matching commands across five ecosystems...

## Major decisions
- 57404da — Add agent-count-adaptive concurrency capping (2026-04-04). The pivotal
  restructure. Single check_gate split into dual gate_suppress / gate_cap dispatch.
  Introduced the cap formula floor((cores - 2) / active_agents), min 1.
- 89e72bf — Flip gate from auto-suppress to opt-in /coolant (2026-04-08).
  Behavioral inversion. Motivation in the body: "orphaned agents inflate the
  counter permanently" causing "silent build suppression."
- 4e8282e — Swift as seventh process category (2026-04-05). Ecosystem matrix
  extension.

## Recent activity
Dormant since 2026-04-22 (last change was a copy relabel). Repo itself remains
active. Logic is settled.

## Open questions
- Why (cores - 2)? Formula stated without justifying the -2 reserve.
- Why these specific wrappers? List appears fully formed in 8645a86.
- The "echo -n gotcha" mentioned in 57404da's body — failure mode not described.
```

## How it works

Three pieces:

| Piece | What it does |
|------|-----|
| `archaeologist` agent | Runs `git log --follow -p`, `git blame -w -C -C`, scans CLAUDE.md/README evolution, opportunistically calls `gh` for PR/issue context. Synthesizes into the report. |
| `/excavate` skill | Thin invocation layer. Parses the argument (path / symbol / SHA / PR URL) and dispatches to the archaeologist. |
| `PostToolUse` hook on `LSP` | Pure-bash digest script. When LSP returns a location, attaches the file's commit count, author count, origin commit, and last 3 commits. No jq, no Python. |

The hook is the composability story. When you install excavate alongside `gopls-lsp` or another language-server plugin, every LSP query gets enriched with a provenance digest for free — even when you're not running `/excavate` explicitly. The plugin earns its keep without surface area in the way.

## Requirements

- **git** — any reasonably recent version
- **bash 3.2+** — ships with macOS, the hook avoids jq and Python
- **gh** — optional, used opportunistically when a GitHub remote + valid auth are present
- An LSP plugin — optional but recommended (the hook earns its keep when paired with one)

## Project structure

```
.claude-plugin/
  marketplace.json     # self-marketplace for local install
plugins/excavate/      # the plugin
  .claude-plugin/
    plugin.json        # plugin manifest
  agents/
    archaeologist.md   # the agent prompt
  skills/
    excavate/SKILL.md  # the /excavate skill
  hooks/
    hooks.json         # PostToolUse on LSP
  scripts/
    provenance-digest.sh # the hook script
    lib.sh             # shared helpers (JSON escape, repo-root lookup)
docs/
  build-your-own-plugin.md  # one-page guide for peers
```

## What I'd do with more time

- Add a `--diff <sha>` mode to walk multiple file histories simultaneously (useful for excavating a refactor across files).
- Cache LSP→provenance lookups within a session so the hook doesn't re-run on repeated queries against the same file.
- A second skill `/timeline <repo>` that produces a repo-level chronology — what shipped when, what landed before/after a given commit — for "I joined two months ago, catch me up."

## License

MIT
