# /timeline — repo-level chronology for the just-joined engineer

Add a second skill + agent to the excavate plugin. Same agent-collects /
skill-synthesizes pattern as `/excavate`. Different question, different
zoom level.

## Problem

`/excavate` answers "why does this *file* exist?" — file-scoped depth.
`/timeline` answers "what's been happening in this *repo*?" — repo-scoped
breadth.

**Target persona:** senior engineer in week 1–4 at a new company / new
team, trying to build a mental model of where the work is happening,
who's been doing what, and what's stable vs. churning. Also useful for
returning to your own project after months away.

**The Loom benefit:** demonstrates the same plugin pattern composing to
two zoom levels (file → repo). The build-your-own guide becomes richer:
"here's how the pattern scales."

## Architecture (locked — do not redesign)

Same shape as `/excavate` (which lives at v0.1.5). The decision history
behind this is in the excavate plugin's git log — read commits `977c3f5`
through `a94d82f` if you need it.

- **Agent (`timeline-collector`):** collects raw findings in a clean
  subagent context. Returns structured markdown sections. No prose, no
  narrative.
- **Skill (`/timeline`):** dispatches to `excavate:timeline-collector`,
  then synthesizes the brief as its assistant message. Parent applies
  judgment on themes, dormancy, signal vs. noise.

**Why this shape and not others:**

- Don't have the agent produce the full prose brief and ask the parent
  to echo. The parent skips the redundant echo and the deliverable
  hides behind a `Done` block. (Killed v0.1.3 of /excavate.)
- Don't inline the work into the skill. You lose subagent isolation
  and the parent transcript fills with 50+ git tool calls. (Killed
  v0.1.4 of /excavate.)
- Agent-collects / skill-synthesizes is the working pattern. The parent's
  curated message IS the deliverable, so it surfaces naturally.

## File touchlist

Create:

- `plugins/excavate/agents/timeline-collector.md` — collector agent
- `plugins/excavate/skills/timeline/SKILL.md` — skill body

Modify:

- `plugins/excavate/.claude-plugin/plugin.json` — bump to `0.2.0` (minor
  version because new feature)
- `README.md` — add `/timeline` to the "How it works" table; add a
  `/timeline` example invocation alongside the `/excavate` examples
- `docs/build-your-own-plugin.md` — one-line note that `/timeline` is
  the second example of the agent-collects / skill-synthesizes pattern

Delete (after merge):

- This spec file (move it to git history)

## Agent: `timeline-collector`

**Argument:** an optional time window (`90d`, `30d`, `1y`, `all`). Default `90d`.

**Mining steps:**

1. **Activity by directory.** `git log --since=<window> --name-only --pretty=format:'COMMIT|%h|%ad|%an' --date=short` then aggregate file paths up to first directory level. Output: directory → commit count, author count.

2. **Top-touched files.** `git log --since=<window> --pretty=format:'' --name-only | sort | uniq -c | sort -rn | head -10`. Output: file path → commit count.

