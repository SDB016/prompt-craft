# Architect Review - System Architecture Analysis

## Key Findings

### 1. Claude Code Session Data Is Not an Official API

**Location**: `~/.claude/projects/{encoded-path}/{session-uuid}.jsonl`

**Format** (verified):
```json
{
  "type": "user" | "assistant" | "file-history-snapshot",
  "message": {
    "role": "user" | "assistant",
    "content": "..."
  },
  "sessionId": "uuid",
  "cwd": "/path/to/project",
  "version": "2.0.27",
  "timestamp": "..."
}
```

**Risks**:
- Internal implementation detail
- No compatibility guarantees across version changes
- Parser may break

**Mitigation**:
- Implement a version-aware parser
- Graceful degradation for unknown formats
- Add real-time capture option in Phase 2

---

## System Components

### 5 Main Components

| Component | Responsibility | Data Source |
|-----------|---------------|------------|
| **Session Extractor** | JSONL parsing, conversation reconstruction | `~/.claude/projects/` |
| **Diff Collector** | Code change extraction | `git diff`, `git log` |
| **Metadata Generator** | Session summary, decision extraction | LLM analysis |
| **PR Formatter** | PR body structuring | Output from above components |
| **GitHub Publisher** | PR creation | `gh` CLI |

---

## Data Flow

```
[1] User: /prompt-review
         |
[2] Session Extractor
    Read ~/.claude/projects/{cwd}/{sessionId}.jsonl
         |
[3] Diff Collector
    Run git diff + git log
         |
[4] Metadata Generator
    Generate summary via LLM
         |
[5] PR Formatter
    Assemble markdown PR body
         |
[6] USER PREVIEW + CONFIRM
         |
[7] GitHub Publisher
    Create branch -> commit -> push -> PR
```

---

## Architectural Tension Points

### "Learning Archive" vs "Code PR"

**Problem**:
- GitHub PRs are designed for code review
- Session documents are designed for knowledge sharing
- Different audiences, workflows, and lifecycles

### Solution Options

| Option | Mechanism | Pros | Cons |
|--------|-----------|------|------|
| **Single PR + rich body** | Code diff + narrative in PR body | Simple | PR body is poorly suited for long narratives |
| **PR + wiki** | PR (code) + wiki page (session) | Separation of concerns | Two things to maintain |
| **PR + session file** (recommended) | Commit `.sessions/file.md` | Version-controlled + searchable | Adds non-code files |
| **Issue + PR** | Issue (narrative) + PR (code) | Aligns with Prompt Request Platform design | Increased complexity |

**Recommendation**: **PR + session file** (Option 3)

**Rationale**:
- Self-contained (no external infrastructure required)
- Searchable via Git
- All context included in a single PR
- Aligns with the Prompt Request Platform vision

---

## Integration Points

### Claude Code Session API (Unofficial)

**Risk**:
- No official API
- Format may change
- No stability guarantees

**Mitigation**:
```typescript
interface SessionParser {
  version: string;
  parse(line: string): SessionEntry | null;

  // Version-aware parsing
  static create(version: string): SessionParser {
    if (version.startsWith('2.0')) {
      return new SessionParserV2();
    }
    throw new Error(`Unsupported session format: ${version}`);
  }
}
```

### GitHub API (via `gh` CLI)

**Benefits**:
- Already authenticated
- Automatic token management
- Standard within the OMC ecosystem

**Required operations**:
- `gh pr create --title "..." --body-file ...`
- `git push -u origin {branch}`
- `gh pr view` (verification)

### LLM Summarization

The skill execution agent handles this naturally:
- No separate API call needed
- "Analyze and summarize" is included in the skill prompt
- Context window management required (for large sessions)

---

## Scalability

### Session Size Constraints

**Problem**: Long sessions can produce tens of thousands of JSONL lines

**Options**:
1. **Full transcript, chunked summarization** - Accurate but slow
2. **Selective extraction** (recommended) - User messages + tool results only
3. **Header + tail + sampling** - Fast but may introduce distortion

**Recommendation**: Option 2 (MVP)

```bash
# Only extract user prompts and tool results
jq 'select(.type == "user" or .tool_use or .tool_result)' session.jsonl
```

### Extension Points

```yaml
# .omc/project-memory.json
prompt_review:
  target_repo: "owner/archive"
  pr_template: "custom-template.md"
  redaction_rules:
    - pattern: "internal\.company\.com"
      replacement: "[REDACTED-DOMAIN]"
```

