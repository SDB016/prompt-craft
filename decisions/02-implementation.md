# Implementation Decisions

> **Note**: This document was written during the initial "session archiving" phase.
> The project has since pivoted to a **prompt review tool**.
> Most of the implementation decisions below remain valid. For the latest consolidated decision record, see `brainstorming/03-decisions.md`.

## Fully Independent vs. Integrated

### Background
Early in the project, a "Prompt Request Platform" project existed at `/Users/db-mac/Documents/code/playground/pr/`.

### Options Discussed

#### Option 1: Pure OMC Skill (Fully Independent)
- Completely separate from the PR platform
- Create GitHub PRs directly
- No server; all processing done locally
- Installation: just copy the skill file

#### Option 2: PR Platform Extension
- Leverage the existing PR project
- OMC skill = client
- PR platform = backend (metadata generation, storage, etc.)
- Installation: skill + server deployment

#### Option 3: Hybrid
- OMC skill calls the PR platform API
- Optional server features (prompt analysis, pattern extraction, etc.)
- Installation: skill required, server optional

### Final Decision
**Option 1: Fully Independent OMC Skill**

**Rationale**:
1. **Fast launch**: Immediately usable without server deployment
2. **Low barrier to entry**: Self-contained in a single skill file
3. **Simplified maintenance**: Only client code to manage
4. **Privacy**: All data processed locally
5. **No OMC dependency**: Uses only native Claude Code features

---

## OMC-Exclusive vs. General-Purpose Skill

### Background
The completed skill (`prompt-review`) does not use any OMC-specific tools:
- AskUserQuestion (built-in Claude Code feature)
- bash, gh, git (system tools)
- OMC state system (not used)
- OMC-specific agent delegation (not used)

### Discussion
**User question**: "Can users who don't use OMC and only use plain Claude Code not use this?"

### Current State
Skill location: `/Users/db-mac/.claude/skills/omc-learned/prompt-review/`
- Requires OMC installation
- Invocation: `/oh-my-claudecode:prompt-review`

### Possible Deployment Options

#### Option A: Keep OMC-Exclusive
**Pros**:
- Premium feature within the oh-my-claudecode ecosystem
- Consistent naming convention
- Focused on OMC users

**Cons**:
- Limited user base
- Requires OMC installation

#### Option B: Also Offer as a General-Purpose Claude Code Skill
**Pros**:
- Broader user base
- Usable with just Claude Code
- Increased potential for community contributions

**Cons**:
- Maintenance required in two locations
- Potential naming conflicts

#### Option C: Consolidate as General-Purpose
**Deployment location**:
```bash
~/.claude/skills/prompt-review/
```

**Invocation**:
```bash
/prompt-review
# or natural language
"save this session"
```

**Pros**:
- Single deployment point
- Maximum accessibility
- OMC users can use it the same way

### Deferred (Undecided)
This item has not been finalized yet.

**Next steps**:
1. Test with plain Claude Code
2. Confirm it works without OMC
3. Decide after gathering community feedback

---

## File Structure

### Current Structure
```
/Users/db-mac/.claude/skills/omc-learned/prompt-review/
├── SKILL.md        # Full skill definition (817 lines)
└── QUICKREF.md     # Quick reference card
```

### Future Extended Structure (Phase 2)
```
prompt-review/
├── SKILL.md
├── QUICKREF.md
├── templates/
│   ├── default.md       # Default PR template
│   ├── minimal.md       # Minimal template
│   └── detailed.md      # Detailed template
└── utils/
    ├── secret-scan.sh   # Secret scanning script
    └── format-diff.sh   # Diff formatting
```

---

## Data Flow

### Input
1. Current Claude Code session context
2. Git working directory state
3. User settings (`~/.claude/omc_config.prompt-review.json`)

### Processing
1. Session analysis (LLM)
2. Git diff extraction (git)
3. Secret scanning (regex)
4. PR body generation (markdown)

### Output
1. GitHub PR (via `gh` CLI)
2. Local audit log (optional)
3. User feedback (terminal)

---

## Settings Management

### Settings File Location
```bash
~/.claude/omc_config.prompt-review.json
```

### Settings Priority
1. CLI flags (one-time)
2. User-level settings (persistent)
3. Defaults

### Prohibited
- Reading project-level settings (for security reasons)
- Specifying the target repo via environment variables
- Automatic execution (no hook triggers)

---

## Error Handling Philosophy

### Principles
1. **Fail loudly**: Never fail silently
2. **Actionable errors**: Provide resolution steps
3. **Clean rollback**: Clean up partial state

### Error Message Format
```
Error: [What went wrong]
Cause: [Why it happened]
Fix:   [How to resolve it - including commands]
```

### Example
```
Error: gh CLI not found
Cause: GitHub CLI is required for PR creation
Fix:   Install from https://cli.github.com/
       Then authenticate: gh auth login
```

---

## Testing Strategy

### Phase 1 (Manual Testing)
- [ ] Initial setup flow
- [ ] Session capture (git repo)
- [ ] Session capture (non-git)
- [ ] Various prompt lengths
- [ ] Secret scanning behavior
- [ ] Error cases (no gh, no auth, etc.)

### Phase 2 (Automation)
- E2E test scripts
- Mock GitHub API
- Various Claude Code versions

---

## Performance Considerations

### Bottlenecks
1. Git diff (large repos)
2. Session JSONL parsing (long sessions)
3. LLM summary generation
4. GitHub API calls

### Optimization Strategies
1. **Git diff**: Run `--name-only` first, then full diff only when needed
2. **JSONL parsing**: Stream processing, skip unnecessary fields
3. **LLM summary**: Token limit (4K), fast model (Haiku)
4. **API calls**: Batch where possible

---

## Future Improvement Ideas

### Potential Community Requests
1. **Multi-format support**: JSON, YAML output
2. **Statistics dashboard**: Session trend analysis
3. **Prompt template extraction**: Reusable patterns
4. **Cross-session linking**: Automatic linking of related sessions
5. **Image capture**: Generated charts/diagrams

### Constraints
- Maintain local execution (no server)
- Minimize OMC dependency
- Keep it simple (focus on core features)
