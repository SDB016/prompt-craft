# Quick Start - Prompt Craft

## Get Started in 5 Minutes

### 1. Install

```bash
# Inside Claude Code, run:
/install-plugin https://github.com/SDB016/prompt-craft
```

This installs all skills as Claude Code slash commands.

### 2. Initial Setup

```bash
# Run inside Claude Code
/prompt-review --setup
```

The setup wizard will guide you through:
- Selecting the prompt review repo
- Branch naming strategy

### 3. Work Normally

Prompts are recorded automatically on each `git push` inside Claude Code.
When you create a PR (`gh pr create`), a prompt review PR is also created.

```bash
# Or create a prompt review PR manually at any time:
/prompt-review
```

### 4. Check Your Score Mid-Session

```bash
/prompt-feedback
```

Get an instant scorecard of your current session prompts — no PR created, purely local.

### 5. Review the PR

Open the generated PR URL in your browser:
- Auto-scored scorecard with 8 criteria
- Assign a teammate as reviewer to start the prompt review

---

## Requirements

- Claude Code installed
- GitHub CLI (`gh`) installed and authenticated
- Git installed
- jq installed

### Install Dependencies

```bash
# macOS
brew install gh jq

# Linux
sudo apt install gh jq
```

### Authenticate

```bash
gh auth login
```

---

## Two Skills

| Skill | Purpose |
|-------|---------|
| `/prompt-review` | Create prompt review PR for team feedback |
| `/prompt-feedback` | Local scoring + tips (no PR) |
| `/prompt-stats` | Score trends over time |
| `/prompt-tips` | Pre-task prompt writing guide |
| `/prompt-replay` | Extract high-scoring patterns |
| `/prompt-compare` | Compare two sessions |
| `/prompt-template` | Reusable prompt templates |

---

## Common Patterns

### Pattern 1: Feature Development
```bash
# Work with Claude Code...
# git push during development → prompts recorded automatically
# When done, create PR → prompt review PR is also created
```

### Pattern 2: Mid-Session Self-Check
```bash
# Check your prompt quality before pushing
/prompt-feedback
# See score + tips, fix weak prompts, then push
```

### Pattern 3: Debugging Session Review
```bash
# Solve a complex bug...
# Share how you prompted with the team
/prompt-review --tag "debugging"
```

---

## Frequently Used Commands

| Command | Purpose |
|---------|---------|
| `/prompt-review` | Create prompt review PR |
| `/prompt-review --setup` | Change settings |
| `/prompt-review --status` | Check recent PRs |
| `/prompt-feedback` | Local score check |
| `/prompt-feedback --verbose` | Score with per-prompt breakdown |

---

## Troubleshooting

### "gh CLI not found"
```bash
which gh
brew install gh  # macOS
```

### "Not authenticated"
```bash
gh auth login
```

### "Cannot access repository"
```bash
gh repo view owner/repo
gh auth status
```

### Hook not firing
```bash
# Verify hook is installed
cat ~/.claude/settings.json | jq '.hooks'

# Re-install hook
bash ~/.claude/plugins/prompt-craft/skills/prompt-review/hooks/install-hook.sh
```

---

## Next Steps

- [Full documentation](README.md)
- [Security considerations](brainstorming/security-review.md)
- [Consolidated decisions](brainstorming/03-decisions.md)
- [Architecture decisions](decisions/01-architecture.md)
