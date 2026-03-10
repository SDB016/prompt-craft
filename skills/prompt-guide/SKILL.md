---
name: prompt-guide
description: Pre-task prompt guide and reusable template management. Use when asked for prompt tips, writing advice, or template management.
argument-hint: "[template save|list|use|delete [name]]"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash(git *)
  - Bash(mkdir *)
  - Bash(rm *)
  - Bash(head *)
  - Bash(grep *)
---

# Prompt Guide — Tips & Templates

Pre-task prompt guide and reusable template management. Get contextual advice before starting work, or save and reuse high-scoring prompt patterns.

> "Better prompts start before you type the first word."

**Received arguments:** $ARGUMENTS

---

## Step 0: Route the Request

- If `$ARGUMENTS` starts with `template` → jump to [TEMPLATE MANAGER]
- Otherwise → default to [COACHING] (tips mode)

---

## [COACHING] — Pre-task Prompt Tips

You are a prompt coaching assistant. Your job is to help the user write better prompts BEFORE they start a task. Analyze the current project context and provide targeted advice.

## Input

`$ARGUMENTS` may contain an optional task type hint: refactor, bugfix, feature, test, docs, migration, or review. If empty, infer the likely task from context.

## Steps

### 1. Gather Context

Run these in parallel to understand the current project state:

- `git branch --show-current` to get the current branch name
- `git log --oneline -10` to see recent commits
- `git diff --stat HEAD~3..HEAD 2>/dev/null || git diff --stat` to see recently changed files
- `git status --short` to see uncommitted work
- Use Glob to scan the top-level project structure (e.g., `**/*.{ts,js,py,go,rs,java}` limited to depth 2)

### 2. Determine Task Type

If `$ARGUMENTS` specifies a task type, use it. Otherwise, infer from:
- Branch name patterns (e.g., `fix/` -> bugfix, `feat/` -> feature, `refactor/` -> refactor)
- Recent commit messages
- Current file changes
- Default to "feature" if unclear

### 3. Generate Tips

Based on the task type, produce output following the format below. Tailor the template, focus areas, and pitfalls to the SPECIFIC project context you discovered (branch name, file paths, languages, frameworks).

## Task Type Reference

Use these guidelines per task type:

**refactor**
- Focus: Exit Criteria, Scope Control
- Pitfall: Scope creep — "refactor the auth module" is too vague
- Tip: Name specific functions/classes, state what should NOT change

**bugfix**
- Focus: Accuracy, Verification
- Pitfall: Fixing symptoms not causes — always ask for root cause analysis
- Tip: Include error messages, reproduction steps, expected vs actual behavior

**feature**
- Focus: Completeness, Exit Criteria, Edge Cases
- Pitfall: Underspecifying behavior at boundaries
- Tip: Describe the happy path AND at least two edge cases

**test**
- Focus: Completeness, Accuracy
- Pitfall: Only testing the happy path
- Tip: Specify what categories of tests (unit, integration, edge cases, error paths)

**docs**
- Focus: Clarity, Audience
- Pitfall: Writing docs that repeat the code instead of explaining the "why"
- Tip: State the target audience and what they should be able to do after reading

**migration**
- Focus: Safety, Rollback, Verification
- Pitfall: No rollback plan — always include one
- Tip: Specify before/after states explicitly, mention data preservation requirements

**review**
- Focus: Accuracy, Scope Control
- Pitfall: Reviewing everything at surface level instead of critical paths deeply
- Tip: Point Claude at specific files or concerns, ask for severity ratings

## Output Format

Produce output in this structure (fill in project-specific details from your context gathering):

```
Prompt Tips — [Task Type] Task

Based on: branch [branch-name], recent changes in [directories/files]

Template:
  [Task verb] [what] in [file/module].
  Context: [why this change, current state of the code]
  Constraints: [do not touch X, keep Y, maintain Z interface]
  Done when: [specific, verifiable conditions]
  Verify: [how to check it works — tests, manual check, build]

Focus on:
  - [Criterion 1] ([why it matters for this task type])
  - [Criterion 2] ([specific advice tied to their project])

Common pitfall:
  [Bad prompt example] → [why it's bad]. [Better alternative].

Quick checklist before prompting:
  [ ] Did I specify which files/functions to touch?
  [ ] Did I say what NOT to change?
  [ ] Did I define "done"?
  [ ] Did I mention how to verify?
```

## Rules

- Keep output concise and actionable — no filler text
- Use real file paths and branch names from the project, not generic placeholders
- If you cannot determine the project context (e.g., no git repo, empty directory), give general tips for the requested task type
- Do NOT modify any files — this skill is purely advisory
- Do NOT execute the task itself — only coach on how to prompt for it

---

## [TEMPLATE MANAGER] — Save & Reuse Prompt Templates

Manage reusable prompt templates stored at `~/.claude/prompt-templates/`.

Parse the rest of `$ARGUMENTS` after `template`:
- First token after `template` is the subcommand: `save`, `list`, `use`, or `delete`
- Second token (if present) is the template name

### Subcommand: `save`

Save a new prompt template.

1. The template name is required. If missing, print an error:
   ```
   Error: Template name required. Usage: /prompt-guide template save [name]
   ```
2. Ensure the storage directory exists:
   ```bash
   mkdir -p ~/.claude/prompt-templates
   ```
