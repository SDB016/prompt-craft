---
name: prompt-review
description: Capture prompts from Claude Code sessions and create prompt review PRs for team feedback. Use when asked to review prompts, create prompt PR, or share session prompts.
argument-hint: "[--push] [--setup] [--status]"
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
| `/prompt-review` (manual) | Create PR at desired time | **Create PR** |

This means:
- During development, each push records prompts incrementally
- When the feature is done (code PR created), the prompt review PR is also created
- Multi-session and multi-day work is naturally supported

---

## Step 0: Route the Request

- If `$ARGUMENTS` contains `--push` → jump to **[PUSH HOOK]**
- If `$ARGUMENTS` contains `--setup` → jump to **[SETUP WIZARD]**
- If `$ARGUMENTS` contains `--status` → jump to **[STATUS DISPLAY]**
- If no config exists at `~/.claude/prompt-review.config.json` → run **[SETUP WIZARD]** first
- Otherwise → proceed to **[CAPTURE FLOW]**

---

## [SETUP WIZARD]

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
```

If not accessible, offer to create the repo or try a different name.

---

### Step W-2: Branch and PR Defaults

**Question:** "How should prompt review branches be named?"

**Options:**
1. **`prompt-review/YYYY-MM-DD-slug`** (default)
2. **`review/topic-slug`**
3. **Custom prefix**

Then ask for base branch (`main` or `master` or custom).

---

### Step W-3: Write Configuration

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

jq -n \
  --arg repo "$REPO" \
  --arg branch_prefix "$BRANCH_PREFIX" \
  --arg base_branch "$BASE_BRANCH" \
  --arg label "$LABEL_NAME" \
  '{
    repo: $repo,
    branch_prefix: $branch_prefix,
    base_branch: $base_branch,
    label: $label,
    created_at: (now | todate)
  }' > "$CONFIG_FILE"
```

Display confirmation:
```
prompt-review configured.

  Review repo:     owner/ai-sessions
  Branch prefix:   prompt-review/
  Base branch:     main
  Config saved:    ~/.claude/prompt-review.config.json

Prompt data will be recorded on each git push.
A review PR will be created when you run gh pr create or /prompt-review.
```

---

## [STATUS DISPLAY]

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
[ -f "$CONFIG_FILE" ] || { echo "Not configured. Run: /prompt-review --setup"; exit 0; }

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

- **VERBATIM prompts only.** Paste the EXACT, COMPLETE text of every user prompt. Do NOT summarize, paraphrase, or shorten. Do NOT add "Intent:" labels. If a user typed 5 lines, include all 5 lines.
- **Follow the template exactly.** Use `${CLAUDE_SKILL_DIR}/templates/push-record.md` as the format reference.
- **One section per prompt.** Each prompt gets its own `### Prompt N {MINI_BADGE}` block with a fenced code block containing the raw text, followed by per-prompt mini-scores: `<sub>Goal G/20 · Exit E/10 · Scope S/15 · Context C/15</sub>`.
- **Capture user decisions.** When AskUserQuestion selections follow a prompt, add a `### Decisions after Prompt N` block with a table of question → selected answer pairs.
- **Score all prompts.** Evaluate the entire prompt sequence against 8 criteria (see Step C-3 scoring table). Include the Scorecard table and grade badge in the push record header.
- **Suggest improvements.** For any criterion below 70% of its max, write a concrete "Instead of / Try" rewrite fragment. Omit the Improvement Suggestions section entirely if all criteria score well.
- **Analyze Prompt Gaps (Gap 2).** When a prompt defect led to a code defect, frame it as "Prompt Gap: {prompt deficiency} → {code consequence}". Example: "Missing exit criteria → Claude modified db/sessions.ts beyond stated scope". This is how AI code review is integrated — not as a separate section, but as cause→effect chains linking prompt quality to code outcomes.
- **Flag constraint violations.** In the Code Impact table, mark files that were changed against stated constraints with "**Flagged: constraint violation**".

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
- `SHA` COMMIT_MESSAGE

## Session Metadata
\`\`\`yaml
session_id: ...
project_repo: OWNER/REPO
project_branch: BRANCH
prompt_count: N
push_number: N
triggered_by: git-push-hook
date: YYYY-MM-DD
score:
  total: N
  goal_clarity: G
  scope_control: S
  context_sufficiency: C
  exit_criteria: E
  decomposition: D
  verification_strategy: V
  iteration_quality: I
  complexity_fit: CF
  grade: GRADE
\`\`\`
```

### Implementation

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
[ -f "$CONFIG_FILE" ] || exit 0

REPO=$(jq -r '.repo' "$CONFIG_FILE")
BASE_BRANCH=$(jq -r '.base_branch' "$CONFIG_FILE")
BRANCH=$(git branch --show-current 2>/dev/null)
DATE=$(date +%Y-%m-%d)

ARCHIVE_DIR="$(mktemp -d)"
trap '[[ -n "$ARCHIVE_DIR" ]] && rm -rf "$ARCHIVE_DIR"' EXIT

# Clone the prompt review repo
# Try HTTPS + token first, fall back to SSH if it fails
GH_TOKEN=$(gh auth token 2>/dev/null || true)
if [ -n "$GH_TOKEN" ]; then
  git clone "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$ARCHIVE_DIR" 2>/dev/null
fi
if [ ! -d "$ARCHIVE_DIR/.git" ]; then
  # HTTPS failed — try SSH variants
  git clone "git@github.com:${REPO}.git" "$ARCHIVE_DIR" 2>/dev/null \
    || git clone "git@github-personal:${REPO}.git" "$ARCHIVE_DIR" 2>/dev/null \
    || { echo "Error: Cannot clone $REPO via HTTPS or SSH"; exit 0; }
