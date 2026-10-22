# auto-post

Mac で「ネタ集め（Codex）→ 下書き作成（Claude Code）」を毎週月曜に自動で動かすスクリプト集です。
API はどちらも Poe を経由して使います。上記の下書きをNoteへ手動投稿することで、記事一覧情報を読み取り、snsへの自動投稿するためのスクリプト、スキルを追加しています。この時、Bufferを利用します。

## 必要なもの

- macOS
- Poe の API キー（https://poe.com/api/keys で発行・確認できます）
- Node.js（Codex のインストールに使います）
- Codex CLI と Claude Code（インストール方法は下に書いてあります）
- jq（`header.sh` で使います。`brew install jq` で入れられます）
- Buffer アカウント（SNS投稿を使う場合。無料プランで利用できます https://buffer.com）

## フォルダ構成

| フォルダ・ファイル | 中身 |
|---|---|
| `scripts/` | `research.sh`（ネタ集め）、`draft.sh`（下書き作成）、`header.sh`（ヘッダー画像生成）、`note-post.sh`（note投稿）、`note-finalize.js`（カバー画像・インライン画像設定）、`buffer-post.sh`（Buffer単体投稿）、`buffer-post-all.sh`（X・Threads同時投稿） |
| `research/` | `RESEARCH.md`（リサーチの手順書）。実行するたびの結果もここに保存されます |
| `sns/x/` | X（旧Twitter）用の投稿文下書き |
| `sns/threads/` | Threads用の投稿文下書き |
| `launchd/` | 毎週月曜に自動で動かすための設定 |
| `.claude/commands/` | Claude Code 用のコマンド（`/draft`、`/edit`、`/sns-post`、`/threads-post`） |
| `AGENTS.md` / `CLAUDE.md` / `WRITING.md` | AI への指示書 |
| `config.example.toml` | Codex に追加する Poe の設定の見本 |


## 料金についての注意

毎週の自動実行では、リサーチ・下書き・ヘッダー画像の3つでポイントを使います。
Poe のポイントを使います。目安として、リサーチ1回で約20万トークンかかります。

## セットアップ（Codex / リサーチ部分）

### 0. Codex をインストールする

```bash
npm install -g @openai/codex
codex --version
```

### 1. Poe の API キーをキーチェーンに保存する

キーはファイルに書かず、macOS のキーチェーンに保存します。
次のコマンドを実行すると入力を求められるので、そこにキーを貼り付けてください（コマンドの履歴には残りません）。

```bash
security add-generic-password -s POE_API_KEY -a "$USER" -w
```

### 2. Codex に Poe の設定を追加する

リポジトリのフォルダで、次のコマンドを実行します。

```bash
mkdir -p ~/.codex
if grep -q '^\[model_providers\.poe\]' ~/.codex/config.toml 2>/dev/null; then
  echo "すでに [model_providers.poe] があるので、追記は不要です"
else
  printf '\n' >> ~/.codex/config.toml
  cat config.example.toml >> ~/.codex/config.toml
  echo "追記しました"
fi
chmod 600 ~/.codex/config.toml
```

※ 使う Poe の設定は `scripts/research.sh` の中で `-c model_provider=poe` として指定しています。
ふだん Codex で使っている設定は変わりません。

### 3. 動作を確認する

```bash
POE_API_KEY="$(security find-generic-password -s POE_API_KEY -w)" \
  codex exec -c model_provider=poe -m gpt-5.3-codex --skip-git-repo-check \
  "1+1は？数字だけで答えて"
```

`2` と返ってくれば準備は完了です。

※ この確認でも、Codex の仕組み上 約6万トークン を使います。

## セットアップ（Claude Code / 下書き部分）

### 1. Claude Code をインストールする

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
```

### 2. 追加の設定は不要です

`scripts/draft.sh` の中で、次の内容を自動で設定しています。

- 接続先を Poe（`https://api.poe.com`）にする
- API キーはキーチェーンの `POE_API_KEY` から読み込む（Codex の手順で保存したものと同じです）
- 使うモデル（`claude-opus-4.8` など）を指定する

