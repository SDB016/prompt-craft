---
name: review
description: Capture prompts from Claude Code sessions and create prompt review PRs for team feedback. Includes setup, doctor check, and project management. Use when asked to review prompts, create prompt PR, share session prompts, or configure prompt review.
argument-hint: "[--push] [--setup] [--status] [--doctor] [--advanced]"
disable-model-invocation: false
allowed-tools: Bash, Read, Grep, Glob
---

# Prompt Review Skill

Captures prompts and code changes from Claude Code sessions, scores prompt quality against 8 criteria, and creates GitHub PRs in a dedicated review repo for team feedback.

> "Code review looks at results. Prompt review looks at causes."

**Received arguments:** $ARGUMENTS

---

## How It Works: Two-Phase Capture

| Event | What happens | In prompt repo |
|-------|-------------|----------------|
| `git push` (inside Claude Code) | Capture session prompts + diff | **Commit only** (no PR) |
| `gh pr create` (inside Claude Code) | Aggregate all commits + score | **Create PR** |
| `/review` (manual) | Create PR at desired time | **Create PR** |

This means:
- During development, each push records prompts incrementally
- When the feature is done (code PR created), the prompt review PR is also created
- Multi-session and multi-day work is naturally supported

---

## Step 0: Route the Request

- If `$ARGUMENTS` contains `--doctor` → jump to **[DOCTOR]**
- If `$ARGUMENTS` contains `--setup` → jump to **[SETUP WIZARD]**
- If `$ARGUMENTS` contains `--push` → jump to **[PUSH HOOK]**
- If `$ARGUMENTS` contains `--status` → jump to **[STATUS DISPLAY]**
- If `$ARGUMENTS` matches project management intent (add, remove, list, projects) → jump to **[PROJECT MANAGEMENT]** (redirects to `/setup-project`)
- If no config exists at `~/.claude/prompt-review.config.json` → run **[LAZY SETUP]** first
- Otherwise → proceed to **[CAPTURE FLOW]**

### Project Management Intent Detection

Detect these patterns in `$ARGUMENTS` (natural language, case-insensitive) and redirect to the `/setup-project` skill:

| Intent | Trigger phrases | Action |
|--------|----------------|--------|
| **Add/enable project** | "add project", "add this project", "track this", "enable here", "이 프로젝트 추가" | → invoke `/setup-project on` |
| **Remove/disable project** | "remove project", "stop tracking", "disable", "이 프로젝트 제거" | → invoke `/setup-project off` |
| **List projects** | "list projects", "show projects", "which projects", "projects", "프로젝트 목록" | → invoke `/setup-project list` |

---

## [DOCTOR]

Check all prerequisites and report status. This is a read-only check — no installation, no configuration changes.

```bash
# 1. git
if command -v git &>/dev/null; then
  echo "✓ git $(git --version | head -1)"
else
  echo "✗ git — not found"
fi

# 2. GitHub CLI (gh)
if command -v gh &>/dev/null; then
  echo "✓ gh $(gh --version | head -1)"
  # Check authentication
  if gh auth status &>/dev/null 2>&1; then
    echo "  ✓ authenticated"
  else
    echo "  ✗ not authenticated — run: gh auth login"
  fi
else
  echo "✗ gh — not found (install from https://cli.github.com/)"
fi

# 3. jq
if command -v jq &>/dev/null; then
  echo "✓ jq $(jq --version 2>/dev/null)"
else
  echo "✗ jq — not found"
fi

# 4. Hook registration
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
  echo "✓ Hook registered (hooks/hooks.json found)"
else
  echo "✗ Hook not registered — push capture will not work automatically"
fi
```

Display a summary table:

```
Prompt Craft — Prerequisite Check

| Tool    | Status | Version / Note          |
|---------|--------|-------------------------|
| git     | ✓ / ✗  | x.y.z or —              |
| gh      | ✓ / ✗  | x.y.z or —              |
| jq      | ✓ / ✗  | x.y.z or —              |
| gh auth | ✓ / ✗  | logged in or —          |
| hook    | ✓ / ✗  | registered or —         |
```

If all checks pass, report: "All prerequisites met. Run `/review` to create a prompt review PR."

If any check fails, report the failure with the fix command. Do not install anything — just report.

If the hook check fails, add: "If the hook isn't firing after installation, restart your Claude Code session to reload plugin hooks."

---

## [LAZY SETUP]

Triggered automatically when no config exists at `~/.claude/prompt-review.config.json` and the user runs `/review` without `--setup`.

Ask only ONE question:

**Question:** "Which GitHub repository should prompt reviews be sent to? (format: owner/repo)"

Examples: `myname/ai-sessions`, `myorg/prompt-reviews`

**Validate:**
- Must match `[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+`
- Check accessibility via `gh repo view`

```bash
REPO="USER_PROVIDED_REPO"

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI is required."
  echo "Fix:   Install from https://cli.github.com/ then run: gh auth login"
  exit 0
fi

gh repo view "$REPO" --json name 2>/dev/null \
  && echo "REPO_ACCESSIBLE=true" \
  || echo "REPO_ACCESSIBLE=false"

IS_PRIVATE=$(gh repo view "$REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null || echo "unknown")
echo "REPO_IS_PRIVATE=$IS_PRIVATE"
```

If not accessible, offer to create the repo or try a different name.

If `REPO_IS_PRIVATE=false` (public repo), show warning:

**Question:** "Warning: `{REPO}` is a **public repository**. Your prompt session data will be publicly visible. How would you like to proceed?"

