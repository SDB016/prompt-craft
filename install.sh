#!/usr/bin/env bash
set -euo pipefail

SKILL_NAME="prompt-review"
TARGET_DIR="$HOME/.claude/skills/$SKILL_NAME"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skill"

echo "Installing $SKILL_NAME skill..."
echo ""

# Check prerequisites
ERRORS=0

if ! command -v gh &>/dev/null; then
  echo "WARNING: gh CLI not found."
  echo "  Install from: https://cli.github.com/"
  echo "  Then authenticate: gh auth login"
  echo ""
else
  if ! gh auth status &>/dev/null; then
    echo "WARNING: gh CLI is not authenticated."
    echo "  Run: gh auth login"
    echo ""
  fi
fi

if ! command -v git &>/dev/null; then
  echo "ERROR: git is required but not found."
  ERRORS=$((ERRORS + 1))
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: jq is required but not found."
  echo "  Install: brew install jq (macOS) or apt install jq (Linux)"
  ERRORS=$((ERRORS + 1))
fi

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "$ERRORS required dependency(ies) missing. Cannot install."
  exit 1
fi

# Verify source files exist
for required_file in SKILL.md QUICKREF.md PROMPT-FEEDBACK.md PROMPT-STATS.md PROMPT-TIPS.md PROMPT-REPLAY.md PROMPT-COMPARE.md PROMPT-TEMPLATE.md; do
  if [ ! -f "$SOURCE_DIR/$required_file" ]; then
    echo "ERROR: $required_file not found in $SOURCE_DIR"
    exit 1
  fi
done

# Create target directories
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/utils"
mkdir -p "$TARGET_DIR/hooks"
mkdir -p "$TARGET_DIR/templates"

# Copy skill files
for skill_file in SKILL.md QUICKREF.md PROMPT-FEEDBACK.md PROMPT-STATS.md PROMPT-TIPS.md PROMPT-REPLAY.md PROMPT-COMPARE.md PROMPT-TEMPLATE.md; do
  cp "$SOURCE_DIR/$skill_file" "$TARGET_DIR/$skill_file"
done

# Copy templates
if [ -d "$SOURCE_DIR/templates" ]; then
  find "$SOURCE_DIR/templates" -maxdepth 1 -type f -name "*.md" \
    -exec cp -P {} "$TARGET_DIR/templates/" \;
fi

# Copy utils
if [ -d "$SOURCE_DIR/utils" ]; then
  find "$SOURCE_DIR/utils" -maxdepth 1 -type f -name "*.sh" \
    -exec cp -P {} "$TARGET_DIR/utils/" \;
fi

# Copy hooks
if [ -d "$SOURCE_DIR/hooks" ]; then
  find "$SOURCE_DIR/hooks" -maxdepth 1 -type f -name "*.sh" \
    -exec cp -P {} "$TARGET_DIR/hooks/" \;
fi

# Set executable permissions
find "$TARGET_DIR/utils" -name "*.sh" -exec chmod +x {} \; 2>/dev/null
find "$TARGET_DIR/hooks" -name "*.sh" -exec chmod +x {} \; 2>/dev/null

echo "Installed to: $TARGET_DIR"
echo ""
echo "Files:"
find "$TARGET_DIR" -type f | sort | while read -r f; do
  echo "  $f"
done
echo ""

# Install hook
echo "Installing PostToolUse hook..."
bash "$TARGET_DIR/hooks/install-hook.sh"
echo ""

echo "Installation complete."
echo ""
echo "Next steps:"
echo "  1. Restart Claude Code (for hook to take effect)"
echo "  2. Run setup:  /prompt-review --setup"
echo "  3. Or just:    /prompt-review"
echo ""
echo "All skills:"
echo "  /prompt-review              Create prompt review PR"
echo "  /prompt-feedback            Local prompt scoring (no PR)"
echo "  /prompt-stats               Score trends over time"
echo "  /prompt-tips                Pre-task prompt writing guide"
echo "  /prompt-replay              High-scoring pattern extraction"
echo "  /prompt-compare [#1] [#2]   Compare two review sessions"
echo "  /prompt-template            Save/use prompt templates"
