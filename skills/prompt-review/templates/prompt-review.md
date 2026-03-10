<!--
  PROMPT REVIEW PR TEMPLATE
  ─────────────────────────
  Population guide (for the skill that generates this):

  {GRADE_BADGE}            → one of: 🟢 Excellent (90–100) | 🔵 Good (70–89) | 🟡 Needs Work (50–69) | 🔴 Poor (<50)
  {TOTAL_SCORE}            → integer 0–100
  {SESSION_DATE}           → YYYY-MM-DD
  {AUTHOR}                 → GitHub @handle
  {PROJECT}                → owner/repo (the project repo, never modified)
  {PROMPT_COUNT}           → total number of human turns across all pushes
  {SESSION_DURATION}       → e.g. "~42 min"
  {PUSH_COUNT}             → number of push records aggregated
  {TRIGGER}                → "git-push-hook" | "gh-pr-create" | "manual"
  {ONE_LINE_SUMMARY}       → ≤120 chars: what this session accomplished
  {SCORECARD_ROWS}         → see Scorecard table format below
  {IMPROVEMENT_TIPS}       → see Tips section format below
  {PROMPT_SEQUENCE}        → see Prompt Sequence format below
  {CODE_IMPACT_ROWS}       → see Code Impact format below
  {FILE_COUNT}             → integer
  {INSERTIONS}             → integer
  {DELETIONS}              → integer
  {BRANCH}                 → branch that was pushed
  {COMMIT_LIST}            → see Commit List format below
  {SESSION_METADATA}       → YAML block

  Scorecard row format (repeat per criterion):
    | {ICON} | **{CRITERION}** | {SCORE}/{MAX} | {PROGRESS_BAR} | {FINDING} |

  ICON key (based on percentage of criterion max):
    ✅ = 80%+ of max   🟡 = 50–79% of max   ❌ = <50% of max

  PROGRESS_BAR: 10-char string using █ (filled) and ░ (empty), scaled to score/max
    18/20 → █████████░   7/10 → ███████░░░   4/15 → ██░░░░░░░░

  Tip format:
    ### {CRITERION} (scored {SCORE}/{MAX})
    > {WHAT_WAS_MISSING}
    **Suggested rewrite fragment:**
    ```
    Instead of: "{ORIGINAL}"
    Try:        "{IMPROVED}"
    ```

  Prompt sequence format: see [PROMPT SEQUENCE] section below.

  Commit list format:
    - [`{SHA}`]({COMMIT_URL}) {COMMIT_MESSAGE_FIRST_LINE}
-->

<!-- LEVEL 1 TRIAGE ─────────────────────────────────────────────────────── -->

## {GRADE_BADGE} Score: {TOTAL_SCORE}/100 — {ONE_LINE_SUMMARY}

> **Prompts:** {PROMPT_COUNT} &nbsp;|&nbsp; **Pushes:** {PUSH_COUNT} &nbsp;|&nbsp; **Duration:** {SESSION_DURATION} &nbsp;|&nbsp; **Session:** {SESSION_DATE} by @{AUTHOR} &nbsp;|&nbsp; **LLM scored**

<!-- Labels applied automatically by the skill:
     prompt-quality/excellent | prompt-quality/good | prompt-quality/needs-work | prompt-quality/poor
     project/{PROJECT_SLUG}
     author/@{AUTHOR}
-->

---

<!-- LEVEL 2 SCORECARD ──────────────────────────────────────────────────── -->

## Prompt Quality Scorecard

All 8 criteria are scored by LLM in a single evaluation call.

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
{SCORECARD_ROWS}

<details>
<summary>Scoring rubric</summary>

| Criterion | Max | What it evaluates |
|---|---|---|
| **Goal Clarity** | 20 | Is the goal specific? Does the result match the stated intent? |
| **Scope Control** | 15 | Are boundaries set? Constraints stated? No out-of-scope changes? |
| **Context Sufficiency** | 15 | Enough background provided? Reference code/patterns specified? |
| **Exit Criteria** | 10 | Are completion/stop conditions stated? Did Claude stop appropriately? |
| **Decomposition** | 10 | Are complex tasks broken into manageable steps? |
| **Verification Strategy** | 10 | Verification method specified? Failure behavior defined? |
| **Iteration Quality** | 10 | Are follow-up requests specific and concrete? (N/A → redistribute) |
| **Complexity Fit** | 10 | Is prompt sophistication appropriate for task complexity? |

**N/A rule:** When Iteration Quality is not applicable (single-prompt session), its 10 points are redistributed proportionally across the other 7 criteria. Effective max is always 100.

**Grade bands:** 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor

</details>

---

<!-- LEVEL 2 CODE DELTA ─────────────────────────────────────────────────── -->

## What Was Produced

> Branch: `{BRANCH}` — {FILE_COUNT} files changed, +{INSERTIONS} −{DELETIONS}

| File | Change | Summary |
|---|---|---|
{CODE_IMPACT_ROWS}

