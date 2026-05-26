# /savor enhancement — historical reviewer for spec audits

Add a backward-looking reviewer to savor's audit pass. Same shape as
the existing systems / integration / contextual personas — runs as a
fresh-context Agent, returns numbered findings, classifies into "fix
in spec" / "code comment" / "discard" via savor's existing Phase 3.

## Problem

Savor's current reviewers are all *forward-looking*:

- Systems asks "will this compile / run / hold under concurrency?"
- Integration asks "will this break callers / conventions / tests?"
- Contextual personas ask "does my specialty's failure mode apply here?"

None of them ask the *backward-looking* question: **have we been here
before?** They can't — they don't read `git log` by default, and even
when they do, mining inflection candidates is its own discipline.

Four concrete failure cases this gap allows through to implementation:

- Spec re-proposes an approach a prior commit explicitly tried and
  reverted (**re-litigation**).
- Spec's premise contradicts the origin commit's still-valid stated
  rationale (**eroded rationale**).
- Spec touches a file that's been dormant for months — the team has
  drifted from the assumptions baked into the commit history
  (**dormant-area risk**).
- Spec touches a file where every prior change re-introduces the same
  class of bug (**re-introduction pattern**).

These four are real, citation-bearing (SHAs), and bounded. They fit
savor's existing "tighten, don't grow" mandate without inventing new
shape.

## Architecture (locked)

- **Reviewer:** a contextual persona triggered by Phase 2b when the
  touchlist has files-with-history. Dispatched in parallel with other
  reviewers as a fresh-context Agent. Same brief shape as systems /
  integration: role sentence, spec path, files to read, checklist,
  400-word cap, "tighten only" rule, numbered findings.
- **No new agent file.** The reviewer's prompt lives inline in
  savor's `SKILL.md`, matching how systems / integration are already
  structured. The mining-step wisdom from `excavate:archaeologist`
  ports into the prompt; savor stays self-contained (no plugin
  dependency).
- **Findings, not a report.** The reviewer returns only findings,
  classified into the four categories above. If you want the full
  provenance narrative, run `/excavate <file>` separately. The
  reviewer's question is "does this spec repeat a known mistake?" —
  not "what is this file's biography?"

**Why this shape and not others:**

- Don't depend on the `excavate` plugin at runtime. The archaeology
  wisdom transfers via prompt-engineering, not subagent dispatch.
  Savor stays portable; the excavate plugin's fate can be decided
  separately (see Open question below).
- Don't make the reviewer produce a report — that duplicates
  `/excavate` and forces the synthesis phase to re-filter narrative
  text into findings. Findings-only output drops straight into Phase
  3's classification machinery.

## File touchlist

Modify:

- `~/.claude/skills/savor/SKILL.md` — three changes: (a) add the
  historical reviewer row to Phase 2b's persona-selection guide;
  (b) embed the reviewer's brief inline (parallel to the systems /
  integration briefs already in the file); (c) update Phase 4's
  summary template to include the new reviewer in the Contextual
  list when it runs.

That's it. One file, three localized edits.

Delete (after merge):

- This spec file (move it to git history).

## The historical reviewer's brief

**Role:** "You are a code archaeologist reviewing a spec for repetition
of known mistakes. Read the proposed change against the history of
each touched file and flag four specific patterns."

**Mining (per file in the spec's touchlist that exists at HEAD with
>10 commits of history):**

