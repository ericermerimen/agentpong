#!/bin/bash
# hook-sender.sh -- Sends Claude Code hook events to AgentPong's local HTTP server.
# Installed by `agentpong setup` into ~/.agentpong/hooks/
#
# Claude Code hooks receive a JSON object on stdin with fields like:
#   session_id, hook_event_name, tool_name, tool_input (object), cwd, etc.
#
# APPROACH: Read the JSON from stdin and forward it directly to the local
# HTTP server via curl. This avoids JSON injection issues (no string
# interpolation) and stays compatible with any future field additions.
#
# For PreToolUse events with permission_mode="ask", the curl request
# blocks until AgentPong responds with a HookDecision JSON. The response
# is printed to stdout so Claude Code can read the decision.
# The exit code is set based on the X-Hook-Exit-Code header (0=allow, 2=block).

set -euo pipefail

# Temp file for response headers (mktemp avoids race conditions between
# concurrent hook invocations that share the same PID)
HEADERS_FILE=$(mktemp /tmp/agentpong-hook-headers.XXXXXX)
trap 'rm -f "$HEADERS_FILE"' EXIT

# Read port from server-port file (written by AgentPong on startup).
# Falls back to default port if file doesn't exist or contains garbage.
PORT_FILE="$HOME/.agentpong/server-port"
PORT=$(cat "$PORT_FILE" 2>/dev/null || echo "52775")
if ! [[ "$PORT" =~ ^[0-9]+$ ]]; then
  PORT=52775
fi
URL="http://localhost:${PORT}/hook"

# Read the full JSON payload from stdin (Claude Code pipes it in)
INPUT=$(cat)

# Inject Claude Code's PID so AgentPong can find the terminal window.
# Falls back gracefully if jq is not installed -- PID injection is
# nice-to-have (enables click-to-jump) but not required.
if command -v jq >/dev/null 2>&1; then
  INPUT=$(echo "$INPUT" | jq --argjson pid "$PPID" '. + {claude_pid: $pid}')
  EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
  PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // ""')
else
  # Without jq: extract fields with grep (best-effort)
  EVENT_NAME=$(echo "$INPUT" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || echo "")
  PERM_MODE=$(echo "$INPUT" | grep -o '"permission_mode"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"//' || echo "")
fi

# Permission events get longer timeout (server holds connection until user decides)
if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ]; then
  TIMEOUT=300
else
  TIMEOUT=5
fi

# Forward the stdin JSON directly to AgentPong -- no string interpolation,
# no injection risk. curl -d @- reads the body from stdin.
# Headers go to HEADERS_FILE for exit code extraction; curl errors go to /dev/null.
RESPONSE=$(echo "$INPUT" | curl -s --max-time "$TIMEOUT" \
  -X POST \
  -H "Content-Type: application/json" \
  -D "$HEADERS_FILE" \
  -d @- \
  "$URL" 2>/dev/null) || exit 0

# For permission events, output the decision JSON and set exit code
if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ] && [ -n "$RESPONSE" ]; then
  echo "$RESPONSE"
  # Read exit code from response header
  EXIT_CODE=$(grep -i "X-Hook-Exit-Code" "$HEADERS_FILE" 2>/dev/null | tr -dc '0-9' || echo "0")
  exit "${EXIT_CODE:-0}"
fi

exit 0
