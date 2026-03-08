# PR Template Design — Prompt Review

> Date: 2026-03-08
> Author: Designer agent
> Status: Decided

---

## The Core Reframe

The original prompt-review templates (code_change / debugging / exploration) are written for
the **session author** reading their own archive. The prompt-review template is written for
a **reviewer** evaluating someone else's prompts. These are different readers, different
questions, and different success conditions.

| Dimension        | Session Archive           | Prompt Review                          |
|------------------|---------------------------|----------------------------------------|
| Primary reader   | Author (future self)      | Reviewer (teammate)                    |
| Core question    | "What did we build?"      | "Did this prompt set Claude up to win?"|
| Success metric   | Recall                    | Actionable feedback                    |
| Key content      | Decisions, code, learnings| Intent, context quality, exit criteria |
| Time pressure    | None — author reads at leisure | Reviewer has limited attention    |

Every structural decision in the template flows from this distinction.

---

## The Five Questions Every Reviewer Must Answer

A reviewer opening a prompt review PR needs to evaluate exactly one thing:
**did the prompt give Claude enough to succeed?** That resolves into five sub-questions
that map directly to the DoD criteria:

1. Was the **goal** specific enough that Claude knew what "done" meant?
2. Were **exit criteria** stated, or did Claude have to guess when to stop?
3. Were the right **constraints** given (do this, not that)?
4. Was enough **context** included (codebase state, prior decisions, dependencies)?
5. Was the **output format** specified?

The template structure is built to answer these five questions in order of reading cost.

---

## Information Hierarchy: Four Reading Levels

Reviewers should not have to read the full PR to perform triage. The template implements
four progressive disclosure levels:

```
LEVEL 1 — 10 seconds    Score badge + one-line summary + PR labels
LEVEL 2 — 2 minutes     DoD scorecard table + AC table + code delta
LEVEL 3 — 5 minutes     Annotated prompt sequence + improvement tips
LEVEL 4 — as needed     Raw metadata, harness principles, full reviewer checklist
```

Levels 3 and 4 are never collapsed in the PR body itself (GitHub has no native collapsing
for top-level sections), but the `<details>` tags on Level 4 sections reduce visual weight.
Level 1 and 2 content is always visible on page load.

---

## Scorecard Design Decisions

### Why emoji traffic lights, not colored text

GitHub markdown does not support inline CSS or colored spans. Emoji (✅ 🟡 ❌) render
identically in light and dark themes, are accessible to screen readers with default
descriptions, and require no images or CDN dependencies. They are the only reliable
cross-platform visual indicator available in GitHub PR bodies.

### Why progress bars with block characters

`████████░░` (8 filled, 2 empty = score 8/10) gives a spatial representation of the
score that is faster to parse than a number alone. Block characters render in all
GitHub-supported fonts and themes. This is preferable to a percentage which requires
mental division.

### Why split DoD (auto) and AC (LLM-judged) into separate tables

The scoring model has a hard boundary: 70 points from deterministic rule-based analysis,
30 points from LLM judgment. Combining them in one table would obscure this distinction
and make it harder for reviewers to understand why a score is what it is. Separate tables
also communicate the confidence level — auto scores are more reproducible than LLM scores.

### Why include a collapsed scoring rubric

Reviewers need to know the grading criteria to give good feedback. Without the rubric,
a reviewer who sees "Goal Clarity: 6/10" does not know whether 6 is "almost there" or
"barely passing." The collapsed rubric makes the scoring transparent without cluttering
the default view.

---

## Prompt Sequence Display Decisions

### Why verbatim prompts in code blocks

Prompts must be shown exactly as written — no paraphrasing, no summarizing. The reviewer
is evaluating the prompt text itself, not a description of it. Code blocks preserve
whitespace and formatting, signal "this is the raw artifact," and make copy-paste easy
for reviewers who want to suggest rewrites.

### Why per-prompt mini-scorecards

A session with 8 prompts may have 2 excellent ones and 3 poor ones. A single session-level
score hides this variation. Per-prompt inline scores (`Goal 8/10 · Exit 3/10 · ...`) let
reviewers immediately identify which prompts in the sequence were the problem, without
reading every prompt carefully. The mini-badge (🟢/🔵/🟡/🔴 on the heading) is the
5-second signal; the inline breakdown is the 30-second diagnosis.

### Why "delta" links after each prompt

The most important evaluation question for each prompt is: **did the code change match
what was asked?** Linking each prompt to the diff it produced closes this loop. Without
it, reviewers must manually correlate prompts to commits, which is high friction.

When a prompt produced no code delta (a clarification turn, a question), the delta note
makes this explicit ("no code delta"), which is itself useful data — it shows where
the session stalled or needed iteration.

### Why sequence numbers on prompts

