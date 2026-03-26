#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

AUDIO_URL="${1:-}"
REQUEST_ID="${2:-test_$(date +%s)}"
SUBMIT_URL="${ASR_SUBMIT_URL:-https://openspeech.bytedance.com/api/v3/auc/bigmodel/submit}"
QUERY_URL="${ASR_QUERY_URL:-https://openspeech.bytedance.com/api/v3/auc/bigmodel/query}"
POLL_INTERVAL_SEC="${ASR_POLL_INTERVAL_SEC:-2}"
POLL_MAX_ATTEMPTS="${ASR_POLL_MAX_ATTEMPTS:-30}"
PRINT_JSON="${ASR_PRINT_JSON:-0}"

if [ -z "$AUDIO_URL" ]; then
  echo "Usage: ./test-asr.sh <audio_url> [request_id]"
  echo "Example: ./test-asr.sh https://example.com/audio.mp3"
  exit 1
fi

if [ -z "${ASR_APPID:-}" ] || [ -z "${ASR_TOKEN:-}" ]; then
  echo "Missing ASR_APPID or ASR_TOKEN"
  exit 1
fi

echo "=== Test Doubao ASR API ==="
SAFE_AUDIO_URL="${AUDIO_URL%%\?*}"
echo "Audio URL: $SAFE_AUDIO_URL"
echo "Request ID: $REQUEST_ID"
echo ""

echo "--- Submitting ASR task ---"
TMP_HEADERS="$(mktemp)"
TMP_BODY="$(mktemp)"
curl -sS -D "$TMP_HEADERS" -o "$TMP_BODY" -X POST "$SUBMIT_URL" \
  -H "X-Api-App-Key: $ASR_APPID" \
  -H "X-Api-Access-Key: $ASR_TOKEN" \
  -H "X-Api-Resource-Id: volc.bigasr.auc" \
  -H "X-Api-Request-Id: $REQUEST_ID" \
  -H "X-Api-Sequence: -1" \
  -H "Content-Type: application/json" \
  -d "{\"user\":{\"uid\":\"eval_platform_user\"},\"audio\":{\"url\":\"$AUDIO_URL\"},\"request\":{\"model_name\":\"bigmodel\",\"enable_speaker_info\":true,\"enable_punc\":true,\"show_utterances\":true}}"

API_STATUS="$(awk 'BEGIN{IGNORECASE=1} /^x-api-status-code:/{print $2}' "$TMP_HEADERS" | head -n 1 | tr -d '\r')"
LOG_ID="$(awk 'BEGIN{IGNORECASE=1} /^x-tt-logid:/{print $2}' "$TMP_HEADERS" | head -n 1 | tr -d '\r')"

echo "x-api-status-code: ${API_STATUS:-<missing>}"
echo "x-tt-logid: ${LOG_ID:-<missing>}"
echo "body: $(cat "$TMP_BODY")"
echo ""

if [ "$API_STATUS" != "20000000" ] || [ -z "$LOG_ID" ]; then
  rm -f "$TMP_HEADERS" "$TMP_BODY"
  echo "❌ Task submission failed"
  exit 1
fi

rm -f "$TMP_HEADERS" "$TMP_BODY"
echo "✅ Task submitted successfully"
echo ""
echo "--- Querying result ---"

attempt=1
while [ "$attempt" -le "$POLL_MAX_ATTEMPTS" ]; do
  TMP_HEADERS="$(mktemp)"
  TMP_BODY="$(mktemp)"
  curl -sS -D "$TMP_HEADERS" -o "$TMP_BODY" -X POST "$QUERY_URL" \
    -H "X-Api-App-Key: $ASR_APPID" \
    -H "X-Api-Access-Key: $ASR_TOKEN" \
    -H "X-Api-Resource-Id: volc.bigasr.auc" \
    -H "X-Api-Request-Id: $REQUEST_ID" \
    -H "X-Tt-Logid: $LOG_ID" \
    -H "Content-Type: application/json" \
    -d "{}"

  API_STATUS="$(awk 'BEGIN{IGNORECASE=1} /^x-api-status-code:/{print $2}' "$TMP_HEADERS" | head -n 1 | tr -d '\r')"
  echo "attempt $attempt/$POLL_MAX_ATTEMPTS: x-api-status-code=${API_STATUS:-<missing>}"

  if [ "$API_STATUS" = "20000000" ]; then
    echo "--- Result (utterances) ---"
    node --input-type=module - "$TMP_BODY" <<'NODE'
import fs from 'node:fs';

const file = process.argv[2];
const j = JSON.parse(fs.readFileSync(file, 'utf8'));
const r = j.result || j.data || j;
const utterances = Array.isArray(r.utterances) ? r.utterances : [];

const pad = (n, w = 2) => String(n).padStart(w, '0');
const fmt = (ms) => {
  const num = Number(ms);
  if (!Number.isFinite(num)) return '??:??:??.???';
  const t = Math.max(0, num);
  const hh = Math.floor(t / 3600000);
  const mm = Math.floor((t % 3600000) / 60000);
  const ss = Math.floor((t % 60000) / 1000);
  const mmm = Math.floor(t % 1000);
  return pad(hh) + ':' + pad(mm) + ':' + pad(ss) + '.' + pad(mmm, 3);
};

if (utterances.length === 0) {
  const text = r.text || '';
  process.stdout.write(text ? text + '\n' : JSON.stringify(j));
} else {
  for (const u of utterances) {
    const speaker = (u && u.additions && u.additions.speaker) ?? u?.speaker ?? '';
    const s = fmt(u?.start_time);
    const e = fmt(u?.end_time);
    const line = String(u?.text || '').replace(/\s+/g, ' ').trim();
    const sp = speaker !== '' ? ' speaker=' + speaker : '';
    process.stdout.write('[' + s + ' - ' + e + ']' + sp + ' ' + line + '\n');
  }
  const full = utterances.map((u) => u?.text || '').join('');
  if (full) process.stdout.write('\n--- Result (full_text) ---\n' + full + '\n');
}
NODE
    if [ "$PRINT_JSON" = "1" ]; then
      echo "--- Result (json) ---"
      cat "$TMP_BODY"
      echo ""
    fi
    rm -f "$TMP_HEADERS" "$TMP_BODY"
    exit 0
  fi

  if [ "$API_STATUS" != "20000001" ] && [ "$API_STATUS" != "20000002" ]; then
    cat "$TMP_BODY"
    echo ""
    rm -f "$TMP_HEADERS" "$TMP_BODY"
    echo "❌ Query failed"
    exit 1
  fi

  rm -f "$TMP_HEADERS" "$TMP_BODY"
  sleep "$POLL_INTERVAL_SEC"
  attempt=$((attempt + 1))
done

echo "❌ Timeout: no final result after ${POLL_MAX_ATTEMPTS} attempts"
exit 1
