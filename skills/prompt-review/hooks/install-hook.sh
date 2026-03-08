#!/bin/bash
# Install prompt-review hook into Claude Code settings
# Usage: bash install-hook.sh

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"
HOOK_PATH="$HOME/.claude/skills/prompt-review/hooks/prompt-review-hook.sh"

# Ensure hook script exists and is executable
if [[ ! -f "$HOOK_PATH" ]]; then
  echo "Error: Hook script not found at $HOOK_PATH"
  echo "Fix:   Copy the skill files first: cp -r skill/* ~/.claude/skills/prompt-review/"
  exit 1
fi
chmod +x "$HOOK_PATH"

# Create settings file if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if hook is already installed
if jq -e '.hooks.PostToolUse[]? | select(.hooks[]?.command | test("prompt-review-hook"))' "$SETTINGS_FILE" &>/dev/null; then
  echo "prompt-review hook is already installed."
  exit 0
fi

# Add the hook using jq
TEMP_FILE=$(mktemp)
jq --arg hook_cmd "$HOOK_PATH" '
  .hooks //= {} |
  .hooks.PostToolUse //= [] |
  .hooks.PostToolUse += [{
    "matcher": "Bash",
    "hooks": [{
      "type": "command",
      "command": $hook_cmd,
      "timeout": 5
    }]
  }]
' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"

echo "prompt-review hook installed successfully."
echo ""
echo "  Settings:  $SETTINGS_FILE"
echo "  Hook:      $HOOK_PATH"
echo ""
echo "The hook will detect git push and gh pr create inside Claude Code."
echo "Restart Claude Code for the hook to take effect."
