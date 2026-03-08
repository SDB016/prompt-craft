---
name: prompt-feedback
description: Score your current session prompts locally and get actionable improvement tips — no PR created. Use when asked to check prompts, score prompts, or get prompt feedback.
argument-hint: "[--verbose]"
allowed-tools: Read, Grep, Glob
---

# Prompt Feedback — Local Prompt Quality Check

Scores the prompts from your current Claude Code session against 8 criteria and gives you actionable feedback. Nothing is sent anywhere — purely local, purely for self-improvement.

> "Fix your prompts before they become a PR."

**Received arguments:** $ARGUMENTS

---

## How It Works

1. Collect all human prompts from the current session context
2. Score against the same 8 criteria used by `/prompt-review`
3. Display scorecard + improvement tips inline
4. No commits, no pushes, no PRs — local only

---

## Invocation

| Command | What happens |
|---------|-------------|
| `/prompt-feedback` | Score current session, show scorecard + tips |
| `/prompt-feedback --verbose` | Include per-prompt breakdown |

---

## Step 0: Collect Prompts

Review the conversation history and gather all human turns from the current session.

If no substantive prompts found (session just started, or only greetings), respond:

```
No prompts to score yet. Start working and run /prompt-feedback again later.
```

If only 1 prompt found, note that Iteration Quality will be N/A (redistribute points).

---

## Step 1: Score (LLM — single call)

Score all collected prompts against 8 criteria. Same scoring system as `/prompt-review`.

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

**N/A rule:** If Iteration Quality is not applicable (single prompt), redistribute its 10 points proportionally across the other 7 criteria.

**Grade bands:**

| Range | Grade |
|-------|-------|
| 90–100 | 🟢 Excellent |
| 70–89 | 🔵 Good |
| 50–69 | 🟡 Needs Work |
| 0–49 | 🔴 Poor |

---

## Step 2: Display Results

### Default Output

```
Prompt Feedback — {PROMPT_COUNT} prompts scored

Score: {TOTAL}/100 ({GRADE_BADGE})

  Goal Clarity:           {G}/20  {ICON}
  Scope Control:          {S}/15  {ICON}
  Context Sufficiency:    {C}/15  {ICON}
  Exit Criteria:          {E}/10  {ICON}
  Decomposition:          {D}/10  {ICON}
  Verification Strategy:  {V}/10  {ICON}
  Iteration Quality:      {I}/10  {ICON}
  Complexity Fit:        {CF}/10  {ICON}
```

ICON key: ✅ = 80%+ of max, 🟡 = 50–79%, ❌ = <50%

### Tips Section

For every criterion scoring below 70% of its max, show a concrete tip.

**Format:**

```
Tips for improvement:

  Exit Criteria (3/10):
    Your prompts don't specify when to stop. Try adding:
    "Stop after modifying only [file list]. Do not touch other files."

  Scope Control (7/15):
    Constraint from prompt #1 wasn't repeated in prompt #4.
    Re-state boundaries when switching to a new area of code.
```

Tips should be:
- **Specific** — reference actual prompt numbers and text
- **Actionable** — give a concrete phrase or pattern to use
- **Brief** — one tip per criterion, 2–3 lines max

If all criteria score 70%+, show:

```
Looking good! No major issues found. Keep it up.
```

### Closing Line

Always end with:

```
This is a local check only — nothing was saved or sent.
When ready for team review, use /prompt-review.
```

---

## Step 3: Verbose Mode (`--verbose`)

When `$ARGUMENTS` contains `--verbose`, add a per-prompt breakdown after the scorecard.

Per-prompt scoring uses 4 prompt-level criteria (Goal, Exit, Scope, Context) out of 60 max. The remaining 4 criteria (Decomposition, Verification, Iteration Quality, Complexity Fit) are session-level and scored only in the aggregate scorecard above.

```
Per-prompt breakdown:

  Prompt 1 🟢 (52/60)
    Goal 18/20 · Exit 9/10 · Scope 13/15 · Context 12/15
    "Refactor the JWT refresh logic in src/auth/refresh.ts..."

  Prompt 2 🟡 (28/60)
    Goal 10/20 · Exit 3/10 · Scope 7/15 · Context 8/15
    "Now update the middleware to use the new function..."

  Prompt 3 🔴 (19/60)
    Goal 8/20 · Exit 2/10 · Scope 4/15 · Context 5/15
    "Fix it."
```

Show first 80 chars of each prompt, truncated with "...".

Mini-badge per prompt (based on sum of 4 inline criteria / 60):
  🟢 48–60 | 🔵 36–47 | 🟡 24–35 | 🔴 0–23

---

## Design Principles

1. **Zero side effects.** No files written, no commits, no network calls. Pure read-only analysis.

2. **Same scoring as `/prompt-review`.** Identical 8 criteria and weights. What you see here is what the PR will show.

3. **Feedback, not judgment.** Tips are constructive and actionable. Low scores are learning signals, not failures.

4. **Fast.** Single LLM scoring call, minimal output. Should complete in seconds.

5. **Mid-session friendly.** Run anytime during a session. Useful before a push to self-check prompt quality.
