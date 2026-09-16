# md-html-peek

`md-html-peek` is a small Emacs tool that turns Markdown into readable,
self-contained HTML and opens the generated file in your default browser.

Some structural Markdown markers, such as heading markers, are kept as subtle
visual hints in the generated HTML. Elements that are already clear from their
HTML rendering, such as lists, bold text, links, tables, and horizontal rules,
are rendered cleanly without showing the original Markdown punctuation.

The goal is to make Markdown easier to read while still preserving enough of
the source structure to understand the original document.

## Usage

Put `md-html-peek.el` and `md-html-peek-linked.el` in the same directory on
your `load-path`, then load the main file:

```elisp
(require 'md-html-peek)
```

Open a Markdown file and run:

```text
M-x md-html-peek-open
```

To preview the current buffer without saving it first, run:

```text
M-x md-html-peek-open-buffer
```

### Preview linked Markdown files

Open the starting Markdown file and run:

```text
M-x md-html-peek-open-linked
```

This reads the saved starting file and recursively follows local Markdown
links, producing one `NAME-linked.html` file. Unsaved buffer changes are not
included. Run the command again to refresh the output.

The left sidebar lists the collected files by relative path, with the starting
file first and the rest sorted by path. Select a file or follow a link in its
body to switch documents. The sidebar shows the selected document's headings.
Links such as `guide/setup.md#configuration` open the target document at its
heading, and the browser's Back and Forward buttons work between documents.
Navigation requires JavaScript; no web server or network request is needed
for the bundled documents.

By default, collection stays inside the starting file's directory. Use
`C-u M-x md-html-peek-open-linked` to choose a wider root, for example the
project directory when links use `../`. Real paths determine the boundary;
symbolic links cannot bring files from outside it into the bundle. Cycles and
multiple links to the same file include that file only once.

- Inline links, full reference links, collapsed references and shortcut
  references are supported. Reference definitions use a single line.
- Relative links are resolved against the document containing them. Spaces
  can be percent-encoded or enclosed in angle brackets, as in `[Guide](<my guide.md>)`.
- Links inside inline code or fenced/indented code blocks are not collected.
- Missing files, files outside the root, missing headings and image failures
  appear in the sidebar's problem list. A missing heading falls back to the
  target document's beginning; unavailable documents display a reason inline.
- Local PNG, JPEG, GIF, WebP, SVG, AVIF, ICO and BMP images inside the root are
  embedded. External images keep their URLs and require a network connection.
- External links keep their URLs. Non-Markdown attachments remain local file
  links and are not bundled, so they are not portable with the HTML alone.
- Wiki links (`[[name]]`), raw HTML links and remote Markdown collection are
  not supported. Rendering otherwise uses the existing lightweight Markdown
  renderer, rather than a complete CommonMark implementation.

Heading fragments use lowercase heading text with punctuation and whitespace
replaced by hyphens; Japanese characters are retained. Duplicate IDs receive
numeric suffixes. Each document has its own namespace in the generated HTML.

## Features

- Generates a standalone HTML file with embedded CSS
- Opens the generated file with `browse-url-of-file`
- Writes output to a temporary directory by default
- Shows a clickable heading list on the left side of the HTML preview
- Supports headings, paragraphs, unordered lists, ordered lists, blockquotes,
  fenced code blocks, emphasis, links, images, horizontal rules, tables, and
  YAML front matter
- Shows structural markers, such as heading markers, in the HTML output
- Renders lists, inline formatting, links, tables, and horizontal rules without
  showing their Markdown punctuation
- Renders YAML front matter as a labeled, syntax-highlighted metadata block

## Configuration

```elisp
(setq md-html-peek-output-directory "~/tmp/markdown-preview/")
(setq md-html-peek-css-theme 'dark)
(setq md-html-peek-show-markdown-markers t)
(setq md-html-peek-show-heading-list t)
```

## Verification

```sh
emacs -Q --batch -L . -l md-html-peek-test.el -f ert-run-tests-batch-and-exit
```
