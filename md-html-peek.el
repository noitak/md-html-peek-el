;;; md-html-peek.el --- Open readable HTML previews of Markdown -*- lexical-binding: t; -*-

;; Author: taku_tsunoi
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; Keywords: markdown, html, preview
;; URL: https://example.invalid/md-html-peek

;;; Commentary:

;; md-html-peek formats a Markdown file or buffer as a self-contained HTML
;; file and opens it with the default browser.  Structural Markdown markers can
;; remain visible in the generated HTML while purely decorative syntax renders
;; as clean HTML.

;;; Code:

(require 'browse-url)
(require 'cl-lib)
(require 'subr-x)

(defgroup md-html-peek nil
  "Generate readable HTML previews from Markdown."
  :group 'text
  :prefix "md-html-peek-")

(defcustom md-html-peek-output-directory nil
  "Directory where generated HTML files are written.
When nil, use a temporary directory."
  :type '(choice (const :tag "Temporary directory" nil)
                 directory)
  :group 'md-html-peek)

(defcustom md-html-peek-open-after-generate t
  "When non-nil, open the generated HTML file in the default browser."
  :type 'boolean
  :group 'md-html-peek)

(defcustom md-html-peek-show-markdown-markers t
  "When non-nil, keep structural Markdown markers visible in generated HTML."
  :type 'boolean
  :group 'md-html-peek)

(defcustom md-html-peek-css-theme 'light
  "Theme used in generated HTML."
  :type '(choice (const :tag "Light" light)
                 (const :tag "Dark" dark))
  :group 'md-html-peek)

(defcustom md-html-peek-file-extensions '("md" "markdown")
  "File extensions treated as Markdown."
  :type '(repeat string)
  :group 'md-html-peek)

;;;###autoload
(defun md-html-peek-open (&optional file)
  "Generate HTML for Markdown FILE and open it in the default browser.
When called interactively, use the current buffer file if it looks like
Markdown; otherwise prompt for a file."
  (interactive)
  (let* ((target (or file (md-html-peek--read-markdown-file)))
         (html-file (md-html-peek-generate-file target)))
    (when md-html-peek-open-after-generate
      (browse-url-of-file html-file))
    (message "Generated %s" html-file)
    html-file))

;;;###autoload
(defun md-html-peek-open-buffer ()
  "Generate HTML from the current buffer contents and open it in a browser.
This command does not require the buffer to be saved."
  (interactive)
  (let* ((title (or (buffer-file-name) (buffer-name)))
         (html-file (md-html-peek-generate-string
                     (buffer-substring-no-properties (point-min) (point-max))
                     title)))
    (when md-html-peek-open-after-generate
      (browse-url-of-file html-file))
    (message "Generated %s" html-file)
    html-file))

(defun md-html-peek-generate-file (file)
  "Generate an HTML preview for Markdown FILE and return the HTML path."
  (unless (file-readable-p file)
    (user-error "File is not readable: %s" file))
  (md-html-peek-generate-string
   (with-temp-buffer
     (insert-file-contents file)
     (buffer-string))
   file))

(defun md-html-peek-generate-string (markdown title)
  "Generate an HTML preview for MARKDOWN named TITLE and return the HTML path."
  (let* ((html (md-html-peek-render-string markdown title))
         (html-file (md-html-peek--output-file title)))
    (make-directory (file-name-directory html-file) t)
    (with-temp-file html-file
      (insert html))
    html-file))

(defun md-html-peek-render-string (markdown title)
  "Return a self-contained HTML document for MARKDOWN named TITLE."
  (let ((body (md-html-peek--render-blocks (split-string markdown "\n"))))
    (concat "<!doctype html>\n"
            "<html lang=\"ja\">\n"
            "<head>\n"
            "<meta charset=\"utf-8\">\n"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
            "<title>" (md-html-peek--escape-html (file-name-nondirectory title)) "</title>\n"
            "<style>\n" (md-html-peek--css) "\n</style>\n"
            "</head>\n"
            "<body>\n"
            "<main class=\"md-html-peek-document\">\n"
            "<div class=\"document-meta\">"
            (md-html-peek--escape-html (abbreviate-file-name title))
            "</div>\n"
            body
            "\n</main>\n"
            "</body>\n"
            "</html>\n")))

(defun md-html-peek--read-markdown-file ()
  "Return the current Markdown file, or prompt for one."
  (let ((file (buffer-file-name)))
    (if (and file (md-html-peek--markdown-file-p file))
        file
      (read-file-name "Markdown file: " nil nil t nil
                      #'md-html-peek--markdown-file-p))))

(defun md-html-peek--markdown-file-p (file)
  "Return non-nil when FILE has a Markdown extension."
  (member (downcase (or (file-name-extension file) ""))
          md-html-peek-file-extensions))

(defun md-html-peek--output-file (title)
  "Return the output HTML file path for TITLE."
  (let* ((base (file-name-base (or title "markdown-preview")))
         (safe-base (replace-regexp-in-string "[^[:alnum:]_.-]+" "-" base))
         (dir (or md-html-peek-output-directory
                  (expand-file-name "md-html-peek/" temporary-file-directory))))
    (expand-file-name (concat safe-base ".html") dir)))

(defun md-html-peek--render-blocks (lines)
  "Render Markdown LINES into HTML blocks."
  (let ((html '())
        (paragraph '())
        (list-stack nil)
        (blockquote '())
        (code-lines '())
        (code-lang nil)
        (in-code nil))
    (cl-labels
        ((emit (text) (push text html))
         (flush-paragraph
          ()
          (when paragraph
            (emit (concat "<p>" (md-html-peek--inline
                                 (string-join (nreverse paragraph) " "))
                          "</p>\n"))
            (setq paragraph nil)))
         (flush-list
          ()
          (while list-stack
            (when (plist-get (car list-stack) :li-open)
              (emit "</li>\n"))
            (emit (format "</%s>\n" (plist-get (car list-stack) :type)))
            (setq list-stack (cdr list-stack))))
         (open-list
          (type indent)
          (emit (format "<%s>\n" type))
          (push (list :type type :indent indent :li-open nil) list-stack))
         (close-list-level
          ()
          (when (plist-get (car list-stack) :li-open)
            (emit "</li>\n"))
          (emit (format "</%s>\n" (plist-get (car list-stack) :type)))
          (setq list-stack (cdr list-stack)))
         (close-list-item
          ()
          (when (plist-get (car list-stack) :li-open)
            (emit "</li>\n")
            (setcar list-stack (plist-put (car list-stack) :li-open nil))))
         (ensure-list
          (type indent)
          (while (and list-stack
                      (< indent (plist-get (car list-stack) :indent)))
            (close-list-level))
          (cond
           ((null list-stack)
            (open-list type indent))
           ((> indent (plist-get (car list-stack) :indent))
            (open-list type indent))
           ((not (equal type (plist-get (car list-stack) :type)))
            (close-list-level)
            (open-list type indent))
           (t
            (close-list-item))))
         (flush-blockquote
          ()
          (when blockquote
            (emit (concat "<blockquote>\n"
                          (mapconcat
                           (lambda (line)
                             (concat "<p>"
                                     (md-html-peek--marker ">")
                                     (md-html-peek--inline line)
                                     "</p>"))
                           (nreverse blockquote)
                           "\n")
                          "\n</blockquote>\n"))
            (setq blockquote nil)))
         (flush-code
          ()
          (emit (concat "<pre class=\"code-fence\">"
                        (md-html-peek--marker (concat "```" (or code-lang "")))
                        "\n<code"
                        (if (and code-lang (not (string-empty-p code-lang)))
                            (format " class=\"language-%s\""
                                    (md-html-peek--escape-html code-lang))
                          "")
                        ">"
                        (md-html-peek--escape-html
                         (string-join (nreverse code-lines) "\n"))
                        "</code>\n"
                        (md-html-peek--marker "```")
                        "</pre>\n"))
          (setq code-lines nil
                code-lang nil
                in-code nil))
         (flush-open-blocks
          ()
          (flush-paragraph)
          (flush-list)
          (flush-blockquote)))
      (while lines
        (let ((line (pop lines)))
          (cond
           (in-code
            (if (string-match-p "\\`[[:space:]]*```[[:space:]]*\\'" line)
                (flush-code)
              (push line code-lines)))
           ((string-match "\\`[[:space:]]*```\\([^`]*\\)[[:space:]]*\\'" line)
            (flush-open-blocks)
            (setq in-code t
                  code-lang (string-trim (match-string 1 line))
                  code-lines nil))
           ((string-match-p "\\`[[:space:]]*\\'" line)
            (flush-open-blocks))
           ((md-html-peek--table-start-p line lines)
            (flush-open-blocks)
            (let ((table-data (md-html-peek--consume-table line lines)))
              (emit (md-html-peek--render-table (car table-data)))
              (setq lines (cdr table-data))))
           ((and (string-match "\\`\\(#+\\)[[:space:]]+\\(.+\\)\\'" line)
                 (<= (length (match-string 1 line)) 6))
            (flush-open-blocks)
            (let* ((marker (match-string 1 line))
                   (level (length marker))
                   (text (match-string 2 line)))
              (emit (format "<h%d>%s%s</h%d>\n"
                            level
                            (md-html-peek--marker marker)
                            (md-html-peek--inline text)
                            level))))
           ((string-match "\\`\\([[:space:]]*\\)\\([-+*]\\)[[:space:]]+\\(.+\\)\\'" line)
            (flush-paragraph)
            (flush-blockquote)
            (ensure-list "ul" (md-html-peek--indent-width (match-string 1 line)))
            (emit (concat "<li>"
                          (md-html-peek--inline (match-string 3 line))))
            (setcar list-stack (plist-put (car list-stack) :li-open t)))
           ((string-match "\\`\\([[:space:]]*\\)\\([0-9]+\\.\\)[[:space:]]+\\(.+\\)\\'" line)
            (flush-paragraph)
            (flush-blockquote)
            (ensure-list "ol" (md-html-peek--indent-width (match-string 1 line)))
            (emit (concat "<li>"
                          (md-html-peek--inline (match-string 3 line))))
            (setcar list-stack (plist-put (car list-stack) :li-open t)))
           ((string-match "\\`[[:space:]]*>[[:space:]]?\\(.*\\)\\'" line)
            (flush-paragraph)
            (flush-list)
            (push (match-string 1 line) blockquote))
           ((string-match-p "\\`[[:space:]]*\\([-*_][[:space:]]*\\)\\{3,\\}\\'" line)
            (flush-open-blocks)
            (emit "<hr class=\"thematic-break\">\n"))
           (t
            (flush-list)
            (flush-blockquote)
            (push line paragraph)))))
      (when in-code
        (flush-code))
      (flush-open-blocks)
      (apply #'concat (nreverse html)))))

(defun md-html-peek--indent-width (indent)
  "Return display width for Markdown list INDENT."
  (let ((width 0))
    (dolist (char (string-to-list (or indent "")) width)
      (setq width (+ width (if (= char ?\t) 4 1))))))

(defun md-html-peek--table-start-p (line remaining-lines)
  "Return non-nil when LINE and REMAINING-LINES start a Markdown table."
  (and (string-match-p "|" line)
       (car remaining-lines)
       (md-html-peek--table-separator-p (car remaining-lines))))

(defun md-html-peek--table-separator-p (line)
  "Return non-nil when LINE is a Markdown table separator."
  (let ((trimmed (string-trim line)))
    (and (string-match-p "|" trimmed)
         (string-match-p "\\`|?[[:space:]]*:?-\\{3,\\}:?[[:space:]]*\\(|[[:space:]]*:?-\\{3,\\}:?[[:space:]]*\\)+|?[[:space:]]*\\'" trimmed))))

(defun md-html-peek--consume-table (first-line lines)
  "Consume a Markdown table starting at FIRST-LINE and LINES.
Return a cons cell whose car is the table rows and whose cdr is the remaining
unconsumed lines."
  (let ((rows (list first-line (car lines)))
        (rest (cdr lines)))
    (while (and rest (string-match-p "|" (car rest))
                (not (string-match-p "\\`[[:space:]]*\\'" (car rest))))
      (setq rows (append rows (list (pop rest)))))
    (cons rows rest)))

(defun md-html-peek--table-cells (line)
  "Return table cells parsed from Markdown table LINE."
  (let ((trimmed (string-trim line)))
    (when (string-prefix-p "|" trimmed)
      (setq trimmed (substring trimmed 1)))
    (when (string-suffix-p "|" trimmed)
      (setq trimmed (substring trimmed 0 -1)))
    (mapcar #'string-trim (split-string trimmed "|"))))

(defun md-html-peek--render-table (table)
  "Render TABLE as HTML."
  (let ((header (md-html-peek--table-cells (car table)))
        (rows (mapcar #'md-html-peek--table-cells (cddr table))))
    (concat
     "<table>\n<thead>\n<tr>"
     (mapconcat (lambda (cell)
                  (concat "<th>"
                          (md-html-peek--inline cell)
                          "</th>"))
                header
                "")
     "</tr>\n</thead>\n<tbody>\n"
     (mapconcat
      (lambda (row)
        (concat "<tr>"
                (mapconcat (lambda (cell)
                             (concat "<td>"
                                     (md-html-peek--inline cell)
                                     "</td>"))
                           row
                           "")
                "</tr>"))
      rows
      "\n")
     "\n</tbody>\n</table>\n")))

(defun md-html-peek--inline (text)
  "Render inline Markdown in TEXT."
  (let ((result (md-html-peek--escape-html text)))
    (setq result (replace-regexp-in-string
                  "`\\([^`]+\\)`"
                  (lambda (match)
                    (format "<code>%s</code>" (match-string 1 match)))
                  result t t))
    (setq result (replace-regexp-in-string
                  "!\\[\\([^]]*\\)\\](\\([^)\s]+\\))"
                  (lambda (match)
                    (let ((alt (match-string 1 match))
                          (src (match-string 2 match)))
                      (format "<img src=\"%s\" alt=\"%s\">" src alt)))
                  result t t))
    (setq result (replace-regexp-in-string
                  "\\[\\([^]]+\\)\\](\\([^)\s]+\\))"
                  (lambda (match)
                    (let ((label (match-string 1 match))
                          (href (match-string 2 match)))
                      (format "<a href=\"%s\">%s</a>" href label)))
                  result t t))
    (setq result (replace-regexp-in-string
                  "\\*\\*\\([^*]+\\)\\*\\*"
                  (lambda (match)
                    (format "<strong>%s</strong>" (match-string 1 match)))
                  result t t))
    (setq result (replace-regexp-in-string
                  "\\(^\\|[[:space:]]\\)\\*\\([^*]+\\)\\*"
                  (lambda (match)
                    (format "%s<em>%s</em>"
                            (or (match-string 1 match) "")
                            (match-string 2 match)))
                  result t t))
    result))

(defun md-html-peek--marker (text)
  "Return HTML for visible Markdown marker TEXT."
  (if md-html-peek-show-markdown-markers
      (format "<span class=\"md-marker\">%s</span> "
              (md-html-peek--escape-html text))
    ""))

(defun md-html-peek--escape-html (text)
  "Escape TEXT for use in HTML."
  (let ((escaped (or text "")))
    (setq escaped (replace-regexp-in-string "&" "&amp;" escaped t t))
    (setq escaped (replace-regexp-in-string "<" "&lt;" escaped t t))
    (setq escaped (replace-regexp-in-string ">" "&gt;" escaped t t))
    (setq escaped (replace-regexp-in-string "\"" "&quot;" escaped t t))
    escaped))

(defun md-html-peek--css ()
  "Return embedded CSS."
  (let ((dark (eq md-html-peek-css-theme 'dark)))
    (concat
     ":root {\n"
     (if dark
         "  color-scheme: dark; --bg: #171717; --paper: #202124; --text: #eeeeee; --muted: #a5a5a5; --line: #3a3a3a; --soft: #2c2d2f; --accent: #7db7ff; --code: #25282c;\n"
       "  color-scheme: light; --bg: #f6f7f8; --paper: #ffffff; --text: #24292f; --muted: #6e7781; --line: #d8dee4; --soft: #f1f4f7; --accent: #0969da; --code: #f6f8fa;\n")
     "}\n"
     "body { margin: 0; background: var(--bg); color: var(--text); font: 16px/1.72 -apple-system, BlinkMacSystemFont, \"Segoe UI\", sans-serif; }\n"
     ".md-html-peek-document { box-sizing: border-box; max-width: 880px; margin: 32px auto; padding: 40px 48px; background: var(--paper); border: 1px solid var(--line); border-radius: 8px; }\n"
     ".document-meta { margin-bottom: 24px; color: var(--muted); font: 13px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace; overflow-wrap: anywhere; }\n"
     "h1, h2, h3, h4, h5, h6 { line-height: 1.28; margin: 1.8em 0 .65em; font-weight: 700; }\n"
     "h1 { font-size: 2rem; border-bottom: 1px solid var(--line); padding-bottom: .25em; }\n"
     "h2 { font-size: 1.55rem; border-bottom: 1px solid var(--line); padding-bottom: .2em; }\n"
     "h3 { font-size: 1.25rem; }\n"
     "p { margin: .8em 0; }\n"
     "a { color: var(--accent); text-decoration-thickness: .08em; text-underline-offset: .18em; }\n"
     "ul, ol { margin: .75em 0 .75em 1.2em; padding-left: 1.1em; }\n"
     "li { margin: .25em 0; }\n"
     "blockquote { margin: 1em 0; padding: .35em 1em; border-left: 4px solid var(--line); background: var(--soft); color: var(--text); }\n"
     "table { width: 100%; border-collapse: collapse; margin: 1em 0; display: block; overflow-x: auto; }\n"
     "th, td { border: 1px solid var(--line); padding: .45em .65em; text-align: left; vertical-align: top; }\n"
     "th { background: var(--soft); font-weight: 700; }\n"
     "pre { overflow-x: auto; margin: 1em 0; padding: 14px 16px; background: var(--code); border: 1px solid var(--line); border-radius: 6px; }\n"
     "code { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: .92em; background: var(--code); border-radius: 4px; padding: .12em .28em; }\n"
     "pre code { display: block; padding: 0; background: transparent; border-radius: 0; white-space: pre; }\n"
     "img { max-width: 100%; height: auto; border-radius: 6px; }\n"
     ".md-marker { color: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: .82em; font-weight: 600; user-select: text; }\n"
     ".thematic-break { margin: 1.8em 0; border: 0; border-top: 1px solid var(--line); height: 0; }\n"
     "@media (max-width: 760px) { .md-html-peek-document { margin: 0; border: 0; border-radius: 0; padding: 24px 20px; } body { background: var(--paper); } }\n"
     "@media print { body { background: white; } .md-html-peek-document { margin: 0; border: 0; padding: 0; } a { color: inherit; } }\n")))

(provide 'md-html-peek)

;;; md-html-peek.el ends here
