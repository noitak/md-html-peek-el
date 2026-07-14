;;; md-html-peek-test.el --- Tests for md-html-peek -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'md-html-peek)

(ert-deftest md-html-peek-renders-heading-with-marker ()
  (let ((html (md-html-peek-render-string "# Title" "sample.md")))
    (should (string-match-p "<h1>" html))
    (should (string-match-p "md-marker\">#" html))
    (should (string-match-p "Title</h1>" html))))

(ert-deftest md-html-peek-renders-list-blockquote-and-code ()
  (let ((html (md-html-peek-render-string "- item\n\n> quote\n\n```elisp\n(message \"hi\")\n```" "sample.md")))
    (should (string-match-p "<ul>" html))
    (should (string-match-p "<li>item</li>" html))
    (should-not (string-match-p "md-marker\">-" html))
    (should (string-match-p "<blockquote>" html))
    (should (string-match-p "class=\"language-elisp\"" html))
    (should (string-match-p "(message &quot;hi&quot;)" html))))

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

(provide 'md-html-peek-test)

;;; md-html-peek-test.el ends here
