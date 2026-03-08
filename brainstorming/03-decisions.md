# prompt-review Decision Record (Consolidated)

> Last updated: 2026-03-08
> Status: A, B, C, D all confirmed

---

## Project Purpose

A tool that enables team members to review each other's AI prompts via GitHub PRs, continuously improving prompt quality.

- Primary reader: Reviewer (teammate)
- Core question: "Did this prompt set Claude up to succeed?"

> **Note**: Initial planning mistakenly started as "session archiving",
> but the original intent was always prompt quality improvement through team review.

**Core philosophy**:
> "Code review looks at results. Prompt review looks at causes."
> Prompt review is a complement to code review, not a replacement.

**User's original words**:
> "Reviewing code cold is old-fashioned. We already ask AI for code reviews and only comment on the important findings."

---

## Confirmed Decisions

### A: Trigger & Data Flow

**Two-phase structure**: push → commit (record), PR → PR (score + review)

| Event | Action | In prompt repo |
|-------|--------|----------------|
| `git push` (inside Claude Code) | Capture current session prompts + diff | **Commit only** (no PR) |
| `gh pr create` (inside Claude Code) | Aggregate commits + score | **Create PR** |
| `/prompt-review` (manual) | Create PR at desired time | **Create PR** |
| Global/project git hook | ❌ Not used | — |

**Core**: Operates only inside Claude Code. No external git hooks.

**Capture method on push**: Full capture (save all prompts from current session each time)
- Simple implementation, no state management needed
- New session naturally creates a new file
- Duplicates resolved by AI at PR creation time

**File structure** (prompt repo):
```
sessions/feature-jwt-refresh/
  push-001.md    ← Day 1, Session A, prompts + diff
  push-002.md    ← Day 1, Session A
  push-003.md    ← Day 2, Session B (new Claude Code conversation)
  push-004.md    ← Day 3, Session C
```

**Multi-session / long-running work support**:
- Accumulates in same directory as long as same branch
- Records on each push regardless of number of sessions or days
- Full integrated scoring at PR creation time

### B: Zero Project Repo Footprint

| Item | Decision |
|------|----------|
| Any trace in project repo | ❌ Absolutely none |
| Git Trailers | ❌ |
| Push hook | ❌ |
| Companion branch | ❌ |
| PR enrichment | ❌ |
| Link direction | Session→commit one-way only (project repo→session ❌) |

**All prompt review PRs are created in a separate repo** (e.g., `my-org/ai-sessions`).

### Code's Role: "Evidence, Not Evaluation Target"

| Item | Decision |
|------|----------|
| Include code in prompt review PR | ✅ As evidence only |
| Evaluate code quality itself | ❌ Out of scope for prompt review |
| Include AI code review results | ✅ Integrated into Improvement Suggestions |
| Framing | "Prompt issue first → code defect mentioned as one-line evidence" |
| Prompt↔code linking | Time-based delta display ("this change occurred after this prompt") |
| Precise causal mapping | ❌ (~61% accuracy → unreliable) |

**AI code review integration**:
- Separate section ❌ → Naturally blended into existing Improvement Suggestions
- When prompt defect leads to code defect, framed as "Prompt Gap"
- Example: "Missing exit criteria → Claude made scope-exceeding changes"

### Gap Model

| Gap | Description | Who evaluates |
|-----|-------------|---------------|
| Gap 1 | Intent → Prompt (was the intent properly captured in the prompt?) | Humans only |
| Gap 2 | Prompt → Code (was the prompt properly translated to code?) | AI can assist |

Prompt review focuses primarily on **Gap 1**. Gap 2 is supplemented by AI code review.

### Review Model: Layered

| Step | Content | Time |
|------|---------|------|
| 1. AI auto-score | 100 points (single LLM call) | Automatic |
| 2. Self-review | Author confirms | ~30 sec |
| 3. Selective peer review | Team reviews low-scoring ones | As needed |
| 4. Monthly pattern analysis | Team-wide prompt quality trends | Monthly |

---

### C: Evaluation Criteria ✅ Confirmed

**8 criteria, scored in a single LLM call. No auto/LLM distinction.**

