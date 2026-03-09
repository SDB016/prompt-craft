# Push #{{PUSH_NUM}} — {{BRANCH}} ({{DATE}})

> Session: {{SESSION_ID}} | Prompts: {{PROMPT_COUNT}} | Trigger: git-push-hook

---

## Prompt Sequence

<!-- For EACH user prompt in this session, write a separate block.
     Include the FULL VERBATIM text of what the user typed.
     Do NOT summarize, paraphrase, or shorten prompts.
     Do NOT add "Intent:" one-liners — paste the raw text exactly. -->

### Prompt 1
```
(paste the EXACT, COMPLETE text of the user's first prompt here)
```
<!-- delta: one-line description of what changed after this prompt -->

### Prompt 2
```
(paste the EXACT, COMPLETE text of the user's second prompt here)
```
<!-- delta: one-line description of what changed after this prompt -->

<!-- Continue for ALL prompts in the session... -->

<!-- If the user made selections via AskUserQuestion (Claude's interactive questions),
     include them as a Decision block right after the related prompt.
     Format: question → selected answer. Include ALL question-answer pairs. -->

### Decisions after Prompt N
| Question | Selected |
|----------|----------|
| 통합 엔드포인트의 경로를 어떻게 할까요? | /shape (Recommended) |

<!-- Only include this block when AskUserQuestion selections exist.
     One row per question-answer pair. Include the full question text and selected option. -->

---

## Code Impact

> {{TOTAL_FILES}} files changed, +{{INSERTIONS}} −{{DELETIONS}}

| File | Change | Summary |
|------|--------|---------|
| `path/to/file` | added/modified (+N, −M) | AI-generated one-line description of the change |

<!-- One row per changed file. Generate a meaningful summary, not just the filename. -->

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
```
