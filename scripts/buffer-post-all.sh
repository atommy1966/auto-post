#!/bin/zsh
# 使い方: buffer-post-all.sh <テーマ名> [A|B]
# 例: buffer-post-all.sh 2026-10-20_Deezer-AIトグル A
# X と Threads の両方をまとめてBufferキューに追加する

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR" || exit 1

THEME="$1"

[ -n "$THEME" ] || { echo "使い方: buffer-post-all.sh <テーマ名>"; exit 1; }

X_FILE="sns/x/${THEME}.md"
T_FILE="sns/threads/${THEME}.md"

[ -f "$X_FILE" ]  || { echo "❌ X用ファイルが見つかりません: $X_FILE"; exit 1; }
[ -f "$T_FILE" ] || { echo "❌ Threads用ファイルが見つかりません: $T_FILE"; exit 1; }

# chosen_x: の確認（X側で代表して確認）
PATTERN="$(awk '/^chosen_x:/{print $2; exit}' "$X_FILE")"
[ -n "$PATTERN" ] || { echo "❌ 未選択です。/choose-post で A/B を選んでから実行してください: $THEME"; exit 1; }

echo "=== X（パターン${PATTERN}）==="
"$SCRIPT_DIR/buffer-post.sh" "$X_FILE"
echo ""
echo "=== Threads（パターン${PATTERN}）==="
"$SCRIPT_DIR/buffer-post.sh" "$T_FILE"
