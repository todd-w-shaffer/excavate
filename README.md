# excavate

Code archaeology for Claude Code — reconstructs the *why* behind a file, symbol, or commit, and the chronology of a repo. Pairs with LSP plugins (gopls-lsp, ts-lsp, etc.) to add a historical dimension to symbol navigation.

## What it does

Language servers tell you *what* the code is — where a symbol is defined, who calls it, what its type is. They don't tell you *why* it exists in this shape, or what's been happening in the repo lately. Excavate fills both gaps with two slash commands at different zoom levels:

- **`/excavate <path>`** (or a symbol, or a commit SHA) — file-scoped depth. One-page provenance report: when this came into the codebase and on what stated rationale, the inflection points that bent its shape, what's been changing lately, and what history *can't* tell you.
- **`/timeline [window]`** — repo-scoped breadth. One-page chronology: where the work has been happening, who's contributing, the themes, what's gone dormant. Useful in your first 30 days at a new team, or returning to your own project after months away.

Both commands cite SHAs so you can drill in with `/excavate <sha>`.

Excavate also installs a `PostToolUse` hook on the `LSP` tool. When the agent uses any LSP plugin to resolve a definition or find references, excavate quietly attaches a 4-line git digest to the LSP response. The agent sees both the *what* and a head start on the *why* — without an extra tool round-trip.

Works on any git repo. Opportunistically uses `gh` for PR/issue context when the remote is GitHub and you're logged in.

## For whom

- Solo and small-team engineers returning to code they wrote 3+ months ago, trying to recover their own past reasoning.
- Senior engineers in their first 30 days at a 5+ year codebase, where reconstructing intent is the dominant onboarding pain.
- Anyone who has ever closed a tab, then reopened it, and asked "wait, why is this here?"

## Quick start

**From the published marketplace:**

```bash
claude plugin marketplace add todd-w-shaffer/marketplace
claude plugin install excavate@todd-w-shaffer
```

**From a fresh clone (for evaluating before publish, or working off a fork):**

```bash
git clone https://github.com/todd-w-shaffer/excavate.git
cd excavate
claude plugin marketplace add .
claude plugin install excavate@archaeology
```

Restart Claude Code, then in any git repo:

```
/excavate src/auth/middleware.ts
/excavate computeCap
/excavate a1b2c3d

/timeline             # last 90 days (default)
/timeline 30d         # last 30 days
/timeline all         # full history
```

## What you'll see

A one-page markdown report. The structure is the same every time:

```markdown
# Provenance: <target>

**Scope:** <file | symbol | commit>  •  **Repo:** <name>  •  **History depth:** N commits, M authors

## Origin
When introduced, by whom, in what commit, with the stated rationale.

## Major decisions
Inflection points — refactors, scope changes, behavioral pivots — each cited by SHA.

## Recent activity
Last few changes. Velocity. Is this code being actively shaped, or stable?

## Related code
Tests, sibling files, direct callers.

## Open questions
What history *cannot* tell you. Undocumented constraints. Ambiguous renames.
```

See [`docs/example.md`](docs/example.md) for a full report from a real run.

## How it works

Five pieces, organized as two agent-collects / skill-synthesizes pairs plus a hook:

| Piece | What it does |
|------|-----|
| `/excavate` skill | The user-facing entry point for file-level archaeology. Parses path / symbol / SHA / PR URL arguments, dispatches to `excavate:archaeologist`, then synthesizes the structured findings into a one-page provenance report as the assistant's response. |
| `archaeologist` agent | The collector for `/excavate`. Mines `git log --follow -p`, `git blame -w -C -C`, CLAUDE.md/README evolution, opportunistic `gh` — and returns structured findings (not prose). The skill writes the story. |
| `/timeline` skill | The user-facing entry point for repo-level chronology. Accepts a window (`30d`, `90d`, `6mo`, `1y`, `all`), translates it to a git-ready form, dispatches to `excavate:timeline-collector`, then synthesizes the brief. |
| `timeline-collector` agent | The collector for `/timeline`. Mines activity-by-directory, top files, contributor breakdown, significant commits, dormant areas, and doc evolution — returns structured findings only. |
| `PostToolUse` hook on `LSP` | Pure-bash digest. When LSP returns a location, attaches the file's commit count, origin commit, and last 3 commits. No jq, no Python. Only composes with symbol-scoped flows (the `archaeologist` agent and any LSP plugin you have installed) — `/timeline` is commit-scoped and doesn't touch LSP, so the hook is silent for it by design. |

Both slash commands use the same shape — **agent collects, skill synthesizes**. The agent does the noisy git mining in a clean subagent context (50+ tool calls collapsed into one `Done` block). The skill does the judgment work (which inflections are real, which commits are themes, what dormancy means) and the synthesis IS the parent's response, so the deliverable surfaces naturally.

The hook is the composability story. Installed alongside `gopls-lsp` or a TypeScript language-server plugin, every LSP query gets enriched with provenance for free — even when you're not running `/excavate` explicitly. The plugin earns its keep without adding surface area in the way.

## Requirements

- **git** — any reasonably recent version
- **bash 3.2+** — ships with macOS; the hook avoids jq and Python deps
- **gh** — optional, used opportunistically when a GitHub remote + valid auth are present
- An LSP plugin — optional but recommended (the hook earns its keep when paired with one)

## Project structure

```
.claude-plugin/
  marketplace.json     # self-marketplace, for installing from a local clone
plugins/excavate/      # the plugin
  .claude-plugin/
    plugin.json        # plugin manifest
  agents/
    archaeologist.md       # collector for /excavate
    timeline-collector.md  # collector for /timeline
  skills/
    excavate/SKILL.md  # the /excavate skill
    timeline/SKILL.md  # the /timeline skill
  hooks/
    hooks.json         # PostToolUse on LSP
  scripts/
    provenance-digest.sh # the hook script
    lib.sh             # shared helpers (JSON escape, repo-root lookup)
docs/
  build-your-own-plugin.md  # one-page guide for peers
  example.md           # a full report from a real run
```

## What I'd do with more time

- Add a `--diff <sha>` mode to walk multiple file histories in concert (useful for excavating a refactor that touched many files).
- Cache LSP→provenance lookups within a session so the hook doesn't re-run on repeated queries against the same file.
- A `refactor-archaeologist` mode that takes a glob and produces a single provenance story across many files — the cross-file complement to `/excavate`'s single-file depth.

## License

MIT
