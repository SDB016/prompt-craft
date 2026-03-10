---
name: setup
description: Configure Prompt Craft — set your review repository and preferences. Run this after installing the plugin.
argument-hint: "[--advanced]"
allowed-tools: Bash, Read
---

# Prompt Craft Setup

First-time configuration for Prompt Craft. Sets up your review repository and preferences so prompt capture and review features work.

**Received arguments:** $ARGUMENTS

---

## Step 0: Route

- If `$ARGUMENTS` contains `--advanced` → invoke the Skill tool: `skill: "review"`, `args: "--setup --advanced"`
- Otherwise → continue with Quick Setup below

---

## Step 1: Check Existing Config

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

if [ -f "$CONFIG_FILE" ]; then
  REPO=$(jq -r '.repo // empty' "$CONFIG_FILE" 2>/dev/null)
  VERSION=$(jq -r '.config_version // "unknown"' "$CONFIG_FILE" 2>/dev/null)
  echo "EXISTING_CONFIG=true"
  echo "REPO=$REPO"
  echo "VERSION=$VERSION"
else
  echo "EXISTING_CONFIG=false"
fi
```

If existing config found, show summary and ask:

**Question:** "Prompt Craft is already configured for `{REPO}` (config v{VERSION}). What would you like to do?"

**Options:**
1. **Keep current config** — No changes needed
2. **Reconfigure** — Set up again from scratch
3. **Advanced setup** — Full wizard with all options (`/review --setup --advanced`)

If user picks option 1, show current config summary and exit.
If user picks option 3, invoke the Skill tool: `skill: "review"`, `args: "--setup --advanced"`

---

## Step 2: Prerequisites Check

```bash
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI is required."
  echo "Cause: GitHub CLI not installed."
  echo "Fix:   Install from https://cli.github.com/ then run: gh auth login"
  exit 0
fi

if ! gh auth status &>/dev/null 2>&1; then
  echo "Error: Not authenticated with GitHub."
  echo "Cause: gh auth session expired or not configured."
  echo "Fix:   Run: gh auth login"
  exit 0
fi

echo "PREREQS_OK=true"
```

---

## Step 3: Ask Review Repository

**Question:** "Which GitHub repository should prompt reviews be sent to? (format: owner/repo)"

Examples: `myname/ai-sessions`, `myorg/prompt-reviews`

**Validate:**
- Must match `[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+`
- Check accessibility via `gh repo view`

```bash
REPO="USER_PROVIDED_REPO"

gh repo view "$REPO" --json name 2>/dev/null \
  && echo "REPO_ACCESSIBLE=true" \
  || echo "REPO_ACCESSIBLE=false"

IS_PRIVATE=$(gh repo view "$REPO" --json isPrivate --jq '.isPrivate' 2>/dev/null || echo "unknown")
echo "REPO_IS_PRIVATE=$IS_PRIVATE"
```

If not accessible, offer to create the repo or try a different name.

If `REPO_IS_PRIVATE=false` (public repo), show warning:

**Question:** "Warning: `{REPO}` is a **public repository**. Your prompt session data will be publicly visible. How would you like to proceed?"

**Options:**
1. **Use anyway** — I understand my data will be public
2. **Choose a different repo** — Go back to repo selection
3. **Make it private first** — Run `gh repo edit {REPO} --visibility private` then continue

---

## Step 4: Write Config

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

jq -n \
  --arg repo "$REPO" \
  '{
    config_version: "1.3",
    repo: $repo,
    branch_prefix: "prompt-review/",
    base_branch: "main",
    label: "prompt-review",
    capture: { mode: "ask", projects: {} },
    language: "auto",
    created_at: (now | todate)
  }' > "$CONFIG_FILE"
```

---

## Step 5: Display Confirmation

```
Prompt Craft configured!

  Review repo:     owner/ai-sessions
  Branch prefix:   prompt-review/  (default)
  Base branch:     main  (default)
  Language:        auto  (default)
  Capture mode:    ask  (asks on first push per project)
  Config version:  1.3
  Config saved:    ~/.claude/prompt-review.config.json

What happens next:
  1. git push     → Prompts auto-captured to prompt repo (commit only)
  2. gh pr create → Prompt review PR created with scoring (or run /review)
  3. /score       → Check prompt quality locally before pushing
  4. /coach       → Get prompt writing tips before starting a task
  5. /insights    → View score trends after multiple sessions

Note: Push hooks activate after restarting Claude Code (if this is your first install).

Tip: Try /score now to see how your current session prompts score.

Customize all settings: /setup --advanced
```

---

## Error Handling

All errors use this format:

```
Error: [what went wrong]
Cause: [why it happened]
Fix:   [exact command to resolve]
```

| Error | Message |
|-------|---------|
| gh CLI not found | `Error: gh CLI is required.` / `Cause: GitHub CLI not installed.` / `Fix: Install from https://cli.github.com/ then run: gh auth login` |
| Not authenticated | `Error: Not authenticated with GitHub.` / `Cause: gh auth session expired or not configured.` / `Fix: Run: gh auth login` |
| Repo not accessible | `Error: Cannot access {REPO}.` / `Cause: Repository doesn't exist or you lack access.` / `Fix: Check the name and try again.` |
