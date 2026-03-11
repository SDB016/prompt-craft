# Prompt Craft

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**English** | [한국어](README.ko.md) | [日本語](README.ja.md) | [中文](README.zh.md)

**Prompt review for Claude Code — because code review looks at results, prompt review looks at causes.**

> You review each other's code. Why not review each other's prompts?
>
> Prompt Craft captures your Claude Code prompts, scores them against 8 quality criteria,
> and creates a GitHub PR in a dedicated review repo — so your team can give feedback
> on the *instructions* that produced the code, not just the code itself.

---

## What It Does

```
You work with Claude Code as usual.
No extra steps. No interruptions.

                                            ┌─────────────────────────────┐
  git push  ──→  metadata logged silently   │  ~/.claude/pushlog.jsonl    │
  git push  ──→  metadata logged silently   │  (no network, no blocking)  │
  git push  ──→  metadata logged silently   └─────────────────────────────┘
                                                        │
  /review   ──→  collect prompts from session           │
             ──→  score against 8 criteria    ◄─────────┘
             ──→  create PR in review repo

                        ▼

  ┌─ PR in review repo ──────────────────────────────────────┐
  │                                                          │
  │  PR body       Score badge + Review Focus                │
  │                                                          │
  │  Files Changed:                                          │
  │    prompts.md   ← reviewers leave line comments here     │
  │    summary.md   ← scorecard, improvements, metadata      │
  │                                                          │
  └──────────────────────────────────────────────────────────┘
```

**Zero friction during development.** The push hook is silent (<100ms, no approvals).
All the heavy work (scoring, PR creation) happens only when you run `/review`.

**Zero project footprint.** Nothing is written to your project repo. All review PRs go to a separate repo (e.g., `my-org/ai-sessions`).

---

## Quick Start

**Step 1: Install**
```
/install-plugin https://github.com/sdb016/prompt-craft
```

**Step 2: Setup (right after install)**
```
/setup           # Asks for your review repo → auto-configures everything
```

**Step 3: Use**
```
# Work normally... push code... then when ready:
/review          # Create prompt review PR for team feedback
/score           # Local scoring only (no PR, instant feedback)
```

> **Note:** Restart Claude Code after first install for the push hook to activate.

---

## Why Prompt Craft?

| Problem | How Prompt Craft helps |
|---------|----------------------|
| "Claude went off-scope" | Prompt review reveals missing exit criteria and scope constraints |
| "How did they get Claude to do that?" | Team sees the exact prompt sequence that produced great results |
| "My prompts work but feel inefficient" | 8-criteria scoring with concrete rewrite suggestions |
| "Code review only catches effects, not causes" | Prompt review catches the *instructions* that led to the code |
| "I want to improve but don't know what to change" | Per-prompt mini-scores pinpoint which prompts need work |

---

## Skills

| Skill | Purpose |
|-------|---------|
| `/review` | Create prompt review PR for team feedback |
| `/score` | Local scoring + improvement tips (instant, no PR) |
| `/insights` | Score trends, high-scoring patterns, session comparison |
| `/prompt-guide` | Pre-task prompt guide + reusable templates |
| `/setup-project` | Per-project capture settings (enable, disable, custom repo) |

### review

| Command | Action |
|---------|--------|
| `/review` | Create prompt review PR |
| `/review --status` | Show config + recent PRs |
| `/review --doctor` | Check prerequisites (git, gh, jq) |
| `/review --setup` | Reconfigure settings |

### insights

| Command | Action |
|---------|--------|
| `/insights` | Score trends over time |
| `/insights --team` | All authors' trends |
| `/insights patterns` | Extract high-scoring prompt patterns |
| `/insights compare #1 #2` | Compare two review sessions |

### prompt-guide

| Command | Action |
|---------|--------|
| `/prompt-guide` | Contextual prompt writing tips |
| `/prompt-guide template save/list/use/delete` | Manage reusable templates |

### setup-project

| Command | Action |
|---------|--------|
| `/setup-project` | Show current project capture status |
| `/setup-project on` | Enable capture for current project |
| `/setup-project on --repo R` | Enable with a specific review repo |
| `/setup-project off` | Disable capture (silently skipped) |
| `/setup-project list` | Show all project settings |
| `/setup-project reset` | Re-enable asking for a skipped project |

---

## How It Works

