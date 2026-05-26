---
name: excavate
description: Code archaeology — reconstruct the why behind a file, symbol, commit, or PR by reading git history, commit bodies, CLAUDE.md/README evolution, and (opportunistically) GitHub PRs and issues. Use when the user types /excavate, says "why does this exist", "what was the original intent", "give me the history of this file", "explain this code's history", or is onboarding to an unfamiliar area of a codebase.
---

# Excavate

The user wants the *why* behind some code, not the *what*. You will do this archaeology yourself, in this context, and produce the report as your final assistant message.

The plugin also ships an `excavate:archaeologist` agent with the same protocol — that's for users who want subagent isolation and invoke it directly via the Agent tool. The `/excavate` slash command does not route through that agent. It runs the protocol inline so the report surfaces naturally as your reply.

## Argument

`${ARGUMENTS}` — one of:

- A **file path** (absolute or relative to cwd): `scripts/gate.sh`, `src/auth/middleware.ts`
- A **symbol name**: `compute_cap`, `AuthMiddleware`, `useAuth` — resolve via LSP first
- A **commit SHA** (7+ chars): `7a4c1f0`, `abc123def`
- A **GitHub PR URL**: `https://github.com/owner/repo/pull/42`
- **Empty** — ask the user what they want excavated; offer the file they're currently looking at or recently edited as a default

If the argument is ambiguous, make a reasonable guess and state your assumption in the report.

## Investigation pattern

You have `Bash`, `Read`, `Grep`, `Glob`, and `LSP`. Keep tool calls compact — you're synthesizing, not exploring blindly.

**1. Resolve and locate.** If the input is a symbol, use `LSP` to resolve to a file+range first. This pairs with language-server plugins (gopls-lsp, etc.) — and triggers the excavate hook, which attaches a provenance digest to the LSP response, so you get a head start on the history before issuing a single git command.

**2. Get the history.** Use `git` directly:

```
git -C <repo> log --follow --no-merges --pretty=format:'%h %ad %an  %s%n%b' --date=short -- <path>
git -C <repo> log --follow --reverse --pretty=format:'%h %ad %an  %s%n%b' --date=short -- <path> | head
git -C <repo> blame -w -C -C --line-porcelain <path> | grep '^author ' | sort | uniq -c
```

`--follow` tracks renames. `-w -C -C` makes blame robust to whitespace and code moves. `%b` includes commit message bodies — for solo-contributor repos, the bodies are the inline ADRs, so read them.

**3. Cross-reference documented intent.** Check whether CLAUDE.md, README.md, or an adjacent doc was touched in the same commits — that's literal documented rationale:

```
git -C <repo> log --follow --pretty=format:'%h %s' -- CLAUDE.md README.md
```

**4. Look at related files.** Tests, sibling modules, and direct callers (via `Grep` for the symbol) help you understand what this code is *for*. Skip if not productive.

**5. Opportunistic remote enrichment.** Only if `gh auth status` succeeds and the repo's remote is GitHub:

```
gh pr list --search 'sha:<short-sha>' --json number,title,body,url --state all
gh issue view <number> --json title,body  # if a commit references an issue
```

If the repo has no remote, no GitHub remote, no PRs, or no `gh` auth — say so in the Open Questions section and move on. Do not fabricate a PR story.

**6. Stop investigating when the picture is clear.** A 3-line file with two commits doesn't need a 20-tool-call investigation. Match effort to signal.

## Output

Your final assistant message is the report. It is the *only* output the user sees from /excavate — there is no separate "echo" step. Use this exact structure, in markdown, ≤ one page. Cite SHAs inline so the reader can verify.

```markdown
# Provenance: <target>

**Scope:** <file | symbol | commit | PR>  •  **Repo:** <name>  •  **History depth:** N commits, M authors

## Origin
One paragraph. When introduced, by whom, in what commit (SHA), with the stated rationale from the commit body. If the rationale is absent or terse, say so plainly.

## Major decisions
The inflection points — not every commit, just the ones that bent the shape. Each as: `abc123 — short description (date)`, followed by one sentence of why it mattered. If there are no clear inflections, say "No major pivots — file has had only mechanical changes since origin."

## Recent activity
Last 2–4 changes, summarized. What's the velocity? Is this code being actively shaped, or stable?

## Related code
Bulleted. Tests, sibling files, direct callers — with file:line. Skip the section if nothing useful.

## Open questions
What history *cannot* tell you. Undocumented constraints. Ambiguous renames. Decisions that left no trace. Be honest — a short, accurate "open questions" section is more valuable than a long fabricated one.
```

## Discipline

- **Don't invent intent.** If a commit message says "fix bug," quote it and note the terseness. Don't speculate.
- **Cite SHAs.** Every claim about a decision should reference the SHA that backs it.
- **Be brutal about brevity.** A reader of this report wants to ship a change in the next hour — give them load-bearing facts only.
- **State what's missing.** "No CLAUDE.md evolution touching this file" or "No GitHub remote available" is useful. Silence about gaps is misleading.
- **Don't editorialize about code quality.** This is archaeology, not code review. Note what changed, don't grade it.
