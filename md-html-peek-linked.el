;;; md-html-peek-linked.el --- Linked Markdown bundles -*- lexical-binding: t; -*-

;;; Commentary:
;; Collect local Markdown documents and render a portable, file-navigable HTML.

;;; Code:

(require 'md-html-peek)
(require 'url-util)

(defun md-html-peek-linked--reference-key (label)
  "Normalize reference LABEL."
  (downcase (replace-regexp-in-string "[[:space:]]+" " " (string-trim label))))

(defun md-html-peek-linked--destination (text)
  "Extract a link destination from TEXT, allowing an optional title."
  (when (string-match "\\`[[:space:]]*\\(?:<\\([^>]*\\)>\\|\\([^[:space:]]*\\)\\)\\(?:[[:space:]]+.*\\)?\\'" text)
    (or (match-string 1 text) (match-string 2 text))))

(defun md-html-peek-linked--prepare (markdown)
  "Return front matter, body lines and reference definitions for MARKDOWN."
  (let* ((parts (md-html-peek--split-front-matter markdown))
         (refs (make-hash-table :test #'equal))
         (fence nil)
         lines)
    (dolist (line (cdr parts))
      (cond
       (fence
        (when (md-html-peek--fence-close-p line fence) (setq fence nil))
        (push line lines))
       ((setq fence (md-html-peek--fence-open line)) (push line lines))
       ((string-match "\\` \\{0,3\\}\\[\\([^]]+\\)\\]:[[:space:]]*\\(.+\\)\\'" line)
        (let* ((label (match-string 1 line))
               (destination (match-string 2 line))
               (key (md-html-peek-linked--reference-key label))
               (url (md-html-peek-linked--destination destination)))
          (unless (gethash key refs) (puthash key url refs)))
        (push "" lines))
       (t (push line lines))))
    (list (car parts) (nreverse lines) refs)))

(defun md-html-peek-linked--closing-paren (text start)
  "Find the closing parenthesis in TEXT for the opening at START."
  (let ((pos (1+ start)) (depth 1) (angle nil))
    (while (and (> depth 0) (< pos (length text)))
      (let ((char (aref text pos)))
        (cond
         ((= char ?\\) (setq pos (1+ pos)))
         ((= char ?<) (setq angle t))
         ((= char ?>) (setq angle nil))
         ((and (not angle) (= char ?\()) (setq depth (1+ depth)))
         ((and (not angle) (= char ?\))) (setq depth (1- depth)))))
      (setq pos (1+ pos)))
    (when (= depth 0) (1- pos))))

(defun md-html-peek-linked--inline (text refs link)
  "Render TEXT with REFS, calling LINK with destination, label and image flag."
  (let ((pos 0) chunks)
    (while (string-match "\\\\.\\|`+\\|!?\\[\\([^]\n]*\\)\\]" text pos)
      (let* ((start (match-beginning 0)) (end (match-end 0))
             (token (match-string 0 text)) (label (match-string 1 text))
             (image (string-prefix-p "!" token)) destination rendered)
        (push (md-html-peek--inline-basic (substring text pos start)) chunks)
        (cond
         ((string-prefix-p "\\" token)
          (setq rendered (md-html-peek--escape-html (substring token 1))))
         ((string-prefix-p "`" token)
          ;; Match a closing run of exactly the same number of backticks.
          (let ((search end) close)
            (while (and (not close) (string-match "`+" text search))
              (setq search (match-end 0))
              (when (= (length token) (- (match-end 0) (match-beginning 0)))
                (setq close (match-beginning 0) end search)))
            (when close
              (setq rendered (concat "<code>" (md-html-peek--escape-html
                                                (substring text (+ start (length token)) close))
                                     "</code>")))))
         (t
          (cond
           ((and (< end (length text)) (= (aref text end) ?\())
            (let ((close (md-html-peek-linked--closing-paren text end)))
              (when close
                (setq destination (md-html-peek-linked--destination
                                   (substring text (1+ end) close))
                      end (1+ close)))))
           ((and (< end (length text))
                 (string-match "\\`\\[\\([^]]*\\)\\]" (substring text end)))
            (let ((key (match-string 1 (substring text end)))
                  (size (match-end 0)))
              (setq destination (gethash (md-html-peek-linked--reference-key
                                          (if (string-empty-p key) label key)) refs))
              (when destination (setq end (+ end size)))))
           (t (setq destination (gethash (md-html-peek-linked--reference-key label) refs))))
          (when destination
            (setq rendered (funcall link destination label image)))))
        (push (or rendered (md-html-peek--escape-html (substring text start end))) chunks)
        (setq pos end)))
    (push (md-html-peek--inline-basic (substring text pos)) chunks)
    (apply #'concat (nreverse chunks))))

(defun md-html-peek-linked--local (url source)
  "Resolve local URL against SOURCE, returning (FILE FRAGMENT), or nil."
  (unless (string-match-p "\\`\\(?:[[:alpha:]][[:alnum:]+.-]*:\\|//\\)" url)
    (let* ((hash (string-match "#" url))
           (fragment (and hash (decode-coding-string
                                (url-unhex-string (substring url (1+ hash))) 'utf-8)))
           (path (car (split-string (if hash (substring url 0 hash) url) "?")))
           (decoded (decode-coding-string (url-unhex-string (or path "")) 'utf-8)))
      (list (if (string-empty-p decoded) source
              (file-truename (expand-file-name decoded (file-name-directory source))))
            fragment))))

(defun md-html-peek-linked--problem (file root)
  "Return why FILE cannot be collected under ROOT, or nil."
  (cond
   ((not (file-in-directory-p file root)) "探索範囲外（未収録）")
   ((not (file-regular-p file)) "ファイルが見つかりません")
   ((not (file-readable-p file)) "ファイルを読み取れません")))

(defun md-html-peek-linked--read (file)
  "Read and prepare saved FILE."
  (with-temp-buffer
    (insert-file-contents file)
    (md-html-peek-linked--prepare (buffer-string))))

(defun md-html-peek-linked--collect (entry root)
  "Collect documents reachable from ENTRY under ROOT in a hash table."
  (let ((docs (make-hash-table :test #'equal)) (pending (list entry)))
    (while pending
      (let ((file (pop pending)))
        (unless (gethash file docs)
          (let* ((doc (md-html-peek-linked--read file))
                 (refs (nth 2 doc))
                 (md-html-peek--inline-renderer
                  (lambda (text)
                    (md-html-peek-linked--inline
                     text refs
                     (lambda (url _label image)
                       (let* ((local (md-html-peek-linked--local url file))
                              (target (car local)))
                         (when (and (not image) target
                                    (md-html-peek--markdown-file-p target)
                                    (not (md-html-peek-linked--problem target root))
                                    (not (gethash target docs)))
                           (push target pending)))
                       "")))))
            (puthash file doc docs)
            (md-html-peek--render-blocks (nth 1 doc) nil)))))
    docs))

(defun md-html-peek-linked--image (file)
  "Return a data URL for local image FILE, or signal an error."
  (let ((mime (cdr (assoc (downcase (or (file-name-extension file) ""))
                          '(("png" . "image/png") ("jpg" . "image/jpeg")
                            ("jpeg" . "image/jpeg") ("gif" . "image/gif")
                            ("webp" . "image/webp") ("svg" . "image/svg+xml")
                            ("avif" . "image/avif") ("ico" . "image/x-icon")
                            ("bmp" . "image/bmp"))))))
    (unless mime (error "未対応の画像形式"))
    (with-temp-buffer
      (set-buffer-multibyte nil)
      (insert-file-contents-literally file)
      (concat "data:" mime ";base64," (base64-encode-string (buffer-string) t)))))

(defconst md-html-peek-linked--script
  "(() => {
  const docs = [...document.querySelectorAll('article[data-document]')];
  const links = [...document.querySelectorAll('[data-file-link]')];
  function show() {
    let id; try { id = decodeURIComponent(location.hash.slice(1)); } catch (_) { id = ''; }
    const target = document.getElementById(id);
    const doc = (target && target.closest('article[data-document]')) || docs[0];
    docs.forEach(item => { item.hidden = item !== doc; });
    document.querySelectorAll('[data-heading-list]').forEach(item => {
      item.hidden = item.dataset.headingList !== doc.id;
    });
    links.forEach(link => {
      if (link.dataset.fileLink === doc.id) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
    document.title = doc.dataset.title;
    if (target && target !== doc) target.scrollIntoView();
    else window.scrollTo(0, 0);
    doc.focus({preventScroll: true});
  }
  addEventListener('hashchange', show);
  show();
})();"
  "Navigation for the standalone bundle; URL fragments supply browser history.")

(defun md-html-peek-generate-linked (file &optional root)
  "Generate linked HTML from saved FILE under ROOT and return its path."
  (let* ((entry (file-truename (expand-file-name file)))
         (root (file-name-as-directory
                (file-truename (or root (file-name-directory entry)))))
         (problem (md-html-peek-linked--problem entry root)))
    (when problem (user-error "%s: %s" problem file))
    (let* ((docs (md-html-peek-linked--collect entry root))
           (files (cons entry (sort (delete entry (hash-table-keys docs)) #'string<)))
           (ids (make-hash-table :test #'equal))
           (headings (make-hash-table :test #'equal))
           (images (make-hash-table :test #'equal))
           issues articles navigation tocs)
      (cl-loop for path in files for index from 0 do
               (puthash path (format "doc-%d" index) ids)
               (puthash path (md-html-peek--extract-headings
                              (string-join (nth 1 (gethash path docs)) "\n")) headings))
      (dolist (path files)
        (let* ((doc (gethash path docs)) (id (gethash path ids))
               (relative (file-relative-name path root))
               (local-headings (gethash path headings))
               (prefixed (mapcar (lambda (heading)
                                  (let ((copy (copy-sequence heading)))
                                    (plist-put copy :id (concat id "--" (plist-get heading :id)))))
                                local-headings))
               (md-html-peek--inline-renderer
                (lambda (text)
                  (md-html-peek-linked--inline
                   text (nth 2 doc)
                   (lambda (url label image)
                     (let* ((local (md-html-peek-linked--local url path))
                            (target (car local)) (fragment (cadr local))
                            (href url) reason)
                       (cond
                        ((string-match-p "\\`[[:space:]]*\\(?:javascript\\|vbscript\\|data\\):" (downcase url))
                         (setq reason "未対応のURL形式"))
                        ((and image target)
                         (setq reason (md-html-peek-linked--problem target root))
                         (unless reason
                           (condition-case err
                               (setq href (or (gethash target images)
                                              (puthash target (md-html-peek-linked--image target) images)))
                             (error (setq reason (error-message-string err))))))
                        ((and target (md-html-peek--markdown-file-p target))
                         (if (not (gethash target ids))
                             (setq reason (or (md-html-peek-linked--problem target root) "未収録"))
                           (setq href (concat "#" (gethash target ids)))
                           (when (and fragment (not (string-empty-p fragment)))
                             (if (cl-find fragment (gethash target headings)
                                          :key (lambda (h) (plist-get h :id)) :test #'equal)
                                 (setq href (concat href "--" fragment))
                               (setq reason "見出しが見つかりません（文書先頭へ移動）")))))
                        (target
                         (setq href (concat "file://" (url-encode-url target)
                                            (if fragment (concat "#" fragment) "")))))
                       (when reason
                         (cl-pushnew (format "%s → %s: %s" relative url reason) issues :test #'equal))
                       (let ((content (md-html-peek--escape-html label))
                             (attribute (md-html-peek--escape-html-attribute href)))
                         (cond
                          ((and reason (not (string-prefix-p "#" href)))
                           (format "<span class=\"link-problem\">%s <small>[%s]</small></span>"
                                   content (md-html-peek--escape-html reason)))
                          (image (format "<img src=\"%s\" alt=\"%s\">" attribute content))
                          (t (format "<a href=\"%s\">%s</a>%s" attribute content
                                     (if reason " <small class=\"link-problem\">[見出しなし]</small>" "")))))))))))
          (push (format "<li><a data-file-link=\"%s\" href=\"#%s\">%s</a></li>"
                        id id (md-html-peek--escape-html relative)) navigation)
          (when md-html-peek-show-heading-list
            (push (format "<div data-heading-list=\"%s\"%s>%s</div>"
                          id (if (equal path entry) "" " hidden")
                          (md-html-peek--render-heading-list prefixed)) tocs))
          (push (concat
                 (format "<article data-document id=\"%s\" data-title=\"%s\" tabindex=\"-1\"%s>"
                         id (md-html-peek--escape-html-attribute relative)
                         (if (equal path entry) "" " hidden"))
                 "<div class=\"document-meta\">" (md-html-peek--escape-html relative) "</div>"
                 (when (car doc) (md-html-peek--render-yaml-front-matter (car doc)))
                 (md-html-peek--render-blocks (nth 1 doc) prefixed)
                 "</article>") articles)))
      (let* ((output (md-html-peek--output-file (concat (file-name-base entry) "-linked.md")))
             (html (concat
                    "<!doctype html><html lang=\"ja\"><head><meta charset=\"utf-8\">"
                    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
                    "<title>" (md-html-peek--escape-html (file-name-nondirectory entry)) "</title><style>"
                    (md-html-peek--css)
                    "[hidden]{display:none!important} .file-list{padding-left:1.2em}"
                    "[aria-current=page]{font-weight:bold;background:var(--soft)}"
                    ".bundle-nav a{overflow-wrap:anywhere} .bundle-nav .md-html-peek-toc{position:static;border:0;padding:0;max-height:none}"
                    ".link-problem{color:var(--muted)} article:focus{outline:none}"
                    "</style></head><body><div class=\"md-html-peek-shell\">"
                    "<aside class=\"md-html-peek-toc bundle-nav\"><nav aria-label=\"ファイル一覧\">"
                    (format "<strong>ファイル一覧 (%d)</strong><ul class=\"file-list\">" (length files))
                    (apply #'concat (nreverse navigation)) "</ul></nav>"
                    (apply #'concat (nreverse tocs))
                    (format "<details><summary>問題一覧 (%d)</summary><ul>" (length issues))
                    (mapconcat (lambda (issue) (concat "<li>" (md-html-peek--escape-html issue) "</li>"))
                               (nreverse issues) "")
                    "</ul></details></aside><main class=\"md-html-peek-document\">"
                    (apply #'concat (nreverse articles))
                    "<noscript>文書の切り替えにはJavaScriptを有効にしてください。</noscript>"
                    "</main></div><script>" md-html-peek-linked--script "</script></body></html>")))
        (make-directory (file-name-directory output) t)
        (with-temp-file output (insert html))
        output))))

(provide 'md-html-peek-linked)
;;; md-html-peek-linked.el ends here
