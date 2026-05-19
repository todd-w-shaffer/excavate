#!/bin/bash
# Shared helpers for excavate hook scripts.

# JSON-escape a string for embedding in a JSON value.
# Handles backslash, double-quote, newline, tab, carriage return.
# Stdin → stdout.
json_escape() {
  awk 'BEGIN { ORS="" } {
    gsub(/\\/, "\\\\")
    gsub(/"/, "\\\"")
    gsub(/\t/, "\\t")
    gsub(/\r/, "\\r")
    print
    if (NR > 0) printf "\\n"
  }' "$@"
}

# Emit a PostToolUse hookSpecificOutput JSON envelope with the given text
# as additionalContext. Reads context text from stdin.
emit_additional_context() {
  local escaped
  escaped=$(json_escape)
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$escaped"
}

# Find the repo root for a given path. Echoes the root on stdout, or
# returns nonzero if the path isn't in a git work tree.
repo_root_for() {
  local path="$1"
  local dir
  if [ -d "$path" ]; then
    dir="$path"
  else
    dir="$(dirname "$path")"
  fi
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}
