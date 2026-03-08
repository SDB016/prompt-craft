# Session Notes - 2026-03-07

## Discussion Overview

Team brainstorming on developing a skill to automatically archive Claude Code sessions as GitHub PRs.

**Participants**: 5 specialized agents (Architect, Planner, Analyst, Security Reviewer, Designer)
**Duration**: Approximately 2 hours
**Outcome**: Completed OMC skill + detailed documentation

---

## Key Decisions

### 1. Pivot from GitHub App to OMC Skill

**Initial Idea**:
- Provide PR reviews via a GitHub App
- Server-side processing

**Problem Identified**:
> "If I'm getting Claude Code reviews, that means I already have Claude Code running locally and I'm on a paid plan."

**Decision**: An entirely new direction - **pivot to a Claude Code plugin**

### 2. Fully Standalone Implementation

3 options discussed:
1. Pure OMC skill (fully standalone) - **Selected**
2. PR platform extension
3. Hybrid

**Rationale for Selection**:
- Fast time to launch
- Low barrier to entry
- Simple maintenance
- No OMC dependency

### 3. Security-First Design

Security Reviewer identified **3 CRITICAL issues**:
1. Risk of API key/secret leakage
2. GitHub token storage concerns
3. Malicious repo redirect

**Response**: 3-layer defense
- Preview + User Confirmation
- Automatic Secret Scanning
- User-level Config Only

---

## Team Insights Summary

### Architect
- **Finding**: Claude Code JSONL is an unofficial API
- **Proposal**: Hybrid of real-time capture + post-hoc extraction
- **Tension**: "Learning archive" vs "Code PR"
- **Resolution**: `.sessions/` directory pattern

### Planner
- Provided an immediately actionable roadmap
- Decided on standalone skill approach
- Centralized archive repository

### Analyst
- Identified 9 unanswered questions
- Discovered edge cases (empty sessions, binary files, etc.)
- Defined acceptance criteria

### Security Reviewer
- 23-item security checklist
- 3 CRITICAL and 4 HIGH severity issues
- Least privilege principle matrix

### Designer
- **Completed skill implementation** (817 lines)
- Designed 3 execution modes
- 9-step capture flow

---

## Technology Stack

- **Claude Code Skill System** - Markdown workflow
- **GitHub CLI (`gh`)** - PR creation and management
- **Git** - Code diff extraction
- **Bash** - Skill execution logic
- **JQ** - JSON configuration management

---

## File Structure

```
promptrequest/
├── README.md                    # Project overview
├── QUICKSTART.md               # 5-minute quick start
├── SESSION-NOTES.md            # This file
├── decisions/
│   ├── 01-architecture.md      # Architecture decisions
│   └── 02-implementation.md    # Implementation approach decisions
├── brainstorming/
│   ├── 00-summary.md           # Brainstorming summary
│   ├── architect-review.md     # Architecture analysis
│   └── security-review.md      # Security review
└── skill/
    ├── SKILL.md                # Completed skill (817 lines)
    └── QUICKREF.md             # Quick reference card
```

---

## Key Discussion Points

### Q1: Is OMC Required?

**Question**: "If someone uses plain Claude Code without oh-my-claudecode, can they not use this?"

**Answer**:
- Currently: OMC-exclusive (`/oh-my-claudecode:prompt-review`)
- In practice: No OMC-specific features are used
- Possible: Can also be distributed as a pure Claude Code skill
- **Undecided**: General-purpose vs OMC-exclusive

### Q2: Relationship with the PR Project?

An existing `/playground/pr/` project was already in place:
- Option 1: Fully standalone - **Selected**
- Option 2: PR platform extension
- Option 3: Hybrid

**Decision**: Option 1 - Fully standalone

---

## Unresolved Issues

1. **OMC-Exclusive vs General-Purpose Distribution**
   - Pure Claude Code compatibility testing needed
   - Decision deferred until community feedback is collected

2. **Real-Time Capture Feature**
   - Phase 1: Post-hoc extraction only
   - Phase 2: Add `--start-recording` option

3. **Multi-Session Aggregation**
   - MVP: Single session only
   - Future: Combine multiple sessions

---

## Next Steps

### Immediate
- [ ] End-to-end testing with a real session
- [ ] Validate security scanning patterns
- [ ] Test error cases

### Short-Term
- [ ] Verify pure Claude Code compatibility
- [ ] Improve documentation
- [ ] Add usage examples

### Medium-Term
- [ ] Collect community feedback
- [ ] Implement real-time capture option
- [ ] Add multi-session support

---

## Lessons Learned

1. **The User Perspective Turning Point**
   - Initial approach: "Provide a service via GitHub App"
   - Pivot: "The user is already running Claude Code locally"
   - Result: A completely different architecture

2. **Security Is Non-Negotiable**
   - 3 CRITICAL issues discovered
   - Feature sends user data to a remote destination
   - 3-layer defense is essential

3. **Risks of an Unofficial API**
   - Claude Code JSONL is an internal format
   - It can break with version changes
   - Defensive parsing + real-time capture hybrid approach needed

4. **The Value of Team Brainstorming**
   - 5 experts each brought a different perspective
   - Architect: Technical feasibility assessment
   - Security: Early discovery of CRITICAL issues
   - Designer: Delivered a ready-to-use implementation

---

## Notable Quote

> "I just thought of an entirely new approach. If I'm getting Claude Code reviews, that means I already have Claude Code running locally and I'm on a paid plan. So this service should not be built as a GitHub App. It needs to be a Claude Code plugin."

This single statement was the moment that redirected the entire project.

---

## Metadata

- **Date**: 2026-03-07
- **Duration**: ~2 hours
- **Agents**: 5 specialized agents
- **Lines of Code**: 817 (SKILL.md)
- **Documents**: 10 files
- **Decisions**: 6 major decisions
- **Issues Found**: 12 (3 CRITICAL, 4 HIGH, 3 MEDIUM, 2 LOW)
