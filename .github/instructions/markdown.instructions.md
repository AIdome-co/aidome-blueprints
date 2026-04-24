---
description: 'Markdown formatting aligned to the CommonMark specification (0.31.2)'
applyTo: '**/*.md'
---

<!--
Source: https://github.com/github/awesome-copilot/blob/main/instructions/markdown.instructions.md
License: MIT (github/awesome-copilot)
-->

# CommonMark Markdown

Apply these rules per the [CommonMark spec 0.31.2](https://spec.commonmark.org/0.31.2/) when writing or reviewing `.md` files.

## Preliminaries

- A line ends at a newline (`U+000A`), carriage return (`U+000D`), or end of file. A blank line contains only spaces or tabs.
- Tabs behave as 4-space tab stops for block structure but are not expanded in content.
- **Backslash escapes**: `\` before any ASCII punctuation character renders the literal character. Not recognized in code spans, code blocks, or autolinks.

## Leaf Blocks

- **Thematic breaks**: 3+ matching `-`, `_`, or `*` with 0–3 spaces indent.
- **ATX headings**: 1–6 `#` followed by a space or end of line.
- **Setext headings**: Text underlined with `=` (level 1) or `-` (level 2). Blank line required after a preceding paragraph.
- **Fenced code blocks**: Open with 3+ backticks or tildes. Closing fence must use same character with at least the same count. Specify a language identifier after the opening fence.
- **Link reference definitions**: `[label]: destination "title"`. Case-insensitive. First definition wins.

## Container Blocks

- **Block quotes**: `>` (optionally followed by a space). Blank line separates consecutive block quotes.
- **List items**: `-`, `+`, `*` or ordered `1.` / `1)`. An ordered list interrupting a paragraph must start with `1`.
- **Lists**: Changing bullet character or ordered delimiter starts a new list. A list is loose if any item is separated by a blank line.

## Inlines

- **Code spans**: backtick-delimited.
- **Emphasis**: `*`/`_` for `<em>`, `**`/`__` for `<strong>`. `_` not allowed for intraword emphasis.
- **Links**: `[text](url "title")` or reference `[text][label]`. No whitespace between link text and `(` or `[`.
- **Images**: `![alt](src "title")`. Always provide non-empty alt text.
- **Autolinks**: `<URI>` or `<email>` in angle brackets. Bare URLs are not CommonMark autolinks.
- **Hard line breaks**: Two+ trailing spaces or `\` before line ending.

## Repo-specific rules

- Every `blueprints/NN-*/README.md` must start with `#` (level-1) heading that matches the directory name.
- Relative links between blueprints are preferred; do not link to absolute `https://github.com/AIdome-co/...` URLs.
- Code fences for IaC should specify the language: ```` ```hcl ````, ```` ```yaml ````, ```` ```bash ````, ```` ```python ````.

## Validation Checklist

- [ ] ATX headings use 1–6 `#` followed by a space.
- [ ] Fenced code blocks specify a language identifier.
- [ ] Emphasis uses `*` for intraword; `_` only at word boundaries.
- [ ] Links use `[text](url)` with no whitespace before `(` or `[`.
- [ ] Images include non-empty alt text.
- [ ] Autolinks use angle brackets.
