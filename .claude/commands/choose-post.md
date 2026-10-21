sns/x/ の中から chosen_x: が設定されていない下書きを探し、X と Threads それぞれに A/B を選んでください。

## 手順

1. `sns/x/` のファイルを確認し、フロントマターに `chosen_x:` がないファイルを一覧表示する
2. 未選択ファイルがなければ「未選択の記事はありません」と報告して終了する
3. 未選択ファイルが1件以上あれば、1件ずつ以下の形式で提示する：

---
**テーマ名**

【X用】
パターンA: （本文）
パターンB: （本文）

【Threads用】
パターンA: （本文）
パターンB: （本文）

→ X: A か B、Threads: A か B をそれぞれ選んでください
---

4. ユーザーが選択したら（例:「X=B, Threads=A」）：
   - `sns/x/ファイル名.md` のフロントマターに `chosen_x:` と `chosen_threads:` を追記する
   - `sns/threads/ファイル名.md` にも同じ `chosen_x:` と `chosen_threads:` を追記する
   - 続けて `bash scripts/buffer-post-all.sh テーマ名` を実行して投稿する
   - 次の未選択ファイルがあれば同じ手順を繰り返す

5. すべて完了したら、今回選んだ記事とパターンの一覧を報告する

## フィールドの追記位置

フロントマターの `note_url:` の次の行に追加する：
```
note_url: https://...
chosen_x: B
chosen_threads: A
```