**Options:**
1. **Use anyway** — I understand my data will be public
2. **Choose a different repo** — Go back to repo selection
3. **Make it private first** — Run `gh repo edit {REPO} --visibility private` then continue

Once repo is confirmed, write config using all defaults:

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

jq -n \
  --arg repo "$REPO" \
  '{
    config_version: "1.3",
    repo: $repo,
    branch_prefix: "prompt-review/",
    base_branch: "main",
    label: "prompt-review",
    capture: { mode: "ask", projects: {} },
    language: "auto",
    created_at: (now | todate)
  }' > "$CONFIG_FILE"
```

Display confirmation:

```
prompt-review configured.

  Review repo:     owner/ai-sessions
  Branch prefix:   prompt-review/  (default)
  Base branch:     main  (default)
  Language:        auto  (default)
  Capture mode:    ask  (asks on first push per project)
  Config version:  1.3
  Config saved:    ~/.claude/prompt-review.config.json

What happens next:
  1. git push     → Prompts auto-captured to prompt repo (commit only)
  2. gh pr create → Prompt review PR created with scoring (or run /review)
  3. /score       → Check prompt quality locally before pushing
  4. /prompt-guide → Get prompt writing tips before starting a task
  5. /insights    → View score trends after multiple sessions

Note: Push hooks activate after restarting Claude Code (if this is your first install).

Tip: Try /score now to see how your current session prompts score.

Advanced: /review --setup --advanced | Doctor: /review --doctor
```

Then proceed to **[CAPTURE FLOW]**.

---

## [SETUP WIZARD]

Accessible via `--setup` flag. Use `--setup --advanced` for the full wizard with all questions.

### Detect Existing Configuration

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

if [ -f "$CONFIG_FILE" ]; then
  REPO=$(jq -r '.repo // empty' "$CONFIG_FILE" 2>/dev/null)
  if [ -n "$REPO" ]; then
    echo "EXISTING_CONFIG=true"
    echo "REPO=$REPO"
  else
    echo "EXISTING_CONFIG=false"
  fi
else
  echo "NO_CONFIG_FILE"
fi
```

If existing config found, show summary and ask:

**Question:** "prompt-review is already configured for `{REPO}`. What would you like to do?"

**Options:**
1. **Use existing config** — Continue with current settings
2. **Reconfigure** — Walk through setup again
3. **Edit one setting** — Change a specific option

---

### Step W-1: Collect the Review Repository

**Question:** "Which GitHub repository should prompt reviews be sent to? (format: owner/repo)"

Examples: `myname/ai-sessions`, `myorg/prompt-reviews`

**Validate:**
- Must match `[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+`
- Check accessibility via `gh repo view`

```bash
REPO="USER_PROVIDED_REPO"

if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI is required."
  echo "Fix:   Install from https://cli.github.com/ then run: gh auth login"
  exit 0
fi

gh repo view "$REPO" --json name 2>/dev/null \
  && echo "REPO_ACCESSIBLE=true" \
  || echo "REPO_ACCESSIBLE=false"

# Check repo visibility
IS_PRIVATE=$(gh repo view "$REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null || echo "unknown")
echo "REPO_IS_PRIVATE=$IS_PRIVATE"
```

If not accessible, offer to create the repo or try a different name.

#### Case A: Repo accessible → check if it has commits

```bash
# Clone and check if repo is empty (no branches/commits)
TEMP_DIR=$(mktemp -d)
GH_TOKEN=$(gh auth token)
git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$TEMP_DIR" 2>/dev/null
if [ $? -ne 0 ] || [ -z "$(git -C "$TEMP_DIR" log --oneline -1 2>/dev/null)" ]; then
  echo "REPO_EMPTY=true"
else
  echo "REPO_EMPTY=false"
fi
rm -rf "$TEMP_DIR"
```

If repo is empty (`REPO_EMPTY=true`), initialize it automatically:

```bash
TEMP_DIR=$(mktemp -d)
GH_TOKEN=$(gh auth token)
git clone "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$TEMP_DIR"
cd "$TEMP_DIR"
echo "# Prompt Reviews" > README.md
mkdir -p sessions
echo "Prompt review sessions are stored here." > sessions/.gitkeep
git add README.md sessions/.gitkeep
git commit -m "Initial commit: prompt reviews repository"
git push -u origin main
cd -
rm -rf "$TEMP_DIR"
```

Tell the user: "Review repository initialized with README and sessions/ directory."

#### Case B: Repo not accessible → offer to create

**Ask:** "Repository `{REPO}` doesn't exist. What would you like to do?"

**Options:**
1. **Create as private** — `gh repo create "$REPO" --private --description "Prompt review PRs from Prompt Craft"` then initialize (same as above)
2. **Create as public** — `gh repo create "$REPO" --public --description "Prompt review PRs from Prompt Craft"` then initialize
3. **Try a different name** — ask again

**Important:** After creating the repo, always run the initialization step (Case A empty repo) to ensure there is at least one commit on the base branch.

#### Case C: Repo accessible and has commits → proceed

No action needed. Proceed to Step W-2.

If `REPO_IS_PRIVATE=false` (public repo), show warning:

**Question:** "Warning: `{REPO}` is a **public repository**. Your prompt session data (including all prompts and code diffs) will be publicly visible. How would you like to proceed?"

**Options:**
1. **Use anyway** — I understand my data will be public
2. **Choose a different repo** — Go back to repo selection
3. **Make it private first** — Run `gh repo edit {REPO} --visibility private` then continue

---

### Step W-2: Capture Mode

**Question:** "How should prompt capture work for your projects?"

