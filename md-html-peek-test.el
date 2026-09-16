;;; md-html-peek-test.el --- Tests for md-html-peek -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'md-html-peek)

(ert-deftest md-html-peek-renders-heading-with-marker ()
  (let ((html (md-html-peek-render-string "# Title" "sample.md")))
    (should (string-match-p "<h1 id=\"title\">" html))
    (should (string-match-p "md-marker\">#" html))
    (should (string-match-p "Title</h1>" html))))

(ert-deftest md-html-peek-renders-heading-list-with-links ()
  (let ((html (md-html-peek-render-string "# Title\n\n## Child" "sample.md")))
    (should (string-match-p "class=\"md-html-peek-toc\"" html))
    (should (string-match-p "href=\"#title\"" html))
    (should (string-match-p "href=\"#child\"" html))
    (should-not (string-match-p "<button" html))
    (should-not (string-match-p "<script>" html))
    (should (string-match-p "<h2 id=\"child\">" html))))

(ert-deftest md-html-peek-renders-unique-heading-ids ()
  (let ((html (md-html-peek-render-string "# Same\n\n## Same" "sample.md")))
    (should (string-match-p "<h1 id=\"same\">" html))
    (should (string-match-p "<h2 id=\"same-2\">" html))
    (should (string-match-p "href=\"#same-2\"" html))))

