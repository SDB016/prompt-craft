<!--
  PR BODY TEMPLATE (slim)
  ───────────────────────
  This template generates the PR description only.
  The main review content is in two committed files:
    - prompts.md  → prompt sequence for line-level review
    - summary.md  → scorecard, improvements, code impact, metadata

  Population guide:

  {GRADE_BADGE}       → 🟢 Excellent (90–100) | 🔵 Good (70–89) | 🟡 Needs Work (50–69) | 🔴 Poor (<50)
  {TOTAL_SCORE}       → integer 0–100
  {ONE_LINE_SUMMARY}  → ≤120 chars: what this session accomplished
  {PROMPT_COUNT}      → total number of human turns
  {SESSION_DURATION}  → e.g. "~42 min"
  {SESSION_DATE}      → YYYY-MM-DD
  {AUTHOR}            → GitHub @handle
  {REVIEW_FOCUS}      → 2-3 line AI summary of what to look at
  {REVIEW_REPO_URL}   → full URL of the review repo
-->

## {GRADE_BADGE} Score: {TOTAL_SCORE}/100 — {ONE_LINE_SUMMARY}

> **Prompts:** {PROMPT_COUNT} &nbsp;|&nbsp; **Duration:** {SESSION_DURATION} &nbsp;|&nbsp; **Session:** {SESSION_DATE} by @{AUTHOR}

---

### Review Focus

{REVIEW_FOCUS}

---

### How to Review

| File | What's inside | Action |
|------|---------------|--------|
| **`prompts.md`** | Prompt sequence (plain text) | Leave line comments on specific prompts |
| **`summary.md`** | Scorecard, code impact, improvements, metadata | Read for context and scoring details |

> Open the **Files Changed** tab to start reviewing.

---

*Auto-captured by [prompt-review](https://github.com/Yeachan-Heo/oh-my-claudecode) · [View all prompt reviews]({REVIEW_REPO_URL}/pulls) · [Your reviews]({REVIEW_REPO_URL}/pulls?q=author%3A{AUTHOR})*