**Options:**
1. **Ask on first push** (default) — You'll be asked to enable/disable capture the first time you push from each project
2. **Capture from all projects** — Automatically capture prompts from every project without asking

If option 1, set `capture.mode` to `"ask"`. If option 2, set `capture.mode` to `"all"`.

Manage per-project settings anytime with `/setup-project on|off|list`.

---

### Step W-2.5: Language Preference

**Question:** "What language should prompt review content be written in?"

**Options:**
1. **Auto-detect** (default) — Match the language of your prompts
2. **English** — Always write in English
3. **한국어** — Always write in Korean
4. **Custom** — Enter a language code (e.g. `ja`, `zh`, `de`)

Store in config as `"language": "auto"`, `"language": "en"`, `"language": "ko"`, or the custom code.

---

### Step W-3: Branch and PR Defaults

**Question:** "How should prompt review branches be named?"

**Options:**
1. **`prompt-review/YYYY-MM-DD-slug`** (default)
2. **`review/topic-slug`**
3. **Custom prefix**

Then ask for base branch (`main` or `master` or custom).

---

### Step W-4: Write Configuration

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

jq -n \
  --arg repo "$REPO" \
  --arg branch_prefix "$BRANCH_PREFIX" \
  --arg base_branch "$BASE_BRANCH" \
  --arg label "$LABEL_NAME" \
  --arg capture_mode "$CAPTURE_MODE" \
  --arg language "$LANGUAGE" \
  '{
    config_version: "1.3",
    repo: $repo,
    branch_prefix: $branch_prefix,
    base_branch: $base_branch,
    label: $label,
    capture: { mode: $capture_mode, projects: {} },
    language: $language,
    created_at: (now | todate)
  }' > "$CONFIG_FILE"
```

Where `$CAPTURE_MODE` is:
- `"ask"` if user chose "Ask on first push" (default)
- `"all"` if user chose "Capture from all projects"

Display confirmation:

```
Prompt Craft Setup Complete

Prerequisites:
  ✓ git x.y.z
  ✓ gh x.y.z (authenticated)
  ✓ jq x.y.z

Configuration:
  ✓ Config file: ~/.claude/prompt-review.config.json
    Config version: 1.3
    Review repo:    owner/ai-sessions
    Branch prefix:  prompt-review/
    Base branch:    main
    Capture mode:   ask

What happens next:
  1. git push     → Prompts auto-captured to prompt repo (commit only)
  2. gh pr create → Prompt review PR created with scoring (or run /review)
  3. /score       → Check prompt quality locally before pushing
  4. /prompt-guide → Get prompt writing tips before starting a task
  5. /insights    → View score trends after multiple sessions

Note: Push hooks activate after restarting Claude Code (if this is your first install).

Tip: Try /score now to see how your current session prompts score.

Advanced: /review --setup --advanced | Doctor: /review --doctor
```

---

## [STATUS DISPLAY]

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
[ -f "$CONFIG_FILE" ] || { echo "Not configured. Run: /review --setup"; exit 0; }

REPO=$(jq -r '.repo' "$CONFIG_FILE")
LABEL=$(jq -r '.label // "prompt-review"' "$CONFIG_FILE")

echo "Review repo: $REPO"

gh pr list --repo "$REPO" --label "$LABEL" --limit 10 \
  --json number,title,state,createdAt,url \
  2>/dev/null | jq -r '.[] | "#\(.number)\t\(.state)\t\(.createdAt[:10])\t\(.title)"'
```

---

## [PUSH HOOK] — Record on git push

This runs automatically via Claude Code Hook (`PostToolUse`) when `git push` is detected.

### What It Captures

1. **All prompts** from the current session — **VERBATIM full text, not summaries**
2. **User decisions** — AskUserQuestion selections (question → answer pairs)
3. **Prompt quality score** — 8-criteria scorecard (100 points) with per-prompt mini-scores
4. **Improvement suggestions** — concrete rewrite fragments for low-scoring criteria
5. **Git diff summary** — per-file change table with +/- counts
6. **File change summaries** — AI-generated one-line summary per changed file (flag constraint violations)
7. **Commit list** — SHAs and messages
8. **Session metadata** — YAML block with session ID, branch, counts, and score breakdown

### Critical Rules

- **Respect language setting.** Check `language` in config (`~/.claude/prompt-review.config.json`):
  - `"auto"` (or absent): Detect the dominant language of user prompts in this session. Write Finding, Summary, Improvement Suggestions, delta descriptions, and commit messages in that language.
  - Explicit code (e.g. `"ko"`, `"en"`, `"ja"`): Use that language for the above content.
  - Template structure (section headers, table column names, badge labels like "Excellent"/"Good"/"Needs Work"/"Poor", metadata keys) **always remains in English** regardless of language setting.