3. Write a new markdown file at `~/.claude/prompt-templates/<name>.md` with this format:
   ```markdown
   ---
   name: <name>
   author: unknown
   score: 0
   task-type: general
   created: <YYYY-MM-DD>
   ---

   Refactor [WHAT] in [FILE].

   Context:
   - [WHY this change is needed]
   - [CURRENT state / problem]

   Constraints:
   - Do not modify [BOUNDARY]
   - Keep [INVARIANT]

   Done when:
   - [CONDITION 1]
   - [CONDITION 2]
   - Existing tests pass

   Verify:
   - [HOW to check it works]
   ```
4. Print confirmation:
   ```
   Template saved: <name>
   Location: ~/.claude/prompt-templates/<name>.md
   Edit the file to customize the prompt body, author, score, and task-type.
   ```

### Subcommand: `list`

List all saved prompt templates.

1. Use Glob to find all `~/.claude/prompt-templates/*.md` files.
2. If no templates found, print:
   ```
   No saved templates found. Use: /prompt-guide template save [name]
   ```
3. For each template file, use Bash to extract the frontmatter fields `name`, `score`, `task-type`, and `author`:
   ```bash
   head -10 ~/.claude/prompt-templates/<file> | grep -E "^(name|score|task-type|author):"
   ```
4. Format and print the output as a table:
   ```
   Saved Templates (<count>):

     <name>                <score>/100  <task-type>  @<author>
     <name>                <score>/100  <task-type>  @<author>
     ...

   Use: /prompt-guide template use <name>
   ```
   - Left-align template names, pad to 24 characters
   - Right-align scores in `<score>/100` format
   - Left-align task-type, pad to 12 characters

### Subcommand: `use`

Load a template and display it with placeholders ready to fill in.

1. The template name is required. If missing, print an error:
   ```
   Error: Template name required. Usage: /prompt-guide template use [name]
   ```
2. Check if the template file exists at `~/.claude/prompt-templates/<name>.md`. If not, print:
   ```
   Error: Template "<name>" not found. Run /prompt-guide template list to see available templates.
   ```
3. Use Read to load the full contents of `~/.claude/prompt-templates/<name>.md`.
4. Print the template body (everything after the closing `---` of the frontmatter).
5. Use Grep to find all `[PLACEHOLDER]` patterns in the file:
   ```bash
   grep -oE '\[[A-Z][A-Z _/]+\]' ~/.claude/prompt-templates/<name>.md | sort -u
   ```
6. Print a summary of placeholders to fill:
   ```
   Placeholders to fill:
     - [WHAT]
     - [FILE]
     - [WHY this change is needed]
     ...

   Copy the template above and replace each placeholder with your specific values.
   ```

### Subcommand: `delete`

Remove a saved template.

1. The template name is required. If missing, print an error:
   ```
   Error: Template name required. Usage: /prompt-guide template delete [name]
   ```
2. Check if the template file exists at `~/.claude/prompt-templates/<name>.md`. If not, print:
   ```
   Error: Template "<name>" not found. Run /prompt-guide template list to see available templates.
   ```
3. Use Bash to remove the file:
   ```bash
   rm ~/.claude/prompt-templates/<name>.md
   ```
4. Print confirmation:
   ```
   Template deleted: <name>
   ```

### Unknown Subcommand

If the subcommand is not one of `save`, `list`, `use`, or `delete`, print:
```
Unknown subcommand: <subcommand>

Usage: /prompt-guide template [save|list|use|delete] [name]

  save [name]    Save a new prompt template scaffold
  list           Show all saved templates
  use [name]     Load a template and show placeholders
  delete [name]  Remove a template
```

### No Subcommand (just `template` with nothing after)

If `$ARGUMENTS` contains only `template` with nothing after it, print the same usage message as "Unknown Subcommand" above.

---

## Error Handling

All errors use this format:

```
Error: [what went wrong]
Cause: [why it happened]
Fix:   [exact command to resolve]
```

| Error | Message |
|-------|---------|
| Template name missing | `Error: Template name required.` / `Cause: Save/use/delete needs a template name.` / `Fix: Usage: /prompt-guide template [save\|use\|delete] [name]` |
| Template not found | `Error: Template "{name}" not found.` / `Cause: No template with that name exists.` / `Fix: Run /prompt-guide template list to see available templates.` |
| No templates saved | `No saved templates found. Use: /prompt-guide template save [name]` |
| Unknown subcommand | `Error: Unknown subcommand "{cmd}".` / `Cause: Valid subcommands are save, list, use, delete.` / `Fix: Usage: /prompt-guide template [save\|list\|use\|delete] [name]` |

---

## Design Principles

- **Coaching first**: The default mode (no arguments or a task-type hint) gives contextual prompt writing advice before work begins. Templates are opt-in via the `template` subcommand.
- **Context-driven advice**: Tips are tailored to the actual project state (branch name, recent commits, file structure) — not generic placeholders.
- **Reusable patterns**: High-scoring prompts from past sessions can be saved as templates and reused, reducing prompt-writing overhead on future tasks.
- **Non-destructive by default**: The coaching path never modifies files. Only the `template save` and `template delete` subcommands write or remove files.
- **Single entry point**: Both `prompt-tips` and `prompt-template` functionality is now available under `/prompt-guide`, simplifying the skill surface. Use `/prompt-guide` for tips, `/prompt-guide template` for template management, `/review` for prompt review, and `/score` for scoring prompts.
