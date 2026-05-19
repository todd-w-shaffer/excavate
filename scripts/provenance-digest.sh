#!/bin/bash
set -euo pipefail
# PostToolUse hook for the LSP tool.
# When LSP returns a file location, attach a compact git provenance digest
# (last commits, first-touch commit) so the agent sees both "what" and "why"
# without spending an extra tool round-trip.
#
# Design notes:
# - Pure bash + git. No jq, no python. macOS-friendly out of the box.
# - Glob-matches tool_name without parsing JSON (coolant's trick).
# - Caps at 3 unique paths per LSP response to keep the injection small.
# - Silent no-op outside git repos, on missing files, or if LSP returns
#   nothing path-shaped. Hooks must never block the agent on side-issues.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"

input=$(cat)

# Only act on LSP tool calls. Defensive — the matcher should already filter,
# but mismatched matcher semantics across Claude Code versions are cheap to
# guard against here.
case "$input" in
  *'"tool_name"'*'"LSP"'*) : ;;
  *) exit 0 ;;
esac

# Extract candidate file paths from the JSON blob. We look for both
# "file":"...", "uri":"file://...", and "path":"..." patterns since LSP
# response shapes vary by tool implementation.
paths=$(printf '%s' "$input" \
  | grep -oE '"(file|uri|path|filename)":"[^"]+"' \
  | sed -E 's/^"[^"]+":"//; s/"$//; s|^file://||' \
  | sort -u \
  | head -3)

if [ -z "$paths" ]; then
  exit 0
fi

digest=""

while IFS= read -r path; do
  # Strip ":line:col" fragments some LSP responses include
  path="${path%%:*[0-9]*}"
  # Bail if file doesn't exist on disk
  [ -f "$path" ] || continue

  repo_root=$(repo_root_for "$path") || continue
  [ -n "$repo_root" ] || continue

  rel_path="${path#$repo_root/}"

  # Last 3 commits touching this file (follow renames)
  recent=$(git -C "$repo_root" log --follow --no-merges \
    --pretty=format:'    %h  %ar  %an  —  %s' \
    -3 -- "$rel_path" 2>/dev/null || true)

  # First-touch commit (file's origin)
  first=$(git -C "$repo_root" log --follow --reverse --no-merges \
    --pretty=format:'    %h  %ar  %an  —  %s' \
    -- "$rel_path" 2>/dev/null | head -1 || true)

  # Total commits + unique authors (one line)
  stats_line=""
  total=$(git -C "$repo_root" log --follow --no-merges --pretty=format:'%h' -- "$rel_path" 2>/dev/null | wc -l | tr -d ' ' || echo 0)
  authors=$(git -C "$repo_root" log --follow --no-merges --pretty=format:'%an' -- "$rel_path" 2>/dev/null | sort -u | wc -l | tr -d ' ' || echo 0)
  if [ "$total" != "0" ]; then
    stats_line="    ${total} commits, ${authors} author$([ "$authors" = "1" ] || echo s)"
  fi

  # If we got nothing useful, skip
  [ -n "$recent" ] || continue

  digest+="${rel_path}"$'\n'
  [ -n "$stats_line" ] && digest+="${stats_line}"$'\n'
  [ -n "$first" ]      && digest+="  origin:"$'\n'"${first}"$'\n'
  digest+="  recent:"$'\n'"${recent}"$'\n\n'
done <<< "$paths"

if [ -z "$digest" ]; then
  exit 0
fi

# Emit additionalContext via the documented PostToolUse JSON envelope.
# The agent sees this as extra context attached to its LSP tool result.
printf '%s' "📜 excavate — provenance for LSP location(s):

${digest}" | emit_additional_context