- **VERBATIM prompts only.** Paste the EXACT, COMPLETE text of every user prompt. Do NOT summarize, paraphrase, or shorten. Do NOT add "Intent:" labels. If a user typed 5 lines, include all 5 lines.
- **Follow the template exactly.** Use `${CLAUDE_SKILL_DIR}/templates/push-record.md` as the format reference.
- **One section per prompt.** Each prompt gets its own `### Prompt N {MINI_BADGE}` block with a fenced code block containing the raw text, followed by per-prompt mini-scores: `<sub>Goal G/20 · Exit E/10 · Scope S/15 · Context C/15</sub>`.
- **Capture user decisions.** When AskUserQuestion selections follow a prompt, add a `### Decisions after Prompt N` block with a table of question → selected answer pairs.
- **Score all prompts.** Evaluate the entire prompt sequence against 8 criteria (see Step C-3 scoring table). Include the Scorecard table and grade badge in the push record header.
- **Suggest improvements.** For any criterion below 70% of its max, write a concrete "Instead of / Try" rewrite fragment. Omit the Improvement Suggestions section entirely if all criteria score well.
- **Analyze Prompt Gaps (Gap 2).** When a prompt defect led to a code defect, frame it as "Prompt Gap: {prompt deficiency} → {code consequence}". Example: "Missing exit criteria → Claude modified db/sessions.ts beyond stated scope". This is how AI code review is integrated — not as a separate section, but as cause→effect chains linking prompt quality to code outcomes.
- **Flag constraint violations.** In the Code Impact table, mark files that were changed against stated constraints with "**Flagged: constraint violation**".
- **Sanitize user content for markdown.** When embedding user prompts in markdown files, escape characters that could break markdown structure: backtick sequences (` ``` `), pipe characters in table rows, and raw HTML tags. Use fenced code blocks for prompt text (already done) which provides natural escaping. For commit messages and branch names appearing in markdown, strip or escape special characters. The utility at `${CLAUDE_SKILL_DIR}/utils/sanitize-markdown.sh` can be used to validate generated content.

### Payload Limits

To prevent oversized push records:

| Limit | Value | Behavior |
|-------|-------|----------|
| Max file size | 1 MB | Abort push record creation if generated file exceeds 1 MB |
| Max prompt length | 10,000 chars | Truncate individual prompt text at 10,000 chars with `[truncated]` note |
| Max prompts per record | 100 | Include first 100 prompts; add `> Note: N additional prompts omitted` footer |

### Output Format

Creates a file in the prompt repo: `sessions/{branch-name}/push-{NNN}.md`

The push file MUST contain ALL of these sections (see `templates/push-record.md` for full template):

```markdown
# Push #N — BRANCH (DATE)
> GRADE_BADGE **Score: TOTAL/100** | Session: SESSION_ID | Prompts: COUNT | Trigger: git-push-hook

## Prompt Quality Scorecard
| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| ICON | **Goal Clarity** | G/20 | PROGRESS_BAR | one-line finding |
(all 8 criteria...)

## Prompt Sequence
### Prompt 1 MINI_BADGE
\`\`\`
(VERBATIM full text of what the user typed — NEVER summarize)
\`\`\`
<sub>Goal G/20 · Exit E/10 · Scope S/15 · Context C/15</sub>
<!-- delta: one-line description of what changed after this prompt -->
(repeat for every prompt in the session)

### Decisions after Prompt N
| Question | Selected |
|----------|----------|
| question text | selected answer |

## Improvement Suggestions
(only for criteria below 70% of max — omit if all score well)
### Criterion (scored SCORE/MAX)
> What was missing
**Suggested rewrite:**
Instead of: "original"
Try:        "improved"

## Code Impact
> N files changed, +INSERTIONS −DELETIONS
| File | Change | Summary |
|------|--------|---------|
| `path/to/file` | modified (+N, −M) | AI-generated description (**Flagged** if constraint violation) |

## Commits
- [`SHA`](https://github.com/OWNER/REPO/commit/SHA) COMMIT_MESSAGE
```

### Implementation

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
[ -f "$CONFIG_FILE" ] || exit 0

# Rate limiting: skip if last push was within 30 seconds
STATE_FILE="$HOME/.claude/prompt-review-state.json"
if [ -f "$STATE_FILE" ]; then
  LAST_PUSH=$(jq -r '.last_push_ts // 0' "$STATE_FILE" 2>/dev/null || echo 0)
  NOW_TS=$(date +%s)
  ELAPSED=$((NOW_TS - LAST_PUSH))
  if [ "$ELAPSED" -lt 30 ]; then
    echo "prompt-review: skipping push hook (rate limit: last push ${ELAPSED}s ago)" >&2
    exit 0
  fi
fi

REPO=$(jq -r '.repo' "$CONFIG_FILE")
BASE_BRANCH=$(jq -r '.base_branch' "$CONFIG_FILE")
LANGUAGE=$(jq -r '.language // "auto"' "$CONFIG_FILE")
BRANCH=$(git branch --show-current 2>/dev/null)
BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._/-]//g' | head -c 200)
if [ -z "$BRANCH" ]; then
  echo "Error: Branch name is empty or invalid after sanitization." >&2
  exit 1
fi
DATE=$(date +%Y-%m-%d)
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
PROJECT_SLUG=$(echo "$REMOTE_URL" | sed -E 's#^.*[:/]([^/]+/)?##; s#\.git$##')

# Resolve clone URL (lightweight ls-remote probe, no full clone)
CLONE_URL=""
GH_TOKEN=$(gh auth token 2>/dev/null || true)
if [ -n "$GH_TOKEN" ]; then
  HTTPS_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git"
  git ls-remote "$HTTPS_URL" HEAD &>/dev/null && CLONE_URL="$HTTPS_URL"
fi
[ -z "$CLONE_URL" ] && git ls-remote "git@github.com:${REPO}.git" HEAD &>/dev/null && CLONE_URL="git@github.com:${REPO}.git"
[ -z "$CLONE_URL" ] && git ls-remote "git@github-personal:${REPO}.git" HEAD &>/dev/null && CLONE_URL="git@github-personal:${REPO}.git"
[ -z "$CLONE_URL" ] && { echo "Error: Cannot access $REPO via HTTPS or SSH"; exit 0; }

# Check if project branch exists remotely
REMOTE_BRANCH="$PROJECT_SLUG/$BRANCH"
if git ls-remote --heads "$CLONE_URL" "$REMOTE_BRANCH" 2>/dev/null | grep -q .; then
  TARGET_BRANCH="$REMOTE_BRANCH"
