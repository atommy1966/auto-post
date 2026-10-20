# auto-post

Mac で「ネタ集め（Codex）→ 下書き作成（Claude Code）」を毎週月曜に自動で動かすスクリプト集です。
API はどちらも Poe を経由して使います。現時点ではwebから記事を収集して下書きするだけです。将来的には、
snsへ自動投稿も視野に入れています。

## 必要なもの

- macOS
- Poe の API キー（https://poe.com/api/keys で発行・確認できます）
- Node.js（Codex のインストールに使います）
- Codex CLI と Claude Code（インストール方法は下に書いてあります）
- jq（`header.sh` で使います。`brew install jq` で入れられます）

## フォルダ構成

| フォルダ・ファイル | 中身 |
|---|---|
| `scripts/` | `research.sh`（ネタ集め）、`draft.sh`（下書き作成）、`header.sh`（ヘッダー画像生成） |
| `research/` | `RESEARCH.md`（リサーチの手順書）。実行するたびの結果もここに保存されます |
| `sns/` | 将来の自動投稿用（今は空） |
| `launchd/` | 毎週月曜に自動で動かすための設定 |
| `.claude/commands/` | Claude Code 用のコマンド（`/draft`、`/edit`） |
| `AGENTS.md` / `CLAUDE.md` / `WRITING.md` | AI への指示書 |
| `config.example.toml` | Codex に追加する Poe の設定の見本 |


## 料金についての注意

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
