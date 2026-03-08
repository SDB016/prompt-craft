---
name: prompt-stats
description: Show prompt review score trends over time by querying past PRs from the review repo. Use when asked for prompt stats, score trends, or review history.
argument-hint: "[--team] [--me] [--last N]"
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
---

# Prompt Stats — Score Trends Over Time

Queries past prompt review PRs and displays score trends, averages, and per-criteria breakdowns.

> "Track your prompt quality like you track your test coverage."

**Received arguments:** $ARGUMENTS

---

## Step 0: Route the Request

- `--team` → `MODE=team` (all authors) | `--me` or default → `MODE=me`
- `--last N` → `LIMIT=N` | default → `LIMIT=10`

---

## Step 1: Pre-flight and Fetch

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

[ -f "$CONFIG_FILE" ] || { echo "Error: No config found."; echo "Fix:   Run /prompt-review --setup"; exit 0; }
command -v gh &>/dev/null || { echo "Error: gh CLI not found."; echo "Fix:   Install from https://cli.github.com/"; exit 0; }
gh auth status &>/dev/null || { echo "Error: Not authenticated."; echo "Fix:   Run: gh auth login"; exit 0; }

REPO=$(jq -r '.repo' "$CONFIG_FILE")
LABEL=$(jq -r '.label // "prompt-review"' "$CONFIG_FILE")
AUTHOR_FLAG=""
[ "$MODE" = "me" ] && AUTHOR_FLAG="--author=@me"

gh pr list --repo "$REPO" --label "$LABEL" --state all --limit "$LIMIT" \
  $AUTHOR_FLAG \
  --json number,title,body,author,createdAt,url \
  --jq '.[] | {number, title, author: .author.login, date: .createdAt, url, body}'
```

If no PRs found: `No prompt reviews found. Create some reviews first with /prompt-review.`

---

## Step 2: Parse Scores

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

## Step 3: Compute Statistics

1. **Overall trend** — chronological total scores; pick first, middle, last
2. **Average score** — mean of all totals
3. **Best / Worst** — highest and lowest totals with PR topic
4. **Per-criteria averages** — mean of each criterion across all PRs
5. **Per-criteria trend** — compare first-half avg vs second-half avg

Grade bands: 90-100 Excellent | 70-89 Good | 50-69 Needs Work | 0-49 Poor

Trend labels: second half > first half + 5 → "improving" | < -5 → "declining" | else → "consistent"

---

## Step 4: Display Results

### Output format (`--me` default, `--team` adds author details)

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

## Tip Generation

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

## Error Handling

All errors use: `Error: ... / Cause: ... / Fix: ...`

| Error | Fix |
|-------|-----|
| No config | `Run /prompt-review --setup` |
| gh CLI missing | `Install from https://cli.github.com/` |
| Not authenticated | `Run: gh auth login` |
| No PRs found | `Create some with /prompt-review` |
| Unparseable PR | Skip with warning, continue |

---

## Design Principles

1. **Read-only.** No files written, no commits, no PRs. Pure query and display.
2. **Same scoring system.** Identical criteria and weights as `/prompt-review` and `/prompt-feedback`.
3. **Trends over judgment.** Value is in improvement over time, not any single score.
4. **Graceful degradation.** Unparseable PRs are skipped with a note.
5. **Fast.** Single `gh pr list` call, local parsing. No cloning required.