モデルを変えたいときは、`scripts/draft.sh` の上の方にある `ANTHROPIC_DEFAULT_*_MODEL` を書き換えてください。

※ ふだん使っている Claude Code の設定やログイン状態は変わりません（スクリプトの中だけで設定しています）。

## ヘッダー画像について

下書きが作られたあと、`scripts/draft.sh` から自動で `scripts/header.sh` が動きます。結果は `logs/` のログで確認できます。

作り直したいときや、別の下書きに使いたいときは手動でも動かせます。

```bash
./scripts/header.sh                  # 一番新しい下書きの画像を作る
./scripts/header.sh drafts/xxx.md    # 下書きを指定して作る
```

- 下書きのフロントマターにある `image_prompt:` をもとに、Poe の `GPT-Image-1.5` で画像を作ります
- 画像は `drafts/images/下書き名.png`（1280×670）に保存されます
- 下書きのフロントマターに `header: "[[下書き名.png]]"`（Obsidian のリンク形式）が追加されます。すでにある場合は追加しません
- 画像を1枚作るたびに Poe のポイントを使います（毎週の自動実行でも使います）
- モデルを変えたいときは、`scripts/header.sh` の上の方にある `MODEL` を書き換えてください
- 画像の作成に失敗しても、下書きはそのまま残ります。`logs/` のログにある `header exit code` で結果を確認でき、失敗していたら `./scripts/header.sh drafts/xxx.md` で作り直せます
- `image_prompt:` は、`CLAUDE.md` の指示で Claude Code が下書きに自動で付けます。自分で書いた下書きに使うときは、フロントマターに `image_prompt: "英語の画像の説明"` を1行で書いてください

## 自動実行の設定（launchd）
毎週月曜の 7:00 に `scripts/research.sh` が動きます。リサーチが成功すると、続けて `scripts/draft.sh` が自動で動いて下書きが作られ、そのあと `scripts/header.sh` でヘッダー画像も作られます（リサーチに失敗したときは、下書きも画像も作られません）。

※ Mac がスリープしている場合は、スリープが解除されたときに動きます。電源が切れている場合は、その週は動きません。


リポジトリのフォルダで、次のコマンドを実行します。

```bash
mkdir -p logs
sed "s|/Users/YOUR_NAME/auto-post|$PWD|g" \
  launchd/com.example.autopost.research.plist.template \
  > ~/Library/LaunchAgents/com.example.autopost.research.plist
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.example.autopost.research.plist
```

止めたいとき：

```bash
launchctl bootout gui/$(id -u)/com.example.autopost.research
```

手動で動かしたいとき：

```bash
./scripts/research.sh
```

## note自動投稿

`drafts/` にある下書きMarkdownを、noteのエディタに自動で投稿できます。本文の入力・カバー画像の設定・インライン画像の挿入まで自動で行います。

