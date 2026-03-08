---
name: prompt-compare
description: Compare two prompt review sessions side by side, showing what improved and what regressed between PRs.
argument-hint: "[PR#1] [PR#2]"
allowed-tools: Bash, Read, Grep, Glob
disable-model-invocation: true
---

# Prompt Compare — Side-by-Side PR Review Diff

Compares two prompt review PRs criterion by criterion, highlighting improvements and regressions.

**Received arguments:** $ARGUMENTS

---

## Step 0: Parse Arguments

Extract two PR numbers from `$ARGUMENTS`:
- `$0` — the baseline (older) PR number
- `$1` — the comparison (newer) PR number

If fewer than two PR numbers provided, respond: `Usage: /prompt-compare [PR#1] [PR#2]`

---

## Step 1: Load Config

Read `~/.claude/prompt-review.config.json` for repository and custom settings.

If missing, respond: `Config not found: ~/.claude/prompt-review.config.json — run /prompt-review first.`

---

## Step 2: Fetch Both PRs

Fetch each PR body in parallel:

```bash
gh pr view $0 --json body,number,title
gh pr view $1 --json body,number,title
```

If either PR is not found, respond: `Could not fetch PR #<number>. Check that it exists and you have access.`

---

## Step 3: Extract Scores

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

## Step 4: Compute Deltas

For each criterion: `delta = PR#2 score - PR#1 score`

- Positive delta = improvement, negative = regression, zero = unchanged
- Track the biggest improvement (largest positive delta) and all regressions

---

## Step 5: Display Comparison

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

## Step 6: Highlight Changes

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

## Design Principles

1. **Two PRs, one view.** See progress or backslides in a single output.
2. **Same criteria as `/prompt-review` and `/prompt-feedback`.** Consistent scoring.
3. **Regressions are surfaced, not buried.** Negative deltas always called out.
4. **Read-only.** No files written, no commits, no side effects.
