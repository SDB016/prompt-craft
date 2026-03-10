---
name: insights
description: Analyze prompt review trends, extract high-scoring patterns, and compare sessions. Use when asked for prompt stats, trends, patterns, replay, or comparison.
argument-hint: "[patterns] [compare #1 #2] [--team] [--me] [--last N] [--min-score N] [--criterion NAME] [--author USER]"
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
---

# Prompt Insights — Trends, Patterns & Comparison

Unified analysis skill for prompt review data. Query score trends, extract high-scoring patterns, or compare sessions side by side.

> "Track your prompt quality like you track your test coverage."

**Received arguments:** $ARGUMENTS

---

## Step 0: Route the Request

- If `$ARGUMENTS` starts with `patterns` → jump to [PATTERNS]
- If `$ARGUMENTS` starts with `compare` → jump to [COMPARE]
- Otherwise → default to [TRENDS]

Arguments after the subcommand are passed through (e.g., `patterns --min-score 90` → [PATTERNS] with --min-score 90).

---

## Common Pre-flight

(shared by all three subcommands — run this first)

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

[ -f "$CONFIG_FILE" ] || { echo "Error: No config found."; echo "Fix:   Run /review --setup"; exit 0; }
command -v gh &>/dev/null || { echo "Error: gh CLI not found."; echo "Fix:   Install from https://cli.github.com/"; exit 0; }
gh auth status &>/dev/null || { echo "Error: Not authenticated."; echo "Fix:   Run: gh auth login"; exit 0; }

REPO=$(jq -r '.repo' "$CONFIG_FILE")
LABEL=$(jq -r '.label // "prompt-review"' "$CONFIG_FILE")
```

---

## [TRENDS] — Score Trends Over Time

(This is the old prompt-stats skill content)

### Step T-0: Route the Request

- `--team` → `MODE=team` (all authors) | `--me` or default → `MODE=me`
- `--last N` → `LIMIT=N` | default → `LIMIT=10`

---

### Step T-1: Fetch PRs

```bash
AUTHOR_FLAG=""
[ "$MODE" = "me" ] && AUTHOR_FLAG="--author=@me"

gh pr list --repo "$REPO" --label "$LABEL" --state all --limit "$LIMIT" \
  $AUTHOR_FLAG \
  --json number,title,body,author,createdAt,url \
  --jq '.[] | {number, title, author: .author.login, date: .createdAt, url, body}'
```

If no PRs found: `No prompt reviews found. Create some reviews first with /review.`

---

### Step T-2: Parse Scores

Each PR body contains a YAML metadata block inside `<details><summary>Session Metadata</summary>` with a `score:` section:

```yaml
score:
  total: {TOTAL}
  goal_clarity: {G}
  scope_control: {S}
  context_sufficiency: {C}
  exit_criteria: {E}
  decomposition: {D}
  verification_strategy: {V}
  iteration_quality: {I}
  complexity_fit: {CF}
  grade: {GRADE}
```

Extract scores by grepping the `score:` block from each PR body. If no YAML block, fall back to the `Score: {N}/100` pattern from the PR headline. Skip unparseable PRs with a warning.

Also extract the topic from PR title format: `[Prompt Review] {date} — {topic} — @{author}`

---

### Step T-3: Compute Statistics

1. **Overall trend** — chronological total scores; pick first, middle, last
2. **Average score** — mean of all totals
3. **Best / Worst** — highest and lowest totals with PR topic
4. **Per-criteria averages** — mean of each criterion across all PRs
5. **Per-criteria trend** — compare first-half avg vs second-half avg

Grade bands: 90-100 Excellent | 70-89 Good | 50-69 Needs Work | 0-49 Poor

Trend labels: second half > first half + 5 → "improving" | < -5 → "declining" | else → "consistent"

---

### Step T-4: Display Results

#### Output format (`--me` default, `--team` adds author details)

```
Prompt Stats — @{AUTHOR} (last {N} reviews)

Overall trend: {FIRST} → {MID} → {LAST} ({TREND_LABEL})

  Average score:  {AVG}/100 ({GRADE})
  Best:           {BEST}/100 — {BEST_TOPIC}
  Worst:          {WORST}/100 — {WORST_TOPIC}
  Reviews:        {COUNT}