else
  TARGET_BRANCH="$BASE_BRANCH"
fi

# Shallow clone of only the needed branch
ARCHIVE_DIR="$(mktemp -d)"
trap '[[ -n "$ARCHIVE_DIR" ]] && rm -rf "$ARCHIVE_DIR"' EXIT
git clone --depth 1 --branch "$TARGET_BRANCH" "$CLONE_URL" "$ARCHIVE_DIR"
cd "$ARCHIVE_DIR"

# If we cloned base branch, create the project branch
if [ "$TARGET_BRANCH" = "$BASE_BRANCH" ]; then
  git checkout -b "$REMOTE_BRANCH"
fi

# Create session directory and determine push number
SESSION_DIR="$ARCHIVE_DIR/sessions/$PROJECT_SLUG/$BRANCH"
mkdir -p "$SESSION_DIR"
PUSH_NUM=$(ls "$SESSION_DIR"/push-*.md 2>/dev/null | wc -l | tr -d ' ')
PUSH_NUM=$((PUSH_NUM + 1))
PUSH_FILE="$SESSION_DIR/push-$(printf '%03d' $PUSH_NUM).md"

# === AI FILE GENERATION STEP (not bash — Claude performs this) ===
# You MUST generate the push record content and write it to $PUSH_FILE before continuing.
#
# 1. Collect ALL user prompts from your current session context (verbatim, not summarized)
# 2. Run: git log --oneline $(git merge-base HEAD origin/$BASE_BRANCH)..HEAD
# 3. Run: git diff --stat $(git merge-base HEAD origin/$BASE_BRANCH)..HEAD
# 4. Score all prompts against the 8 criteria (see Step C-3 scoring table)
# 5. Format everything per ${CLAUDE_SKILL_DIR}/templates/push-record.md
# 6. Apply language setting ($LANGUAGE):
#    - "auto": detect the dominant language of user prompts; write Finding,
#      Summary, Improvement Suggestions, delta descriptions, and the commit
#      message topic in that language.
#    - Explicit code (e.g. "ko"): use that language for the above content.
#    - Section headers, table column names, and badge labels stay in English.
# 7. Write the result to $PUSH_FILE using the Write tool or cat <<'EOF' > "$PUSH_FILE"
# 8. Set COMMIT_SUMMARY to a concise one-line summary of the session's work
#    (e.g. "add circle diameter endpoint and negative input auto-correction").
#    This becomes the commit message. Write in the $LANGUAGE setting.
# 9. Then continue with the size check and git commit below.
# ===

# Size check: abort if push file exceeds 1 MB
if [ -f "$PUSH_FILE" ]; then
  FILE_SIZE=$(wc -c < "$PUSH_FILE" | tr -d ' ')
  if [ "$FILE_SIZE" -gt 1048576 ]; then
    echo "Error: Push record exceeds 1 MB limit (${FILE_SIZE} bytes). Aborting." >&2
    exit 1
  fi
fi

git add .
# COMMIT_SUMMARY is set by the AI generation step above.
# It should be a concise one-line summary of what this session accomplished
# (e.g. "add circle diameter endpoint and negative input auto-correction").
# Write in the language determined by $LANGUAGE setting.
git commit -m "$COMMIT_SUMMARY (#$PUSH_NUM)"
git push origin "$PROJECT_SLUG/$BRANCH"

# Update state file with last push timestamp
mkdir -p "$(dirname "$STATE_FILE")"
if [ -f "$STATE_FILE" ]; then
  jq --argjson ts "$(date +%s)" '.last_push_ts = $ts' "$STATE_FILE" > "${STATE_FILE}.tmp" \
    && mv "${STATE_FILE}.tmp" "$STATE_FILE"
else
  jq -n --argjson ts "$(date +%s)" '{"last_push_ts": $ts}' > "$STATE_FILE"
fi
```

### Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| HTTPS clone fails | SSH-only auth or multi-account setup | Script auto-falls back to SSH |
| Branch already exists | Previous push created it | Script fetches and checks out existing branch |
| Push number conflict | Race condition | Script counts existing files to determine next number |

---

## [CAPTURE FLOW] — Create Prompt Review PR

This runs when the user invokes `/review` or when `gh pr create` is detected.

---

### Step C-1: Pre-flight Checks

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

[ -f "$CONFIG_FILE" ] || { echo "NO_CONFIG"; exit 0; }
command -v gh &>/dev/null || { echo "NO_GH_CLI"; exit 0; }
gh auth status &>/dev/null || { echo "NOT_AUTHENTICATED"; exit 0; }

REPO=$(jq -r '.repo' "$CONFIG_FILE")
BASE_BRANCH=$(jq -r '.base_branch' "$CONFIG_FILE")
BRANCH_PREFIX=$(jq -r '.branch_prefix' "$CONFIG_FILE")
LABEL=$(jq -r '.label // "prompt-review"' "$CONFIG_FILE")
LANGUAGE=$(jq -r '.language // "auto"' "$CONFIG_FILE")

# Check repo visibility
IS_PRIVATE=$(gh repo view "$REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null || echo "unknown")
echo "REPO_IS_PRIVATE=$IS_PRIVATE"

echo "READY"
```

If `REPO_IS_PRIVATE=false` (public repo), show warning:

**Question:** "Warning: `{REPO}` is a **public repository**. Your prompt session data will be publicly visible. Continue?"

**Options:**
1. **Continue** — I understand my data will be public
2. **Abort** — Stop and let me switch to a private repo

---

### Step C-2: Collect Push Records

