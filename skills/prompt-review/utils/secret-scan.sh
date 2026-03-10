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

# === Cloud Provider Keys ===

# Azure Storage Account Key (context-aware)
run_scan "AZURE_STORAGE_KEY" '[Aa]ccount[Kk]ey[[:space:]]*=[[:space:]]*[a-zA-Z0-9+/]{86}=='

# Azure SAS Token
run_scan "AZURE_SAS_TOKEN"   'AccountKey=[a-zA-Z0-9+/]{86}=='

# Azure Connection String
run_scan "AZURE_CONN_STR"    'DefaultEndpointsProtocol=https;AccountName=[^;]+;AccountKey=[a-zA-Z0-9+/]{86}=='

# Azure generic key (bare 86-char base64 + ==)
run_scan "AZURE_KEY"         '[a-zA-Z0-9+/]{86}=='

# Vercel token (prefix-based)
run_scan "VERCEL_TOKEN"      'vercel_[a-zA-Z0-9]{24,}'

# Supabase project API key (prefix-based)
run_scan "SUPABASE_KEY"      'sbp_[a-zA-Z0-9]{40,}'

# Supabase JWT (HS256 header prefix)
run_scan "SUPABASE_JWT"      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+'

# Cloudflare API Token (prefix-based)
run_scan "CLOUDFLARE_TOKEN"  'cf_[a-zA-Z0-9_-]{37,}'

# === Communication Services ===

# Twilio Account SID
# NOTE: TWILIO_AUTH pattern ([a-f0-9]{32}) is broad and may produce false positives;
#       treat as advisory and pair with nearby "twilio" keyword for confirmation
run_scan "TWILIO_SID"        'AC[a-f0-9]{32}'
run_scan "TWILIO_AUTH"       '[a-f0-9]{32}'

# SendGrid API Key
run_scan "SENDGRID_KEY"      'SG\.[a-zA-Z0-9_-]{22}\.[a-zA-Z0-9_-]{43}'

# Discord Bot Token
run_scan "DISCORD_TOKEN"     '[MN][a-zA-Z0-9]{23,}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27,}'

# === Database URIs ===

# MySQL connection string
run_scan "MYSQL_URI"         'mysql(2)?://[^[:space:]]+'

# Redis connection string
run_scan "REDIS_URI"         'redis(s)?://[^[:space:]]+'

# AMQP / RabbitMQ connection string
run_scan "AMQP_URI"          'amqps?://[^[:space:]]+'

# === Token Formats ===

# JWT generic (three Base64url segments)
run_scan "JWT_TOKEN"         'eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*'

# Generic Base64-encoded secret (long encoded strings in key assignments)
run_scan "BASE64_SECRET"     '(secret|key|token|password|credential)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9+/]{40,}={0,2}'

# === Network Info ===

# Internal IP addresses (RFC 1918 ranges)
run_scan "INTERNAL_IP"       '(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})'

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