### During development (automatic, silent)

Every `git push` inside Claude Code silently appends one line to a local log file. No network, no AI, no blocking — you won't even notice it.

### At review time (on-demand)

When you run `/review` (or when `gh pr create` is detected), Prompt Craft:

1. Reads push metadata from the local log
2. Collects all prompts from your current session
3. Scores them against 8 quality criteria (single LLM call)
4. Creates two files in your review repo:
   - **`prompts.md`** — prompt sequence as plain text (reviewers leave line comments here)
   - **`summary.md`** — scorecard, code impact, improvement suggestions, metadata
5. Opens a PR with a slim body pointing to Files Changed

### Automatic Flow

| Event | What happens | Where |
|-------|-------------|-------|
| `git push` | Record push metadata silently | Local JSONL (<100ms) |
| `gh pr create` | Score prompts + create review PR | Review repo PR |
| `/review` (manual) | Create review PR at desired time | Review repo PR |
| `/score` (manual) | Score locally, cache results | Local only (instant) |

---

## PR Structure

Reviewers see two files in the **Files Changed** tab:

| File | Purpose | Reviewer action |
|------|---------|-----------------|
| **`prompts.md`** | Full prompt sequence as plain text | Leave line comments on specific prompts |
| **`summary.md`** | Scorecard, code impact, improvements, metadata | Read for context and scoring details |

The PR body is a slim summary: score badge + review focus + "open Files Changed to review."

### Example

**PR body:**
```markdown
## 🔵 Score: 74/100 — JWT refresh logic refactoring

> Prompts: 6 | Duration: ~38 min | Session: 2026-03-08 by @dev-alice

### Review Focus
Exit Criteria scored 4/10 — prompts #2 and #3 had no stopping condition,
causing Claude to modify files beyond scope.

### How to Review
| File | What's inside | Action |
|------|---------------|--------|
| prompts.md | Prompt sequence | Leave line comments |
| summary.md | Scorecard + improvements | Read for context |
```

**prompts.md** (in Files Changed):
```markdown
## Review Focus
Exit Criteria scored 4/10 — prompts #2 and #3 had no stopping condition...

## Prompt Sequence

### Prompt 1 🟢
Refactor the JWT refresh logic in src/auth/refresh.ts.
Context: We decided last week to use a mutex...
Done when: src/auth/refresh.ts exports refreshToken(userId)...

Goal 20/20 · Exit 9/10 · Scope 12/15 · Context 14/15

### Prompt 2 🔵
Now update the middleware to use the new refreshToken() function.
Also add tests for the concurrent refresh case.

Goal 12/20 · Exit 4/10 · Scope 6/15 · Context 8/15
```

---

## Scoring System

8 criteria, 100 points total. Scored in a single LLM call.

| Criterion | Points | What it evaluates |
|-----------|--------|-------------------|
| Goal Clarity | 20 | Is the goal specific? Does the result match intent? |
| Scope Control | 15 | Are boundaries set? Constraints stated? No out-of-scope changes? |
| Context Sufficiency | 15 | Enough background provided? Reference code/patterns specified? |
| Exit Criteria | 10 | Are completion/stop conditions stated and followed? |
| Decomposition | 10 | Are complex tasks properly broken down? |
| Verification Strategy | 10 | Are verification methods specified? |
| Iteration Quality | 10 | Are follow-up requests specific and concrete? |
| Complexity Fit | 10 | Is prompt sophistication appropriate for task complexity? |

**Grade bands:** 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor

### Prompt Gap Model

| Gap | What it means | Who evaluates |
|-----|---------------|---------------|
| Gap 1: Intent → Prompt | Did the prompt capture what you actually wanted? | Humans (via review) |
| Gap 2: Prompt → Code | Did the prompt defect cause a code defect? | AI (cause→effect chain) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Hook not firing after install | Restart your Claude Code session to reload plugin hooks |
| Config errors | Delete `~/.claude/prompt-review.config.json` and run `/setup` to reconfigure |
| `/review` shows no prompts | Run `/review` from the same session where you worked. Or run `/score` first to cache results |

---

## Requirements

- [Claude Code](https://docs.anthropic.com/claude-code) CLI
- [`gh` CLI](https://cli.github.com/) (for PR creation)
- Git

---

## License

MIT — see [LICENSE](LICENSE)
