# [Prompt Review] 2026-03-08 — JWT token refresh refactor — @dev-alice

<!-- This is a filled-in example of prompt-review.md showing exactly what
     a reviewer sees. Use this to evaluate the template design.
     Scored with new 8-criteria system (100 points, single LLM call). -->

---

## 🔵 Score: 74/100 — Refactored JWT refresh logic with sliding window expiry

> **Prompts:** 6 &nbsp;|&nbsp; **Pushes:** 3 &nbsp;|&nbsp; **Duration:** ~38 min &nbsp;|&nbsp; **Session:** 2026-03-08 by @dev-alice &nbsp;|&nbsp; **LLM scored**

---

## Prompt Quality Scorecard

All 8 criteria are scored by LLM in a single evaluation call.

| | Criterion | Score | Progress | Finding |
|---|---|---|---|---|
| ✅ | **Goal Clarity** | 18/20 | █████████░ | Prompt #1 named the exact file, function, and desired behavior. Clear success condition. |
| 🟡 | **Scope Control** | 10/15 | ██████░░░░ | "Don't touch the database layer" stated in prompt #1 but never repeated. Claude modified `db/sessions.ts` in prompt #3. |
| ✅ | **Context Sufficiency** | 12/15 | ████████░░ | File paths, architecture decision (mutex over queue), and race condition symptom provided upfront. Strong. |
| ❌ | **Exit Criteria** | 4/10 | ████░░░░░░ | No prompt stated a stopping condition. Claude kept refactoring callers in 3 files beyond scope. |
| 🟡 | **Decomposition** | 7/10 | ███████░░░ | Prompt #1 broke the task into clear steps. Later prompts were more ad-hoc. |
| ✅ | **Verification Strategy** | 8/10 | ████████░░ | Prompt #6 explicitly asked for test run with no auto-fix. Good discipline. |
| ❌ | **Iteration Quality** | 5/10 | █████░░░░░ | Prompts #4 and #5 were corrective — walking back Claude's over-reach. Two extra turns caused by missing exit criteria. |
| ✅ | **Complexity Fit** | 10/10 | ██████████ | Prompt sophistication matched the task complexity well. Appropriate level of detail. |

<details>
<summary>Scoring rubric</summary>

| Criterion | Max | What it evaluates |
|---|---|---|
| **Goal Clarity** | 20 | Is the goal specific? Does the result match the stated intent? |
| **Scope Control** | 15 | Are boundaries set? Constraints stated? No out-of-scope changes? |
| **Context Sufficiency** | 15 | Enough background provided? Reference code/patterns specified? |
| **Exit Criteria** | 10 | Are completion/stop conditions stated? Did Claude stop appropriately? |
| **Decomposition** | 10 | Are complex tasks broken into manageable steps? |
| **Verification Strategy** | 10 | Verification method specified? Failure behavior defined? |
| **Iteration Quality** | 10 | Are follow-up requests specific and concrete? (N/A → redistribute) |
| **Complexity Fit** | 10 | Is prompt sophistication appropriate for task complexity? |

**N/A rule:** When Iteration Quality is not applicable (single-prompt session), its 10 points are redistributed proportionally across the other 7 criteria. Effective max is always 100.

**Grade bands:** 🟢 90–100 Excellent | 🔵 70–89 Good | 🟡 50–69 Needs Work | 🔴 0–49 Poor

</details>

---

## What Was Produced

> Branch: `feature/jwt-refresh` — 5 files changed, +134 −28

| File | Change | Summary |
|---|---|---|
| `src/auth/refresh.ts` | added (+89) | New TokenRefreshService with mutex-based sliding window expiry |
| `src/auth/middleware.ts` | modified (+18, −12) | Auto-refresh on 401 using new refreshToken() |
| `tests/auth/refresh.test.ts` | added (+41) | Concurrent refresh race condition tests |
| `src/auth/pkce.ts` | modified (+8, −4) | PKCE race condition fix using shared mutex |
| `db/sessions.ts` | modified (+7, −12) | **Flagged: constraint violation** — reverted in prompt #4 |

