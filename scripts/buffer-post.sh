#!/bin/zsh
# 使い方: buffer-post.sh <sns/x/xxxx.md または sns/threads/xxxx.md> [A|B]
# パターン省略時は A
# ===== ここだけ変更 =====
BUFFER_CHANNEL_X="YOUR_X_CHANNEL_ID"
BUFFER_CHANNEL_THREADS="YOUR_THREADS_CHANNEL_ID"
# チャンネルIDの確認方法は README を参照してください
# ========================

export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$BASE_DIR" || exit 1

FILE="${1:A}"

[ -f "$FILE" ] || { echo "❌ ファイルが見つかりません: $FILE"; exit 1; }

if [[ "$FILE" == */x/* ]]; then
  PATTERN="$(awk '/^chosen_x:/{print $2; exit}' "$FILE")"
elif [[ "$FILE" == */threads/* ]]; then
  PATTERN="$(awk '/^chosen_threads:/{print $2; exit}' "$FILE")"
fi
# 旧形式 chosen: にフォールバック
[ -n "$PATTERN" ] || PATTERN="$(awk '/^chosen:/{print $2; exit}' "$FILE")"
[ -n "$PATTERN" ] || { echo "❌ 未選択です。/choose-post で A/B を選んでから実行してください: $(basename $FILE)"; exit 1; }

BUFFER_TOKEN="$(security find-generic-password -s BUFFER_TOKEN -w 2>/dev/null)"
[ -n "$BUFFER_TOKEN" ] || { echo "❌ BUFFER_TOKEN が取得できません（キーチェーンを確認）"; exit 1; }

# ファイルパスからチャンネルIDを判定
if [[ "$FILE" == */x/* ]]; then
  CHANNEL_ID="$BUFFER_CHANNEL_X"
elif [[ "$FILE" == */threads/* ]]; then
  CHANNEL_ID="$BUFFER_CHANNEL_THREADS"
else
  echo "❌ sns/x/ または sns/threads/ のファイルを指定してください"
  exit 1
fi

# パターンのテキストを抽出してAPIリクエストを送信
python3 -I - "$FILE" "$PATTERN" "$CHANNEL_ID" "$BUFFER_TOKEN" << 'PYEOF'
import sys, re, json, urllib.request, urllib.error

file_path, pattern, channel_id, token = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

content = open(file_path).read()
heading = f'## パターン{pattern}'
match = re.search(rf'{re.escape(heading)}[^\n]*\n(.*?)(?=\n## パターン|\Z)', content, re.DOTALL)
if not match:
    print(f"❌ パターン{pattern} が見つかりません")
    sys.exit(1)

text = match.group(1).strip()
print(f"📤 投稿内容:\n{text}\n")

query = """
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    ... on PostActionSuccess {
      post { id text status }
    }
    ... on MutationError {
      message
    }
  }
}
"""
payload = json.dumps({
    "query": query,
    "variables": {
        "input": {
            "text": text,
            "channelId": channel_id,
            "schedulingType": "automatic",
            "mode": "addToQueue"
        }
    }
}).encode()

req = urllib.request.Request(
    "https://api.buffer.com/graphql",
    data=payload,
    headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
)
try:
    with urllib.request.urlopen(req) as res:
        data = json.loads(res.read())
    post = data.get("data", {}).get("createPost", {}).get("post")
    if post:
        print(f"✅ キューに追加しました（ID: {post['id']}）")
    else:
        errors = data.get("errors") or data.get("data", {}).get("createPost", {}).get("message")
        print(f"❌ 投稿失敗: {errors}")
        sys.exit(1)
except urllib.error.HTTPError as e:
    print(f"❌ HTTPエラー: {e.code} {e.read().decode()}")
    sys.exit(1)
PYEOF
