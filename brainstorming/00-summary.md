# Team Brainstorming Summary

## Participating Experts

Five specialized agents participated in the brainstorming simultaneously in parallel:

1. **Architect** (oh-my-claudecode:architect) - Architecture and system design
2. **Planner** (oh-my-claudecode:planner) - Execution planning and roadmap
3. **Analyst** (oh-my-claudecode:analyst) - Requirements and product analysis
4. **Security Reviewer** (oh-my-claudecode:security-reviewer) - Security threat model
5. **Designer** (oh-my-claudecode:designer) - UX design and implementation

## Key Insights

### 🏗️ Architect
**Biggest Finding**: Claude Code session data is **not an official API**
- Location: `~/.claude/projects/{path}/{sessionId}.jsonl`
- Risk: Parser may break when the format version changes
- Solution: Hybrid approach combining real-time capture (stable) + post-hoc extraction (flexible)

**Architectural Tension**: "Learning archive" vs "Code PR"
- Proposal: Commit session markdown files to a `.sessions/` directory

### 📋 Planner
**Provided an immediately actionable plan**
- Implementation form: Standalone OMC skill
- Archive strategy: Centralized single repository
- Content: Focused on prompts + code (git diff)

### 🔍 Analyst
**Identified 9 unanswered questions**:
1. Target repository: Same repo vs separate repo?
2. Prompt history format?
3. GitHub authentication method?
4. Branch naming strategy?
5. Handling sessions with no code changes?
6. Sensitive information scrubbing?
7. PR target branch?
8. Session size limits?
9. Multi-session support?

**Edge Cases**:
- Empty sessions
- Binary file changes
- GitHub PR body 65,535 character limit
- Sessions that span multiple repositories

### 🔒 Security Reviewer
**Identified 3 CRITICAL issues**:

1. **Sensitive Data Leakage**
   - Prompts may contain API keys, passwords
   - Solution: 3-layer defense (preview + scanning + exclusion patterns)

2. **GitHub Token Storage**
   - `repo` scope is too powerful
   - Solution: Prefer `gh` CLI, fine-grained PAT, system keychain

3. **Target Repo Manipulation**
   - Redirect attacks from malicious projects
   - Solution: Trust only user-level configuration

**Security Checklist**: 23 items provided

### 🎨 Designer
**Provided a complete skill implementation**

**3 execution modes**:
- `--setup`: Initial setup wizard
- `--status`: Check current configuration
- Default: 9-step capture flow

**UX Principles**:
1. Opt-in at every step (no automatic execution)
2. Graceful on missing context
3. Append-only archive (no force pushes)
4. Fail loudly, recover cleanly

## Agreed Decisions

| Item | Decision | Rationale |
|------|----------|-----------|
| **Implementation Form** | OMC Skill | No server needed, runs locally |
| **Target Repo** | Separate archive repo | Avoid polluting the working repo |
| **Authentication** | `gh` CLI | Avoids token management issues |
| **Security** | 3-layer defense | Preview + scanning + user configuration |
| **PR Structure** | `.sessions/` files | Version controlled + searchable |
| **Branch** | `session/YYYY-MM-DD-slug` | Chronological sorting |

## Unresolved Issues

1. **OMC-exclusive vs general-purpose skill**
   - Current: OMC-exclusive
   - Needs discussion: Support for plain Claude Code users?

2. **Real-time vs post-hoc capture**
   - Phase 1: Post-hoc extraction
   - Phase 2: Consider hybrid approach

3. **Multi-session aggregation**
   - Phase 1: Single session only
   - Phase 2: Feature to combine multiple sessions

## Next Action Items

- [x] Skill implementation complete (completed by Designer)
- [ ] End-to-end testing with real sessions
- [ ] Validate security scanning patterns
- [ ] Test compatibility with plain Claude Code
- [ ] Collect community feedback

## Reference Documents

See individual files for each expert's detailed analysis:
- `architect-review.md` - In-depth architecture analysis
- `planner-roadmap.md` - Execution plan and roadmap
- `analyst-requirements.md` - Requirements and acceptance criteria
- `security-review.md` - Security threat model and countermeasures
- `designer-ux.md` - UX design and implementation
