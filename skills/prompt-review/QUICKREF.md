# prompt-review Quick Reference

## One-liner

```
/prompt-review
```

Creates a prompt review PR from accumulated push records.

## First time?

```
/prompt-review --setup
```

## How it works

1. **On each `git push`** (inside Claude Code) → prompts + diff recorded as commit in prompt repo
2. **On `gh pr create` or `/prompt-review`** → aggregate all push records, score, create review PR

## Common invocations

```bash
/prompt-review                          # create prompt review PR
/prompt-review --setup                  # first-time setup / reconfigure
/prompt-review --status                 # show config + recent PRs
/prompt-review --tag debugging          # pre-tag the PR
```

## Scoring (8 criteria, 100 points)

| Criterion | Max |
|-----------|-----|
| Goal Clarity | 20 |
| Scope Control | 15 |
| Context Sufficiency | 15 |
| Exit Criteria | 10 |
| Decomposition | 10 |
| Verification Strategy | 10 |
| Iteration Quality | 10 |
| Complexity Fit | 10 |

Grades: 🟢 90+ Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 <50 Poor

## Config location

`~/.claude/prompt-review.config.json`

## What goes into the PR

- Scorecard with 8 criteria (LLM scored, single call)
- Code changes as evidence (files changed + AI summary)
- Full prompt sequence with per-prompt mini-scores
- Improvement suggestions with rewrite fragments
- Reviewer checklist
- Session metadata

## Prompt repo file structure

```
sessions/{branch-name}/
  push-001.md    ← recorded on first git push
  push-002.md    ← recorded on second git push
  push-003.md    ← new session, same branch
```

## Requirements

- `gh` CLI installed and authenticated (`gh auth login`)
- A GitHub repo for prompt reviews (public or private)
