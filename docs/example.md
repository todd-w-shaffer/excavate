# Example run

A full report from `/excavate scripts/gate.sh` run against [coolant](https://github.com/todd-w-shaffer/coolant). Solo-contributor repo, no PRs to fetch — the agent works entirely from git history and commit bodies.

> Excavate ships two slash commands. This is `/excavate` — file-scoped depth (one file's "why"). The repo-scoped breadth view is `/timeline` (where the work has been happening across the whole codebase). The SHAs cited below can be drilled into via `/excavate <sha>` — that's the bridge between the two zoom levels.

---

# Provenance: scripts/gate.sh

**Scope:** file  •  **Repo:** coolant  •  **History depth:** 5 commits, 1 author (Todd Shaffer)

## Origin
Introduced 2026-04-04 in `8645a86` as a new PreToolUse hook for Claude Code. The stated goal: "Build an extensible PreToolUse gating system for Coolant that suppresses expensive CLI tools during parallel mode." First incarnation was a single `check_gate` function pattern-matching commands across five ecosystems (TS, Rust, Go, Python, Java), stripping transparent wrappers (`npx`, `env`, `command`, `nice`, `time`, `sudo`) and path prefixes, and emitting a `permissionDecision: deny` during parallel mode. Companion concerns from day one: symlink-attack resistance via `$TMPDIR` instead of `/tmp`, and JSON-escaping every interpolated value via `_json_escape` in `common.sh`.

## Major decisions

- `8645a86` — Initial gate as suppress-only PreToolUse hook (2026-04-04). Set the architectural baseline: name-based matching (not ecosystem detection), wrapper-stripping, JSONL events to `$TMPDIR/coolant-$USER.events.jsonl`, no jq dependency (bash regex via `_json_field`).
- `57404da` — Add agent-count-adaptive concurrency capping; retire parallel-gate.sh (2026-04-04, same day). The pivotal restructure. Single `check_gate` split into dual `gate_suppress` / `gate_cap` dispatch. Introduced the cap formula `floor((cores - 2) / active_agents), min 1`, per-ecosystem flag mapping (`--maxWorkers`, `--maxConcurrency`, `-j`, `-parallel`, `-n`), the `cargo test --` separator handling, and word-boundary dup-checks. Test runners now get **capped always** (not just under parallel mode); type/lint/build remain suppress-only. The retired `parallel-gate.sh` (PostToolUse) was fully superseded here.
- `d7f36e9` — Hot-path allocation/fork audit (2026-04-04). Replaced gate.sh's inline `cat` + manual regex counter validation with the shared `_read_counter` helper from `common.sh`. Body frames the system as "a monitor that must perform well under the exact stress it observes."
- `4e8282e` — Swift as seventh process category (2026-04-05). Added `swift test -j`, `xcodebuild test -parallel-testing-worker-count` capping, plus suppression for `swift build`, `xcodebuild build/archive/analyze`, and `swiftlint`.
- `89e72bf` — Flip gate from auto-suppress to opt-in `/coolant` with JSONL reconciliation (2026-04-08). Behavioral inversion. `compute_cap` switched from `_read_counter` to `_reconcile_counter`, which cross-checks the counter file against the JSONL event log (starts minus stops) scoped to events after the last `counter.reset` marker. Motivation in the body: "orphaned agents inflate the counter permanently" causing "silent build suppression."
- `7d05e45` — Relabel gate alerts to plain English (2026-04-22). Copy-only. `emit_deny` reason became "blocked:", `emit_cap` log became "throttled:". JSONL event names (`gate.cap`, `gate.suppress`) deliberately unchanged — only display strings moved.

## Recent activity
The file has been **dormant since 2026-04-22** (latest change is the copy relabel). The repo itself remains active (CLAUDE.md / README.md touched as recently as 2026-05-15), so the gate logic is settled. Velocity peaked on 2026-04-04 (three commits the same day rebuilding it from scratch), then tapered to roughly weekly through 2026-04-22, then stopped.

## Related code
- `scripts/common.sh` — provides `_read_counter`, `_reconcile_counter`, `_json_escape`, `_json_field`, `_nested_command`, `_COOLANT_NCPU`, and `coolant_event`. Gate.sh depends on all of these.
- `hooks/hooks.json` — registers gate.sh as the PreToolUse hook matching the Bash tool.
- `tests/gate.bats` — 445 lines; ~20 cap tests + 29 ecosystem tests + 2 reconciliation tests + 6 Swift tests.
- `scripts/toggle.sh`, `scripts/preflight.sh`, `scripts/agent-start.sh`, `scripts/agent-stop.sh` — emit the `counter.reset`, `agent.start`, `agent.stop` events that `_reconcile_counter` consumes.
- `thermal/internal/collector/events.go`, `thermal/internal/model/state.go` — Go-side consumers of `gate.cap` / `gate.suppress` JSONL events.
- `docs/gate-system-report.md` — referenced in both `8645a86` and `57404da` bodies as the design-decisions doc.
- Retired sibling (gone from tree): `scripts/parallel-gate.sh`, `tests/parallel-gate.bats`, deleted in `57404da`.

## Open questions
- **Why was debounce dropped?** `57404da`'s body says Step 8 was "marked as dropped" but gives no in-line reason. The dead `EventGateDebounce` Go constant lingered until `89e72bf` removed it.
- **Why these specific wrappers?** The transparent-wrapper list (`npx`, `env`, `command`, `nice`, `time`, `sudo`) appears fully formed in `8645a86` with no body discussion of selection criteria (no `xargs`, no `make`).
- **Why `(cores - 2)`?** The cap formula is stated in `57404da` without justifying the `-2` reserve.
- **Pre-history of the design.** `8645a86` already references `docs/gate-system-report.md` as an implementation report — that doc likely contains rationale never re-stated in commit bodies.
- **The "echo -n gotcha."** `57404da`'s body mentions it as the driver for switching to `printf` in `cap_flag` but does not describe the failure mode.

---

## What this example shows

- **Found the load-bearing pivot** (`57404da` restructure into dual dispatch + cap formula) without you having to read every commit.
- **Surfaced a behavioral inversion** (`89e72bf` flip from auto-suppress to opt-in) with the actual motivation quoted from the commit body.
- **Named a retired sibling** (`parallel-gate.sh`) so you don't grep for it expecting it to still exist.
- **Asked questions the commits don't answer.** The "why `(cores - 2)`?" question is exactly the kind of decision-trace gap a new contributor (or future-you) would hit.

The whole report is ~50 lines. Reading time: under two minutes. Compare with the alternative — opening `git log -p scripts/gate.sh` and reading the diff stream yourself, which is roughly 1,500 lines.
