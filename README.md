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

Put `md-html-peek.el` somewhere in your `load-path`, then load it:

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
emacs -Q --batch -l md-html-peek.el -l md-html-peek-test.el -f ert-run-tests-batch-and-exit
```
