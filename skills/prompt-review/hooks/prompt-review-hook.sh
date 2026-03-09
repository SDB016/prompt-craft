#!/bin/bash
# prompt-review PostToolUse hook
# Detects git push and gh pr create inside Claude Code,
# then instructs Claude to run the appropriate prompt-review flow.
#
# Output: exit 2 + stderr → feedback sent to Claude
# Install: bash install-hook.sh (or manually add to ~/.claude/settings.json)

set -euo pipefail

# Ensure jq is available
if ! command -v jq &>/dev/null; then
  exit 0
fi

# Read JSON from stdin
INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# tool_response is a plain string (stdout), not an object.
# We skip commands that produced error-like output.
RESPONSE=$(echo "$INPUT" | jq -r '.tool_response // ""')
if echo "$RESPONSE" | grep -qiE '(fatal|error|rejected|denied)'; then
  exit 0
fi

# Check if prompt-review is configured
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Detect: git push (anchored to command start or after shell operators)
# Excludes --dry-run and --delete variants
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)git\s+push\b' && \
   ! echo "$COMMAND" | grep -qE 'git\s+push\s+.*--(dry-run|delete)'; then
  echo "git push detected. Use the Skill tool to run: /prompt-review --push" >&2
  echo "This will capture current session prompts and commit them to the prompt review repository." >&2
  exit 2
fi

# Detect: gh pr create (anchored)
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)gh\s+pr\s+create\b'; then
  echo "gh pr create detected. Use the Skill tool to run: /prompt-review" >&2
  echo "This will aggregate push records, score prompts, and create a prompt review PR." >&2
  exit 2
fi

exit 0

# ─────────────────────────────────────────────────────────
# INSTALLATION
# ─────────────────────────────────────────────────────────
#
# Option 1: Run the installer
#   bash install-hook.sh
#
# Option 2: Manually add to ~/.claude/settings.json:
#
# {
#   "hooks": {
#     "PostToolUse": [
#       {
#         "matcher": "Bash",
#         "hooks": [
#           {
#             "type": "command",
#             "command": "$HOME/.claude/skills/prompt-review/hooks/prompt-review-hook.sh",
#             "timeout": 5
#           }
#         ]
#       }
#     ]
#   }
# }
