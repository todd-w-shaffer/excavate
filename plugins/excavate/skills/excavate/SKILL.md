---
name: excavate
description: Code archaeology — reconstruct the why behind a file, symbol, commit, or PR by reading git history, commit bodies, CLAUDE.md/README evolution, and (opportunistically) GitHub PRs and issues. Use when the user types /excavate, says "why does this exist", "what was the original intent", "give me the history of this file", "explain this code's history", or is onboarding to an unfamiliar area of a codebase.
---

# Excavate

The user wants the *why* behind some code, not the *what*. Your job is to dispatch the `excavate:archaeologist` agent to mine the repo for structured findings, then synthesize those findings into a narrative provenance report.

The agent does the noisy work (50+ git/blame/grep calls in a clean subagent context). You do the judgment work (which inflections are real, what the velocity says, what's missing). The agent returns facts; you write the story.

## Argument

`${ARGUMENTS}` — one of:

- A **file path** (absolute or relative to cwd): `scripts/gate.sh`, `src/auth/middleware.ts`
- A **symbol name**: `compute_cap`, `AuthMiddleware`, `useAuth` — the agent resolves via LSP
- A **commit SHA** (7+ chars): `7a4c1f0`, `abc123def`
- A **GitHub PR URL**: `https://github.com/owner/repo/pull/42`
- **Empty** — ask the user what they want excavated; offer the file they're currently looking at or recently edited as a default

If the argument is ambiguous, make a reasonable guess and state your assumption in the final report.

## Dispatch

Use the `Agent` tool with `subagent_type: "excavate:archaeologist"` and this prompt:

```
Collect archaeological findings for: ${ARGUMENTS}

Repo root: <output of `git -C "$(pwd)" rev-parse --show-toplevel`>
Working directory: <pwd>

Return structured findings using the section headers in your protocol. Do not write a narrative report — that's my job.
```

The agent returns findings as markdown sections (`## resolved_target`, `## origin_commit`, `## inflection_candidates`, etc.). Read its full output before synthesizing.

## Synthesize

Take the agent's findings and write the narrative report below as your assistant message. This is the deliverable the user sees. Apply judgment — the agent gave you raw material; you pick what's load-bearing.

Specifically:

- **Origin** — from `origin_commit`. Quote the body's stated rationale. If absent or terse, say so plainly.
- **Major decisions** — from `inflection_candidates`. Not all candidates are real inflections; pick 2–5 that actually bent the file's shape. Filter out routine refactors or rename-only commits. Each gets a SHA + date + one-sentence "why it mattered."
- **Recent activity** — from `recent_commits` and `history_depth`. What's the velocity? Has it gone dormant? Is this an active area?
- **Related code** — from `related_files`. Skip the section if the agent returned nothing useful.
- **Open questions** — from `investigation_notes`, gaps in commit bodies, and anything the agent flagged as unavailable. Be honest. A short, accurate "open questions" beats a long fabricated one.

If `gh_context` returned PR data, fold the PR summaries into Major decisions or Origin as appropriate. If `gh_context` was unavailable, mention that in Open questions (one line: "No GitHub remote / gh auth — PR context unavailable").

## Output format

Markdown, ≤ one page. Cite SHAs inline. Your assistant message is the report:

```markdown
# Provenance: <target>

**Scope:** <file | symbol | commit | PR>  •  **Repo:** <name>  •  **History depth:** N commits, M authors

## Origin
One paragraph. When introduced, by whom, in what commit (SHA), with the stated rationale from the commit body. If the rationale is terse, say so.

## Major decisions
The inflection points. Each as: `abc123 — short description (date)`, followed by one sentence of why it mattered. If there are no clear inflections, say "No major pivots — file has had only mechanical changes since origin."

## Recent activity
Last 2–4 changes summarized. Velocity. Active or stable?

## Related code
Bulleted. Tests, sibling files, direct callers — with file:line. Skip if nothing useful.

## Open questions
What history *cannot* tell you. Be honest.
```

## Discipline

- **Don't invent intent.** If a commit body says "fix bug," quote it and note the terseness. No speculation.
- **Cite SHAs.** Every claim about a decision references its SHA.
- **Be brutal about brevity.** Load-bearing facts only.
- **Trust the agent's findings.** Don't re-run git commands the agent already ran. If the agent's findings are insufficient, note that in Open questions and move on.
- **Don't editorialize about code quality.** This is archaeology, not code review.
