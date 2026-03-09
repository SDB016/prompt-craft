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

# Read config values for inline instructions
REPO=$(jq -r '.repo' "$CONFIG_FILE")
BASE_BRANCH=$(jq -r '.base_branch' "$CONFIG_FILE")

# Detect: git push (anchored to command start or after shell operators)
# Excludes --dry-run and --delete variants
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)git\s+push\b' && \
   ! echo "$COMMAND" | grep -qE 'git\s+push\s+.*--(dry-run|delete)'; then
  cat >&2 <<HOOK_MSG
[PROMPT CAPTURE] git push detected. You MUST execute these steps NOW to record prompts:

1. Clone the prompt review repo:
   GH_TOKEN=\$(gh auth token)
   ARCHIVE_DIR=\$(mktemp -d)
   git clone --depth 1 "https://x-access-token:\${GH_TOKEN}@github.com/${REPO}.git" "\$ARCHIVE_DIR"

2. Determine the current branch and create session directory:
   BRANCH=\$(git branch --show-current)
   mkdir -p "\$ARCHIVE_DIR/sessions/\$BRANCH"

3. Count existing push files and create the next one:
   PUSH_NUM=\$(ls "\$ARCHIVE_DIR/sessions/\$BRANCH"/push-*.md 2>/dev/null | wc -l | tr -d ' ')
   PUSH_NUM=\$((PUSH_NUM + 1))
   PUSH_FILE="\$ARCHIVE_DIR/sessions/\$BRANCH/push-\$(printf '%03d' \$PUSH_NUM).md"

4. Write the push file in markdown with ALL of the following sections:

   ## Header
   # Push #N — BRANCH (DATE)
   > Session: CLAUDE_SESSION_ID | Prompts: COUNT | Trigger: git-push-hook

   ## Prompt Sequence
   For EACH user prompt in this session, write a separate block:
   ### Prompt N
   \`\`\`
   (paste the VERBATIM full text of what the user typed — do NOT summarize)
   \`\`\`
   <!-- delta: one-line description of what changed after this prompt -->

   ## Code Impact
   > TOTAL files changed, +INSERTIONS −DELETIONS
   | File | Change | Summary |
   |---|---|---|
   | \`path/to/file\` | added/modified (+N, −M) | AI-generated one-line description |
   (one row per changed file — generate a meaningful summary, not just the filename)

   ## Commits
   - \`SHA\` COMMIT_MESSAGE (one per line, from git log)

   ## Session Metadata
   \`\`\`yaml
   session_id: ...
   project_repo: OWNER/REPO
   project_branch: BRANCH
   prompt_count: N
   push_number: N
   triggered_by: git-push-hook
   \`\`\`

   IMPORTANT: Include the FULL verbatim text of every user prompt. Do NOT summarize prompts into one-liners.

5. Commit and push to the prompt review repo:
   cd "\$ARCHIVE_DIR"
   git checkout -b "prompt-data/\$BRANCH" "origin/${BASE_BRANCH}" 2>/dev/null || git checkout "prompt-data/\$BRANCH" 2>/dev/null || git checkout -b "prompt-data/\$BRANCH"
   git add .
   git commit -m "push: \$BRANCH push #\$PUSH_NUM (\$(date +%Y-%m-%d))"
   git push origin "prompt-data/\$BRANCH"

6. Clean up: rm -rf "\$ARCHIVE_DIR"

IMPORTANT: Do NOT skip these steps. Do NOT just say "push completed". Execute the commands above to record prompts in ${REPO}.
HOOK_MSG
  exit 2
fi

# Detect: gh pr create (anchored)
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)gh\s+pr\s+create\b'; then
  cat >&2 <<HOOK_MSG
[PROMPT REVIEW] gh pr create detected. You MUST execute these steps NOW to create a prompt review PR:

1. Clone the prompt review repo:
   GH_TOKEN=\$(gh auth token)
   ARCHIVE_DIR=\$(mktemp -d)
   git clone --depth 1 "https://x-access-token:\${GH_TOKEN}@github.com/${REPO}.git" "\$ARCHIVE_DIR"

2. Check for existing push records:
   BRANCH=\$(git branch --show-current)
   ls "\$ARCHIVE_DIR/sessions/\$BRANCH"/push-*.md 2>/dev/null
   If no push records exist, capture the current session directly (same as push flow above).

3. Score ALL prompts from the session against these 8 criteria (100 points total):
   - Goal Clarity (20pts): Is the goal specific?
   - Scope Control (15pts): Are boundaries set?
   - Context Sufficiency (15pts): Enough background provided?
   - Exit Criteria (10pts): Are completion conditions stated?
   - Decomposition (10pts): Are complex tasks broken down?
   - Verification Strategy (10pts): Verification method specified?
   - Iteration Quality (10pts): Are follow-ups specific?
   - Complexity Fit (10pts): Is sophistication appropriate?

4. Create a review branch and PR in ${REPO}:
   cd "\$ARCHIVE_DIR"
   REVIEW_BRANCH="prompt-review/\$(date +%Y-%m-%d)-\$BRANCH"
   git checkout -b "\$REVIEW_BRANCH" "origin/${BASE_BRANCH}"
   Write the scored review as a markdown file, then commit, push, and create a PR with gh pr create.

5. Ask the user for confirmation before creating the PR.

6. Clean up: rm -rf "\$ARCHIVE_DIR"
HOOK_MSG
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
