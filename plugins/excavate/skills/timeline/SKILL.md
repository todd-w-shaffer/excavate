---
name: timeline
description: Repo-level chronology — where the work has been happening, who's contributing, themes, dormant areas, doc activity. Use when the user types /timeline, says "catch me up on this repo", "what's been happening lately", "where's the team focused", "who's been working on what", "give me a tour of recent work", or is onboarding to an unfamiliar codebase at the repo level.
---

# Timeline

The user wants a sense of where the work is happening in this repo, not what any one file does. Your job is to dispatch the `excavate:timeline-collector` agent to mine the repo for structured findings, then synthesize those findings into a one-page brief.

The agent does the noisy work (git log + file aggregation + author tallies in a clean subagent context). You do the judgment work (which commits are real themes vs. mechanical, what dormancy means here, what the velocity says). The agent returns facts; you write the story.

This is the same shape as `/excavate` — agent collects, skill synthesizes — at a different zoom level (repo, not file).

## Argument

`${ARGUMENTS}` — optional time window. Accepted presets:

- `30d` — last 30 days
- `90d` — last 90 days (**default** when no argument given)
- `6mo` — last 6 months
- `1y` — last 1 year
- `all` — all history

Anything else: warn the user ("unknown window `<arg>` — falling back to `90d`") and proceed with `90d`.

## Window translation

The skill resolves the user-facing window into a git-ready form **before** dispatching. The agent's mining commands use the git form directly inside `--since=<value>`.

| User arg | Display form | Git form (passed to agent) |
|----------|--------------|----------------------------|
| `30d`    | `30 days`    | `30.days.ago`              |
| `90d`    | `90 days`    | `90.days.ago`              |
| `6mo`    | `6 months`   | `6.months.ago`             |
| `1y`     | `1 year`     | `1.year.ago`               |
| `all`    | `all history`| *(empty string — agent omits `--since`)* |

## Dispatch

First, resolve the repo root with `git rev-parse --show-toplevel` from the cwd. If that fails (not a git repo), tell the user plainly and stop — no agent dispatch.

Then use the `Agent` tool with `subagent_type: "excavate:timeline-collector"` and this prompt:

```
Collect timeline findings for this repo.

Repo root: <output of `git -C "$(pwd)" rev-parse --show-toplevel`>
Working directory: <pwd>
Window (display): <e.g., "90 days">
Window (git): <e.g., "90.days.ago", or empty when window=all>

Return structured findings using the section headers in your protocol.
Do not write a narrative brief — that's my job.
```

The agent returns findings as markdown sections (`## resolved_window`, `## activity_by_directory`, `## active_contributors`, `## significant_commits`, `## dormant_areas`, `## doc_evolution`, `## investigation_notes`). Read its full output before synthesizing.

## Synthesize

Take the agent's findings and write the brief below as your assistant message. This is the deliverable the user sees. Apply judgment — the agent gave you raw material; you pick what's load-bearing.

Specifically:

- **Where the work happened** — from `activity_by_directory`. Top 3–6 directories. A simple ASCII bar (proportional to commit count) is fine; or just `<dir> N commits (M authors)` lines.
- **Themes** — pick 2–4 from `significant_commits`. Not all 8 candidates are real themes; filter out mechanical commits (renames, version bumps, dependency updates). Group by month or by topic. Each entry: month/topic, one-line description, key SHAs.
- **Active contributors** — from `active_contributors`. Top 3–5 with their focus area.
- **Stable / dormant** — from `dormant_areas`. 2–4 entries. Frame each as "settled mature code" or "potentially abandoned" — if you can't tell, say so in Open questions rather than guess.
- **Doc activity** — from `doc_evolution`. One sentence: `<N> doc updates this window` or `Docs haven't moved in <window>`.
- **Open questions** — from `investigation_notes`, gaps in the data, anything the agent flagged as unavailable. Honest, short.

If `dormant_areas` returns `(unavailable: window=all)`, the Stable/dormant section should say "Not computed (window=all — try `/timeline 90d` for dormancy signal)" rather than fabricate entries.

If `activity_by_directory` returns `(none — no commits in window)`, skip the full brief and reply with a single short paragraph: "No commits in the last `<window>`. Try a wider window (e.g., `/timeline all` or `/timeline 1y`)."

## Output format

Markdown, ≤ one page. Cite SHAs inline so the user can drill in via `/excavate <sha>`. Your assistant message is the brief:

```markdown
# Timeline: <repo-name> — <window>

**History depth in window:** N commits, M authors

## Where the work happened
<dir>  ████████ N commits (M authors)
<dir>  █████    N commits (M authors)
<dir>  ██       N commits (M authors)
(3–6 lines)

## Themes
- **<month or topic>** — one-line description (key SHAs: `abc123`, `def456`)
- **<month or topic>** — one-line description (key SHAs: `…`)
(2–4 themes)

## Active contributors
- **<author>** (<%>) — focus: `<dir1>`, `<dir2>`
(top 3–5)

## Stable / dormant
- `<dir>` — last touched <date> (settled / potentially abandoned)
(2–4 entries; or "Not computed (window=all)")

## Doc activity
<one sentence>

## Open questions
<honest gaps>
```

## Discipline

- **Don't invent themes.** A list of small commits isn't a theme. If you can't name a real direction in 2–3 themes, write fewer themes and say so in Open questions.
- **Cite SHAs.** Every theme entry references at least one SHA. The user uses these to drill in with `/excavate <sha>`.
- **Velocity narrative is one phrase.** "Steady cadence" or "heavy in March" — not a paragraph.
- **Be brutal about brevity.** This is a brief, not an audit. Load-bearing data points only.
- **Trust the agent's findings.** Don't re-run git commands the agent already ran. If the agent's findings are insufficient, note that in Open questions and move on.
- **Don't editorialize about code or team.** No "the team is shipping fast" or "this is messy." Report what's there.