ブラウザ操作に [note-scripts](https://github.com/naginata63/note-scripts)（Playwright）を使います。

### 1. note-scripts をインストールする

```bash
git clone https://github.com/naginata63/note-scripts.git ~/note-scripts
cd ~/note-scripts
npm install
npx playwright install chromium
```

### 2. noteのログイン情報をキーチェーンに保存する

```bash
security add-generic-password -s NOTE_EMAIL -a "$USER" -w "your@email.com"
security add-generic-password -s NOTE_PASSWORD -a "$USER" -w "yourpassword"
```

### 3. 投稿する

```bash
bash scripts/note-post.sh drafts/YYYY-MM-DD_テーマ名.md
```

実行すると：
1. 下書きのフロントマター・Obsidian記法を除去して本文を整形
2. noteに新規下書きを作成
3. カバー画像（`drafts/images/下書き名.png`）を自動設定
4. 本文中のインライン画像プレースホルダーを処理（後述）
5. 完了後、ブラウザでエディタを開く

### インライン画像の自動挿入

下書きに `（スクリーンショット：filename）` と書いておくと、`drafts/images/filename.png` を自動でその位置に挿入します。

```markdown
この画面がダッシュボードです。

（スクリーンショット：dashboard-main）

上の画像のように…
```

### 注意事項

- Playwrightはheadedモード（ブラウザ画面表示）が必要です。スクリーンロック中は動作しません
- Cron等の自動実行には対応していません。手動で実行してください
- 投稿後、カバー画像のリロードが必要な場合があります（ブラウザでエディタを開き直すと反映されます）

## SNS投稿（Buffer連携）

note記事を公開した後、X・Threadsへの投稿文を生成してBufferのキューに追加できます。

### 1. Buffer アカウントを作成してチャンネルを接続する

Buffer（https://buffer.com）に登録し、X・Threadsのアカウントをチャンネルとして接続します。無料プランで3チャンネルまで利用できます。

### 2. Buffer APIトークンをキーチェーンに保存する

Buffer Publish の設定画面（Settings > API）からAPIトークンを取得し、キーチェーンに保存します。

```bash
security add-generic-password -s BUFFER_TOKEN -a buffer -w "YOUR_TOKEN"
```

### 3. チャンネルIDを確認する

organizationId を取得してからチャンネル一覧を取得します。

```bash
# organizationId を取得
curl -s -X POST "https://api.buffer.com/graphql" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ account { organizations { id name } } }"}'

# チャンネル一覧を取得（YOUR_ORG_ID を上で取得した id に置き換える）
curl -s -X POST "https://api.buffer.com/graphql" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ channels(input: { organizationId: \"YOUR_ORG_ID\" }) { id name service } }"}'
```

### 4. スクリプトにチャンネルIDを設定する

`scripts/buffer-post.sh` の上の方にある変数を書き換えます。

```bash
# ===== ここだけ変更 =====
BUFFER_CHANNEL_X="取得したXのチャンネルID"
BUFFER_CHANNEL_THREADS="取得したThreadsのチャンネルID"
# ========================
```

### 5. SNS投稿文を生成する

Claude Code のスキルで投稿文を生成します。note のRSSフィードから公開済み記事のURLを自動で取得します。

`sns-post.md` と `threads-post.md` の中にある `YOUR_NOTE_USERNAME` を自分のnoteのユーザー名に書き換えてください。

```bash
/sns-post テーマ名      # X用投稿文を sns/x/ に生成（パターンA・B の2案）
/threads-post テーマ名  # Threads用投稿文を sns/threads/ に生成（パターンA・B の2案）
```

### 6. A/Bを選んでBufferキューに追加する

`/choose-post` を実行すると、未選択の記事を1件ずつ表示します。X用とThreads用それぞれにA/Bを選ぶと、選択結果がファイルに記録されてそのままBufferのキューに追加されます。

```bash
/choose-post
```

選択結果はフロントマターの `chosen_x:` と `chosen_threads:` に記録されます。XとThreadsで異なるパターンを選ぶこともできます。

```yaml
note_url: https://note.com/YOUR_NOTE_USERNAME/n/xxx
chosen_x: B
chosen_threads: A
```

**選択せずに投稿しようとするとエラーになります。** 必ず `/choose-post` を経由してください。

```bash
# 手動で個別に投稿する場合（chosen_x: / chosen_threads: が設定済みであること）
bash scripts/buffer-post-all.sh 2026-10-20_テーマ名
bash scripts/buffer-post.sh sns/x/2026-10-20_テーマ名.md
```

## Obsidianで確認
Obsidianを使って記事を管理すると、もっと簡単に確認ができます。

https://obsidian.md/

## 関連記事

このリポジトリの仕組みについて、noteで詳しく解説しています。

- [Mac で「ネタ集め→下書き→ヘッダー画像」を毎週自動で作る仕組みを作った（Codex × Claude Code × Poe）](https://note.com/aimusicjapan/n/n332ac2ff7260)
- [note記事を書いたら、X・ThreadsへのSNS投稿もまとめて仕上げる仕組みを作った](https://note.com/aimusicjapan/n/n762d3e4e43d2)
- note記事の投稿も自動化した——無料の公開スクリプトで下書きまで自動で入る（公開後に更新）