Gather all push-*.md files for the current branch from the prompt repo:

```bash
BRANCH=$(git branch --show-current 2>/dev/null)
BRANCH=$(echo "$BRANCH" | sed 's/[^a-zA-Z0-9._/-]//g' | head -c 200)
if [ -z "$BRANCH" ]; then
  echo "Error: Branch name is empty or invalid after sanitization." >&2
  exit 1
fi
REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
PROJECT_SLUG=$(echo "$REMOTE_URL" | sed -E 's#^.*[:/]([^/]+/)?##; s#\.git$##')
# Resolve clone URL (lightweight ls-remote probe)
CLONE_URL=""
GH_TOKEN=$(gh auth token 2>/dev/null || true)
if [ -n "$GH_TOKEN" ]; then
  HTTPS_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git"
  git ls-remote "$HTTPS_URL" HEAD &>/dev/null && CLONE_URL="$HTTPS_URL"
fi
[ -z "$CLONE_URL" ] && git ls-remote "git@github.com:${REPO}.git" HEAD &>/dev/null && CLONE_URL="git@github.com:${REPO}.git"
[ -z "$CLONE_URL" ] && git ls-remote "git@github-personal:${REPO}.git" HEAD &>/dev/null && CLONE_URL="git@github-personal:${REPO}.git"
[ -z "$CLONE_URL" ] && { echo "Error: Cannot access $REPO via HTTPS or SSH"; exit 0; }

# Check if project branch exists remotely
REMOTE_BRANCH="$PROJECT_SLUG/$BRANCH"
if git ls-remote --heads "$CLONE_URL" "$REMOTE_BRANCH" 2>/dev/null | grep -q .; then
  TARGET_BRANCH="$REMOTE_BRANCH"
else
  TARGET_BRANCH="$BASE_BRANCH"
fi

# Shallow clone of only the needed branch
ARCHIVE_DIR="$(mktemp -d)"
trap '[[ -n "$ARCHIVE_DIR" ]] && rm -rf "$ARCHIVE_DIR"' EXIT
git clone --depth 1 --branch "$TARGET_BRANCH" "$CLONE_URL" "$ARCHIVE_DIR"
cd "$ARCHIVE_DIR"
if [ "$TARGET_BRANCH" = "$BASE_BRANCH" ]; then
  git checkout -b "$REMOTE_BRANCH"
fi
SESSION_DIR="$ARCHIVE_DIR/sessions/$PROJECT_SLUG/$BRANCH"

if [ ! -d "$SESSION_DIR" ] || [ -z "$(ls "$SESSION_DIR"/push-*.md 2>/dev/null)" ]; then
  echo "NO_PUSH_RECORDS"
  # Fall back to capturing current session directly
fi
```

If no push records exist (user never pushed, or ran `/review` manually), capture the current session directly (same as push hook, but inline).

---

### Step C-3: Score Prompts (LLM — single call)

Score all collected prompts against 8 criteria in a single LLM call.

**Scoring criteria (100 points total):**

| # | Criterion | Points | What to evaluate |
|---|-----------|--------|------------------|
| 1 | **Goal Clarity** | 20 | Is the goal specific? Does the result match the intent? |
| 2 | **Exit Criteria** | 10 | Are completion/stop conditions stated? Did Claude stop appropriately? |
| 3 | **Scope Control** | 15 | Are boundaries set? Constraints stated? No out-of-scope changes? |
| 4 | **Context Sufficiency** | 15 | Enough background provided? Reference code/patterns specified? |
| 5 | **Decomposition** | 10 | Are complex tasks broken into steps? |
| 6 | **Verification Strategy** | 10 | Verification method specified? Failure behavior defined? |
| 7 | **Iteration Quality** | 10 | Are follow-up requests specific? (N/A for single-prompt → redistribute) |
| 8 | **Complexity Fit** | 10 | Is prompt sophistication appropriate for task complexity? |

**N/A rule:** If Iteration Quality is not applicable (single prompt session), redistribute its 10 points proportionally across the other 7 criteria.

**Grade bands:** 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor

**Per-prompt mini-scores:** Each prompt gets inline scores for Goal/Exit/Scope/Context to help reviewers identify problematic prompts.

**Improvement suggestions:** For any criterion scoring below 70% of its max, generate a concrete "suggested rewrite fragment" — not abstract advice, but actual text the author could have used.

**Language:** Apply the `$LANGUAGE` setting when writing Finding text, Improvement Suggestions (description + rewrite fragment), and delta descriptions. If `"auto"`, detect the dominant language of the scored prompts. Section headers, column names, and badge labels stay in English.

---

### Step C-4: Secret Scanning (Mandatory Gate)

Scan the generated content for secrets before creating the PR. **Non-negotiable — no data leaves the machine without scanning.**

Run the secret scanner from the skill directory:

```bash
"${CLAUDE_SKILL_DIR}/utils/secret-scan.sh" "$PR_BODY_FILE"
```

If secrets detected, ask user to redact, confirm false positive, or abort.

---

### Step C-5: Generate PR Content

**PR Title:** `[Prompt Review] {date} — {topic} — @{author}`

The `{topic}` portion of the PR title should be written in the configured language (auto-detected or explicit). The `[Prompt Review]` prefix, date, and `@{author}` remain in English.

**PR Body:** Follow the template at `${CLAUDE_SKILL_DIR}/templates/prompt-review.md`. See the filled example at `${CLAUDE_SKILL_DIR}/templates/prompt-review-example.md` for reference.

Apply the `$LANGUAGE` setting: write Finding, Summary, Improvement Suggestions, Prompt Sequence delta descriptions, and Code Impact summaries in the configured language. Section headers, table column names, and badge labels remain in English.

