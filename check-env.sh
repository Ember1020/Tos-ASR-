#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

echo "=== ASR Evaluation Platform - Environment Check ==="
echo ""

missing=0

check_var() {
  if [ -z "${!1-}" ]; then
    echo "❌ $1 is NOT set"
    missing=1
    return 0
  else
    echo "✅ $1 is configured"
    return 0
  fi
}

check_optional() {
  if [ -z "${!1-}" ]; then
    echo "ℹ️  $1 is NOT set (optional)"
    return 0
  else
    echo "✅ $1 is configured"
    return 0
  fi
}

echo "--- ASR Configuration ---"
check_var "ASR_APPID"
check_var "ASR_TOKEN"
check_optional "ASR_SUBMIT_URL"
check_optional "ASR_QUERY_URL"

echo ""
echo "--- TOS Configuration ---"
check_var "VITE_TOS_ACCESS_KEY_ID"
check_var "VITE_TOS_SECRET_ACCESS_KEY"
check_var "VITE_TOS_REGION"
check_var "VITE_TOS_BUCKET"
check_optional "VITE_TOS_ENDPOINT"

exit "$missing"
