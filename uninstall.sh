#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="prompt-review"
TARGET_DIR="$HOME/.claude/skills/$SKILL_NAME"
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Uninstalling $SKILL_NAME skill..."
echo ""

# Safety: verify target resolves under expected path
REAL_TARGET="$(realpath "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")"
if [[ "$REAL_TARGET" != "$HOME/.claude/skills/"* ]]; then
  echo "ERROR: Target directory resolved outside expected path: $REAL_TARGET" >&2
  exit 1
fi

# Remove skill directory
if [ -d "$REAL_TARGET" ]; then
  rm -rf "$REAL_TARGET"
  echo "Removed: $REAL_TARGET"
else
  echo "Skill directory not found (already removed): $TARGET_DIR"
fi

# Remove hook from settings.json
if [ -f "$SETTINGS_FILE" ] && command -v jq &>/dev/null; then
  if jq -e '.hooks.PostToolUse[]? | select(.hooks[]?.command | test("prompt-review-hook"))' "$SETTINGS_FILE" &>/dev/null; then
    TEMP_FILE=$(mktemp)
    jq '
      .hooks.PostToolUse = [
        .hooks.PostToolUse[]? | select(.hooks | all(.command | test("prompt-review-hook") | not))
      ] |
      if .hooks.PostToolUse == [] then del(.hooks.PostToolUse) else . end |
      if .hooks == {} then del(.hooks) else . end
    ' "$SETTINGS_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$SETTINGS_FILE"
    echo "Removed hook from: $SETTINGS_FILE"
  else
    echo "No prompt-review hook found in settings."
  fi
fi

# Ask about config file removal
if [ -f "$CONFIG_FILE" ]; then
  echo ""
  if [ -t 0 ]; then
    read -rp "Remove configuration file ($CONFIG_FILE)? [y/N] " answer
  else
    answer="N"
    echo "Non-interactive mode: keeping configuration file."
  fi
  case "$answer" in
    [yY]|[yY][eE][sS])
      rm -f "$CONFIG_FILE"
      echo "Removed: $CONFIG_FILE"
      ;;
    *)
      echo "Kept: $CONFIG_FILE"
      ;;
  esac
else
  echo "No configuration file found."
fi

echo ""
echo "Uninstall complete."
