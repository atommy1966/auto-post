#!/bin/zsh
# note-post.sh <draft_path> [--publish]
# フロントマターを除去してnote.comに投稿する

set -e
# Node.js: nvm を使う場合は下記を有効化し、バージョンを合わせる
# NODE="$HOME/.nvm/versions/node/YOUR_NODE_VERSION/bin/node"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
NODE="$(which node)"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DRAFT="$1"
PUBLISH="${2:-}"
NOTE_SCRIPTS_DIR="${NOTE_SCRIPTS_DIR:-$HOME/note-scripts}"

if [[ -z "$DRAFT" ]]; then
  echo "使い方: note-post.sh <下書きパス> [--publish]"
  exit 1
fi

# フロントマターからタイトルを取得（# 行）
TITLE=$(grep -m1 '^# ' "$DRAFT" | sed 's/^# //')
if [[ -z "$TITLE" ]]; then
  echo "エラー: タイトル行（# ...）が見つかりません"
  exit 1
fi

# 一時ファイルに本文を書き出す
TMPFILE=$(mktemp /tmp/note-post-XXXXXX.md)
trap "rm -f $TMPFILE" EXIT

python3 -I - "$DRAFT" "$TMPFILE" << 'PYEOF'
import sys, re

src, dst = sys.argv[1], sys.argv[2]
with open(src) as f:
    content = f.read()

# フロントマターを除去
if content.startswith('---'):
    end = content.find('\n---', 3)
    if end != -1:
        content = content[end+4:].lstrip('\n')

# Obsidian wiki リンク ![[...]] と [[...]] を除去
content = re.sub(r'!\[\[.*?\]\]', '', content)
content = re.sub(r'\[\[.*?\]\]', '', content)

# # タイトル行を除去（note-edit.js の --title で渡すため）
content = re.sub(r'^# .+\n+', '', content, count=1)

# --- 水平線を除去（note-edit.js が不安定なため）
content = re.sub(r'^\s*---\s*$', '', content, flags=re.MULTILINE)

# **太字** マーカーを除去（ProseMirrorでの文字化け回避）
content = re.sub(r'\*\*(.+?)\*\*', r'\1', content)

# 箇条書き「- item」→「・item」に変換し、前後に空行を確保
lines = content.split('\n')
out = []
for i, line in enumerate(lines):
    is_bullet = line.startswith('- ')
    prev_bullet = i > 0 and lines[i-1].startswith('- ')
    next_bullet = i < len(lines)-1 and lines[i+1].startswith('- ')
    if is_bullet:
        # 直前が空行でなければ空行を挿入
        if out and out[-1] != '':
            out.append('')
        out.append('・' + line[2:])
        # 直後が箇条書きでなければ空行を挿入
        if not next_bullet:
            out.append('')
    else:
        out.append(line)
content = '\n'.join(out)

# 3行以上の連続空行を2行に圧縮
content = re.sub(r'\n{3,}', '\n\n', content)

with open(dst, 'w') as f:
    f.write(content.strip() + '\n')
PYEOF

echo "タイトル: $TITLE"
echo "投稿中..."

# カバー画像のパス（存在すれば設定）
DRAFT_DIR=$(dirname "$DRAFT")
DRAFT_NAME=$(basename "$DRAFT" .md)
COVER_IMAGE="$DRAFT_DIR/images/${DRAFT_NAME}.png"

NOTE_EMAIL="$(security find-generic-password -s NOTE_EMAIL -w 2>/dev/null)"
NOTE_PASSWORD="$(security find-generic-password -s NOTE_PASSWORD -w 2>/dev/null)"
NOTE_PROFILE_DIR="$HOME/Library/Caches/ms-playwright/note-cli-profile"

export NOTE_EMAIL NOTE_PASSWORD NOTE_PROFILE_DIR

CMD=("$NODE" "$NOTE_SCRIPTS_DIR/scripts/note-edit.js" --action=create \
  --title="$TITLE" \
  --body-file="$TMPFILE")

OUTPUT=$("${CMD[@]}" 2>&1)
echo "$OUTPUT"

# エディタURLを取得
EDITOR_URL=$(echo "$OUTPUT" | grep -o 'https://editor\.note\.com/notes/[^[:space:]]*' | tail -1 | tr -d '\n')

# カバー画像・インライン画像を1セッションで処理
if [[ -n "$EDITOR_URL" ]]; then
  echo "カバー画像・インライン画像を設定中..."
  NOTE_PROFILE_DIR="$NOTE_PROFILE_DIR" \
    "$NODE" "$SCRIPT_DIR/note-finalize.js" \
      "$EDITOR_URL" "$COVER_IMAGE" "$DRAFT"
fi

# 全処理完了後にブラウザで開く
if [[ -n "$EDITOR_URL" ]]; then
  open "$EDITOR_URL"
fi

# --publish が指定されていれば公開まで実行
if [[ "$PUBLISH" == "--publish" ]]; then
  NOTE_URL=$(node "$NOTE_SCRIPTS_DIR/scripts/note-edit.js" --action=list 2>/dev/null | grep -A1 "$TITLE" | grep 'https://note.com' | awk '{print $1}')
  if [[ -n "$NOTE_URL" ]]; then
    echo "公開中: $NOTE_URL"
    NOTE_EMAIL="$NOTE_EMAIL" NOTE_PASSWORD="$NOTE_PASSWORD" NOTE_PROFILE_DIR="$NOTE_PROFILE_DIR" \
      node "$NOTE_SCRIPTS_DIR/scripts/note-edit.js" --action=publish --url="$NOTE_URL"
  fi
fi
