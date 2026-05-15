#!/usr/bin/env bash
set -u

SELF=/home/goringich/ollama_auto_120b_shutdown.sh
LOG=/home/goringich/ollama-auto-120b.log
exec >>"$LOG" 2>&1

export HOME=/home/goringich
export USER=goringich
export OLLAMA_HOST=http://127.0.0.1:11434

echo "[$(date '+%F %T')] job started"

if ! systemctl is-active --quiet ollama; then
  echo "[$(date '+%F %T')] starting ollama service"
  sudo -n systemctl start ollama
fi

pkill -f '^ollama pull gpt-oss:120b$' || true
sleep 1

attempt=0
while true; do
  attempt=$((attempt+1))
  echo "[$(date '+%F %T')] pull attempt #$attempt"
  ollama pull gpt-oss:120b
  rc=$?
  if [ "$rc" -eq 0 ]; then
    echo "[$(date '+%F %T')] pull finished successfully"
    break
  fi
  echo "[$(date '+%F %T')] pull failed rc=$rc, sleeping 20s"
  sleep 20
done

if ! ollama list | grep -q '^gpt-oss:120b\b'; then
  echo "[$(date '+%F %T')] verify failed: model not found in ollama list"
  exit 1
fi

if ! ollama show gpt-oss:120b >/dev/null 2>&1; then
  echo "[$(date '+%F %T')] verify failed: ollama show failed"
  exit 1
fi

echo "[$(date '+%F %T')] verification passed"

echo "[$(date '+%F %T')] self-cleanup"
rm -f "$SELF"
rm -f "$LOG"

echo "[$(date '+%F %T')] issuing poweroff"
sudo -n systemctl poweroff
