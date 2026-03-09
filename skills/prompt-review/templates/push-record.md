# Push #{{PUSH_NUM}} — {{BRANCH}} ({{DATE}})

> {{GRADE_BADGE}} **Score: {{TOTAL_SCORE}}/100** | Session: {{SESSION_ID}} | Prompts: {{PROMPT_COUNT}} | Trigger: git-push-hook

---

## Prompt Quality Scorecard

<!-- Score ALL prompts in this push against 8 criteria. Use a single evaluation pass.
     ICON key: ✅ = 80%+ of max, 🟡 = 50–79%, ❌ = <50%
     PROGRESS_BAR: 10-char using █ (filled) and ░ (empty), scaled to score/max
     Grade bands: 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor
     N/A rule: If Iteration Quality is N/A (single prompt), redistribute 10 pts proportionally. -->

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| {{ICON}} | **Goal Clarity** | {{G}}/20 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Scope Control** | {{S}}/15 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Context Sufficiency** | {{C}}/15 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Exit Criteria** | {{E}}/10 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Decomposition** | {{D}}/10 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Verification Strategy** | {{V}}/10 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Iteration Quality** | {{I}}/10 | {{BAR}} | {{FINDING}} |
| {{ICON}} | **Complexity Fit** | {{CF}}/10 | {{BAR}} | {{FINDING}} |

---

## Prompt Sequence

<!-- For EACH user prompt in this session, write a separate block.
     Include the FULL VERBATIM text of what the user typed.
     Do NOT summarize, paraphrase, or shorten prompts.
     Do NOT add "Intent:" one-liners — paste the raw text exactly.
     Add per-prompt mini-scores and badge after each prompt.
     MINI_BADGE: 🟢 48–60, 🔵 36–47, 🟡 24–35, 🔴 0–23 (sum of Goal+Exit+Scope+Context / 60) -->

### Prompt 1 {{MINI_BADGE}}
```
(paste the EXACT, COMPLETE text of the user's first prompt here)
```
<sub>Goal {{G}}/20 · Exit {{E}}/10 · Scope {{S}}/15 · Context {{C}}/15</sub>
<!-- delta: one-line description of what changed after this prompt -->

### Prompt 2 {{MINI_BADGE}}
```
(paste the EXACT, COMPLETE text of the user's second prompt here)
```
<sub>Goal {{G}}/20 · Exit {{E}}/10 · Scope {{S}}/15 · Context {{C}}/15</sub>
<!-- delta: one-line description of what changed after this prompt -->

<!-- Continue for ALL prompts in the session... -->

<!-- If the user made selections via AskUserQuestion (Claude's interactive questions),
     include them as a Decision block right after the related prompt.
     Format: question → selected answer. Include ALL question-answer pairs. -->

### Decisions after Prompt N
| Question | Selected |
|----------|----------|
| (full question text) | (selected option) |

<!-- Only include this block when AskUserQuestion selections exist.
     One row per question-answer pair. Include the full question text and selected option. -->

---

## Improvement Suggestions

<!-- Populated ONLY for criteria scoring below 70% of their max.
     Omit this section entirely if all criteria score well.
     Provide concrete "Instead of / Try" rewrites, not abstract advice.
     When a prompt defect led to a code issue, frame as "Prompt Gap":
       "Missing exit criteria → Claude made scope-exceeding changes" -->

### {{CRITERION}} (scored {{SCORE}}/{{MAX}})
> {{WHAT_WAS_MISSING}}

**Suggested rewrite:**
```
Instead of: "{{ORIGINAL}}"
Try:        "{{IMPROVED}}"
```

---

## Code Impact

> {{TOTAL_FILES}} files changed, +{{INSERTIONS}} −{{DELETIONS}}

| File | Change | Summary |
|------|--------|---------|
| `path/to/file` | added/modified (+N, −M) | AI-generated one-line description of the change |

<!-- One row per changed file. Generate a meaningful summary, not just the filename.
     Flag constraint violations: "**Flagged: constraint violation** — description" -->

---

## Commits

- `{{SHA}}` {{COMMIT_MESSAGE}}

<!-- One line per commit, from git log -->

---

## Session Metadata

```yaml
session_id: {{SESSION_ID}}
project_repo: {{PROJECT_OWNER}}/{{PROJECT_REPO}}
project_branch: {{BRANCH}}
prompt_count: {{PROMPT_COUNT}}
push_number: {{PUSH_NUM}}
triggered_by: git-push-hook
date: {{DATE}}
score:
  total: {{TOTAL_SCORE}}
  goal_clarity: {{G}}
  scope_control: {{S}}
  context_sufficiency: {{C}}
  exit_criteria: {{E}}
  decomposition: {{D}}
  verification_strategy: {{V}}
  iteration_quality: {{I}}
  complexity_fit: {{CF}}
  grade: {{GRADE}}
```
