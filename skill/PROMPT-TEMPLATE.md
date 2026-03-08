---
name: prompt-template
description: Save, list, use, and delete reusable prompt templates that scored well in past sessions.
argument-hint: "[save|list|use|delete] [name]"
allowed-tools: Bash, Read, Write, Grep, Glob
disable-model-invocation: true
---

# Prompt Template Manager

Manage reusable prompt templates stored at `~/.claude/prompt-templates/`.

## Parse Arguments

Extract the subcommand and template name from `$ARGUMENTS`.

- First token is the subcommand: `save`, `list`, `use`, or `delete`
- Second token (if present) is the template name

## Subcommand: `save`

Save a new prompt template.

1. The template name is required. If missing, print an error:
   ```
   Error: Template name required. Usage: /prompt-template save [name]
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

## Subcommand: `list`

List all saved prompt templates.

1. Use Glob to find all `~/.claude/prompt-templates/*.md` files.
2. If no templates found, print:
   ```
   No saved templates found. Use: /prompt-template save [name]
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

   Use: /prompt-template use <name>
   ```
   - Left-align template names, pad to 24 characters
   - Right-align scores in `<score>/100` format
   - Left-align task-type, pad to 12 characters

## Subcommand: `use`

Load a template and display it with placeholders ready to fill in.

1. The template name is required. If missing, print an error:
   ```
   Error: Template name required. Usage: /prompt-template use [name]
   ```
2. Check if the template file exists at `~/.claude/prompt-templates/<name>.md`. If not, print:
   ```
   Error: Template "<name>" not found. Run /prompt-template list to see available templates.
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

## Subcommand: `delete`

Remove a saved template.

1. The template name is required. If missing, print an error:
   ```
   Error: Template name required. Usage: /prompt-template delete [name]
   ```
2. Check if the template file exists at `~/.claude/prompt-templates/<name>.md`. If not, print:
   ```
   Error: Template "<name>" not found. Run /prompt-template list to see available templates.
   ```
3. Use Bash to remove the file:
   ```bash
   rm ~/.claude/prompt-templates/<name>.md
   ```
4. Print confirmation:
   ```
   Template deleted: <name>
   ```

## Unknown Subcommand

If the subcommand is not one of `save`, `list`, `use`, or `delete`, print:
```
Unknown subcommand: <subcommand>

Usage: /prompt-template [save|list|use|delete] [name]

  save [name]    Save a new prompt template scaffold
  list           Show all saved templates
  use [name]     Load a template and show placeholders
  delete [name]  Remove a template
```

## No Subcommand

If `$ARGUMENTS` is empty, print the same usage message as "Unknown Subcommand" above.