**Commits:**
- [`a1b2c3d`](https://github.com/myorg/myapp/commit/a1b2c3d) feat(auth): add sliding window JWT refresh with mutex serialization
- [`d4e5f6g`](https://github.com/myorg/myapp/commit/d4e5f6g) test(auth): add refresh token concurrency tests
- [`h7i8j9k`](https://github.com/myorg/myapp/commit/h7i8j9k) fix(auth): revert db/sessions change (constraint violation)

---

## Prompt Sequence

### Prompt 1 🟢

```
Refactor the JWT refresh logic in src/auth/refresh.ts.

Context:
- We decided last week to use a mutex (not a queue) for concurrent refresh
  serialization — see ADR-12 in docs/decisions/
- The current implementation has a race condition: two simultaneous refresh
  calls both succeed, invalidating each other's tokens
- The token store is in src/auth/token-store.ts

What to do:
- Implement sliding window expiry (extend on each valid request, not fixed TTL)
- Add a refresh mutex so only one refresh call runs at a time; others wait
- Do not touch the database layer (db/ directory) — token state lives in memory

Done when:
- src/auth/refresh.ts exports a refreshToken(userId) function
- Concurrent calls to refreshToken() for the same userId are serialized
- Existing tests in tests/auth/ still pass
```

<sub>Goal 20/20 · Exit 9/10 · Scope 12/15 · Context 14/15</sub>

<!-- delta: Created src/auth/refresh.ts (+89 lines) with TokenRefreshService class and sliding window implementation -->

---

### Prompt 2 🔵

```
Now update the middleware to use the new refreshToken() function.
Also add tests for the concurrent refresh case.
```

<sub>Goal 12/20 · Exit 4/10 · Scope 6/15 · Context 8/15</sub>

<!-- delta: Modified src/auth/middleware.ts (+18, −12), created tests/auth/refresh.test.ts (+41 lines) -->

---

### Prompt 3 🔴

```
The PKCE integration also needs to handle the race condition we discussed.
Fix it.
```

<sub>Goal 8/20 · Exit 2/10 · Scope 4/15 · Context 5/15</sub>

<!-- delta: Modified src/auth/pkce.ts (+8, −4) AND db/sessions.ts (+7, −12) — db change was a constraint violation -->

---

### Prompt 4 🟢

```
Wait — you modified db/sessions.ts. I said not to touch the database layer.
Revert that change.
```

<sub>Goal 16/20 · Exit 9/10 · Scope 11/15 · Context 10/15</sub>

<!-- delta: Reverted db/sessions.ts -->

---

### Prompt 5 🔵

```
Also the test file is using describe/it but our test suite uses test/assert.
Fix the test file to match our existing pattern.
```

<sub>Goal 14/20 · Exit 7/10 · Scope 8/15 · Context 8/15</sub>

<!-- delta: Modified tests/auth/refresh.test.ts (−describe/it, +test/assert pattern) -->

---

### Prompt 6 🟢

```
Good. Run the existing auth tests to confirm nothing is broken.
Report which tests pass and which fail. Do not fix failures — just report.
```

<sub>Goal 18/20 · Exit 9/10 · Scope 13/15 · Context 12/15</sub>

<!-- delta: no code delta — test run output only -->

---

## Improvement Suggestions

### Exit Criteria (scored 4/10)

> Prompts #2 and #3 had no stopping condition. Claude interpreted "update the middleware" as license to touch adjacent files, and "fix the PKCE integration" as license to touch the database layer. Both required corrective prompts. Prompt Gap: missing exit criteria → out-of-scope changes in 2 prompts.

**Suggested rewrite for Prompt 2:**
```
Instead of: "Now update the middleware to use the new refreshToken() function.
             Also add tests for the concurrent refresh case."

Try:        "Update src/auth/middleware.ts to call refreshToken() from the
             new src/auth/refresh.ts instead of the old inline logic.
             Add tests in tests/auth/refresh.test.ts for concurrent calls.

             Stop after modifying those two files only.
             Do not touch any other file.
             Done when: existing middleware tests still pass."
```

---

### Iteration Quality (scored 5/10)

> Prompts #4 and #5 were purely corrective — walking back Claude's over-reach from prompt #3. These extra turns could have been avoided with better exit criteria and constraint repetition in the original prompts.

**Pattern to adopt:**
```
When issuing a prompt that touches a different area than the previous one,
re-state the boundary constraints from the session's original prompt.
One line is enough: "Reminder: do not touch db/ or tests/ unless I ask."
```

---

### Scope Control (scored 10/15)

> The "don't touch the database layer" constraint from prompt #1 was forgotten by prompt #3. Constraints stated early in a session decay as context grows. Prompt Gap: constraint drift → constraint violation in `db/sessions.ts`.

**Suggested addition to follow-up prompts:**
```
Add to any follow-up prompt in a new area:
"Same constraints as before: do not modify files in db/ directory."
```

---

<details>
<summary>Reviewer Checklist</summary>

**Reading the prompt sequence, I found:**

- [x] The opening prompt gave Claude enough context to not guess the codebase state
- [ ] Exit criteria were explicit in at least one prompt
- [x] No single prompt asked for more than two distinct outcomes
- [ ] Constraints were stated proactively, not reactively (after Claude made a wrong choice)
- [ ] Complex tasks were decomposed into sequential steps
- [x] The final code delta matches what the prompts asked for

**My overall take:**
<!-- Example: "Strong opening prompt, but quality degraded sharply from prompt #3 onward — the author stopped specifying scope and Claude over-reached twice." -->

**The one thing to improve for next session:**
<!-- Example: "Add 'stop after modifying only [file list]' to every prompt that changes existing files." -->

</details>

---

<details>
<summary>Session Metadata</summary>

```yaml
session_id: session-2026-0308-a1b2c3d
triggered_by: gh-pr-create
push_count: 3
push_timestamps: ["2026-03-08T14:00:00Z", "2026-03-08T14:22:00Z", "2026-03-08T14:42:07Z"]
project_repo: myorg/myapp
project_branch: feature/jwt-refresh
prompt_count: 6
session_duration_minutes: 38
score:
  total: 74
  goal_clarity: 18
  scope_control: 10
  context_sufficiency: 12
  exit_criteria: 4
  decomposition: 7
  verification_strategy: 8
  iteration_quality: 5
  complexity_fit: 10
  grade: good
review_repo: myorg/prompt-reviews
session_dir: sessions/feature/jwt-refresh/
tool_version: prompt-review/2.0
```

</details>

---

*Auto-captured by [prompt-review](https://github.com/Yeachan-Heo/oh-my-claudecode) · [View all prompt reviews](https://github.com/myorg/prompt-reviews/pulls) · [Your reviews](https://github.com/myorg/prompt-reviews/pulls?q=author%3Adev-alice)*