Criteria breakdown (avg):
  Goal Clarity:            {G}/20  {ICON}  ({TREND})
  Exit Criteria:           {E}/10  {ICON}  ({TREND})
  Scope Control:           {S}/15  {ICON}  ({TREND})
  Context Sufficiency:     {C}/15  {ICON}  ({TREND})
  Decomposition:           {D}/10  {ICON}  ({TREND})
  Verification Strategy:   {V}/10  {ICON}  ({TREND})
  Iteration Quality:       {I}/10  {ICON}  ({TREND})
  Complexity Fit:         {CF}/10  {ICON}  ({TREND})

Tip: {TARGETED_TIP}
```

ICON key: ✅ = 80%+ of max | 🟡 = 50-79% | ❌ = <50%

**Team mode additions** (after Reviews line):

```
  Contributors:   {UNIQUE_AUTHORS}

By author:
  @{AUTHOR1}:  avg {A1}/100 ({COUNT1} reviews)
  @{AUTHOR2}:  avg {A2}/100 ({COUNT2} reviews)
```

Team mode also shows `by @{AUTHOR}` after Best/Worst topics.

---

### Tip Generation

If any criterion has been below 60% of its max for 3+ consecutive recent reviews, show a targeted tip with a concrete phrase to try:

| Criterion | Suggested phrase |
|-----------|-----------------|
| Goal Clarity | "Done when [specific measurable outcome]" |
| Exit Criteria | "Stop after [specific boundary]" |
| Scope Control | "Only modify [file list]. Do not touch [exclusion]." |
| Context Sufficiency | "The current behavior is [X]. The desired behavior is [Y]." |
| Decomposition | "Step 1: ... Step 2: ... Step 3: ..." |
| Verification Strategy | "Verify by running [command]. Expected output: [X]." |
| Iteration Quality | "Specifically, change [X] to [Y] in [file]." |
| Complexity Fit | "This is a simple/complex task. [Adjust detail accordingly]." |

Format: `Tip: Your {CRITERION} has been low for {N} reviews. Try adding "{PHRASE}" to every prompt.`

If no criterion qualifies: `Looking good! Your scores are consistent across all criteria.`

---

## [PATTERNS] — Learn from Your Best Prompts

(This is the old prompt-replay skill content)

### Step P-0: Parse Arguments

Parse the portion of `$ARGUMENTS` after `patterns` for:
- `--min-score N` — minimum total score to include (default: 80)
- `--criterion NAME` — filter to a specific criterion (e.g., "goal-clarity", "exit-criteria", "scope-control", "context-sufficiency", "decomposition", "verification", "iteration", "complexity-fit")
- `--author USER` — filter to PRs by a specific GitHub user

Config is already loaded from Common Pre-flight.

---

### Step P-1: Fetch Closed Prompt Review PRs

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
Create some with /review first.
```

---

### Step P-2: Extract Scores and Prompts

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

### Step P-3: Identify Patterns

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

### Step P-4: Display Results

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

### Step P-5: Closing

Always end with:

```
Source: {REPO} — {QUALIFIED} PRs scored {MIN_SCORE}+
Run /review to add your sessions to the dataset.
```

---

## [COMPARE] — Side-by-Side PR Comparison

(This is the old prompt-compare skill content)

### Step C-0: Parse Arguments

Extract two PR numbers from the portion of `$ARGUMENTS` after `compare`:
- `$0` — the baseline (older) PR number
- `$1` — the comparison (newer) PR number

If fewer than two PR numbers provided, respond: `Usage: /insights compare [PR#1] [PR#2]`

Config is already loaded from Common Pre-flight.

---

### Step C-1: Fetch Both PRs

Fetch each PR body in parallel:

```bash
gh pr view $0 --json body,number,title
gh pr view $1 --json body,number,title
```

If either PR is not found, respond: `Could not fetch PR #<number>. Check that it exists and you have access.`

---

### Step C-2: Extract Scores

Parse the scorecard from each PR body. Extract scores for all 8 criteria:

| Criterion | Max | Criterion | Max |
|-----------|-----|-----------|-----|
| Goal Clarity | 20 | Decomposition | 10 |
| Exit Criteria | 10 | Verification Strategy | 10 |
| Scope Control | 15 | Iteration Quality | 10 |
| Context Sufficiency | 15 | Complexity Fit | 10 |

Also extract the overall score (out of 100).

If scores cannot be parsed, respond: `Could not parse scores from PR #<number>. Is this a prompt-review PR?`

---

### Step C-3: Compute Deltas

