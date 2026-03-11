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
  PID_LOWER=$(echo "$PROJECT_ID" | tr '[:upper:]' '[:lower:]')
  RR_LOWER=$(echo "$REVIEW_REPO" | tr '[:upper:]' '[:lower:]')
  if [[ "$PID_LOWER" == "$RR_LOWER" ]]; then
    exit 0
  fi
fi

# --- Project capture check (allow/deny/ask) ---
# Read capture mode and project status from config
CAPTURE_MODE=$(jq -r '.capture.mode // "ask"' "$CONFIG_FILE" 2>/dev/null)
PROJECT_STATUS=""
PROJECT_REPO=""

if [[ -n "$PROJECT_ID" ]]; then
  PROJECT_STATUS=$(jq -r --arg p "$PROJECT_ID" '.capture.projects[$p].status // ""' "$CONFIG_FILE" 2>/dev/null)
  PROJECT_REPO=$(jq -r --arg p "$PROJECT_ID" '.capture.projects[$p].repo // ""' "$CONFIG_FILE" 2>/dev/null)
fi

# Determine effective repo for this project (project-specific or global default)
EFFECTIVE_REPO="${PROJECT_REPO:-$REVIEW_REPO}"

# Resolve project capture decision
# Deny always wins — even if mode is "all", explicit deny is respected
CAPTURE_DECISION="skip"
if [[ "$PROJECT_STATUS" == "deny" ]]; then
  # Denied project — suppress completely, Claude never sees this
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
elif [[ "$CAPTURE_MODE" == "all" ]]; then
  CAPTURE_DECISION="capture"
elif [[ "$PROJECT_STATUS" == "allow" ]]; then
  CAPTURE_DECISION="capture"
elif [[ -z "$PROJECT_STATUS" && -n "$PROJECT_ID" ]]; then
  # Not in allow or deny — need to ask
  CAPTURE_DECISION="ask"
fi

# Detect: git push (anchored to command start or after shell operators)
# Excludes --dry-run and --delete variants
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)git\s+push\b' && \
   ! echo "$COMMAND" | grep -qE 'git\s+push\s+.*--(dry-run|delete)'; then

  # Ask flow: project not in allow or deny — ask user, then delegate to /setup-project
  if [[ "$CAPTURE_DECISION" == "ask" ]]; then
    jq -n \
      --arg reason "[PROMPT CRAFT] New project detected: $PROJECT_ID. Ask user whether to enable prompt capture." \
      --arg project_id "$PROJECT_ID" \
      --arg context "Project \"$PROJECT_ID\" is not tracked for prompt capture yet.

Ask the user using AskUserQuestion: \"Enable prompt capture for $PROJECT_ID?\"
Options:
1. Yes — enable capture
2. No — skip this project

If YES: use the Skill tool to run /prompt-craft:setup-project with args \"on\". The skill will ask which review repo to use and update config. After setup completes, run /prompt-craft:review --push to capture session prompts.

If NO: use the Skill tool to run /prompt-craft:setup-project with args \"off\". This marks the project as denied — future pushes will be silently skipped." \
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

  # Capture flow: project is allowed — write lightweight JSONL metadata (silent, non-blocking)
  if [[ "$CAPTURE_DECISION" == "capture" ]]; then
    BRANCH=$(git -C "${CWD:-.}" branch --show-current 2>/dev/null || echo "unknown")
    SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""')
    PUSHLOG="$HOME/.claude/prompt-review-pushlog.jsonl"
    mkdir -p "$(dirname "$PUSHLOG")"

    # Record push metadata locally — no clone, no scoring, no network
    jq -n -c \
      --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
      --arg project "$PROJECT_ID" \
      --arg branch "$BRANCH" \
      --arg session_id "$SESSION_ID" \
      --arg cwd "${CWD:-.}" \
      --arg repo "$EFFECTIVE_REPO" \
      '{ts: $ts, project: $project, branch: $branch, session_id: $session_id, cwd: $cwd, repo: $repo}' \
      >> "$PUSHLOG"

    # Silent — no blocking, no Claude involvement, no approval needed
    echo '{"continue":true,"suppressOutput":true}'
    exit 0
  fi

  # Skip silently (no project ID or other edge case)
  exit 0
fi

# Detect: gh pr create (anchored)
if echo "$COMMAND" | grep -qE '(^|&&\s*|\|\|\s*|;\s*)gh\s+pr\s+create\b'; then

  # Only trigger review if project is captured
  if [[ "$CAPTURE_DECISION" != "capture" ]]; then
    exit 0
  fi

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
