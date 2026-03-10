#!/bin/bash
# prompt-review PostToolUse hook
# Detects git push and gh pr create inside Claude Code,
# then prompts Claude to run the review skill via official JSON protocol.
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

# tool_response for Bash tool is typically a structured object: { stdout, stderr, exit_code }
# but may be a plain string in some environments. Handle both cases.
STDOUT=$(echo "$INPUT" | jq -r 'if (.tool_response | type) == "object" then .tool_response.stdout // "" else (.tool_response // "") end')
STDERR=$(echo "$INPUT" | jq -r 'if (.tool_response | type) == "object" then .tool_response.stderr // "" else "" end')
if echo "$STDOUT$STDERR" | grep -qiE '(fatal|error|rejected|denied)'; then
  exit 0
fi

# Check if prompt-review is configured
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  exit 0
fi

# Resolve current project identity
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
REMOTE_URL=$(git -C "${CWD:-.}" remote get-url origin 2>/dev/null || true)
# Extract owner/repo from any remote URL format:
#   git@github.com:owner/repo.git, git@github-personal:owner/repo.git,
#   https://github.com/owner/repo.git, ssh://git@host/owner/repo.git
PROJECT_ID=$(echo "$REMOTE_URL" | sed -E 's#^.*@[^:]+:##; s#^https?://[^/]+/##; s#^ssh://[^/]+/##; s#\.git$##')

# Recursion guard: skip if current repo IS the prompt-reviews repo
REVIEW_REPO=$(jq -r '.repo // ""' "$CONFIG_FILE" 2>/dev/null)
if [[ -n "$PROJECT_ID" && -n "$REVIEW_REPO" ]]; then
  # Case-insensitive comparison (GitHub repos are case-insensitive)
  PID_LOWER=$(echo "$PROJECT_ID" | tr '[:upper:]' '[:lower:]')
  RR_LOWER=$(echo "$REVIEW_REPO" | tr '[:upper:]' '[:lower:]')
  if [[ "$PID_LOWER" == "$RR_LOWER" ]]; then
    exit 0
  fi
fi

# Project allowlist check
PROJECTS=$(jq -r '.projects // [] | .[]' "$CONFIG_FILE" 2>/dev/null)
PROJECT_IN_LIST=false
if [[ -z "$PROJECTS" ]]; then
  # Empty allowlist = all projects enabled
  PROJECT_IN_LIST=true
elif [[ -n "$PROJECT_ID" ]] && echo "$PROJECTS" | grep -qxF "$PROJECT_ID"; then
  PROJECT_IN_LIST=true
fi

# Check dismissed projects (don't ask again for these)
if [[ -n "$PROJECT_ID" ]]; then
  STATE_FILE="$HOME/.claude/prompt-review-state.json"
  DISMISSED=$(jq -r --arg p "$PROJECT_ID" '.dismissed_projects[$p] // ""' "$STATE_FILE" 2>/dev/null || true)
  if [[ -n "$DISMISSED" ]]; then
    # Check if cooldown expired (7 days)
    NOW_TS=$(date +%s)
    DISMISSED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${DISMISSED%Z}" +%s 2>/dev/null || echo 0)
    if [[ $((NOW_TS - DISMISSED_TS)) -lt 604800 ]]; then
      PROJECT_IN_LIST=false  # Will be skipped below without asking
      PERMANENTLY_DISMISSED=true
    fi
  fi
fi

# Detect: git push (anchored to command start or after shell operators)
# Excludes --dry-run and --delete variants
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)git\s+push\b' && \
   ! echo "$COMMAND" | grep -qE 'git\s+push\s+.*--(dry-run|delete)'; then

  # Just-in-Time opt-in: project not in allowlist → ask to enable
  if [[ "$PROJECT_IN_LIST" != "true" && -n "$PROJECT_ID" && "${PERMANENTLY_DISMISSED:-}" != "true" ]]; then
    jq -n \
      --arg reason "[PROMPT CRAFT] New project detected: $PROJECT_ID. Ask if the user wants to enable prompt capture." \
      --arg context "Project \"$PROJECT_ID\" is not in the prompt-review allowlist. Ask the user:

\"I noticed you pushed from $PROJECT_ID, but prompt review isn't tracking this project yet. Enable prompt capture for this project?\"

Options (use AskUserQuestion):
1. Yes, enable for this project — add \"$PROJECT_ID\" to the projects array in ~/.claude/prompt-review.config.json using jq, then run /prompt-craft:review --push
2. Not now — store dismissal in ~/.claude/prompt-review-state.json: set .dismissed_projects[\"$PROJECT_ID\"] to current ISO timestamp. Do NOT run review.
3. Never for this project — store permanent dismissal: set .dismissed_projects[\"$PROJECT_ID\"] to \"permanent\". Do NOT run review.

If the user says yes, after adding the project, proceed to run the review --push skill." \
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

  # Project is in allowlist — proceed with normal capture
  if [[ "$PROJECT_IN_LIST" == "true" ]]; then
    jq -n \
      --arg reason '[PROMPT CAPTURE] git push detected. Run /prompt-craft:review --push to capture session prompts.' \
      --arg context 'You MUST use the Skill tool to run: /prompt-craft:review --push

This skill captures all user prompts from this session and commits them to the configured prompt review repository. The push was successful — this is a post-push capture step that records session data for team review.

Do NOT skip this step. Do NOT summarize with "push completed" without running the skill first.

If the Skill tool fails to resolve the skill name, try: Skill(skill="prompt-craft:review", args="--push"). As a last resort, read and follow the instructions in the SKILL.md file at the plugin root: skills/review/SKILL.md with ARGUMENTS="--push".' \
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

  # Project dismissed or not identifiable — skip silently
  exit 0
fi

# Detect: gh pr create (anchored)
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)gh\s+pr\s+create\b'; then

  jq -n \
    --arg reason '[PROMPT REVIEW] gh pr create detected. Run /prompt-craft:review to create a scored prompt review PR.' \
    --arg context 'You MUST use the Skill tool to run: /prompt-craft:review

This skill aggregates all captured prompts, scores them against 8 quality criteria (100 points), and creates a prompt review PR in the configured review repository. The code PR was created successfully — now create the companion prompt review PR.

Do NOT skip this step.

If the Skill tool fails to resolve the skill name, try: Skill(skill="prompt-craft:review"). As a last resort, read and follow the instructions in the SKILL.md file at the plugin root: skills/review/SKILL.md.' \
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