(ert-deftest md-html-peek-heading-list-does-not-nest-links ()
  (let ((toc (md-html-peek--render-heading-list
              '((:level 1 :id "guide" :text "[Guide](guide.md)")))))
    (should (string-match-p "<a href=\"#guide\">Guide</a>" toc))
    (should-not (string-match-p "href=\"guide.md\"" toc))))

(ert-deftest md-html-peek-ignores-code-fence-headings-in-heading-list ()
  (let ((html (md-html-peek-render-string "# Real\n\n```\n# Not heading\n```" "sample.md")))
    (should (string-match-p "href=\"#real\"" html))
    (should-not (string-match-p "href=\"#not-heading\"" html))))

(ert-deftest md-html-peek-renders-list-blockquote-and-code ()
  (let ((html (md-html-peek-render-string "- item\n\n> quote\n\n```elisp\n(message \"hi\")\n```" "sample.md")))
    (should (string-match-p "<ul>" html))
    (should (string-match-p "<li>item</li>" html))
    (should-not (string-match-p "md-marker\">-" html))
    (should (string-match-p "<blockquote>" html))
    (should (string-match-p "class=\"language-elisp\"" html))
    (should (string-match-p "(message &quot;hi&quot;)" html))))

(ert-deftest md-html-peek-renders-nested-unordered-lists ()
  (let ((html (md-html-peek-render-string "- parent\n  - child\n- sibling" "sample.md")))
    (should (string-match-p
             "<ul>\n<li>parent<ul>\n<li>child</li>\n</ul>\n</li>\n<li>sibling</li>\n</ul>"
             html))))

(ert-deftest md-html-peek-renders-nested-mixed-lists ()
  (let ((html (md-html-peek-render-string "1. parent\n   - child\n2. sibling" "sample.md")))
    (should (string-match-p
             "<ol>\n<li>parent<ul>\n<li>child</li>\n</ul>\n</li>\n<li>sibling</li>\n</ol>"
             html))))

(ert-deftest md-html-peek-renders-inline-formatting-without-markers ()
  (let ((html (md-html-peek-render-string
               "Text with **bold**, *em*, `code`, and [link](https://example.com)."
               "sample.md")))
    (should (string-match-p "<strong>bold</strong>" html))
    (should (string-match-p "<em>em</em>" html))
    (should (string-match-p "<code>code</code>" html))
    (should (string-match-p "<a href=\"https://example.com\">link</a>" html))
    (should-not (string-match-p "md-marker\">\\*\\*" html))
    (should-not (string-match-p "md-marker\">`" html))
    (should-not (string-match-p "md-marker\">\\[\\]" html))))

(ert-deftest md-html-peek-renders-table ()
  (let ((html (md-html-peek-render-string "| A | B |\n| --- | --- |\n| x | y |" "sample.md")))
    (should (string-match-p "<table>" html))
    (should (string-match-p "<th>.*A" html))
    (should (string-match-p "<td>.*x" html))
    (should-not (string-match-p "md-marker\">|" html))))

(ert-deftest md-html-peek-renders-horizontal-rule-without-marker ()
  (let ((html (md-html-peek-render-string "before\n\n----\n\nafter" "sample.md")))
    (should (string-match-p "<hr class=\"thematic-break\">" html))
    (should-not (string-match-p "md-marker\">----" html))))

(ert-deftest md-html-peek-renders-yaml-front-matter ()
  (let ((html (md-html-peek-render-string
               "---\ntitle: \"Sample\"\ndraft: false\ntags:\n  - emacs\n---\n# Title"
               "sample.md")))
    (should (string-match-p "class=\"yaml-front-matter\"" html))
    (should (string-match-p "<span class=\"yaml-key\">title</span>" html))
    (should (string-match-p "<span class=\"yaml-string\">&quot;Sample&quot;</span>" html))
    (should (string-match-p "<span class=\"yaml-literal\">false</span>" html))
    (should (string-match-p "<h1 id=\"title\">" html))
    (should-not (string-match-p "<p>--- title:" html))))

(ert-deftest md-html-peek-does-not-treat-unclosed-front-matter-as-yaml ()
  (let ((html (md-html-peek-render-string "---\nnot front matter" "sample.md")))
    (should-not (string-match-p "class=\"yaml-front-matter\"" html))
    (should (string-match-p "<hr class=\"thematic-break\">" html))))


(require 'md-html-peek-linked)

(ert-deftest md-html-peek-linked-bundle-preserves-navigation ()
  (let* ((dir (make-temp-file "md-html-peek-test-" t))
         (md-html-peek-output-directory dir))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "guide" dir))
          (dolist (item '(("README.md" . "# Home\n\n[Setup](guide/setup.md#設定) [Again][setup]\n\n[setup]: guide/setup.md\n\n[Missing](gone.md) [Bad heading](guide/setup.md#absent)\n\n![Logo](logo.png)\n\n`[Ignore](ignored.md)`\n\n~~~md\n[Ignore](ignored.md)\n~~~\n\n````\n```\n[Ignore](ignored.md)\n````")
                          ("guide/setup.md" . "# 設定\n\n[Home](../README.md) [Usage](usage.md)\n\n## 設定")
                          ("guide/usage.md" . "# Home\n\n[Back](setup.md#設定-2)")
                          ("ignored.md" . "# Should not be collected")))
            (with-temp-file (expand-file-name (car item) dir) (insert (cdr item))))
          (with-temp-file (expand-file-name "logo.png" dir)
            (set-buffer-multibyte nil)
            (insert (base64-decode-string "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aS9kAAAAASUVORK5CYII=")))
          (let* ((output (md-html-peek-generate-linked (expand-file-name "README.md" dir)))
                 (html (with-temp-buffer (insert-file-contents output) (buffer-string))))
            (should (string-suffix-p "README-linked.html" output))
            (should (string-match-p "ファイル一覧 (3)" html))
            (should (string-match-p "href=\"#doc-1--設定\">Setup" html))
            (should (string-match-p "href=\"#doc-1\">Again" html))
            (should (string-match-p "href=\"#doc-0\">Home" html))
            (should (string-match-p "href=\"#doc-1--設定-2\">Back" html))
            (should (string-match-p "href=\"#doc-1\">Bad heading" html))
            (should (string-match-p "id=\"doc-2--home\"" html))
            (should (string-match-p "問題一覧 (2)" html))
            (should (string-match-p "src=\"data:image/png;base64," html))
            (should-not (string-match-p "Should not be collected" html))
            (should-not (string-match-p "href=\"ignored.md\"" html))
            (should (string-match-p "<code>\\[Ignore\\](ignored.md)</code>" html))))
      (delete-directory dir t))))

