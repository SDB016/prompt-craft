# Prompt Craft — Quick Reference

## 6 Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| **review** | `/review` | Create prompt review PR (core flow) |
| **score** | `/score` | Local scoring, no PR |
| **insights** | `/insights` | Trends, patterns, comparison |
| **coach** | `/coach` | Pre-task tips + templates |
| **setup** | `/setup` | First-time configuration |
| **setup-project** | `/setup-project` | Per-project capture settings |

## review

```bash
/review                    # create prompt review PR
/review --push             # hook-triggered push capture
/review --status           # show config + recent PRs
/review --doctor           # check prerequisites (git, gh, jq)
/review --setup            # reconfigure settings
/review --setup --advanced # full setup wizard
```

## score

```bash
/score                     # score current session locally
/score --verbose           # include per-prompt breakdown
```

## insights

```bash
/insights                  # score trends (default)
/insights --team           # all authors
/insights --last 20        # last 20 reviews
/insights patterns         # high-scoring prompt patterns
/insights patterns --min-score 90
/insights compare #1 #2    # side-by-side PR comparison
```

## coach

```bash
/coach                     # contextual prompt tips
/coach feature             # tips for feature task
/coach template save X     # save a template
/coach template list       # list templates
/coach template use X      # load a template
/coach template delete X   # remove a template
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

## setup-project

```bash
/setup-project             # show current project capture status
/setup-project on          # enable capture for current project
/setup-project on --repo R # enable with specific review repo
/setup-project off         # disable capture (silently skipped)
/setup-project list        # show all project settings
/setup-project reset       # re-enable asking for skipped project
```

## Automatic Flow

1. **On `git push`** → prompts + diff recorded as commit in prompt repo
2. **On `gh pr create` or `/review`** → aggregate, score, create review PR

## Config

`~/.claude/prompt-review.config.json`

## Requirements

- `gh` CLI installed and authenticated (`gh auth login`)
- A GitHub repo for prompt reviews (public or private)
