#!/usr/bin/env bash
# sanitize-markdown.sh - Escape/neutralize potentially dangerous markdown constructs
# Usage: sanitize-markdown.sh [file]  or  cat file | sanitize-markdown.sh
# Exit code: 0 = no issues found, 1 = issues sanitized, 2 = usage error
# Output: sanitized text on stdout; summary messages go to stderr

set -euo pipefail

# Determine input source
if [[ $# -gt 0 ]]; then
  INPUT_FILE="$1"
  if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: File not found: $INPUT_FILE" >&2
    exit 2
  fi
else
  if [[ -t 0 ]]; then
    echo "Error: No file argument and stdin is a terminal. Provide a file or pipe input." >&2
    exit 2
  fi
  INPUT_FILE="$(mktemp)"
  chmod 600 "$INPUT_FILE"
  trap 'rm -f "$INPUT_FILE"' EXIT
  cat > "$INPUT_FILE"
fi

ISSUE_COUNT=0
SANITIZED_FILE="$(mktemp)"
chmod 600 "$SANITIZED_FILE"
trap 'rm -f "$SANITIZED_FILE"' EXIT

cp "$INPUT_FILE" "$SANITIZED_FILE"

# Count grep matches (ERE) and emit a label if any found
count_matches() {
  local pattern="$1"
  grep -cE "$pattern" "$SANITIZED_FILE" 2>/dev/null || true
}

echo "Sanitizing markdown content..." >&2

# === Backtick sequences ===

# Escape triple backtick code fences  ``` -> \`\`\`
_cnt=$(count_matches '```')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] Triple backtick code fence: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's/```/\\`\\`\\`/g' "$SANITIZED_FILE"
fi

# Escape remaining single/double backticks (not part of triple sequence already escaped)
_cnt=$(count_matches '(?<!\\)``?')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] Inline backtick(s): ${_cnt} occurrence(s)" >&2
  perl -i -pe 's/(?<!\\)``?/\\`/g' "$SANITIZED_FILE"
fi

# === Pipe characters ===

# Escape unescaped pipe characters (table injection)
_cnt=$(count_matches '\|')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] Unescaped pipe character: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's/(?<!\\)\|/\\|/g' "$SANITIZED_FILE"
fi

# === HTML tags ===

# Neutralize opening HTML tags  <tag ...> -> &lt;tag ...>
_cnt=$(count_matches '<[a-zA-Z][a-zA-Z0-9]*[ >]')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] HTML opening tag: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's{<([a-zA-Z][a-zA-Z0-9]*)(?=[ >])}{&lt;$1}g' "$SANITIZED_FILE"
fi

# Neutralize closing HTML tags  </tag> -> &lt;/tag&gt;
_cnt=$(count_matches '</[a-zA-Z][a-zA-Z0-9]*>')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] HTML closing tag: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's{</([a-zA-Z][a-zA-Z0-9]*)>}{&lt;/$1&gt;}g' "$SANITIZED_FILE"
fi

# Neutralize self-closing HTML tags  <tag .../> -> &lt;tag...&gt;
_cnt=$(count_matches '<[a-zA-Z][a-zA-Z0-9][^>]*/>')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] HTML self-closing tag: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's{<([a-zA-Z][a-zA-Z0-9]*)[^>]*/>}{&lt;$1/&gt;}g' "$SANITIZED_FILE"
fi

# === Link injection ===

# Neutralize javascript: URLs in markdown links [text](javascript:...)
_cnt=$(count_matches '\]\(javascript:')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] JavaScript URL injection: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's/\]\(javascript:/](javascript%3A/g' "$SANITIZED_FILE"
fi

# Neutralize data: URLs in markdown links
_cnt=$(count_matches '\]\(data:')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] Data URL injection: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's/\]\(data:/](data%3A/g' "$SANITIZED_FILE"
fi

# Neutralize vbscript: URLs
_cnt=$(count_matches '\]\(vbscript:')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] VBScript URL injection: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's/\]\(vbscript:/](vbscript%3A/g' "$SANITIZED_FILE"
fi

# Neutralize reference-style link definitions with dangerous schemes
# e.g.  [label]: javascript:evil()
_cnt=$(perl -ne 'print if /^\[[^\]]+\]:\s*(javascript|data|vbscript):/' "$SANITIZED_FILE" | wc -l | tr -d '[:space:]')
if [[ "$_cnt" -gt 0 ]]; then
  ISSUE_COUNT=$((ISSUE_COUNT + _cnt))
  echo "  [sanitized] Reference link injection: ${_cnt} occurrence(s)" >&2
  perl -i -pe 's{^(\[[^\]]+\]):\s*(javascript|data|vbscript):}{$1: #blocked-}g' "$SANITIZED_FILE"
fi

# Output sanitized content
cat "$SANITIZED_FILE"

# Report summary
if [[ $ISSUE_COUNT -eq 0 ]]; then
  echo "No markdown injection issues found." >&2
  exit 0
else
  echo "${ISSUE_COUNT} markdown injection issue(s) sanitized." >&2
  exit 1
fi