| # | Criterion | Points | Description |
|---|-----------|--------|-------------|
| 1 | **Goal Clarity** | 20 | Is the goal specific and does the result match the intent? |
| 2 | **Exit Criteria** | 10 | Are completion/stop conditions stated and properly followed? |
| 3 | **Scope Control** | 15 | Are boundaries set + constraints stated + no out-of-scope changes? |
| 4 | **Context Sufficiency** | 15 | Is enough background provided (including reference code/patterns)? |
| 5 | **Decomposition** | 10 | Are complex tasks properly broken down? |
| 6 | **Verification Strategy** | 10 | Are verification methods specified (including failure behavior)? |
| 7 | **Iteration Quality** | 10 | Are follow-up requests specific and concrete? |
| 8 | **Complexity Fit** | 10 | Is prompt sophistication appropriate for task complexity? |

**Scoring structure**: Goal Clarity(20) + Scope Control/Context(15 each) + rest(10 each) = 100 points

**N/A rule**: When Iteration Quality is N/A (first prompt), its 10 points are proportionally distributed to the other 7 criteria → effective max always 100.

**Grades**:
| Range | Grade |
|-------|-------|
| 90–100 | 🟢 Excellent |
| 70–89 | 🔵 Good |
| 50–69 | 🟡 Needs Work |
| 0–49 | 🔴 Poor |

**Decision process**:
- Started with DoD 5 + AC 8 + Harness 6 = 20 criteria
- Deduplicated, adapted for Claude Code, validated with 5 scenario simulations
- Removed: Output Spec (automatic), Intent Match (absorbed into Goal), No Side Effects (absorbed into Scope), Reproducibility (unmeasurable)
- Added: Decomposition, Verification Strategy, Complexity Fit
- Weighted: Goal Clarity 20 (most critical), Exit Criteria 10 (implicit conditions are common)

---

### D: Review Workflow ✅ Confirmed

**Same as code review. The tool does not intervene in the review process.**

| Item | Decision |
|------|----------|
| Who reviews | PR author assigns (GitHub Reviewer assign) |
| When to review | Per team convention (tool does not enforce) |
| Feedback loop | PR comments (GitHub built-in) |
| Automation | None |

**Tool's scope of responsibility**:
- ✅ Prompt capture → scoring → PR creation
- ❌ Reviewer assignment, review timing, feedback tracking

---

## Existing Decisions (Retained)

These decisions were made during initial planning and still apply to prompt review:

| Decision | Content | Source |
|----------|---------|--------|
| Implementation | Fully independent Claude Code skill | decisions/01 |
| Target repo | Dedicated review repo (separate from project repo) | decisions/01 |
| Authentication | `gh` CLI | decisions/01 |
| Security model | 3-layer defense (Preview+Confirm, Secret Scan, User-level Config Only) | decisions/01 |
| Distribution | OMC-only vs universal — undecided (after testing) | decisions/02 |

---

## Backlog

| Item | Priority | Notes |
|------|----------|-------|
| Arc (multi-session grouping) | Low | After sufficient sessions accumulate |
| Real-time capture (`--start-recording`) | Medium | Phase 2 |
| secret-scan.sh pattern expansion | Medium | Security hardening |
| Session Search | High | Discussed in 02-expansion |
| Context Preloader | High | Discussed in 02-expansion |

---

## Generated Artifacts

| File | Description | Status |
|------|-------------|--------|
| `decisions/03-prompt-review-pr-design.md` | PR template design rationale | ✅ Complete |
| `skill/templates/prompt-review.md` | Prompt review PR template | ✅ Updated (new 8 criteria) |
| `skill/templates/prompt-review-example.md` | Filled example (JWT, 74/100) | ✅ Updated (new 8 criteria) |
| `skill/SKILL.md` | Core skill spec | ✅ Rewritten (two-phase + 8 criteria) |
| `skill/QUICKREF.md` | Quick reference card | ✅ Updated |
| `README.md` | Project overview | ✅ Updated |

---

## Next Steps

1. ~~SKILL.md rewrite~~ ✅ Done
2. ~~PR template update~~ ✅ Done
3. **E2E test**: Validate with real sessions
4. **Claude Code Hook setup**: PostToolUse hook for `git push` / `gh pr create` detection
