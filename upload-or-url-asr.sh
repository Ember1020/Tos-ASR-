#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  . "$ROOT_DIR/.env"
  set +a
fi

FILE_PATH=""
AUDIO_URL=""
REQUEST_ID="openclaw_$(date +%s)"

while [ $# -gt 0 ]; do
  case "$1" in
    --file)
      FILE_PATH="${2:-}"
      shift 2
      ;;
    --url)
      AUDIO_URL="${2:-}"
      shift 2
      ;;
    --request-id)
      REQUEST_ID="${2:-}"
      shift 2
      ;;
    -h|--help)
      echo "Usage:"
      echo "  ./upload-or-url-asr.sh --file <local_path> [--request-id <id>]"
      echo "  ./upload-or-url-asr.sh --url <audio_url> [--request-id <id>]"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1"
      exit 1
      ;;
  esac
done

if [ -z "$FILE_PATH" ] && [ -z "$AUDIO_URL" ]; then
  echo "Missing --file or --url"
  exit 1
fi

if [ -n "$FILE_PATH" ] && [ -n "$AUDIO_URL" ]; then
  echo "Provide only one of --file or --url"
  exit 1
fi

if [ -n "$FILE_PATH" ]; then
  if [ ! -f "$FILE_PATH" ]; then
    echo "File not found: $FILE_PATH"
    exit 1
  fi

  if [ -z "${VITE_TOS_ACCESS_KEY_ID:-}" ] || [ -z "${VITE_TOS_SECRET_ACCESS_KEY:-}" ] || [ -z "${VITE_TOS_REGION:-}" ] || [ -z "${VITE_TOS_BUCKET:-}" ]; then
    echo "Missing TOS env: VITE_TOS_ACCESS_KEY_ID / VITE_TOS_SECRET_ACCESS_KEY / VITE_TOS_REGION / VITE_TOS_BUCKET"
    exit 1
  fi

  UPLOAD_JSON="$(node "$SCRIPT_DIR/upload-to-tos.mjs" "$FILE_PATH")"
  AUDIO_URL="$(node -p "JSON.parse(process.argv[1]).url" "$UPLOAD_JSON")"
  KEY="$(node -p "JSON.parse(process.argv[1]).key" "$UPLOAD_JSON")"
  SAFE_URL="${AUDIO_URL%%\?*}"
  echo "{\"key\":\"$KEY\",\"url\":\"$SAFE_URL\"}"
  echo "--- Uploaded to TOS ---"
  echo "key: $KEY"
  echo "url: $SAFE_URL"
fi

if [ -z "${ASR_APPID:-}" ] || [ -z "${ASR_TOKEN:-}" ]; then
  echo "Missing ASR env: ASR_APPID / ASR_TOKEN"
  exit 1
fi

bash "$SCRIPT_DIR/test-asr.sh" "$AUDIO_URL" "$REQUEST_ID"
