#!/bin/bash
# prompt-review PostToolUse hook
# Detects git push and gh pr create inside Claude Code,
# then prompts Claude to run the prompt-review skill via official JSON protocol.
#
# Protocol: exit 0 + JSON { decision: "block", reason, hookSpecificOutput } → prompts Claude
# Registration: auto-registered via hooks/hooks.json (no manual install needed)

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

  jq -n \
    --arg reason '[PROMPT CAPTURE] git push detected. Run /prompt-craft:prompt-review --push to capture session prompts.' \
    --arg context 'You MUST use the Skill tool to run: /prompt-craft:prompt-review --push

This skill captures all user prompts from this session and commits them to the configured prompt review repository. The push was successful — this is a post-push capture step that records session data for team review.

Do NOT skip this step. Do NOT summarize with "push completed" without running the skill first.' \
    '{
      continue: true,
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $context
      }
    }'

  exit 0
fi

# Detect: gh pr create (anchored)
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)gh\s+pr\s+create\b'; then

  jq -n \
    --arg reason '[PROMPT REVIEW] gh pr create detected. Run /prompt-craft:prompt-review to create a scored prompt review PR.' \
    --arg context 'You MUST use the Skill tool to run: /prompt-craft:prompt-review

This skill aggregates all captured prompts, scores them against 8 quality criteria (100 points), and creates a prompt review PR in the configured review repository. The code PR was created successfully — now create the companion prompt review PR.

Do NOT skip this step.' \
    '{
      continue: true,
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: $context
      }
    }'

  exit 0
fi

exit 0
