#!/usr/bin/env bash
# secret-scan.sh - Detect secrets and credentials in text input
# Usage: secret-scan.sh [file]  or  cat file | secret-scan.sh
# Exit code: 0 = no secrets, 1 = secrets detected, 2 = usage error
# Output format: LINE_NUM:PATTERN_TYPE:MATCHED_TEXT (stdout)
# Summary messages go to stderr

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

DETECTIONS=()
DETECTION_COUNT=0

run_scan() {
  local pattern_type="$1"
  local pattern="$2"
  local exclude="${3:-}"

  while read -r grep_line; do
    line_num="${grep_line%%:*}"
    matched="${grep_line#*:}"
    if [[ -n "$exclude" ]] && printf '%s\n' "$matched" | grep -qE "$exclude"; then
      continue
    fi
    DETECTIONS+=("${line_num}:${pattern_type}:${matched}")
    DETECTION_COUNT=$((DETECTION_COUNT + 1))
  done < <(grep -nEo -e "$pattern" "$INPUT_FILE" 2>/dev/null || true)
}

# Anthropic key
run_scan "ANTHROPIC_KEY"    'sk-ant-[a-zA-Z0-9]{20,}'

# OpenAI key (sk- but not sk-ant-)
run_scan "OPENAI_KEY"       'sk-[a-zA-Z0-9]{20,}' '^sk-ant-'

# GitHub Personal Access Token (classic)
run_scan "GITHUB_PAT"       'ghp_[a-zA-Z0-9]{36}'

# GitHub fine-grained PAT
run_scan "GITHUB_FINE_PAT"  'github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}'

# GitHub OAuth/App tokens
run_scan "GITHUB_TOKEN"     'gh[oups]_[a-zA-Z0-9]{36}'

# AWS Access Key ID
run_scan "AWS_ACCESS_KEY"   'AKIA[0-9A-Z]{16}'

# Stripe keys
run_scan "STRIPE_KEY"       '[sr]k_live_[a-zA-Z0-9]{24,}'

# Google Cloud API key
run_scan "GOOGLE_API_KEY"   'AIza[0-9A-Za-z\-_]{35}'

# Generic password assignment (case-insensitive via character class)
run_scan "GENERIC_PASSWORD" '([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss][Ww][Dd]|[Pp][Ww][Dd])[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'

# Generic API key / secret key assignment
run_scan "GENERIC_SECRET"   '(api[_-]?key|secret[_-]?key|api[_-]?secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}'

# Private key header
run_scan "PRIVATE_KEY"      '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'

# MongoDB connection string
run_scan "MONGODB_URI"      'mongodb(\+srv)?://[^[:space:]]+'

# PostgreSQL connection string
run_scan "POSTGRES_URI"     'postgres(ql)?://[^[:space:]]+'

# Slack tokens
run_scan "SLACK_TOKEN"      'xox[bpors]-[a-zA-Z0-9-]+'

# Bearer tokens
run_scan "BEARER_TOKEN"     '[Aa]uthorization:[[:space:]]*[Bb]earer[[:space:]]+[a-zA-Z0-9._\-]{20,}'

# npm tokens
run_scan "NPM_TOKEN"        'npm_[a-zA-Z0-9]{36}'

# Output results
for detection in ${DETECTIONS[@]+"${DETECTIONS[@]}"}; do
  echo "$detection"
done

if [[ $DETECTION_COUNT -eq 0 ]]; then
  echo "No secrets detected" >&2
  exit 0
else
  echo "${DETECTION_COUNT} secrets detected" >&2
  exit 1
fi
