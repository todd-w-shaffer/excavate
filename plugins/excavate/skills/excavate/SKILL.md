---
name: excavate
description: Code archaeology — reconstruct the why behind a file, symbol, commit, or PR by reading git history, commit bodies, CLAUDE.md/README evolution, and (opportunistically) GitHub PRs and issues. Use when the user types /excavate, says "why does this exist", "what was the original intent", "give me the history of this file", "explain this code's history", or is onboarding to an unfamiliar area of a codebase.
---

# Excavate

The user wants the *why* behind some code, not the *what*. Your job is to dispatch the `excavate:archaeologist` agent against the target they named and return its report verbatim.

## Argument

`${ARGUMENTS}` — one of:

- A **file path** (absolute or relative to cwd): `scripts/gate.sh`, `src/auth/middleware.ts`
- A **symbol name**: `compute_cap`, `AuthMiddleware`, `useAuth` — the agent will resolve via LSP first
- A **commit SHA** (7+ chars): `7a4c1f0`, `abc123def`
- A **GitHub PR URL**: `https://github.com/owner/repo/pull/42`
- **Empty** — ask the user what they want excavated; offer the file they're currently looking at or recently edited as a default

## Dispatch

Invoke the `archaeologist` agent with a self-contained prompt:

```
Excavate the provenance of: ${ARGUMENTS}

The user is in repo: <output of `git -C "$(pwd)" rev-parse --show-toplevel`>
Working directory: <pwd>

Produce a one-page markdown report following your output format.
```

Use the `Agent` tool with `subagent_type: "excavate:archaeologist"` (plugin-shipped agents are namespaced as `<plugin>:<agent-name>`). Do not try to do the archaeology yourself — the agent has the focused prompt and the right tool surface.

## After the agent returns

Return the agent's report to the user verbatim, no preamble or commentary. The report is the deliverable.

If the agent reports it couldn't find a git repo, the target doesn't exist, or LSP couldn't resolve a symbol — surface that error directly. Don't try a second guess unless the user asks.
