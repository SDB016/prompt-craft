---
name: prompt-replay
description: Extract and display high-scoring prompt patterns from past prompt review PRs, helping the team learn from their best work. Use when asked to replay prompts, show prompt patterns, or find best prompts.
argument-hint: "[--min-score N] [--criterion NAME] [--author USER]"
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
---

# Prompt Replay — Learn from Your Best Prompts

Mines closed prompt review PRs for high-scoring patterns and surfaces them as reusable templates.

> "Don't just review prompts — replay the winners."

**Received arguments:** $ARGUMENTS

---

## Step 0: Parse Arguments and Load Config

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "NO_CONFIG"
  echo "Error: No prompt-review config found."
  echo "Cause: prompt-replay reads from the same repo as prompt-review."
  echo "Fix:   Run /prompt-review --setup first."
  exit 0
fi

REPO=$(jq -r '.repo' "$CONFIG_FILE")
LABEL=$(jq -r '.label // "prompt-review"' "$CONFIG_FILE")

echo "REPO=$REPO"
echo "LABEL=$LABEL"
```

Parse `$ARGUMENTS` for:
- `--min-score N` — minimum total score to include (default: 80)
- `--criterion NAME` — filter to a specific criterion (e.g., "goal-clarity", "exit-criteria", "scope-control", "context-sufficiency", "decomposition", "verification", "iteration", "complexity-fit")
- `--author USER` — filter to PRs by a specific GitHub user

---

## Step 1: Fetch Closed Prompt Review PRs

```bash
MIN_SCORE="${MIN_SCORE:-80}"

gh pr list --repo "$REPO" --label "$LABEL" --state merged --limit 50 \
  --json number,title,body,author,mergedAt,url \
  --jq '.[] | {number, title, body, author: .author.login, mergedAt, url}'
```

If `--author` is set, filter results to matching author.

If no PRs found:
```
No merged prompt review PRs found in {REPO}.
Create some with /prompt-review first.
```

---

## Step 2: Extract Scores and Prompts

For each PR body, extract:
1. **Total score** (e.g., `85/100`)
2. **Per-criterion scores** from the scorecard table
3. **Prompt text** from the per-prompt breakdown sections
4. **Author** from the PR metadata

Filter to PRs where total score >= `MIN_SCORE`.

If `--criterion` is set, further filter to PRs where that criterion scores >= 70% of its max points.

Track how many PRs were scanned vs. how many qualified:
```
Scanned {TOTAL} merged PRs, {QUALIFIED} scored {MIN_SCORE}+.
```

---

## Step 3: Identify Patterns

Group high-scoring prompts by which criteria they excelled at. Look for recurring structural patterns:

**Pattern detection rules:**

| Pattern Name | How to detect |
|-------------|---------------|
| Verb + file + done-when | Starts with action verb, names specific files, contains "done when" or "complete when" |
| Context-What-Done blocks | Has distinct sections for background, action, and completion |
| Explicit stop boundary | Contains "stop after", "do not modify", "only touch" |
| Verification inline | Contains "verify by", "test by", "confirm that" |
| Step-by-step decomposition | Uses numbered steps or "first...then...finally" |
| Constraint anchoring | Re-states constraints from earlier prompts |

Count how many high-scoring prompts match each pattern.

---

## Step 4: Display Results

Format output as follows:

```
Prompt Replay — Top patterns from {N} reviews

🟢 {Criterion} patterns (avg {SCORE}/{MAX}):

  Pattern: "{pattern description}"
  Example ({TOTAL}/100, @{AUTHOR}):
    "{truncated prompt text, max 160 chars}"

  Pattern: "{pattern description}"
  Used in {COUNT}/{TOTAL} high-scoring sessions.

🟢 {Next Criterion} patterns (avg {SCORE}/{MAX}):

  ...

Team tip: {insight derived from the data}.
```

**Display rules:**
- Only show criteria sections where at least one pattern was found
- Sort criteria sections by average score descending
- Show at most 3 patterns per criterion
- For each pattern, show the single best example (highest total score)
- Truncate prompt examples at 160 characters with "..."
- If `--criterion` is set, show only that criterion's section in expanded form (up to 5 patterns, 3 examples each)

**Team tip generation:**
Compare average scores of prompts with vs. without common structural elements:
- "Sessions with explicit 'Done when' score {N} points higher on average."
- "Prompts naming specific files score {N} points higher on Goal Clarity."
- "Step-by-step prompts score {N} points higher on Decomposition."

Pick the tip with the largest point differential.

---

## Step 5: Closing

Always end with:

```
Source: {REPO} — {QUALIFIED} PRs scored {MIN_SCORE}+
Run /prompt-review to add your sessions to the dataset.
```

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
| Repo not accessible | `Cannot access {REPO}. Check name or run /prompt-review --setup` |
| No merged PRs | `No merged prompt review PRs found. Create some with /prompt-review first.` |
| No PRs meet threshold | `No PRs scored {MIN_SCORE}+. Try lowering: /prompt-replay --min-score 60` |

---

## Design Principles

1. **Read-only.** Never modifies the prompt review repo. Pure analysis of existing PR data.
2. **Pattern-first.** Surfaces reusable patterns, not raw data. The goal is learning, not auditing.
3. **Same ecosystem.** Reads from the same repo and config as `/prompt-review`. No separate setup.
4. **Actionable output.** Every pattern includes a concrete example the team can copy and adapt.
5. **Graceful degradation.** Works with 1 PR or 50. Adjusts output density to dataset size.