fi

# Switch to the prompt-data branch (create or checkout existing)
cd "$ARCHIVE_DIR"
git fetch origin "prompt-data/$BRANCH" 2>/dev/null || true
if git rev-parse --verify "origin/prompt-data/$BRANCH" &>/dev/null; then
  git checkout -b "prompt-data/$BRANCH" "origin/prompt-data/$BRANCH"
else
  git checkout -b "prompt-data/$BRANCH" "origin/$BASE_BRANCH"
fi

# Create session directory and determine push number
SESSION_DIR="$ARCHIVE_DIR/sessions/$BRANCH"
mkdir -p "$SESSION_DIR"
PUSH_NUM=$(ls "$SESSION_DIR"/push-*.md 2>/dev/null | wc -l | tr -d ' ')
PUSH_NUM=$((PUSH_NUM + 1))
PUSH_FILE="$SESSION_DIR/push-$(printf '%03d' $PUSH_NUM).md"

# AI writes push file content following templates/push-record.md format
# (Claude generates the content based on session context + git diff)

git add .
git commit -m "push: $BRANCH push #$PUSH_NUM ($DATE)"
git push origin "prompt-data/$BRANCH"
```

### Error Recovery

| Error | Cause | Fix |
|-------|-------|-----|
| HTTPS clone fails | SSH-only auth or multi-account setup | Script auto-falls back to SSH |
| Branch already exists | Previous push created it | Script fetches and checks out existing branch |
| Push number conflict | Race condition | Script counts existing files to determine next number |

---

## [CAPTURE FLOW] — Create Prompt Review PR

This runs when the user invokes `/prompt-review` or when `gh pr create` is detected.

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

echo "READY"
```

---

### Step C-2: Collect Push Records

Gather all push-*.md files for the current branch from the prompt repo:

```bash
BRANCH=$(git branch --show-current 2>/dev/null)
ARCHIVE_DIR="$(mktemp -d)"
trap '[[ -n "$ARCHIVE_DIR" ]] && rm -rf "$ARCHIVE_DIR"' EXIT

GH_TOKEN=$(gh auth token)
git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$ARCHIVE_DIR"
SESSION_DIR="$ARCHIVE_DIR/sessions/$BRANCH"

if [ ! -d "$SESSION_DIR" ] || [ -z "$(ls "$SESSION_DIR"/push-*.md 2>/dev/null)" ]; then
  echo "NO_PUSH_RECORDS"
  # Fall back to capturing current session directly
fi
```

If no push records exist (user never pushed, or ran `/prompt-review` manually), capture the current session directly (same as push hook, but inline).

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

**PR Body:** Follow the template at `${CLAUDE_SKILL_DIR}/templates/prompt-review.md`. See the filled example at `${CLAUDE_SKILL_DIR}/templates/prompt-review-example.md` for reference.

Use session ID `${CLAUDE_SESSION_ID}` in the metadata section.

---

### Step C-6: Create the PR

```bash
ARCHIVE_DIR="$(mktemp -d)"
PR_BODY_FILE="$(mktemp)"
trap '[[ -n "$ARCHIVE_DIR" ]] && rm -rf "$ARCHIVE_DIR" "$PR_BODY_FILE"' EXIT

echo "  [1/5] Cloning review repository..."
GH_TOKEN=$(gh auth token)
git clone --depth 1 "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$ARCHIVE_DIR"

echo "  [2/5] Creating branch..."
cd "$ARCHIVE_DIR"
git checkout -b "$BRANCH" "origin/$BASE_BRANCH"

echo "  [3/5] Writing session files..."
mkdir -p "sessions/$PROJECT_BRANCH"
# Copy accumulated push records into the branch

echo "  [4/5] Pushing..."
git add .
git commit -m "prompt-review: $PROJECT_BRANCH"
git push origin "$BRANCH"

echo "  [5/5] Creating PR..."
PR_URL=$(gh pr create \
  --repo "$REPO" \
  --base "$BASE_BRANCH" \
  --head "$BRANCH" \
  --title "$TITLE" \
  --body-file "$PR_BODY_FILE" \
  --label "$LABEL")

echo "Prompt review PR created: $PR_URL"
echo "  Score: {TOTAL}/100 ({GRADE})"
echo "  Assign a reviewer to start the prompt review."
```

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
| gh CLI not found | `Install from https://cli.github.com/ then: gh auth login` |
| Not authenticated | `Run: gh auth login` |
| Repo not accessible | `Cannot access {REPO}. Check name or run --setup` |
| Push failed | `Check write permissions: gh auth status` |
| No push records | `No prompt data found. Push some code first, or capture current session directly.` |

---

## Configuration

Config file: `~/.claude/prompt-review.config.json`

```json
{
  "repo": "owner/ai-sessions",
  "branch_prefix": "prompt-review/",
  "base_branch": "main",
  "label": "prompt-review",
  "created_at": "2026-03-08T12:00:00Z"
}
```

---

## Design Principles

1. **Zero project repo footprint.** Never modify the project repository. Links are one-directional: session → commit only.
2. **Two-phase capture.** Record incrementally on push (low cost), score and create PR on feature completion (high value).
3. **Prompts are the review target, code is evidence.** Code changes are included only to verify whether prompts were effective.
4. **Score to guide, not to gatekeep.** Scores are learning signals, not pass/fail gates.
5. **Fail loudly, recover cleanly.** Stop on error with clear message and recovery command.
6. **Full capture, simple state.** Each push saves the entire current session. Deduplication happens at PR creation time.
