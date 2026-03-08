# Architecture Decisions

> **Note**: This document was written during the initial "session archiving" phase.
> The project has since pivoted to a **prompt review tool**, but the architecture
> decisions below remain largely valid. For the latest consolidated decision record,
> see `brainstorming/03-decisions.md`.
>
> What has changed:
> - Decision 3 (Data Extraction): Shifted from post-hoc JSONL extraction to capturing based on current conversation context
> - Decision 4 (PR Structure): Shifted from "learning archive" to "prompt review" PR template
> - Trigger: Manual only to manual + Claude Code Hook (`PostToolUse`) automatic detection

## Decision 1: GitHub App vs OMC Skill

### Initial Idea
- Develop as a GitHub App
- Provide PR reviews on the server side

### Problems Identified
- Users are already **running Claude Code locally**
- Server deployment and maintenance overhead
- Users are already subscribed to a pricing plan

### Final Decision
**OMC Skill (Claude Code Plugin)**

**Rationale**:
1. Local execution ensures privacy
2. No server infrastructure required
3. Full context access through Claude Code
4. Minimal installation barrier

---

## Decision 2: Target Repository Strategy

### Options
1. **Same repo**: Create PRs in the working repo
2. **Separate repo**: Dedicated archive repo
3. **User's choice**: Specified via configuration

### Final Decision
**Dedicated archive repo (Option 2)**

**Rationale**:
- Avoids polluting the working repo with session documents
- Consolidates sessions from multiple projects in one place
- Enables cross-project learning via GitHub search/labels
- No conflicts with PR review workflows

**Configuration example**:
```json
{
  "repo": "myusername/ai-learning-sessions"
}
```

---

## Decision 3: Session Data Extraction Method

### Options
1. **Real-time capture**: Logging during the session via hooks
2. **Post-hoc extraction**: JSONL parsing
3. **Hybrid**: Support both

### Final Decision
**Post-hoc extraction (Option 2), with hybrid considered for Phase 2**

**Rationale**:
- Users don't need to decide before starting a session
- Supports the "this session was useful, let's save it" flow
- Immediately usable without configuration

**Acknowledged Risks**:
- Claude Code JSONL format is a private API
- Parser may break on version changes
- Defensive parsing + version checks are essential

**Phase 2 Enhancement**:
```bash
/prompt-review --start-recording  # Start real-time capture
```

---

## Decision 4: PR Structure

### "Learning Archive" vs "Code PR" Tension

**Problem**:
- GitHub PRs are designed for code review
- Session documents are for knowledge sharing

### Final Decision
**`.sessions/` Directory Pattern**

PR structure:
```
sessions/
  2026-03-07-refactor-jwt-auth.md   # New file added
```

**Rationale**:
- Version controlled (git history)
- Searchable (GitHub search)
- Summary in PR body, full content in file
- No conflicts with code repos
- Readable directly in the browser

---

## Decision 5: Authentication Strategy

### Options
1. GitHub PAT (Personal Access Token)
2. GitHub App
3. `gh` CLI
4. OAuth flow

### Final Decision
**`gh` CLI (Option 3)**

**Rationale**:
1. Already installed by most developers
2. Solves the token storage problem (managed by gh)
3. Automatic token refresh handling
4. Supports fine-grained permissions

**Fallback**:
- Clear installation instructions if `gh` is not available
- Guide to `gh auth login` if not authenticated

---

## Decision 6: Security Model

### Threats
1. API key leakage
2. Malicious repo redirection
3. Automated execution abuse

### Final Decision
**3-Layer Defense**

1. **Preview + Confirm**: User confirmation required before any data leaves
2. **Secret Scanning**: Automatic pattern matching and redaction
3. **User-level Config Only**: Project-level configuration is blocked

**Implementation**:
```bash
# Configuration location
~/.claude/omc_config.prompt-review.json  # Trusted
.omc/prompt-review.json                   # Blocked
```

---

## Architecture Diagram

```
┌─────────────────┐
│ User invokes    │
│ /prompt-review     │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│ Read current session        │
│ ~/.claude/projects/...jsonl │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Extract prompts + decisions │
│ Run git diff                │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Secret scanning             │
│ Pattern-based redaction     │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Generate PR body            │
│ Format as markdown          │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ PREVIEW + USER CONFIRM      │ ◄── Gate
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Clone archive repo (temp)   │
│ Create branch               │
│ Commit session file         │
│ Push + create PR via gh     │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Display PR URL              │
│ Cleanup temp files          │
└─────────────────────────────┘
```

---

## Technology Choice Rationale

| Technology | Reason for Selection |
|------------|---------------------|
| Bash | Standard execution environment for Claude Code skills |
| `gh` CLI | GitHub API abstraction, authentication management |
| JQ | JSON configuration file parsing |
| Git | Code diff extraction |
| Markdown | PR body and session document format |

---

## Scalability Considerations

### Phase 1 (MVP)
- Single session capture
- Manual execution
- Text-based

### Phase 2 (Possible)
- Multi-session aggregation
- Real-time capture mode
- Image/diagram support
- Prompt pattern analysis
- Cross-session search

### Scaling Constraints
- Dependency on Claude Code JSONL format
- GitHub API rate limits
- Local execution (serverless)