For each criterion: `delta = PR#2 score - PR#1 score`

- Positive delta = improvement, negative = regression, zero = unchanged
- Track the biggest improvement (largest positive delta) and all regressions

---

### Step C-4: Display Comparison

Output the comparison table:

```
Prompt Compare — PR #<$0> vs PR #<$1>

                    PR #<$0>      PR #<$1>      Delta
Overall:            <s1>/100      <s2>/100      <+/-N> <arrow>
Goal Clarity:       <s1>/20       <s2>/20       <+/-N> <arrow>
Exit Criteria:      <s1>/10       <s2>/10       <+/-N> <arrow>
Scope Control:      <s1>/15       <s2>/15       <+/-N> <arrow>
Context:            <s1>/15       <s2>/15       <+/-N> <arrow>
Decomposition:      <s1>/10       <s2>/10       <+/-N> <arrow>
Verification:       <s1>/10       <s2>/10       <+/-N> <arrow>
Iteration:          <s1>/10       <s2>/10       <+/-N> <arrow>
Complexity Fit:     <s1>/10       <s2>/10       <+/-N> <arrow>
```

Arrow key: `↑` positive, `↓` negative, `→` unchanged.

---

### Step C-5: Highlight Changes

After the table, show the biggest improvement and any regressions.

**Biggest improvement** — criterion with the largest positive delta:

```
Biggest improvement: <Criterion> (+<N>)
  PR #<$0>: <brief note from PR#1 about this criterion>
  PR #<$1>: <brief note from PR#2 about this criterion>
```

**Regressions** — every criterion with a negative delta:

```
Regression: <Criterion> (<-N>)
  PR #<$1>: <brief note explaining why the score dropped>
```

If no regressions: `No regressions. All criteria held steady or improved.`

If no improvements: `No improvements detected. Consider reviewing prompt patterns from higher-scoring sessions.`

---

## Error Handling

All errors use: `Error: ... / Cause: ... / Fix: ...`

| Error | Message |
|-------|---------|
| No config | `Error: No config found.` / `Cause: Prompt Craft has not been set up yet.` / `Fix: Run /review --setup` |
| gh CLI missing | `Error: gh CLI not found.` / `Cause: GitHub CLI is not installed.` / `Fix: Install from https://cli.github.com/` |
| Not authenticated | `Error: Not authenticated with GitHub.` / `Cause: gh auth session expired or not configured.` / `Fix: Run: gh auth login` |
| No PRs found | `Error: No prompt reviews found.` / `Cause: No review PRs have been created yet.` / `Fix: Create some with /review` |
| Unparseable PR | Skip with warning, continue processing other PRs |
| Repo not accessible | `Error: Cannot access {REPO}.` / `Cause: Repository doesn't exist or you lack access.` / `Fix: Check the name or run /review --setup` |
| No PRs meet threshold | `Error: No PRs scored {MIN_SCORE}+.` / `Cause: All reviews scored below the threshold.` / `Fix: Try lowering: /insights patterns --min-score 60` |
| PR not found (compare) | `Error: Could not fetch PR #{number}.` / `Cause: PR doesn't exist or you lack access.` / `Fix: Check the PR number and repository access.` |
| Scores unparseable (compare) | `Error: Could not parse scores from PR #{number}.` / `Cause: PR body doesn't contain a valid scorecard.` / `Fix: Verify this is a prompt-review PR.` |
| Fewer than 2 PR numbers | `Error: Two PR numbers required.` / `Cause: Compare needs exactly two PRs.` / `Fix: Usage: /insights compare [PR#1] [PR#2]` |

---

## Design Principles

1. **Read-only.** No files written, no commits, no PRs. Pure query and display.
2. **Same scoring system.** Identical criteria and weights as `/review` and `/score`.
3. **Trends over judgment.** Value is in improvement over time, not any single score.
4. **Graceful degradation.** Unparseable PRs are skipped with a note. Works with 1 PR or 50.
5. **Fast.** Single `gh pr list` call, local parsing. No cloning required.
6. **Pattern-first.** Surfaces reusable patterns, not raw data. The goal is learning, not auditing.
7. **Same ecosystem.** Reads from the same repo and config as `/review`. No separate setup.
8. **Actionable output.** Every pattern includes a concrete example the team can copy and adapt.
9. **Two PRs, one view.** See progress or backslides in a single comparison output.
10. **Regressions are surfaced, not buried.** Negative deltas always called out.