<!-- CODE_IMPACT_ROWS format:
  | `path/to/file.ts` | added (+82) | New RefreshTokenService with mutex serialization |
  | `path/to/other.ts` | modified (+14, −7) | Auto-refresh on 401, replaced error handling |
  Summary is AI-generated one-line description per changed file.
  Omit files with no relation to session prompts (e.g. auto-generated lock files).
-->

**Commits:**
{COMMIT_LIST}

<!-- COMMIT_LIST format — link each SHA to the PROJECT repo (not the review repo):
  - [`abc1234`](https://github.com/{PROJECT}/commit/{FULL_SHA}) {COMMIT_MESSAGE}
-->

**Code PR:** [{CODE_PR_TITLE}]({CODE_PR_URL})

<!-- CODE_PR_URL: link to the original code PR in the project repo (if available).
     Derived from the `gh pr create` event that triggered this prompt review.
     If triggered manually, omit this line. -->

---

<!-- LEVEL 3 ANNOTATED PROMPTS ─────────────────────────────────────────── -->

## Prompt Sequence

<!-- Reviewer instructions:
     - Use GitHub's line-level comment feature to annotate specific prompts.
     - Each prompt block is a separate visual unit — comment on the prompt text line
       to leave targeted feedback on that specific prompt.
     - The per-prompt mini-scores show key criteria at a glance.
     - "Delta" describes what changed in the codebase after this prompt.
-->

{PROMPT_SEQUENCE}

<!-- PROMPT_SEQUENCE population format — repeat this block for each human turn:

─────────────────────────────
### Prompt {N} {PROMPT_MINI_BADGE}

```
{VERBATIM_PROMPT_TEXT}
```

<sub>Goal {G}/20 · Exit {E}/10 · Scope {S}/15 · Context {C}/15</sub>

<!-- delta: {DELTA_DESCRIPTION} -->

─────────────────────────────

PROMPT_MINI_BADGE key (based on sum of 4 inline criteria / 60):
  🟢 48–60  🔵 36–47  🟡 24–35  🔴 0–23

DELTA_DESCRIPTION: one-line description of what changed after this prompt.
  Example: "Created src/auth/refresh.ts (+67 lines) with TokenRefreshService"
  If no code change followed this prompt: "no code delta"
-->

---

<!-- LEVEL 3 IMPROVEMENT TIPS ─────────────────────────────────────────── -->

## Improvement Suggestions

<!-- Populated only for criteria scoring below 70% of their max.
     Omit section entirely if all criteria score well.
     When prompt defect leads to code defect, frame as "Prompt Gap":
       "Missing exit criteria → Claude made scope-exceeding changes"
-->

{IMPROVEMENT_TIPS}

<!-- IMPROVEMENT_TIPS format — one block per low-scoring criterion:

### Goal Clarity (scored {SCORE}/20)
> The prompt used "{VAGUE_VERB}" without specifying the success condition.
> Claude had to infer what "done" looked like.

**Suggested rewrite fragment:**
```
Instead of: "improve the auth flow"
Try:        "Refactor the JWT refresh logic in src/auth/refresh.ts so that
             concurrent refresh calls are serialized. Done when:
             (1) a single refresh mutex is in place, (2) existing tests pass,
             (3) no new files are created outside src/auth/."
```

---

### Exit Criteria (scored {SCORE}/10)
> No stopping condition was stated. Claude continued making changes beyond
> the intended scope. Prompt Gap: missing exit criteria → out-of-scope changes.

**Suggested rewrite fragment:**
```
Add to end of prompt: "Stop after modifying only the files listed above.
Do not refactor callers unless explicitly asked."
```

-->

---

<!-- LEVEL 4 REVIEWER CHECKLIST ─────────────────────────────────────────── -->

<details>
<summary>Reviewer Checklist</summary>

<!-- Reviewers: copy this checklist into your review comment. Check each item. -->

**Reading the prompt sequence, I found:**

- [ ] The opening prompt gave Claude enough context to not guess the codebase state
- [ ] Exit criteria were explicit in at least one prompt
- [ ] No single prompt asked for more than two distinct outcomes
- [ ] Constraints were stated proactively, not reactively (after Claude made a wrong choice)
- [ ] Complex tasks were decomposed into sequential steps
- [ ] The final code delta matches what the prompts asked for

**My overall take:**
<!-- One sentence. Example: "Solid goal clarity but the author needs to start stating exit criteria — Claude went too far on prompts #3 and #5." -->

**The one thing to improve for next session:**
<!-- One sentence. Example: "Add 'stop when X' to every prompt that involves modifying existing files." -->

</details>

---

<!-- LEVEL 4 RAW METADATA ────────────────────────────────────────────────── -->

<details>
<summary>Session Metadata</summary>

```yaml
session_id: {ID}
project: {PROJECT}
branch: {BRANCH}
date: {SESSION_DATE}
score: {TOTAL_SCORE}/100 ({GRADE})
prompts: {PROMPT_COUNT}
pushes: {PUSH_COUNT}
```

</details>

---

*Auto-captured by [prompt-review](https://github.com/Yeachan-Heo/oh-my-claudecode) · [View all prompt reviews]({REVIEW_REPO_URL}/pulls) · [Your reviews]({REVIEW_REPO_URL}/pulls?q=author%3A{AUTHOR})*
