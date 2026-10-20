#!/bin/zsh
# 使い方: header.sh [drafts/xxx.md]（省略したら一番新しい下書き）
# ===== ここだけ変更 =====
MODEL="GPT-Image-1.5"
# ========================

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# 引数で渡されたファイルは、移動する前に絶対パスにしておく
[ -n "$1" ] && D="${1:A}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR" || exit 1

command -v jq >/dev/null || { echo "❌ jq がありません（brew install jq で入れてください）"; exit 1; }
POE_API_KEY="${POE_API_KEY:-$(security find-generic-password -s POE_API_KEY -w 2>/dev/null)}"
[ -n "$POE_API_KEY" ] || { echo "❌ APIキーが取得できません"; exit 1; }

D="${D:-$(print -r -- drafts/*.md(N.om[1]))}"
[ -f "$D" ] || { echo "❌ 下書きが見つかりません: $D"; exit 1; }
NAME="$(basename "$D" .md)"
OUT="drafts/images/${NAME}.png"
mkdir -p drafts/images

PROMPT="$(awk '/^image_prompt:/{sub(/^image_prompt: */,"");gsub(/^"|"$/,"");print;exit}' "$D")"
[ -z "$PROMPT" ] && { echo "❌ image_prompt がありません: $D"; exit 1; }
STYLE="Wide landscape blog header image. Keep the main subject in the center. No text, no letters, no logos, no watermark."

BODY="$(jq -n --arg m "$MODEL" --arg p "$PROMPT $STYLE" '{model:$m,messages:[{role:"user",content:$p}]}')"
RES="$(curl -sS --max-time 300 https://api.poe.com/v1/chat/completions \
  -H "Authorization: Bearer $POE_API_KEY" -H "Content-Type: application/json" -d "$BODY")"
URL="$(printf '%s' "$RES" | grep -oE 'https://[^ )"]*poecdn\.net[^ )"]*' | head -1)"
[ -z "$URL" ] && { echo "❌ 画像URLが取れませんでした: $RES"; exit 1; }

TMP="$(mktemp -t header)"
curl -sSL --max-time 120 "$URL" -o "$TMP" || { echo "❌ 画像のダウンロードに失敗しました"; rm -f "$TMP"; exit 1; }
sips -s format png "$TMP" --out "$OUT" >/dev/null
rm -f "$TMP"
sips --resampleWidth 1280 "$OUT" >/dev/null
sips --cropToHeightWidth 670 1280 "$OUT" >/dev/null

# 下書きのフロントマターに header: を追加（まだ無いときだけ）
if [ "$(head -1 "$D")" = "---" ] && ! grep -q '^header:' "$D"; then
  awk -v h="header: \"[[${NAME}.png]]\"" \
    'NR>1 && /^---$/ && !done {print h; done=1} {print}' "$D" > "$D.tmp" && mv "$D.tmp" "$D"
fi

echo "✅ $OUT"
