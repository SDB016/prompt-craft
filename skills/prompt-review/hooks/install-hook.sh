#!/bin/bash
# Prompt Craft hook migration tool
#
# v1.1.0+: Hooks are auto-registered via hooks/hooks.json when the plugin is enabled.
#           Manual installation in ~/.claude/settings.json is no longer needed.
#
# This script:
#   1. Detects and removes legacy manual hook entries from ~/.claude/settings.json
#   2. Confirms auto-registration is active
#
# Usage: bash install-hook.sh [--check]

set -euo pipefail

SETTINGS_FILE="$HOME/.claude/settings.json"

# --check: just report status, don't modify anything
CHECK_ONLY=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=true
fi

echo "Prompt Craft Hook Migration Tool (v1.1.0)"
echo "==========================================="
echo ""

# Step 1: Check for legacy manual hook in settings.json
if [[ -f "$SETTINGS_FILE" ]]; then
  LEGACY_CMD=$(jq -r '.hooks.PostToolUse[]? | select(.hooks[]?.command | test("prompt-review-hook")) | .hooks[0].command' "$SETTINGS_FILE" 2>/dev/null || true)

  if [[ -n "$LEGACY_CMD" ]]; then
    echo "Legacy hook found in ~/.claude/settings.json:"
    echo "  Command: $LEGACY_CMD"
    echo ""

    if $CHECK_ONLY; then
      echo "Status: MIGRATION NEEDED"
      echo "  Run 'bash install-hook.sh' (without --check) to remove the legacy entry."
      exit 0
    fi

    # Remove the legacy hook entry
    TEMP_FILE=$(mktemp)
    jq '
      .hooks.PostToolUse = [
        .hooks.PostToolUse[]
        | select(.hooks | all(.command | test("prompt-review-hook") | not))
      ]
      | if (.hooks.PostToolUse | length) == 0 then del(.hooks.PostToolUse) else . end
      | if (.hooks | length) == 0 then del(.hooks) else . end
    ' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"

    echo "Removed legacy hook entry from settings.json."
    echo ""
  else
    echo "No legacy hook found in settings.json. OK."
    echo ""
  fi
else
  echo "No ~/.claude/settings.json found. OK."
  echo ""
fi

# Step 2: Confirm auto-registration
echo "Auto-registration status:"
echo "  Hooks are now registered via hooks/hooks.json in the plugin package."
echo "  When Prompt Craft is enabled as a plugin, hooks are loaded automatically."
echo ""
echo "No manual installation needed."
echo ""

if ! $CHECK_ONLY; then
  echo "Migration complete. Restart Claude Code for changes to take effect."
fi
