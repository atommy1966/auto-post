#!/bin/zsh
# ===== ここだけ変更 =====
CLAUDE_MODEL="sonnet"
# 「sonnet」「opus」「haiku」が実際にどの Poe のモデルを指すか
export ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-4.8"
export ANTHROPIC_DEFAULT_SONNET_MODEL="claude-sonnet-4.6"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="claude-haiku-4.5"
# ========================

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR" || exit 1
mkdir -p logs drafts
LOG="$BASE_DIR/logs/draft.log"
echo "===== $(date '+%Y-%m-%d %H:%M:%S') =====" >> "$LOG"

# APIキーはキーチェーンから読む
export POE_API_KEY="$(security find-generic-password -s POE_API_KEY -w 2>>"$BASE_DIR/logs/keychain.err")"
if [ -z "$POE_API_KEY" ]; then
  echo "❌ APIキーが取得できません（キーチェーンの POE_API_KEY を確認）" >> "$LOG"
  exit 1
fi
export ANTHROPIC_BASE_URL="https://api.poe.com"
export ANTHROPIC_AUTH_TOKEN="$POE_API_KEY"
export ANTHROPIC_API_KEY=""

# 一番新しい下書き（1つもなければ空）
BEFORE="$(print -r -- drafts/*.md(N.om[1]))"

claude -p "/draft" --model "$CLAUDE_MODEL" \
  --permission-mode acceptEdits \
  --allowedTools "Read,Write,Edit,Glob,Grep" \
  --disallowedTools "Bash,WebFetch,WebSearch" \
  >> "$LOG" 2>&1
STATUS=$?
echo "exit code: $STATUS" >> "$LOG"
[ $STATUS -eq 0 ] || exit $STATUS

AFTER="$(print -r -- drafts/*.md(N.om[1]))"
if [ -z "$AFTER" ] || [ "$AFTER" = "$BEFORE" ]; then
  echo "⚠️ 新しい下書きがないので、見出し画像は作りません" >> "$LOG"
  exit 1
fi

echo "--- header: $AFTER ---" >> "$LOG"
"$SCRIPT_DIR/header.sh" "$AFTER" >> "$LOG" 2>&1
STATUS=$?
echo "header exit code: $STATUS" >> "$LOG"
exit $STATUS