3. **Contributor map.** `git log --since=<window> --pretty=format:'%an'` → frequency. For top 5 contributors, find their dominant directories (cross-reference with step 1's per-commit-author data).

4. **Significant commits.** Scan `git log --since=<window> --pretty=format:'%h|%ad|%an|%s|%b'` for: subjects with keywords (refactor, migrate, introduce, ship, rip out, rewrite, flip), commit bodies >5 lines, or commits touching >10 files. Up to 8.

5. **Dormant areas.** `git log --before=<window-ago> --pretty=format:'%h' -- <dir>` to find directories last touched before the window. Top 5 dormant dirs.

6. **Doc evolution.** Commits in window touching `CLAUDE.md`, `README.md`, `docs/`. Just SHA + date + subject.

7. **Theme inference (optional, simple).** Bucket significant commits into 2–4 themes by month or by shared keyword cluster. Don't over-engineer — terse "Feb: auth refactor" beats elaborate clustering.

**Output format:**

```markdown
## window
<resolved time window, e.g., "since 2026-02-26 (90 days)">

## activity_by_directory
<dir> | <N commits> | <M authors>
<dir> | <N commits> | <M authors>
(top 5–10)

## top_files
<path> | <N commits>
(top 10)

## contributors
<author> (<percentage>%) — <dominant areas>
(top 5)

## significant_commits
<sha> | <date> | <subject>
  <body first paragraph>
(up to 8; caller filters down)

## dormant_areas
<dir> — last touched <date>
(top 5)

## doc_evolution
<sha> | <date> | <file> | <subject>

## investigation_notes
<gaps, ambiguities, anything missing>
```

**Discipline:** see `agents/archaeologist.md` for the rules — no narrative,
no editorializing, state gaps. Same constraints apply here.

## Skill: `/timeline`

**Argument:** `${ARGUMENTS}` — optional time window. If empty, default to
`90d`. Accept `30d`, `90d`, `6mo`, `1y`, `all`.

**Dispatch:** `Agent` with `subagent_type: "excavate:timeline-collector"`,
prompt includes repo root, working dir, and the resolved window.

**Synthesize:** read the agent's findings, write the brief as the
assistant's response.

**Output format:**

```markdown
# Timeline: <repo> — <window>

## Where the work happened
<bar chart in ASCII or just `<dir> N commits (M authors)` lines>
<3–6 lines max>

## Themes
<month> — <one-line theme + key SHAs>
<2–4 themes>

## Active contributors
<author> (<%>) — <focus area>
<top 3–5>

## Stable / dormant
<dir> — last touched <date>
<2–4 entries; signal "this is settled code" or "potentially abandoned">

## Doc activity
<one sentence: "<N> doc updates" or "Docs haven't moved in <window>">

## Open questions
<gaps from agent's investigation_notes, anything the data can't answer>
```

**Synthesis rules:**

- Pick 2–4 themes from `significant_commits`, not all 8. Filter mechanical
  commits (renames, version bumps).
- "Dormant" needs a frame: stable mature code vs. abandoned. If you don't
  know, say so in Open questions.
- Velocity narrative: if commits cluster heavily in one month, name it.
  If steady, say "steady cadence."
- Cite SHAs for theme entries so the user can drill in via `/excavate`.

## Out of scope

- **`refactor-archaeologist`** — explicitly deferred. If batch-across-
  files needed, extend `/excavate` arg parser to accept globs in a
  separate change.
- **Cross-repo timeline** — single repo only.
- **GitHub/PR integration in timeline** — agent's `gh` use is in
  `/excavate`. Timeline stays git-only for now; can add later if useful.
- **Window math beyond simple presets** — accept `30d|90d|6mo|1y|all`,
  not arbitrary date ranges.

## Lessons that must not be re-derived

(See excavate plugin git log for full context.)

- **Plugin manifest:** do not declare `agents`/`skills`/`hooks` as
  string directory paths in `plugin.json`. They're auto-discovered. The
  validator rejects `"agents": "./agents/"` outright; the others either
  no-op or load incorrectly. Manifest stays minimal.
- **Subagent dispatch:** `subagent_type` must be plugin-namespaced —
  `"excavate:timeline-collector"`, not `"timeline-collector"`.
- **Output surfacing:** parent assistant must own the deliverable. Don't
  ask it to "echo" the agent's output.
- **Hook composability:** the existing `PostToolUse` on `LSP` hook
  already enriches LSP responses with provenance. `/timeline` won't
  invoke LSP much (it's about commits, not symbols), so the hook
  won't compose with it — and that's fine.

## Acceptance

- `/timeline` runs in any git repo and produces the brief format above.
- `/timeline 30d` accepts the window argument.
- Agent returns findings under ~100 lines for a medium-history repo.
- Skill's brief is ≤ one page.
- Demo target: run on `excavate` itself (you've been actively committing
  for ~8 days — short timeline, useful for sanity check).
- Version bump to `0.2.0` (minor — new feature).
- Commit + ship via `/commit` then `/ship` (explicit, not nested).

## Cost estimate

45–60 minutes by Claude. Most of the time is the agent prompt's mining
steps and the skill's synthesis rubric. The architectural shape is
locked, so no re-deliberation needed.