1. **Origin commit + body.**

   ```bash
   git -C <repo> log --follow --reverse --no-merges -1 \
     --pretty=tformat:'%h%x1f%ad%x1f%an%x1f%s%n%b%n---END---' \
     --date=short -- <file>
   ```

   Read the rationale. If the body is terse ("initial commit", "add
   file"), note that — eroded-rationale findings need a quotable
   stated reason to land.

2. **Inflection candidates (top 3 per file).**

   ```bash
   git -C <repo> log --follow --no-merges \
     --pretty=tformat:'%h%x1f%ad%x1f%s%n%b%n---END---' \
     --date=short -- <file>
   ```

   Select commits whose subject contains `refactor|migrate|rewrite|
   rip out|flip|introduce|deprecate|split|merge` OR whose body is
   >5 lines. Cap at 3 per file. The reviewer doesn't need 8 — it
   needs the 3 strongest signals.

3. **Recent-activity sample (count-based, cadence-adaptive).**

   ```bash
   git -C <repo> log --max-count=10 --follow --no-merges \
     --pretty=tformat:'%h%x1f%ad%x1f%s' --date=short -- <file>
   ```

   The last 10 commits to this file, whatever timeframe they span.
   On a file you've been touching daily, this might cover two weeks;
   on a file you haven't touched in months, it might span a year.
   Either way you get a comparable amount of recent context, not a
   time-bounded slice that's empty on sleepy files and floods on
   busy ones.

   **Use this for:** judging whether the spec's premise matches what
   people have actually been doing in the file lately, and as the
   cross-reference set for re-introduction-pattern findings.

4. **Dormancy check (time-absolute).**

   ```bash
   git -C <repo> log -1 --since=90.days.ago --no-merges -- <file>
   ```

   Empty result → no commits to this file in the last 90 days → file
   is dormant. Note for dormant-area-risk findings. This is a separate
   question from the recent-activity sample: cadence adapts, but "is
   anyone still paying attention?" is genuinely a calendar question.

5. **Symbol resolution (opportunistic).** If the spec names symbols
   (`AuthMiddleware`, `computeCap`) rather than paths, attempt LSP
   resolution to map symbol → file:line before mining. If LSP is
   unavailable (no plugin installed, or the call fails), fall back
   to grep for the symbol name across the touchlist files. State
   which path was taken in `investigation_notes` — synthesis needs
   to know whether file references are precise or fuzzy.

**Conventions across all mining commands** (port from
`excavate:archaeologist`):

- Use `tformat:` (not `format:`) so the last record ends with a newline.
- Use `%x1f` (ASCII unit separator) as the field delimiter so commit
  messages containing pipes don't corrupt parsing.
- Use `--no-merges` for signal.
- Use `--follow` to track renames.

**Findings categories (each finding gets exactly one tag):**

- **re-litigation** — the spec re-proposes an approach that a prior
  inflection commit explicitly tried and reverted. Cite both SHAs
  (the prior attempt + the revert if visible).
- **eroded rationale** — the origin commit's stated reason still
  holds, and the spec breaks the constraint motivating the code.
  Quote the origin's body.
- **dormant-area risk** — the file has no commits in the last 90
  days (dormancy check returned empty). The spec touches code the
  team isn't paying attention to; downstream consumers may have
  drifted from commit-history assumptions.
- **re-introduction pattern** — three or more prior commits to this
  file each re-introduced the same class of bug or undid the same
  change. Cite the SHAs.

**Output format:**

```
N. [<category-tag>] <one-line summary>
   File: <path>
   SHAs: <abc123>, <def456>
   Detail: <2–3 sentences of specifics, with quoted bodies if relevant>
```

End with:

```
investigation_notes:
<files with no history mined and why; LSP-vs-grep path taken; any
terse-origin-body files where rationale judgment was impossible>
```

**Discipline (mandatory in the brief):**

- **Tighten only.** No scope changes. No "this file has churned a
  lot, consider redesigning" — that's scope growth and out of bounds.
- **Cite SHAs.** Every finding references at least one commit.
- **State gaps.** If a file has no parseable inflections, if LSP
  failed, if commit bodies are too terse to judge — say so in
  `investigation_notes`. Don't pad with weak findings.
- **400-word cap** on the full reviewer output.

## Trigger rule

Phase 2b adds the historical reviewer when:

- The spec's touchlist contains at least one file that exists at HEAD
  with >10 commits of history.

Skip when:

- All touchlist files are net-new (greenfield spec).
- All touchlist files have ≤10 commits (history too thin to surface
  the four patterns meaningfully — the reviewer needs enough commits
  for both the 10-commit recent-activity sample and the inflection
  scan to do real work).
- The spec is documentation-only (every touchlist entry is `*.md`).

Announce the pick during Phase 2b the same way other personas are
announced: *"This spec touches files with deep history, so I'm adding
a **historical reviewer**."*

## How it slots into savor's existing phases

Minimal changes:

- **Phase 2b:** add the historical reviewer to the persona-selection
  guide (a new row in the table), and to the persona-launch logic.
- **Phase 3 (synthesize):** the existing signal filter / classify /
  apply-to-spec flow handles historical findings without modification.
  Each finding is already shaped to be classified as "fix in spec" /
  "code comment" / "discard."
- **Phase 4 (summary):** add the historical reviewer to the
  "Contextual" list when it ran, just like other personas.

Everything else stays the same.

## LSP composability

The reviewer's tool surface includes `LSP` as an *opportunistic*
enhancer — the same pattern `excavate:archaeologist` uses for `gh`:

- If the spec names symbols rather than paths, try LSP first to
  resolve symbol → file:line.
- If LSP is unavailable (no plugin installed, or call fails), fall
  back to grep for the symbol name in touchlist files.
- Either way, the reviewer proceeds — LSP is a tightening, not a
  requirement.

State which path was taken in `investigation_notes` so the synthesis
phase knows whether to trust precise file references or treat them
as fuzzy.

## What to port from `excavate:archaeologist`

The reviewer's brief embeds (not depends on) these conventions:

**Port:**
- `%x1f` field delimiter for `git log --pretty=format` calls.
- `tformat:` (not `format:`) so the last record ends with a newline.
- `--no-merges --follow` for signal and rename-tracking.
- Inflection heuristics — the keyword list, the body-length
  threshold. Tune the candidate count down: 3 per file, not 8.
- Empty-section discipline — `(none)` placeholder if a category has
  zero findings; never silently omit.

**Don't port:**
- The full report shape. The reviewer is findings, not narrative.
- The `gh`-PR opportunistic lookup. Out of scope for spec audit.
- The blame-author breakdown. Not relevant to the four findings
  categories.
- The doc-evolution scan. Already covered by savor's integration
  reviewer reading CLAUDE.md.

## Out of scope

- **`refactor-archaeologist`** — multi-file historical view as a
  standalone deliverable. Savor's touchlist scoping is already the
  right composition; no separate command needed.
- **A full provenance report inside savor.** That's `/excavate`.
  Savor's reviewer asks one focused question, not "tell me everything
  about these files."
- **The LSP hook's fate.** The hook (currently in the `excavate`
  plugin) is orthogonal — it enriches ambient LSP calls outside of
  savor. Savor's reviewer calls LSP directly when it needs to and
  doesn't depend on the hook firing. Decide the hook's home (delete,
  keep in its own thin plugin, fold elsewhere) as a separate change.
