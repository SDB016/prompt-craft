---
name: setup
description: Check prerequisites and configure Prompt Craft. Verifies gh CLI, jq, git are installed and offers to install missing dependencies. Run this before using other prompt-* skills.
argument-hint: "[--check-only]"
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Prompt Setup Skill

Checks all prerequisites for Prompt Craft and guides the user through installation of missing dependencies and initial configuration.

**Received arguments:** $ARGUMENTS

---

## Step 0: Route

- If `$ARGUMENTS` contains `--check-only` → run **[PREREQUISITE CHECK]** only, then stop
- Otherwise → run **[PREREQUISITE CHECK]**, then proceed to **[CONFIGURATION]**

---

## [PREREQUISITE CHECK]

Check each required tool. Report status for all tools before taking any action.

### Tools to Check

```bash
# 1. git
if command -v git &>/dev/null; then
  echo "✓ git $(git --version | head -1)"
else
  echo "✗ git — not found"
fi

# 2. GitHub CLI (gh)
if command -v gh &>/dev/null; then
  echo "✓ gh $(gh --version | head -1)"
  # Check authentication
  if gh auth status &>/dev/null 2>&1; then
    echo "  ✓ authenticated"
  else
    echo "  ✗ not authenticated"
  fi
else
  echo "✗ gh — not found"
fi

# 3. jq
if command -v jq &>/dev/null; then
  echo "✓ jq $(jq --version 2>/dev/null)"
else
  echo "✗ jq — not found"
fi
```

### Display Results

Show a summary table:

```
Prompt Craft — Prerequisite Check

| Tool | Status    | Version         |
|------|-----------|-----------------|
| git  | ✓ / ✗    | x.y.z or —      |
| gh   | ✓ / ✗    | x.y.z or —      |
| jq   | ✓ / ✗    | x.y.z or —      |
| gh auth | ✓ / ✗ | logged in or —  |
```

If `--check-only`, stop here and report the result.

---

## [INSTALL MISSING DEPENDENCIES]

For each missing tool, ask the user for permission before installing.

**Important:** Never install anything without explicit user consent.

### Detect Package Manager

```bash
if command -v brew &>/dev/null; then
  echo "PKG_MANAGER=brew"
elif command -v apt-get &>/dev/null; then
  echo "PKG_MANAGER=apt"
elif command -v dnf &>/dev/null; then
  echo "PKG_MANAGER=dnf"
elif command -v pacman &>/dev/null; then
  echo "PKG_MANAGER=pacman"
else
  echo "PKG_MANAGER=none"
fi
```

### Install Commands by Package Manager

| Tool | brew | apt | dnf | pacman |
|------|------|-----|-----|--------|
| git | `brew install git` | `sudo apt-get install -y git` | `sudo dnf install -y git` | `sudo pacman -S git` |
| gh | `brew install gh` | See note below | `sudo dnf install -y gh` | `sudo pacman -S github-cli` |
| jq | `brew install jq` | `sudo apt-get install -y jq` | `sudo dnf install -y jq` | `sudo pacman -S jq` |

**Note for gh on apt:**
```bash
(type -p wget >/dev/null || sudo apt install wget -y) \
  && sudo mkdir -p -m 755 /etc/apt/keyrings \
  && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && sudo apt update \
  && sudo apt install gh -y
```

### Installation Flow

For each missing tool:

1. **Ask:** "{tool} is not installed. Install it using `{install_command}`?"
2. **Wait for user confirmation** — do NOT proceed without explicit "yes"
3. **Install:** Run the install command
4. **Verify:** Re-check with `command -v {tool}`
5. **Report:** "✓ {tool} installed successfully" or "✗ Installation failed. Install manually: {manual_instructions}"

If no package manager is detected:
- Show manual install instructions with download URLs
- git: https://git-scm.com/downloads
- gh: https://cli.github.com/
- jq: https://jqlang.github.io/jq/download/

---

## [GH AUTHENTICATION]

If gh is installed but not authenticated:

1. **Ask:** "GitHub CLI is not authenticated. Run `gh auth login` now?"
2. If yes, run:

```bash
gh auth login
```

3. Verify:

```bash
gh auth status
```

---

## [CONFIGURATION]

After all prerequisites pass, check if Prompt Craft is already configured:

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
if [ -f "$CONFIG_FILE" ]; then
  echo "CONFIG_EXISTS=true"
  jq '.' "$CONFIG_FILE"
else
  echo "CONFIG_EXISTS=false"
fi
```

- If config exists → show current config and ask: "Configuration already exists. Reconfigure?"
- If no config or user wants to reconfigure → proceed to **[CONFIGURATION WIZARD]**

---

## [CONFIGURATION WIZARD]

### Step C-1: Collect the Review Repository

**Ask:** "Which GitHub repository should prompt reviews be sent to? (format: `owner/repo`)"

Examples: `myname/ai-sessions`, `myorg/prompt-reviews`

**Validate:**
- Must match `[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+`
- Check accessibility via `gh repo view`

```bash
REPO="USER_PROVIDED_REPO"

gh repo view "$REPO" --json name 2>/dev/null \
  && echo "REPO_ACCESSIBLE=true" \
  || echo "REPO_ACCESSIBLE=false"
```

If not accessible, offer:
1. **Create it** — `gh repo create "$REPO" --public` (or `--private`)
2. **Try a different name**

---

### Step C-2: Branch and PR Defaults

**Ask:** "How should prompt review branches be named?"

**Options:**
1. **`prompt-review/YYYY-MM-DD-slug`** (default)
2. **`review/topic-slug`**
3. **Custom prefix**

Then ask for base branch (`main` or `master` or custom).

---

### Step C-3: Write Configuration

```bash
CONFIG_FILE="$HOME/.claude/prompt-review.config.json"
mkdir -p "$(dirname "$CONFIG_FILE")"

jq -n \
  --arg repo "$REPO" \
  --arg branch_prefix "$BRANCH_PREFIX" \
  --arg base_branch "$BASE_BRANCH" \
  --arg label "prompt-review" \
  '{
    repo: $repo,
    branch_prefix: $branch_prefix,
    base_branch: $base_branch,
    label: $label,
    created_at: (now | todate)
  }' > "$CONFIG_FILE"
```

---

## [FINAL REPORT]

Display a final summary:

```
Prompt Craft Setup Complete

Prerequisites:
  ✓ git x.y.z
  ✓ gh x.y.z (authenticated)
  ✓ jq x.y.z

Configuration:
  ✓ Config file: ~/.claude/prompt-review.config.json
    Review repo: owner/ai-sessions
    Branch prefix: prompt-review/
    Base branch: main

Ready to use:
  /prompt-review        — Create prompt review PR
  /prompt-feedback      — Local scoring
  /prompt-tips          — Pre-task guide
  /setup --check-only   — Re-check prerequisites
```

---

## Error Handling

All errors use this format:

```
Error: [what went wrong]
Cause: [why it happened]
Fix:   [exact command to resolve]
```

| Error | Fix |
|-------|-----|
| No package manager found | Show manual download URLs |
| Install command failed | Show manual install alternative |
| gh auth failed | `gh auth login --web` |
| Permission denied (sudo) | Ask user to run manually with sudo |
