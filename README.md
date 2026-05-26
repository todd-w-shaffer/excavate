# excavate

Code archaeology for Claude Code — reconstructs the *why* behind a file, symbol, or commit. Pairs with LSP plugins (gopls-lsp, ts-lsp, etc.) to add a historical dimension to symbol navigation.

## What it does

Language servers tell you *what* the code is — where a symbol is defined, who calls it, what its type is. They don't tell you *why* it exists in this shape. Excavate fills that gap.

Type `/excavate <path>` (or a symbol, or a commit SHA) and you get a one-page provenance report: when this came into the codebase and on what stated rationale, the inflection points that bent its shape, what's been changing lately, and what history *can't* tell you. Every claim cites a SHA so you can verify.

It also installs a `PostToolUse` hook on the `LSP` tool. So when the agent uses any LSP plugin to resolve a definition or find references, excavate quietly attaches a 4-line git digest to the LSP response. The agent sees both the *what* and a head start on the *why* — without an extra tool round-trip.

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

Three pieces:

| Piece | What it does |
|------|-----|
| `/excavate` skill | The user-facing entry point. Runs the archaeology protocol inline — `git log --follow -p`, `git blame -w -C -C`, CLAUDE.md/README evolution, opportunistic `gh` — and writes the report as the assistant's response. Parses path / symbol / SHA / PR URL arguments. |
| `archaeologist` agent | The same protocol packaged as a subagent. Available for explicit dispatch (`Agent` tool with `subagent_type: "excavate:archaeologist"`) when you want subagent isolation. The `/excavate` slash command does not route through it. |
| `PostToolUse` hook on `LSP` | Pure-bash digest. When LSP returns a location, attaches the file's commit count, origin commit, and last 3 commits. No jq, no Python. |

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
  example.md           # a full report from a real run
```

## What I'd do with more time

- Add a `--diff <sha>` mode to walk multiple file histories in concert (useful for excavating a refactor that touched many files).
- Cache LSP→provenance lookups within a session so the hook doesn't re-run on repeated queries against the same file.
- A second skill `/timeline <since>` that produces a repo-level chronology — what shipped when, what landed before/after a given commit — for the "I joined two months ago, catch me up" case.

## License

MIT