Prompt quality often degrades as sessions get longer (authors get lazy, Claude gets
more context so authors stop providing it explicitly). Sequence numbers make iteration
patterns visible. A reviewer can immediately see "prompt #1 was thorough, by prompt #7
the author had stopped specifying exit criteria."

---

## Improvement Tips Design Decisions

### Why only for criteria scoring below 7/10

Tips for high-scoring criteria add noise. A reviewer's attention budget is finite. The
template only generates improvement tips for criteria where the score indicates a real
problem, and omits the section entirely if all criteria score 7+. This makes the tips
section a signal, not boilerplate.

### Why "suggested rewrite fragment" not "explanation"

Abstract advice ("be more specific") does not transfer to behavior change. Concrete
rewrites do. The improvement tip format shows the actual before/after text, which the
author can use as a template for their next session. This is the highest-leverage output
of the entire review.

### Why not generate full prompt rewrites

Full prompt rewrites risk the reviewer putting words in the author's mouth about
intent that was never stated. Fragments ("add to end of prompt: ...") are safer — they
extend the prompt without claiming to know what the author meant to achieve.

---

## Code Delta Section Design Decisions

### Why include the code impact table in a prompt review PR

The code delta is the ground truth for evaluating whether prompts worked. Without it,
reviewers cannot check intent match, constraint adherence, or scope discipline. The code
delta answers: "Claude produced X — did the prompts predict X?"

The table maps each file to the prompt that caused it. This is the most direct link
between prompt quality and outcome.

### Why show it at Level 2 (not collapsed)

If a reviewer only reads one thing at Level 2, it should be the scorecard. If they read
two, it should be the scorecard and what was produced. The code delta must not be hidden
— it is the empirical evidence that the scorecard is interpreting.

---

## Reviewer Checklist Design Decisions

### Why a pre-populated checklist

The single biggest friction in code review is not knowing what to look for. The same is
true for prompt review, but worse — prompt reviewing is a newer skill and most engineers
have no mental model for it. A pre-populated checklist converts "write a review" (open-
ended, high effort) into "confirm or disagree with these observations" (constrained,
lower effort). It also standardizes what "a good review" means across the team.

### Why collapse it

The checklist is for the reviewer to copy into their own comment. It is not part of the
PR body's information hierarchy — it is a tool. Collapsing it keeps the PR body clean
for readers who are not leaving a review.

### Why "the one thing to improve"

Teams that try to address five pieces of feedback improve nothing. Teams that address one
improve consistently. Forcing the reviewer to commit to a single recommendation creates
actionable feedback. This is borrowed from structured retrospective facilitation
(the "1-2-4-All" pattern).

---

## Metadata Design Decisions

### Why YAML not JSON

YAML is more human-readable in a collapsed `<details>` block. The metadata section
exists primarily for machines (tooling that parses PR bodies to build dashboards) but
must also be readable by humans who want to understand how a score was computed. YAML
comments (`# excellent | good | ...`) allow inline documentation without a schema.

### Why collapse metadata

The metadata section is not for reviewers — it is for the tool ecosystem. Reviewers
should never need to look at it. Collapsing it by default keeps it out of the visual
hierarchy without removing it.

---

## Auto-Trigger on git push (vs. manual invocation)

The original SKILL.md required manual invocation (`/prompt-review`). The prompt-review
variant is triggered automatically on `git push` via a global git hook. This changes
two things in the template:

1. The "triggered by" field in metadata must be `git-push-hook` not `manual` — auditors
   need to know the capture was automatic, not curated by the author.

2. The PR title and one-line summary must be generated entirely from session content
   and the push event — there is no Step C-2 where the author provides a title.
   The title format should be: `[Prompt Review] {date} — {inferred_topic} — @{author}`

---

## What This Template Does Not Include

### No full conversation transcript

Full conversation transcripts (all of Claude's responses) are not included. Reviewers
are evaluating **prompts**, not evaluating Claude's outputs. Including Claude's responses
would double the PR body length, shift reviewer attention from input quality to output
quality, and obscure the signal. Claude's responses are implicit in the code delta.

### No session summary written by Claude

The original templates included an AI-generated summary of what was built. This is
appropriate for session archiving (the author wants to remember) but wrong for prompt
review (the reviewer should evaluate prompts, not read Claude's self-assessment). The
code delta table replaces the narrative summary.

### No "learnings and gotchas" section

Learnings are valuable for session archives. For prompt review, they are a distraction
— the review is about prompt craft, not about what was discovered in the codebase. If
the author wants to document learnings, they should create a separate session archive PR.

---

## Template File Location

```
skill/
  templates/
    prompt-review.md     ← this template (prompt review, auto-triggered)
    default.md           ← original session archive template (manual)
    minimal.md           ← future: 30-second quick capture
    detailed.md          ← future: deep-dive with full transcript
```

The prompt-review template is selected automatically when the trigger is `git-push-hook`.
The default template is used for manual `/prompt-review` invocations.
