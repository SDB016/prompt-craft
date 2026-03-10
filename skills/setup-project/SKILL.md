---
name: setup-project
description: Manage per-project prompt capture settings — enable, disable, or configure which repo each project uses.
argument-hint: "[on|off|list|reset|status] [--repo owner/repo]"
allowed-tools: Bash, Read
---

# Project Capture Management

Manage which projects have prompt capture enabled and configure per-project review repositories.

**Received arguments:** $ARGUMENTS

---

## Step 0: Route

- If `$ARGUMENTS` is empty or `status` → jump to **[STATUS]**
- If `$ARGUMENTS` starts with `on` → jump to **[ON]**
- If `$ARGUMENTS` starts with `off` → jump to **[OFF]**
- If `$ARGUMENTS` starts with `list` → jump to **[LIST]**
- If `$ARGUMENTS` starts with `reset` → jump to **[RESET]**
- Otherwise → show usage

### Usage

```
/setup-project              Show current project capture status
/setup-project on           Enable capture for current project (uses default repo)
/setup-project on --repo R  Enable capture with a specific review repo
/setup-project off          Disable capture for current project
/setup-project list         Show all project capture settings
/setup-project reset        Remove current project from deny list (re-enables asking)
```

---

## Pre-flight

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Prompt Craft not configured."
  echo "Cause: No config file found."
  echo "Fix:   Run /setup first."
  exit 0
fi

REMOTE_URL=$(git remote get-url origin 2>/dev/null || true)
PROJECT_ID=$(echo "$REMOTE_URL" | sed -E 's#^.*@[^:]+:##; s#^https?://[^/]+/##; s#^ssh://[^/]+/##; s#\.git$##')

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: Cannot identify project."
  echo "Cause: No git remote 'origin' found in this directory."
  echo "Fix:   Run this command inside a git repository with a remote."
  exit 0
fi

DEFAULT_REPO=$(jq -r '.repo // ""' "$CONFIG_FILE")
PROJECT_STATUS=$(jq -r --arg p "$PROJECT_ID" '.capture.projects[$p].status // ""' "$CONFIG_FILE" 2>/dev/null)
PROJECT_REPO=$(jq -r --arg p "$PROJECT_ID" '.capture.projects[$p].repo // ""' "$CONFIG_FILE" 2>/dev/null)
CAPTURE_MODE=$(jq -r '.capture.mode // "ask"' "$CONFIG_FILE" 2>/dev/null)
```

---

## [STATUS]

Display current project's capture status.

```
Prompt Craft — Project Status

  Project:    {PROJECT_ID}
  Status:     {tracked / skipped / not configured}
  Review repo: {PROJECT_REPO or DEFAULT_REPO} {(project-specific) or (default)}
  Capture mode: {CAPTURE_MODE}

  /setup-project on       Enable capture
  /setup-project off      Disable capture
  /setup-project list     Show all projects
```

Status mapping:
- `PROJECT_STATUS` = "allow" → "tracked"
- `PROJECT_STATUS` = "deny" → "skipped"
- `PROJECT_STATUS` = "" → "not configured (will ask on next push)"

---

## [ON]

Enable prompt capture for the current project.

### Parse --repo flag

Check if `$ARGUMENTS` contains `--repo`:

```bash
CUSTOM_REPO=""
# Extract --repo value from arguments if present
if echo "$ARGUMENTS" | grep -qE '\-\-repo\s+\S+'; then
  CUSTOM_REPO=$(echo "$ARGUMENTS" | sed -E 's/.*--repo\s+(\S+).*/\1/')
fi
```

If no `--repo` flag is provided, ask:

**Question:** "Which repo should prompt reviews for `{PROJECT_ID}` go to?"

**Options:**
1. **Use default** (`{DEFAULT_REPO}`) — Same repo as all other projects
2. **Use a different repo** — Enter owner/repo format

If user picks option 2, ask for the repo name and validate:

```bash
gh repo view "$CUSTOM_REPO" --json name 2>/dev/null \
  && echo "REPO_ACCESSIBLE=true" \
  || echo "REPO_ACCESSIBLE=false"
```

### Write to config

```bash
if [[ -n "$CUSTOM_REPO" ]]; then
  jq --arg p "$PROJECT_ID" --arg r "$CUSTOM_REPO" \
    '.capture.projects[$p] = {"status": "allow", "repo": $r}' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
else
  jq --arg p "$PROJECT_ID" \
    '.capture.projects[$p] = {"status": "allow"}' \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi
```

Display confirmation:

```
Enabled prompt capture for {PROJECT_ID}.
  Review repo: {CUSTOM_REPO or DEFAULT_REPO} {(project-specific) or (default)}

Prompts will be captured on next git push.
```

---

## [OFF]

Disable prompt capture for the current project.

```bash
jq --arg p "$PROJECT_ID" \
  '.capture.projects[$p] = {"status": "deny"}' \
  "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
```

Display confirmation:

```
Disabled prompt capture for {PROJECT_ID}.
Pushes from this project will be silently skipped.

Run /setup-project on to re-enable.
```

---

## [LIST]

Show all projects and their capture settings.

```bash
PROJECTS_JSON=$(jq -r '.capture.projects // {}' "$CONFIG_FILE" 2>/dev/null)
DEFAULT_REPO=$(jq -r '.repo // ""' "$CONFIG_FILE")
```

Display:

```
Prompt Craft — Project Capture Settings

Mode: {CAPTURE_MODE}
Default repo: {DEFAULT_REPO}

Tracked (prompts captured on push):
  {PROJECT_ID}    → {REPO or "(default)"}
  {PROJECT_ID}    → {REPO or "(default)"}

Skipped (no capture, won't ask):
  {PROJECT_ID}
  {PROJECT_ID}

Current project: {PROJECT_ID} ({status})
```

If no projects configured: `No projects configured yet. Projects are added automatically on first push.`

---

## [RESET]

Remove the current project from the deny list so the hook will ask again on next push.

```bash
PROJECT_STATUS=$(jq -r --arg p "$PROJECT_ID" '.capture.projects[$p].status // ""' "$CONFIG_FILE" 2>/dev/null)

if [[ "$PROJECT_STATUS" != "deny" ]]; then
  echo "Project $PROJECT_ID is not in the skip list."
  exit 0
fi

jq --arg p "$PROJECT_ID" 'del(.capture.projects[$p])' \
  "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
```

Display:

```
Removed {PROJECT_ID} from skip list.
You'll be asked about this project on next push.

Or run /setup-project on to enable capture now.
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
| No config | `Error: Prompt Craft not configured.` / `Cause: No config file found.` / `Fix: Run /setup first.` |
| No git remote | `Error: Cannot identify project.` / `Cause: No git remote 'origin' found.` / `Fix: Run inside a git repository with a remote.` |
| Repo not accessible | `Error: Cannot access {REPO}.` / `Cause: Repository doesn't exist or you lack access.` / `Fix: Check the name and try again.` |
| Not in skip list | `Project {ID} is not in the skip list.` |
