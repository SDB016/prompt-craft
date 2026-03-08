# Prompt Craft

A Claude Code skill suite that enables team members to review each other's AI prompts via GitHub PRs, improving prompt quality over time.

## Core Idea

> "Code review looks at results. Prompt review looks at causes."

After working with Claude Code, the developer's prompts and code changes are captured to a separate repo as a PR. Teammates review **prompt quality**, and code serves only as **evidence** of whether the prompts were effective.

**Purpose**:
- Improve prompt engineering quality at the team level
- Auto-score prompts with 8 criteria (100 points, single LLM call)
- A **complement** to code review, not a replacement
- "Reviewing code cold is old-fashioned — we already use AI for code review and only comment on what matters"

## Workflow

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

**Important**: No traces are left in the project repo.

## Key Decisions

### 1. Implementation
**Decision**: Fully independent Claude Code skill
- No server infrastructure needed, all processing is local
- `gh` CLI for GitHub auth and PR creation

### 2. Trigger (Two-phase structure)
| Event | Action | In prompt repo |
|-------|--------|----------------|
| `git push` (inside Claude Code) | Capture prompts + diff | **Commit only** (no PR) |
| `gh pr create` (inside Claude Code) | Aggregate + score | **Create PR** |
| `/prompt-review` (manual) | Create PR at desired time | **Create PR** |

Only operates inside Claude Code. External git push is not detected.
Multi-session / long-running work automatically accumulates on the same branch.

### 3. Zero Project Repo Footprint
- No Git Trailers, Hooks, Branches, or PRs in the project repo
- All review PRs go to a separate repo (e.g., `my-org/ai-sessions`)
- Link direction: session→commit one-way only

### 4. Code's Role: Evidence
- Code is included in prompt review PRs, but only as **evidence**
- Code quality itself is not evaluated
- AI code review results are included, framed as "Prompt Gap"
- Example: "Missing exit criteria → Claude made scope-exceeding changes"

### 5. Evaluation System (8 criteria, single LLM scoring)

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

### 6. Gap Model
| Gap | Description | Evaluator |
|-----|-------------|-----------|
| Gap 1 | Intent → Prompt | Humans only |
| Gap 2 | Prompt → Code | AI can assist |

### 7. Review Workflow
- Same as code review — PR author assigns reviewers
- Tool handles PR creation + scoring only, everything after is human-decided

### 8. Security
1. Preview + user confirmation required (no auto-send)
2. Automatic secret scanning
3. User-level config only

## Directory Structure

```
promptrequest/
├── README.md                              # This file
├── SESSION-NOTES.md                       # Initial brainstorming notes
├── QUICKSTART.md                          # Quick start guide
├── decisions/
│   ├── 01-architecture.md                 # Architecture decisions
│   ├── 02-implementation.md               # Implementation decisions
│   └── 03-prompt-review-pr-design.md      # PR template design rationale
├── brainstorming/
│   ├── 00-summary.md                      # Initial brainstorming summary
│   ├── 02-expansion-brainstorm.md         # Expansion ideas (Phase 2+)
│   ├── 03-decisions.md                    # ⭐ Consolidated decision record (latest)
│   ├── architect-review.md                # Architecture analysis
│   └── security-review.md                 # Security review
└── skill/
    ├── SKILL.md                           # /prompt-review — PR creation skill
    ├── PROMPT-FEEDBACK.md                 # /prompt-feedback — Local scoring
    ├── PROMPT-STATS.md                    # /prompt-stats — Score trends
    ├── PROMPT-TIPS.md                     # /prompt-tips — Pre-task guide
    ├── PROMPT-REPLAY.md                   # /prompt-replay — Pattern extraction
    ├── PROMPT-COMPARE.md                  # /prompt-compare — Session comparison
    ├── PROMPT-TEMPLATE.md                 # /prompt-template — Reusable templates
    ├── QUICKREF.md                        # Quick reference card
    ├── hooks/
    │   ├── prompt-review-hook.sh          # PostToolUse hook (git push / gh pr create)
    │   └── install-hook.sh               # Hook installer script
    ├── templates/
    │   ├── prompt-review.md               # Prompt review PR template
    │   └── prompt-review-example.md       # Filled example (JWT, 74/100)
    └── utils/
        └── secret-scan.sh                 # Secret scanning patterns
```

## Installation

### Option 1: One-line install
```bash
git clone https://github.com/SDB016/prompt-craft.git && cd prompt-craft && bash install.sh
```

### Option 2: Manual install
```bash
# Clone the repo
git clone https://github.com/SDB016/prompt-craft.git

# Copy skill files to Claude Code skills directory
mkdir -p ~/.claude/skills/prompt-review
cp -r prompt-craft/skill/* ~/.claude/skills/prompt-review/

# Install the PostToolUse hook
bash ~/.claude/skills/prompt-review/hooks/install-hook.sh
```

### Verify Installation
```bash
# Check skill files are in place
ls ~/.claude/skills/prompt-review/

# Check hook is registered
cat ~/.claude/settings.json | jq '.hooks'
```

Restart Claude Code after installation for the hook to take effect.

### Uninstall
```bash
bash uninstall.sh
```

---

## Usage

### Initial Setup
```bash
/prompt-review --setup
```

### Create Prompt Review PR
```bash
/prompt-review
```

### Local Score Check (no PR)
```bash
/prompt-feedback
/prompt-feedback --verbose
```

### All Skills

| Skill | Purpose |
|-------|---------|
| `/prompt-review` | Create prompt review PR for team feedback |
| `/prompt-feedback` | Local scoring + improvement tips |
| `/prompt-stats` | Score trends over time (`--team`, `--last N`) |
| `/prompt-tips` | Pre-task prompt writing guide |
| `/prompt-replay` | Extract high-scoring prompt patterns |
| `/prompt-compare [#1] [#2]` | Compare two review sessions |
| `/prompt-template` | Save/use reusable prompt templates |

### Automatic Flow
- `git push` → commit to prompt repo (record only, via PostToolUse hook)
- `gh pr create` → create PR in prompt repo (integrated scoring)

## Example PR

```markdown
## 🔵 Score: 73/100 — JWT refresh logic refactoring

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
### Prompt 1 🟢
```
Refactor JWT refresh logic...
```

## Improvement Suggestions
### Exit Criteria (4/10)
> Claude exceeded scope. Prompt Gap: no exit criteria specified.
```

## Tech Stack

| Tech | Role |
|------|------|
| Claude Code Skill | Markdown-based workflow |
| Claude Code Hook | Auto-detect `git push` (`PostToolUse`) |
| `gh` CLI | PR creation and management |
| Git | Code diff extraction |
| Bash | Skill execution logic |

## Current Status

- [x] Core decisions confirmed (A: trigger, B: repo strategy, code role, Gap model)
- [x] PR template design and example complete
- [x] Evaluation criteria confirmed (C: 8 criteria, 100 points)
- [x] Review workflow confirmed (D: same as code review)
- [x] SKILL.md rewritten (two-phase capture + 8 criteria)
- [x] PR template updated (new 8 criteria scorecard)
- [x] PostToolUse hook implemented (git push / gh pr create detection)
- [x] `/prompt-feedback` skill added (local scoring)
- [x] Install/uninstall scripts updated
- [ ] E2E testing

## License

MIT — see [LICENSE](LICENSE)
