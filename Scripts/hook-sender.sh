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

PORT=49152
URL="http://localhost:${PORT}/hook"

# Read the full JSON payload from stdin (Claude Code pipes it in)
INPUT=$(cat)

# Determine if this is a permission event that needs to block
EVENT_NAME=$(echo "$INPUT" | jq -r '.hook_event_name // ""')
PERM_MODE=$(echo "$INPUT" | jq -r '.permission_mode // ""')

if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ]; then
  TIMEOUT=300
else
  TIMEOUT=5
fi

# Forward the stdin JSON directly to AgentPong -- no string interpolation,
# no injection risk. curl -d @- reads the body from stdin.
RESPONSE=$(echo "$INPUT" | curl -s --max-time "$TIMEOUT" \
  -X POST \
  -H "Content-Type: application/json" \
  -D /dev/stderr \
  -d @- \
  "$URL" 2>/tmp/agentpong-hook-headers.$$ || true)

# For permission events, output the decision JSON and set exit code
if [ "$EVENT_NAME" = "PreToolUse" ] && [ "$PERM_MODE" = "ask" ] && [ -n "$RESPONSE" ]; then
  echo "$RESPONSE"
  # Read exit code from response header
  EXIT_CODE=$(grep -i "X-Hook-Exit-Code" /tmp/agentpong-hook-headers.$$ 2>/dev/null | tr -dc '0-9' || echo "0")
  rm -f /tmp/agentpong-hook-headers.$$
  exit "${EXIT_CODE:-0}"
fi

rm -f /tmp/agentpong-hook-headers.$$ 2>/dev/null
exit 0
