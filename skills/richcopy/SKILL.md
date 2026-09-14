---
name: richcopy
description: Pipe formatted Markdown into the macOS clipboard as rich text (HTML & RTF) for Slack, Notion, Apple Mail, Apple Notes, and Google Docs. Activate ONLY when the user explicitly requests formatted, styled, or rich text copied to the clipboard.
---

# `richcopy` — macOS Rich Text Clipboard CLI

Use `richcopy` to copy Markdown to the macOS pasteboard with rich text formatting (bold, italics, lists, tables, links, code blocks) instead of raw Markdown syntax.

## When to Use
- **Activate ONLY when:** The user explicitly asks for **formatted text**, **rich text**, **Slack formatting**, **Notion formatting**, or **richcopy** on the clipboard (e.g., "copy this formatted for Slack", "copy as rich text to clipboard").
- **Do NOT activate for:** Standard plain-text clipboard requests (e.g., "copy this script to clipboard", "copy this commit hash"), where normal `pbcopy` is expected.

## Usage Guidelines

### 1. Piping via Stdin (Recommended)
Always pipe content via stdin using a heredoc to prevent shell quoting errors and `!` history expansion:

```bash
cat <<'EOF' | richcopy --no-rtf
### Summary of Changes
- **Feature A**: Description with [link](https://example.com)
- **Feature B**: Another item
EOF
```

### 2. Flag Selection
- **`--no-rtf` (Recommended for speed):** Runs in ~20 ms. Most macOS apps (Slack, Notion, Google Docs, Apple Mail, Apple Notes, Discord, web browsers) pull `public.html` directly and render full formatting without RTF.
- **Default (with RTF):** Use default `richcopy` (without `--no-rtf`) only when pasting specifically into **TextEdit** (in rich text mode) or other native Cocoa `NSTextView` applications.

### 3. Fallback
If `richcopy` is not installed or fails:
```bash
echo "$TEXT" | pbcopy
```
Notify the user that plain text was copied via `pbcopy` and `richcopy` can be installed via Homebrew.
