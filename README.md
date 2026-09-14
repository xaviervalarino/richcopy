# richcopy

Pipe Markdown from your terminal, paste styled rich text anywhere on macOS.

No more broken raw asterisks or unformatted text when sharing terminal output, PR summaries, or release notes into **Slack**, **Notion**, **Google Docs**, or **Apple Mail**.

## How It Works

`richcopy` takes Markdown and registers all standard macOS pasteboard flavors simultaneously in a single atomic clipboard write. You never have to specify the target format—the destination app automatically selects its preferred representation:

```text
                  ┌─▶ Slack / Notion / Google Docs / Chrome ──▶ pulls "public.html"
                  │
[NSPasteboard] ───┼─▶ Apple Mail / TextEdit / Pages         ──▶ pulls "public.rtf"
(holds all 3)     │
                  └─▶ Terminal / VS Code / Plain Text       ──▶ pulls "public.utf8-plain-text"
```

- **Slack, Notion, Google Docs, Chrome:** Pastes formatted bold, italics, lists, tables, and clickable hyperlinks.
- **Apple Mail, TextEdit, Pages:** Pastes native rich text (`public.rtf`) with real heading sizes, bullets, and tables.
- **Terminal, Code Editors:** Pastes the original Markdown source (`public.utf8-plain-text`) — lossless.

## Supported Formatting

CommonMark plus the GitHub-flavored extensions Apple's engine parses:

- Headings, **bold**, *italic*, ~~strikethrough~~, `inline code`
- Links, plus bare-URL autolinks
- Ordered and unordered lists, task lists (rendered as ☑ / ☐)
- Tables, including per-column alignment
- Fenced code blocks, blockquotes, horizontal rules

## Usage

```bash
# Pipe from command output
echo "**Release complete**: [PR #1661](https://example.com)" | richcopy

# Copy from a file
richcopy < draft.md

# Pass as a direct string
richcopy "Review options: **Option A** vs *Option B*"

# Ultra-fast mode (skip RTF generation)
richcopy --no-rtf < draft.md
```

### The `--no-rtf` Flag

By default, `richcopy` generates all three clipboard representations (`public.html`, `public.rtf`, and `public.utf8-plain-text`).

Passing `--no-rtf` skips RTF generation entirely and copies in **~20 ms**:
- **Fully supported without RTF:** **Slack**, **Notion**, **Google Docs**, **Apple Mail**, **Apple Notes**, **Discord**, and all Chromium/WebKit web browsers pull `public.html` directly and paste rich text with full styling.
- **When RTF is needed:** Native Cocoa `NSTextView` applications (such as **TextEdit** in rich text mode or Scrivener) rely primarily on `public.rtf`.

## AI Agent Skill

`richcopy` includes a built-in skill definition so AI coding agents (Claude Code, Antigravity, Cursor, OpenCode, Codex) know when and how to pipe formatted Markdown to your clipboard:

```bash
# Print the SKILL.md definition to stdout
richcopy --print-skill

# Install into Claude Code
mkdir -p ~/.claude/skills/richcopy && richcopy --print-skill > ~/.claude/skills/richcopy/SKILL.md

# Install into Antigravity
mkdir -p ~/.gemini/config/skills/richcopy && richcopy --print-skill > ~/.gemini/config/skills/richcopy/SKILL.md

# Append to Cursor or repo rules
richcopy --print-skill >> .cursorrules
```

## Installation

```bash
git clone https://github.com/xavier-greenline/richcopy.git ~/dev/richcopy
cd ~/dev/richcopy
make link
```

Compiles the native binary into `bin/richcopy` and symlinks it to `/usr/local/bin/richcopy`.

## Tests

```bash
make test
```

Runs the [Swift Testing](https://developer.apple.com/documentation/testing) suite via `swift test`. Tests write to a private named pasteboard, so running them never touches your real clipboard.

## Technical Details

- **Size:** ~1.6 MB standalone native binary.
- **Dependencies:** Uses `apple/swift-argument-parser` for standard CLI handling (`-h`, `-V`, `--no-rtf`).
- **Rendering:** Apple's Markdown parser emits semantic presentation intents rather than visual styling. `richcopy` walks the intent tree to emit clean HTML, while generating RTF directly through native Cocoa `NSAttributedString` text attributes (falling back to WebKit for tables).
- **Structure:** Standard Swift Package Manager layout — `RichcopyCore` (library with the render/copy logic), `richcopy` (CLI executable), `RichcopyTests` (test target).
