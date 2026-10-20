#!/bin/zsh
# ===== ここだけ変更 =====
CODEX_MODEL="gpt-5.3-codex"
# ========================

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR" || exit 1
mkdir -p logs
LOG="$BASE_DIR/logs/research.log"

echo "===== $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$LOG"
# Poe APIキーをキーチェーンから取得
export POE_API_KEY="$(security find-generic-password -s POE_API_KEY -w 2>>"$BASE_DIR/logs/keychain.err")"
if [ -z "$POE_API_KEY" ]; then
  echo "❌ POE_API_KEY をキーチェーンから取得できませんでした（logs/keychain.err を確認）" >> "${LOG:-$BASE_DIR/logs/research.log}"
  exit 1
fi

codex exec -c model_provider=poe --skip-git-repo-check --sandbox workspace-write -m "$CODEX_MODEL" \
  "research/RESEARCH.md の手順に従って今日のネタを収集してまとめて" \
  >> "$LOG" 2>&1
STATUS=$?
echo "exit code: $STATUS" >> "$LOG"

if [ "$STATUS" -eq 0 ]; then
  "$SCRIPT_DIR/draft.sh"
else
  echo "research に失敗したため draft.sh は実行しません" >> "$LOG"
fi
