<!--
  PROMPTS FILE — review target for line-level comments
  ────────────────────────────────────────────────────
  This file is committed to the review repo so reviewers can
  leave GitHub line comments directly on individual prompts.

  Prompts are rendered as plain text (NOT in code blocks)
  to enable line-level commenting on any prompt line.

  Population guide:

  {REVIEW_FOCUS}          → 2-3 line AI summary: which criteria scored low,
                            which prompt numbers to focus on, and why
  {PROMPT_SEQUENCE}       → see format below
-->

## Review Focus

{REVIEW_FOCUS}

<!-- REVIEW_FOCUS: AI-generated 2-3 line summary highlighting:
     - Which scoring criteria were weakest
     - Which prompt numbers contributed to low scores
     - The key pattern to watch for (e.g. "missing exit criteria in prompts #2, #3")
     Example:
       Exit Criteria scored 4/10 — prompts #2 and #3 had no stopping condition,
       causing Claude to modify files beyond scope. Scope Control also suffered
       (10/15) due to constraint drift after the opening prompt.
-->

---

## Prompt Sequence

<!-- Reviewer instructions:
     - Click any line of prompt text to leave a GitHub line comment.
     - Prompts are plain text (not in code blocks) to enable line-level annotation.
     - Mini-scores show Goal/Exit/Scope/Context at a glance.
     - See summary.md for the full scorecard, improvement suggestions, and metadata.
-->

{PROMPT_SEQUENCE}

<!-- PROMPT_SEQUENCE format — repeat for each human turn:

─────────────────────────────
### Prompt {N} {PROMPT_MINI_BADGE}

{VERBATIM_PROMPT_TEXT}

<sub>Goal {G}/20 · Exit {E}/10 · Scope {S}/15 · Context {C}/15</sub>

<!-- delta: {DELTA_DESCRIPTION} -->

─────────────────────────────

PROMPT_MINI_BADGE key (based on sum of 4 inline criteria / 60):
  🟢 48–60  🔵 36–47  🟡 24–35  🔴 0–23

VERBATIM_PROMPT_TEXT: the EXACT, COMPLETE text of what the user typed.
  Do NOT use code blocks — render as plain text for line-level commenting.
  Do NOT summarize, paraphrase, or shorten.
  Escape characters that could break markdown structure:
    - Backtick sequences (``` ` ```)
    - Pipe characters in table-like content
    - Raw HTML tags

DELTA_DESCRIPTION: one-line description of what changed after this prompt.
  Example: "Created src/auth/refresh.ts (+67 lines) with TokenRefreshService"
  If no code change followed: "no code delta"

When AskUserQuestion selections follow a prompt, add a Decisions block:

### Decisions after Prompt {N}
| Question | Selected |
|----------|----------|
| (full question text) | (selected option) |

-->
