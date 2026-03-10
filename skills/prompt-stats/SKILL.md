---
name: prompt-stats
description: "[DEPRECATED] Use /insights instead. Redirects automatically."
---

> **Deprecated:** `/prompt-stats` has been renamed to `/insights` in Prompt Craft v2.0.
> This alias will be removed in a future version. Please update your workflow.

**Received arguments:** $ARGUMENTS

## Migration Reference

| v1.x Command | v2.0 Command |
|---|---|
| `/prompt-review` | `/review` |
| `/prompt-feedback` | `/score` |
| `/prompt-stats` | `/insights` |
| `/prompt-tips` | `/coach` |
| `/prompt-replay` | `/insights patterns` |
| `/prompt-compare` | `/insights compare` |
| `/prompt-template` | `/coach template` |
| `/setup` | `/review --doctor` |

## Action

1. Display the deprecation notice above to the user
2. Immediately invoke the new skill using the Skill tool: `skill: "insights"`, `args: "$ARGUMENTS"`