---

## Architectural Challenges

### 1. Session Identification (HIGH)

**Problem**: How do we find the "current session"?

**Approach**:
1. Check the environment variable `$SESSION_ID` (unofficial)
2. CWD encoding + most recently modified file (fallback)
3. Record at session start in OMC state

```bash
# Find current session JSONL
PROJECT_HASH=$(echo "$PWD" | base64 | tr -d '=/')
SESSION_DIR="$HOME/.claude/projects/$PROJECT_HASH"
LATEST_SESSION=$(ls -t "$SESSION_DIR"/*.jsonl | head -1)
```

### 2. Content Sensitivity (HIGH)

**Risk**: Sessions may contain API keys, secrets, or PII

**Required mitigations**:
1. **Mandatory preview** - User confirmation before uploading to GitHub
2. **Automatic secret scanning** - Regex pattern matching
3. **Redaction markers** - Replace with `[REDACTED]`
4. **Opt-in granularity** - User selects what to include

```bash
SECRET_PATTERNS=(
  'sk-[a-zA-Z0-9]{20,}'           # OpenAI
  'ghp_[a-zA-Z0-9]{36}'           # GitHub PAT
  'AKIA[0-9A-Z]{16}'              # AWS
  'password["\s:=]+[^\s"]+'       # Generic
)
```

### 3. Dirty Git State (MEDIUM)

**Problem**: The working tree may be dirty when the skill runs

**Approach**:
1. `git stash` (save temporary changes)
2. Create a new branch
3. Restore stash
4. Add session files
5. Commit & push
6. Switch back to the original branch
7. Restore stash

**Responsibility**: Delegate to the `git-master` agent

---

## Architecture Recommendations

### 1. Manual Review First (Low effort, High impact)

```
Skill generates PR body -> Display to user -> Get approval -> Publish
```

**No automatic publishing** - Addresses sensitivity concerns

### 2. `.sessions/` Directory Pattern (Low effort, High impact)

```
sessions/
  2026-03-07-refactor-jwt-auth.md
  2026-03-06-csv-export.md
```

- Version-controlled
- Searchable
- No external infrastructure required

### 3. Version-Aware JSONL Parser (Medium effort, High impact)

```typescript
function parseSessionLine(line: string): SessionEntry | null {
  const entry = JSON.parse(line);
  const version = entry.version || '1.0';

  if (!isSupportedVersion(version)) {
    console.warn(`Unsupported session format: ${version}`);
    return null; // Graceful degradation
  }

  return extractEntry(entry);
}
```

### 4. Automatic Secret Detection (Medium effort, Critical)

Required before PR publishing:
- Regex pattern scanning
- Flag detected items
- Require user confirmation

### 5. OMC Project Memory Integration (Low effort, Medium impact)

```json
// .omc/project-memory.json
{
  "prompt_review": {
    "target_repo": "owner/sessions",
    "branch_prefix": "session/",
    "auto_merge": false
  }
}
```

---

## Tradeoffs

| Decision | Pros | Cons |
|----------|------|------|
| **Post-hoc JSONL parsing** | Can capture sessions retroactively | Depends on an unofficial format |
| **Using `gh` CLI** | Simple authentication | Requires `gh` to be installed |
| **Committing session files** | Version-controlled | Adds non-code files |
| **Manual review** | Safe | Adds an extra step |

---

## Antithesis (Counterarguments)

**Strongest opposing argument**:

Session data extraction **depends on an undocumented internal format** in `~/.claude/projects/`. Anthropic can change it without notice.

OMC skills are markdown workflow templates, **not** binary/JSONL parsing abstractions.

The reason the `learner` skill works: it captures from the **current conversation context** (in-memory), rather than reading historical files from disk.

**A more robust approach**:
Real-time capture (a hook logs prompts during the session) produces clean structured data and is more stable than post-hoc JSONL parsing.

---

## Synthesis (Conclusion)

**Implement both approaches**:

1. **Lightweight hook** - Log to `.omc/session-log.md` during the session
   - Opt-in: `/prompt-review --start-recording`
   - Primary data source

2. **Fallback JSONL parser** - Post-hoc extraction when the hook is not active
   - Best-effort
   - Version-aware

The skill prioritizes the hook log and falls back to JSONL only when unavailable.

**Supporting both use cases**:
- Planned documentation (real-time)
- Spontaneous sharing (post-hoc)
