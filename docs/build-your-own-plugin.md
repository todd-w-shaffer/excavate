# Build your own plugin — a one-page guide

This is for the engineer who installs `excavate`, likes the shape, and wants to build something similar for a different workflow they keep redoing manually.

## What's in a plugin

A Claude Code plugin is just a directory with a manifest and any subset of four pieces:

| Piece | Use it when |
|---|---|
| **Agent** | You want Claude to behave like a *specialist* — focused prompt, narrow tool surface, custom output shape. Lives in `agents/<name>.md`. |
| **Skill** | You need an *entry point* — a slash command or natural-language trigger. Lives in `skills/<name>/SKILL.md`. Usually thin; dispatches to an agent. |
| **Hook** | You want to *enrich or gate* existing behavior — react when a tool is called, inject context, or block dangerous actions. Lives in `hooks/hooks.json` + a script. |
| **MCP server** | You're exposing *your own system* (an internal API, a private knowledge base) where shell + CLI isn't enough. Don't reach for it just to wrap a CLI — `gh`, `kubectl`, etc. are already token-efficient. |

Pick the smallest set that fits. `excavate` is agent + skill + hook. No MCP — wrapping `git`/`gh` in MCP would add a layer without earning its keep.

## The decision tree

When you have a workflow in mind, ask in this order:

1. **Is there a passive thing that could happen automatically?** → Hook. (Gate a risky command; enrich a tool result with extra context.)
2. **Is there a focused investigation Claude should do on demand?** → Agent. (Custom prompt + narrow tools.)
3. **How will the user trigger it?** → Skill. (`/<name>` or natural-language triggers in the description.)
4. **Are you exposing a system Claude can't reach with shell?** → MCP. (Otherwise skip it.)

If you can't answer "yes" to (1) and you can't answer (2), you don't have a plugin yet — you have a CLI tool. That's fine; ship a CLI tool.

## Worked example: `/preflight`

A pre-deploy checklist plugin. Same persona as excavate's user — solo or small-team — but a different daily pain: "I shipped a broken thing last week because I forgot to run the migration locally first."

**Shape:**
- **Agent `deploy-checker`** — runs `git status`, checks for uncommitted migrations, runs `npm test`, sniffs for new env vars in the diff, summarizes verdict.
- **Skill `/preflight`** — the entry point. Dispatches to the agent.
- **Hook `PreToolUse` on Bash** — when a `git push origin main`, `vercel deploy`, or `flyctl deploy` command is about to run, prints a one-line nudge: "Did you run `/preflight`?" Doesn't block — just nags. Earns its keep by catching you in the moment.

**File layout:**

```
.claude-plugin/plugin.json
agents/deploy-checker.md
skills/preflight/SKILL.md
hooks/hooks.json
scripts/nudge.sh
```

**`plugin.json`** — the manifest:

```json
{
  "name": "preflight",
  "version": "0.1.0",
  "description": "Pre-deploy checklist for solo devs.",
  "agents": "./agents/",
  "skills": "./skills/",
  "hooks": "./hooks/hooks.json"
}
```

**`hooks/hooks.json`** — the nudge hook:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{
          "type": "command",
          "command": "${CLAUDE_PLUGIN_ROOT}/scripts/nudge.sh",
          "timeout": 3
        }]
      }
    ]
  }
}
```

**`scripts/nudge.sh`** — pattern-match the command from stdin, emit additional context if it looks like a deploy:

```bash
#!/bin/bash
input=$(cat)
case "$input" in
  *'"command"'*'git push'*main*|*'vercel deploy'*|*'flyctl deploy'*) : ;;
  *) exit 0 ;;
esac
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"⚠️ About to deploy. Run `/preflight` first to check uncommitted migrations, env drift, and tests."}}\n'
```

That's the whole hook. ~10 lines of bash.

**`skills/preflight/SKILL.md`** and **`agents/deploy-checker.md`** follow the same shape as excavate's — skill is a thin dispatcher; agent does the work with `Bash`, `Read`, `Grep`. Look at `excavate/skills/excavate/SKILL.md` and `excavate/agents/archaeologist.md` for templates.

## Tips that aren't obvious from the docs

**Hook stdin is JSON; you don't need jq.** Pattern-match with bash globs (`case "$input" in *'"tool_name"'*'"Bash"'*)`). Coolant and excavate both do this. Avoids a dependency.

**Hooks can inject context, not just gate.** `hookSpecificOutput.additionalContext` (JSON to stdout) injects text the agent sees. Use this to compose with other plugins instead of building parallel surface area.

**Match hooks on tool name to compose.** If you want your plugin to enrich behavior in another plugin, hook on *that plugin's tool name*. Excavate hooks on `LSP` to enrich any LSP plugin. Your plugin can hook on `mcp__<server>__<tool>` for an MCP tool.

**Agents should have narrow tool surface.** Excavate's archaeologist gets `Bash, Read, Grep, Glob, LSP` — not `Edit, Write`. Read-only by design. Pick the smallest set; the agent will be more focused.

**Test your hook with synthetic stdin before installing.** `echo '{"tool_name":"Bash",...}' | scripts/nudge.sh` shows you exactly what the agent will see, no Claude Code restart needed.

**Skill descriptions are the trigger surface.** The `description:` frontmatter is how Claude decides when to invoke the skill from natural language. Write it to match the *user's words*, not the plugin's name. Excavate's description includes "why does this exist", "give me the history of this file" — phrases users actually say.

## Ship it

1. `git init` your plugin dir.
2. Add a `.claude-plugin/marketplace.json` self-referencing the plugin (so people can install from a local clone — see excavate's for a template).
3. Push to GitHub.
4. Add it to your marketplace repo (if you have one) or share the clone-and-install instructions.

Most plugins are 50–300 lines total. If yours is growing past that, you're probably trying to ship two plugins as one.
