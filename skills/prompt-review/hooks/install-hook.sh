#!/bin/bash
# Install prompt-review hook into Claude Code settings
# Usage: bash install-hook.sh

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"

# Auto-detect hook path (marketplace plugin or manual install)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_PATH="$SCRIPT_DIR/prompt-review-hook.sh"

if [[ ! -f "$HOOK_PATH" ]]; then
  echo "Error: Hook script not found at $HOOK_PATH"
  exit 1
fi
chmod +x "$HOOK_PATH"

# Create settings file if it doesn't exist
if [[ ! -f "$SETTINGS_FILE" ]]; then
  echo '{}' > "$SETTINGS_FILE"
fi

# Check if hook is already installed
EXISTING_CMD=$(jq -r '.hooks.PostToolUse[]? | select(.hooks[]?.command | test("prompt-review-hook")) | .hooks[0].command' "$SETTINGS_FILE" 2>/dev/null)

TEMP_FILE=$(mktemp)
if [[ -n "$EXISTING_CMD" ]]; then
  if [[ "$EXISTING_CMD" == "$HOOK_PATH" ]]; then
    echo "prompt-review hook is already installed (path up to date)."
    exit 0
  fi
  # Update existing hook path to current location
  jq --arg old_cmd "$EXISTING_CMD" --arg new_cmd "$HOOK_PATH" '
    (.hooks.PostToolUse[] | select(.hooks[]?.command == $old_cmd) | .hooks[0].command) = $new_cmd
  ' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
  echo "prompt-review hook path updated."
  echo "  Old: $EXISTING_CMD"
  echo "  New: $HOOK_PATH"
else
  # Add the hook fresh
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
fi

echo "prompt-review hook installed successfully."
echo ""
echo "  Settings:  $SETTINGS_FILE"
echo "  Hook:      $HOOK_PATH"
echo ""
echo "The hook will detect git push and gh pr create inside Claude Code."
echo "Restart Claude Code for the hook to take effect."
