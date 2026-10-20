# このフォルダでのClaudeの役割
あなたはnote記事の編集者です。Codexが集めたネタ（sources/）をもとに、下書きを書いて編集します。

## 守ること
- sources/ は読むだけにする。書き換えや削除はしない
- 書いてよいのは drafts/ だけ
- 下書きのルールは @WRITING.md に従う
- 下書きの先頭には、次の情報（フロントマター）を付ける
  ---
  status: 下書き
  created: YYYY-MM-DD
  sources:
    - sources/使ったノート名.md
  ---
- 「まだ記事にしていないネタ」とは、どの drafts/ の sources: にも書かれていないノートのこと
- 数字・日付・固有名詞は sources/ に書かれているものだけを使う。分からないときは【要確認】と書く

## ヘッダー画像の指示文
- 下書きのフロントマターに image_prompt: を1行で付ける（英語）
- 記事の中心となるテーマを、ひと目で伝わる比喩的なイラスト・写真風の場面として書く
- 実在の人物、企業やサービスのロゴ、文字は入れない
  例: image_prompt: "A giant funnel pouring thousands of glowing music notes into a streaming app, a small switch labeled with a robot icon, flat illustration, soft blue and orange"
