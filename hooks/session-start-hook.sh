#!/bin/bash
set -euo pipefail

CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

# Config exists — nothing to do
if [[ -f "$CONFIG_FILE" ]]; then
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
fi

# Config missing — nudge the user
cat <<'HOOK_OUTPUT'
{"continue":true,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"[Prompt Craft] Not configured yet. Run /setup to set your prompt review repository. Until configured, push capture and prompt review features are inactive."}}
HOOK_OUTPUT
