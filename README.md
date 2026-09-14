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

- **Size:** ~160 KB standalone native binary.
- **Dependencies:** Zero external dependencies. Built directly on macOS's native `Foundation` CommonMark engine and Cocoa `AppKit` pasteboard APIs.
- **Rendering:** Apple's Markdown parser emits semantic presentation intents, not visual styling — richcopy walks that intent tree to emit real HTML (`<h1>`, `<strong>`, `<table>`…), then derives the RTF flavor from that HTML via the Cocoa HTML importer.
- **Structure:** Standard Swift Package Manager layout — `RichcopyCore` (library with the render/copy logic), `richcopy` (CLI executable), `RichcopyTests` (test target).
