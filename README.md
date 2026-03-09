# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Prompt review for Claude Code. Code review looks at results — prompt review looks at causes.**

---

## Quick Start

**Step 1: Install**
```
/plugin marketplace add https://github.com/SDB016/prompt-craft
/plugin install prompt-craft
```

**Step 2: Setup**
```
/setup
```

**Step 3: Configure**
```
/prompt-review --setup
```
Set your review repository (e.g., `my-org/ai-sessions`), branch prefix, and base branch.

**Step 4: Use**
```
/prompt-review          # Create prompt review PR
/prompt-feedback        # Local scoring (no PR)
```

That's it. Prompts are automatically captured on `git push`, scored on `gh pr create`.

---

## Why Prompt Craft?

- **Team-level prompt quality** - Review each other's AI prompts via GitHub PRs
- **Auto-scoring** - 8 criteria, 100 points, single LLM call
- **Zero project footprint** - All review PRs go to a separate repo, no traces in your project
- **Complement to code review** - Code is evidence, prompts are the cause
- **Security first** - Preview before send, automatic secret scanning

---

## Skills

| Skill | Purpose |
|-------|---------|
| `/setup` | Check prerequisites and configure |
| `/prompt-review` | Create prompt review PR for team feedback |
| `/prompt-feedback` | Local scoring + improvement tips (`--verbose`) |
| `/prompt-stats` | Score trends over time (`--team`, `--last N`) |
| `/prompt-tips` | Pre-task prompt writing guide |
| `/prompt-replay` | Extract high-scoring prompt patterns |
| `/prompt-compare [#1] [#2]` | Compare two review sessions |
| `/prompt-template` | Save/use reusable prompt templates |

### Automatic Flow

| Event | Action | In prompt repo |
|-------|--------|----------------|
| `git push` (inside Claude Code) | Capture prompts + diff | **Commit only** (no PR) |
| `gh pr create` (inside Claude Code) | Aggregate + score | **Create PR** |
| `/prompt-review` (manual) | Create PR at desired time | **Create PR** |

---

## How It Works

```
[During development — record on each push]

  Work with Claude Code
        │
        ├── git push #1 → commit to prompt repo (prompts + diff recorded)
        ├── git push #2 → commit to prompt repo (additional record)
        ├── git push #3 → commit to prompt repo (additional record)
        │
[Feature complete — score at PR time]
        │
        └── gh pr create (PR in code repo)
              │
              ▼
    Aggregate accumulated prompts + AI scoring (100 pts)
              │
              ▼
    Create PR in prompt repo
              │
              ▼
    Teammates review prompt quality
```

No traces are left in the project repo. All review PRs go to a separate repo (e.g., `my-org/ai-sessions`).

---

## Scoring System

8 criteria, 100 points total. Scored in a single LLM call.

| Criterion | Points | Description |
|-----------|--------|-------------|
| Goal Clarity | 20 | Is the goal specific and does the result match intent? |
| Scope Control | 15 | Are boundaries set + constraints stated + no out-of-scope changes? |
| Context Sufficiency | 15 | Is enough background provided (including reference code/patterns)? |
| Exit Criteria | 10 | Are completion/stop conditions stated and followed? |
| Decomposition | 10 | Are complex tasks properly broken down? |
| Verification Strategy | 10 | Are verification methods specified? |
| Iteration Quality | 10 | Are follow-up requests specific and concrete? |
| Complexity Fit | 10 | Is prompt sophistication appropriate for task complexity? |

### Gap Model

| Gap | Description | Evaluator |
|-----|-------------|-----------|
| Gap 1 | Intent → Prompt | Humans only |
| Gap 2 | Prompt → Code | AI can assist |

---

## Example PR

```markdown
## Score: 73/100 — JWT refresh logic refactoring

> Prompts: 6 | Duration: ~35 min | LLM scored

## Prompt Quality Scorecard

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| ✅ | Goal Clarity | 18/20 | █████████░ | Clear goal specified |
| ❌ | Exit Criteria | 4/10 | ████░░░░░░ | No stop condition |
| ...

## What Was Produced
> 5 files changed, +142 −38

| File | Change | Summary |
|---|---|---|
| `src/auth/refresh.ts` | added (+67) | New RefreshTokenService with mutex serialization |
| `src/auth/middleware.ts` | modified (+31, −12) | Auto-refresh on 401, replaced error handling |

## Prompt Sequence
### Prompt 1
> Refactor JWT refresh logic...

## Improvement Suggestions
### Exit Criteria (4/10)
> Claude exceeded scope. Prompt Gap: no exit criteria specified.
```

---

## Requirements

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/) (for PR creation)
- Git

---

## License

MIT — see [LICENSE](LICENSE)
