# richcopy

A fast, zero-dependency macOS CLI utility that reads Markdown from `stdin` (or arguments) and copies it to the system pasteboard simultaneously as **HTML**, **RTF**, and **Plain Text**.

Uses Apple's native CommonMark parser in `Foundation` (`NSAttributedString(markdown:)`).

## Installation

```bash
cd ~/dev/richcopy
make install
```

Installs to `~/scripts/richcopy` (which is in `$PATH`).

## Usage

```bash
# Pipe from echo or cat
echo "**Team announcement**: [Review PR #1661](https://github.com/...)" | richcopy

# Read a file
richcopy < draft.md

# Direct argument
richcopy "This is **bold** with a [link](https://apple.com)"

# Run unit tests
richcopy --test
```

## How It Works

When pasted into:
- **Slack, Notion, Google Docs, Chrome**: Receives `public.html` with rich formatting, clickable links, and bullet lists.
- **Apple Mail, TextEdit, Pages**: Receives `public.rtf`.
- **Terminal, VS Code**: Receives `public.utf8-plain-text`.