Use session ID `${CLAUDE_SESSION_ID}` in the metadata section.

---

### Step C-6: Create the PR

```bash
PR_BODY_FILE="$(mktemp)"

echo "  [1/5] Cloning review repository..."
# Resolve clone URL (lightweight ls-remote probe)
CLONE_URL=""
GH_TOKEN=$(gh auth token 2>/dev/null || true)
if [ -n "$GH_TOKEN" ]; then
  HTTPS_URL="https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git"
  git ls-remote "$HTTPS_URL" HEAD &>/dev/null && CLONE_URL="$HTTPS_URL"
fi
[ -z "$CLONE_URL" ] && git ls-remote "git@github.com:${REPO}.git" HEAD &>/dev/null && CLONE_URL="git@github.com:${REPO}.git"
[ -z "$CLONE_URL" ] && git ls-remote "git@github-personal:${REPO}.git" HEAD &>/dev/null && CLONE_URL="git@github-personal:${REPO}.git"
[ -z "$CLONE_URL" ] && { echo "Error: Cannot access $REPO via HTTPS or SSH"; exit 0; }

ARCHIVE_DIR="$(mktemp -d)"
trap '[[ -n "$ARCHIVE_DIR" ]] && rm -rf "$ARCHIVE_DIR" "$PR_BODY_FILE"' EXIT
git clone --depth 1 --branch "$BASE_BRANCH" "$CLONE_URL" "$ARCHIVE_DIR"

echo "  [2/5] Creating branch..."
cd "$ARCHIVE_DIR"
git checkout -b "$BRANCH" "origin/$BASE_BRANCH"

echo "  [3/5] Writing session files..."
mkdir -p "sessions/$PROJECT_SLUG/$PROJECT_BRANCH"
# Copy accumulated push records into the branch

echo "  [4/5] Pushing..."
git add .
# COMMIT_SUMMARY is set during PR content generation (Step C-5).
# One-line summary of what the session accomplished, in $LANGUAGE.
git commit -m "$COMMIT_SUMMARY"
git push origin "$BRANCH"

echo "  [5/5] Creating PR..."

# Derive project slug label from REPO (owner/repo → project/repo)
PROJECT_SLUG=$(echo "$REPO" | cut -d'/' -f2 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
PROJECT_LABEL="project/$PROJECT_SLUG"

# Determine quality label based on score
# TOTAL_SCORE is set earlier when generating PR content
if [ "${TOTAL_SCORE:-0}" -ge 90 ]; then
  QUALITY_LABEL="prompt-quality/excellent"
elif [ "${TOTAL_SCORE:-0}" -ge 70 ]; then
  QUALITY_LABEL="prompt-quality/good"
elif [ "${TOTAL_SCORE:-0}" -ge 50 ]; then
  QUALITY_LABEL="prompt-quality/needs-work"
else
  QUALITY_LABEL="prompt-quality/poor"
fi

# Ensure labels exist in the review repo (idempotent)
gh label create "prompt-quality/excellent" --color "0e8a16" --description "Score 90-100" --repo "$REPO" --force 2>/dev/null || true
gh label create "prompt-quality/good"      --color "0075ca" --description "Score 70-89" --repo "$REPO" --force 2>/dev/null || true
gh label create "prompt-quality/needs-work" --color "e4e669" --description "Score 50-69" --repo "$REPO" --force 2>/dev/null || true
gh label create "prompt-quality/poor"      --color "d93f0b" --description "Score 0-49"  --repo "$REPO" --force 2>/dev/null || true
gh label create "$PROJECT_LABEL"           --color "bfd4f2" --description "Project: $PROJECT_SLUG" --repo "$REPO" --force 2>/dev/null || true

PR_URL=$(gh pr create \
  --repo "$REPO" \
  --base "$BASE_BRANCH" \
  --head "$BRANCH" \
  --title "$TITLE" \
  --body-file "$PR_BODY_FILE" \
  --label "$LABEL" \
  --label "$QUALITY_LABEL" \
  --label "$PROJECT_LABEL")

echo "Prompt review PR created: $PR_URL"
echo "  Score: {TOTAL}/100 ({GRADE})"
echo "  Assign a reviewer to start the prompt review."
```

### Labels

PRs are automatically labeled with:

| Label | Applied when | Color |
|-------|-------------|-------|
| `prompt-quality/excellent` | Score 90–100 | Green |
| `prompt-quality/good` | Score 70–89 | Blue |
| `prompt-quality/needs-work` | Score 50–69 | Yellow |
| `prompt-quality/poor` | Score 0–49 | Red |
| `project/{slug}` | Always (derived from project repo name) | Light blue |

Labels are created with `gh label create --force` before PR creation, so they are always available even in a fresh review repo.

---

### Step C-7: Post-creation

**Question:** "PR created at {PR_URL}. What next?"

**Options:**
1. **Open in browser**
2. **Copy URL**
3. **Done**

---

## Error Handling

All errors use this format:

```
Error: [what went wrong]
Cause: [why it happened]
Fix:   [exact command to resolve]
```