(ert-deftest md-html-peek-linked-scope-and-aliases ()
  (let* ((dir (make-temp-file "md-html-peek-test-" t))
         (root (expand-file-name "docs" dir))
         (md-html-peek-output-directory dir))
    (unwind-protect
        (progn
          (make-directory root)
          (with-temp-file (expand-file-name "outside.md" dir) (insert "# Outside"))
          (with-temp-file (expand-file-name "entry.md" root)
            (insert "# Entry\n[Outside](../outside.md) [Alias](alias.md) [Self](./entry.md#entry)"))
          (make-symbolic-link (expand-file-name "outside.md" dir) (expand-file-name "alias.md" root))
          (let ((html (with-temp-buffer
                        (insert-file-contents (md-html-peek-generate-linked (expand-file-name "entry.md" root)))
                        (buffer-string))))
            (should (string-match-p "ファイル一覧 (1)" html))
            (should (string-match-p "問題一覧 (2)" html))
            (should (string-match-p "探索範囲外" html))
            (should (string-match-p "href=\"#doc-0--entry\"" html)))
          (let ((html (with-temp-buffer
                        (insert-file-contents (md-html-peek-generate-linked (expand-file-name "entry.md" root) dir))
                        (buffer-string))))
            (should (string-match-p "ファイル一覧 (2)" html))
            (should (string-match-p "問題一覧 (0)" html))))
      (delete-directory dir t))))

(ert-deftest md-html-peek-linked-inline-reference-and-code ()
  (let ((refs (make-hash-table :test #'equal)) urls)
    (puthash "ref" "日本語%20file.md" refs)
    (let ((html (md-html-peek-linked--inline
                 "[ref][] [ref] [Label][REF] [Paren](a(b).md \"title\") [Space](<a b.md>) ``[Code](skip.md)`` \\[Escaped](skip.md)"
                 refs (lambda (url label _image) (push url urls) label))))
      (should (equal (nreverse urls) '("日本語%20file.md" "日本語%20file.md" "日本語%20file.md" "a(b).md" "a b.md")))
      (should (string-match-p "<code>\\[Code\\](skip.md)</code>" html)))))

(ert-deftest md-html-peek-linked-encoded-paths-and-unavailable-assets ()
  (let* ((dir (make-temp-file "md-html-peek-test-" t))
         (md-html-peek-output-directory dir))
    (unwind-protect
        (progn
          (with-temp-file (expand-file-name "entry.md" dir)
            (insert "# Entry\n\n[Japanese](日本語%20file.md#同名-2)\n\n"
                    "[Remote](https://example.com/remote.md) [PDF](manual.pdf)\n\n"
                    "![Missing](absent.png) [Unsafe](javascript:alert(1))\n\n"
                    "    [Code](ignored.md)\n"))
          (with-temp-file (expand-file-name "日本語 file.md" dir)
            (insert "# 同名\n\n# 同名\n\n# 同名-2"))
          (with-temp-file (expand-file-name "ignored.md" dir) (insert "# Ignored"))
          (let ((html (with-temp-buffer
                        (insert-file-contents (md-html-peek-generate-linked (expand-file-name "entry.md" dir)))
                        (buffer-string))))
            (should (string-match-p "ファイル一覧 (2)" html))
            (should (string-match-p "href=\"#doc-1--同名-2\">Japanese" html))
            (should (string-match-p "id=\"doc-1--同名-2-2\"" html))
            (should (string-match-p "href=\"https://example.com/remote.md\"" html))
            (should (string-match-p "href=\"file://[^\"]+/manual.pdf\"" html))
            (should-not (string-match-p "href=\"javascript:" html))
            (should-not (string-match-p "src=\"absent.png" html))
            (should (string-match-p "問題一覧 (2)" html))))
      (delete-directory dir t))))

(provide 'md-html-peek-test)
;;; md-html-peek-test.el ends here