- **Promoting historical reviewer to structural.** Ship as contextual
  first. After a few weeks of seeing whether it earns its keep
  universally, decide whether to promote.

## Post-implementation cleanup (decided)

The `excavate` plugin sunsets once savor's historical reviewer is
merged and verified. Full abandon — no maintaining two surfaces.

**Sequence:**

1. Ship the savor enhancement per this spec. Savor stays self-
   contained — the reviewer's brief embeds the archaeology wisdom
   directly, with no runtime dependency on the excavate plugin.
2. Run /savor against a real spec touching files with deep history.
   Verify the historical reviewer earns its keep (catches a
   re-litigation, an eroded rationale, or honestly reports nothing
   notable when there's nothing to flag).
3. Once verified, retire the excavate plugin as a separate change.

**What gets deleted in the retirement change:**

- `plugins/excavate/` (entire directory — agents, skills, hooks,
  scripts, manifest).
- `.claude-plugin/marketplace.json` (the only plugin it lists is
  excavate; the self-marketplace becomes dead weight).
- README.md, docs/build-your-own-plugin.md, docs/example.md —
  rewrite or remove. The repo either gets renamed/repurposed to
  reflect a new center of gravity or archived.

**What's lost in the retirement:**

- Standalone `/excavate <path|symbol|sha>` — the on-demand provenance
  report. Replaceable by running savor against a single-file "audit
  this proposed change" spec, but with friction.
- Standalone `/timeline [window]` — the repo-level chronology brief.
  The onboarding-to-a-new-codebase persona loses its dedicated tool;
  the same data can be hand-rolled with `git log` queries.
- The `PostToolUse` LSP hook — the ambient git-history sidecar
  attached to every LSP tool response. This is the one piece that
  *doesn't* duplicate anything savor will do. Savor's reviewer calls
  LSP directly when needed; the hook served navigation throughout
  the session, not just at audit time.

The LSP hook is the only piece worth a second thought before
retirement. If you find yourself wanting "history attached to every
goto-definition" outside of savor's audit moments, the hook is the
artifact to preserve (in its own ~5-file thin plugin). If you don't
actually trigger LSP tool calls often enough to notice the hook
firing, retire it with the rest.

Make the LSP-hook call at retirement time, not now — by then you'll
have weeks of real usage to inform the decision.

## Lessons that must not be re-derived

(See excavate plugin git log + plugin-authoring memory for full
context. These transfer from the excavate work into savor.)

- **Output surfacing — agent-collects, skill-synthesizes.** Savor's
  parent assistant owns the Phase 3 synthesis. The reviewer returns
  findings; savor's parent merges and applies spec edits. Don't ask
  the parent to "echo" anything from the reviewer. (Burned three
  iterations of /excavate to learn this.)
- **No new agent file required.** Savor's existing reviewers are
  prompts embedded in the skill, not separate `agents/*.md` files.
  The historical reviewer follows the same pattern. Don't introduce
  a parallel structure.
- **Don't grow scope inside the reviewer brief.** The 400-word cap
  and "tighten only" rule are load-bearing — without them the
  reviewer will produce a meandering historical narrative instead
  of bounded findings.
- **Mining-step conventions are fragile.** Use `tformat:` (not
  `format:`) for trailing newlines. Use `%x1f` (not `|`) as field
  delimiter — pipes inside commit messages corrupt naive parsing.
  Use `--no-merges --follow` for signal and rename-tracking. These
  small details cost real debugging time when missed; embed them in
  the brief rather than relying on the agent to re-derive.

## Acceptance

- Savor runs in a repo with non-greenfield history and includes a
  historical reviewer in Phase 2b when the touchlist has files-with-
  history.
- Reviewer returns findings tagged with one of the four categories,
  citing SHAs.
- Phase 3 classifies historical findings into "fix in spec" / "code
  comment" / "discard" using the existing synthesis logic — no new
  Phase 3 rules needed.
- Phase 4 summary reports the historical reviewer in the Contextual
  list with its finding count.
- Reviewer respects 400-word cap.
- Spec edits derived from historical findings land inline in Phase
  3, same flow as other reviewer findings.
- LSP opportunistic-use works: spec naming a symbol triggers LSP
  resolution if a plugin is installed; falls back to grep otherwise
  with a note in `investigation_notes`.
- Greenfield specs do NOT trigger the reviewer (verified by running
  /savor on a spec whose touchlist is all "Create:" entries).
- Demo target: run /savor on a spec touching a file with >10 commits
  of real history (timeline.spec.md's git history qualifies) and
  verify the reviewer surfaces something useful — or honestly reports
  nothing notable in `investigation_notes`.

## Cost estimate

60–90 minutes by Claude. Most of the time is writing the embedded
brief carefully (it's the load-bearing artifact) and threading the
small additions through Phase 2b / 4. The architectural shape is
locked, the integration is minimal, and the mining-step wisdom ports
directly from `excavate:archaeologist`.