| Error | Message |
|-------|---------|
| gh CLI not found | `Error: gh CLI is required.` / `Cause: GitHub CLI not installed.` / `Fix: Install from https://cli.github.com/ then run: gh auth login` |
| Not authenticated | `Error: Not authenticated with GitHub.` / `Cause: gh auth session expired or not configured.` / `Fix: Run: gh auth login` |
| Repo not accessible | `Error: Cannot access {REPO}.` / `Cause: Repository doesn't exist or you lack access.` / `Fix: Check the name or run /review --setup to reconfigure.` |
| Push failed | `Error: Push to {REPO} failed.` / `Cause: Insufficient write permissions.` / `Fix: Check write permissions: gh auth status` |
| No push records | `Error: No prompt data found.` / `Cause: No git push happened in this session yet.` / `Fix: Push some code first, or capture current session directly.` |
| Secret scan found sensitive data | `Error: Sensitive data detected in prompt content.` / `Cause: Potential secrets found (API keys, tokens, passwords).` / `Fix: Redact the flagged content, confirm false positive, or abort.` |
| Rate limited | `Error: Push captured too recently.` / `Cause: Last push was less than 30 seconds ago.` / `Fix: Wait 30 seconds and push again.` |
| File size exceeded | `Error: Push record exceeds 1 MB limit.` / `Cause: Too many prompts or large code diffs in this session.` / `Fix: Split work into smaller sessions with fewer prompts.` |

---

## Configuration

Config file: `~/.claude/prompt-review.config.json`

```json
{
  "config_version": "1.3",
  "repo": "owner/ai-sessions",
  "branch_prefix": "prompt-review/",
  "base_branch": "main",
  "label": "prompt-review",
  "capture": {
    "mode": "ask",
    "projects": {
      "owner/project-a": { "status": "allow", "repo": "owner/custom-reviews" },
      "owner/project-b": { "status": "allow" },
      "owner/personal-notes": { "status": "deny" }
    }
  },
  "language": "auto",
  "created_at": "2026-03-08T12:00:00Z"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `config_version` | Yes | Config schema version for future migrations (e.g., `"1.3"`) |
| `repo` | Yes | Default review repository (where prompt PRs are created) |
| `branch_prefix` | Yes | Branch name prefix for prompt review branches |
| `base_branch` | Yes | Base branch in the review repo |
| `label` | Yes | Default label applied to prompt review PRs |
| `capture.mode` | Yes | `"ask"` (default, ask on first push) or `"all"` (capture from all projects) |
| `capture.projects` | No | Map of `owner/repo` → `{ "status": "allow"\|"deny", "repo": "..." }`. Projects with `"allow"` are captured; `"deny"` projects are silently skipped. Optional `"repo"` overrides the default review repo for that project. Use `/setup-project` to manage. |
| `language` | No | Language for generated content. `"auto"` (default) detects the dominant language of user prompts. Explicit codes like `"en"`, `"ko"`, `"ja"`, `"zh"` force that language. Template structure (headers, column names, badges) always remains in English. |

---

## [PROJECT MANAGEMENT] — Redirect to /setup-project

Per-project capture settings are managed via the `/setup-project` skill. When project management intent is detected, redirect:

```
Use /setup-project to manage per-project capture settings:

  /setup-project              Show current project status
  /setup-project on           Enable capture for this project
  /setup-project on --repo R  Enable with a specific review repo
  /setup-project off          Disable capture for this project
  /setup-project list         Show all project settings
  /setup-project reset        Re-enable asking for a skipped project
```

Invoke the `/setup-project` skill via the Skill tool with the appropriate arguments (`on`, `off`, `list`, `reset`, or empty for status).

### Just-in-Time Opt-in

When the push hook detects a project not yet in `capture.projects`, it asks:

**Question:** "Enable prompt capture for {PROJECT}?"

**Options:**
1. **Yes** — Sets `capture.projects[project].status = "allow"` in config, asks which repo to use, then runs capture
2. **No** — Sets `capture.projects[project].status = "deny"` in config. Silently skipped on future pushes.

Use `/setup-project reset` to re-enable asking for a previously denied project.

This means the project list builds organically through normal development workflow. No upfront setup required.

---

## Design Principles

1. **Zero project repo footprint.** Never modify the project repository. Links are one-directional: session → commit only.
2. **Two-phase capture.** Record incrementally on push (low cost), score and create PR on feature completion (high value).
3. **Prompts are the review target, code is evidence.** Code changes are included only to verify whether prompts were effective.
4. **Score to guide, not to gatekeep.** Scores are learning signals, not pass/fail gates.
5. **Fail loudly, recover cleanly.** Stop on error with clear message and recovery command.
6. **Full capture, simple state.** Each push saves the entire current session. Deduplication happens at PR creation time.
7. **Lazy by default.** First-time setup asks only what is necessary. Advanced configuration is opt-in via `--advanced`.

---

## PR Reading Levels

Prompt review PRs use a 4-level progressive disclosure structure so reviewers can engage at the depth they choose:

| Level | Section | Audience | What it shows |
|-------|---------|----------|---------------|
| **Level 1** | Score header | Everyone | Grade badge, total score, one-line summary — instant triage |
| **Level 2** | Scorecard + Code Delta | Team leads, async reviewers | 8-criterion breakdown with progress bars + what code was produced |
| **Level 3** | Prompt Sequence + Improvement Tips | Detailed reviewers | Verbatim prompts with per-prompt mini-scores, delta annotations, and concrete rewrite suggestions |
| **Level 4** | Reviewer Checklist + Session Metadata | Deep reviewers, auditors | Structured checklist for leaving review comments + full YAML metadata |

Levels 3 and 4 use `<details>` collapse blocks in the PR body so the PR remains scannable at a glance.

> **Note on push records:** Push record files (`sessions/{project-slug}/{branch}/push-NNN.md`) do **not** use `<details>` tags. Push records are committed directly to the `{project-slug}/{branch}` branch and are consumed programmatically when building the PR — they must be plain markdown without HTML tags that would appear as raw text in git diffs.
