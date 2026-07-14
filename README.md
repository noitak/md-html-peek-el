# md-html-peek

EmacsでMarkdownを読みやすいHTMLに変換し、生成後にデフォルトブラウザで開く小さなツールです。

Markdownの見出し記号など、文書構造を読む助けになる一部の記号はHTML上にも薄いマーカーとして残します。
箇条書き、太字、リンク、表、水平線など、HTMLの見た目だけで十分伝わる要素は描画のみにします。
整形後の読みやすさと、元のMarkdown構造の見通しを両立することを目的にしています。

## 使い方

`md-html-peek.el` を `load-path` に置いて読み込みます。

```elisp
(require 'md-html-peek)
```

Markdownファイルを開いた状態で実行します。

```text
M-x md-html-peek-open
```

現在のバッファ内容を、保存せずにプレビューしたい場合は次を使います。

```text
M-x md-html-peek-open-buffer
```

## 主な仕様

- HTMLはCSS埋め込みの単体ファイルとして生成
- 生成後に `browse-url-of-file` でデフォルトブラウザを開く
- 出力先はデフォルトで一時ディレクトリ
- 見出し、段落、リスト、番号付きリスト、引用、コードブロック、強調、リンク、画像、水平線、表に対応
- 見出しなどの構造マーカーをHTML上に表示
- 箇条書き、文字装飾、リンク、表、水平線はMarkdown記号を表示せず描画のみ

## 設定例

```elisp
(setq md-html-peek-output-directory "~/tmp/markdown-preview/")
(setq md-html-peek-css-theme 'dark)
(setq md-html-peek-show-markdown-markers t)
```

## 検証

```sh
emacs -Q --batch -l md-html-peek.el -l md-html-peek-test.el -f ert-run-tests-batch-and-exit
```
