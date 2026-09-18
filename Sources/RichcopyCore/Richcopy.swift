import AppKit
import Foundation

public enum RichcopyError: Error, LocalizedError {
    case emptyInput
    case htmlConversionFailed

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "empty markdown input"
        case .htmlConversionFailed:
            return "could not convert rendered HTML to RTF"
        }
    }
}

/// The three pasteboard flavors generated from one Markdown source.
public struct RenderedMarkdown {
    public let rtf: Data?
    public let html: Data
    public let plainText: String

    public init(rtf: Data?, html: Data, plainText: String) {
        self.rtf = rtf
        self.html = html
        self.plainText = plainText
    }
}

/// Parses CommonMark + GFM (tables, strikethrough, autolinks) and renders
/// HTML, RTF, and plain-text representations.
///
/// Apple's parser emits semantic presentation intents rather than visual
/// styling, so this walks the intent tree to emit real HTML. The RTF flavor
/// is generated directly via native Cocoa text attributes for speed, falling
/// back to the HTML importer for tables. The plain-text flavor is the original
/// Markdown source, which is lossless and pastes cleanly into editors.
@MainActor
public func render(markdown: String, includeRTF: Bool = true, hardBreaks: Bool = true) throws -> RenderedMarkdown {
    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw RichcopyError.emptyInput
    }

    let attributed = try AttributedString(
        markdown: markdown,
        options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
    )
    let html = htmlDocument(body: htmlBody(from: attributed, hardBreaks: hardBreaks))
    let rtf: Data?
    if includeRTF {
        rtf = try generateRTF(from: attributed, fallbackHTML: html, hardBreaks: hardBreaks)
    } else {
        rtf = nil
    }
    return RenderedMarkdown(
        rtf: rtf,
        html: Data(html.utf8),
        plainText: trimmed
    )
}

/// Registers all available flavors on the pasteboard in a single atomic write.
/// Destination apps pick the richest representation they support.
@MainActor
@discardableResult
public func copy(_ rendered: RenderedMarkdown, to pasteboard: NSPasteboard = .general) -> Bool {
    pasteboard.clearContents()
    var rtfOK = true
    if let rtf = rendered.rtf {
        rtfOK = pasteboard.setData(rtf, forType: .rtf)
    }
    let htmlOK = pasteboard.setData(rendered.html, forType: .html)
    let stringOK = pasteboard.setString(rendered.plainText, forType: .string)
    return rtfOK && htmlOK && stringOK
}

// MARK: - Intent tree → HTML

func htmlBody(from attributed: AttributedString, hardBreaks: Bool = true) -> String {
    var out = ""
    // Open blocks, outermost first, each with its precomputed closing tag.
    var stack: [(component: PresentationIntent.IntentType, close: String)] = []
    var tableColumns: [PresentationIntent.TableColumn] = []
    var awaitingTaskMarker = false

    func tags(
        for component: PresentationIntent.IntentType,
        path: [PresentationIntent.IntentType]
    ) -> (open: String, close: String) {
        switch component.kind {
        case .paragraph:
            if path.contains(where: {
                if case .listItem = $0.kind { return true }
                return false
            }) {
                return ("", "")
            }
            return ("<p>", "</p>")
        case .header(let level):
            let capped = max(1, min(level, 6))
            return ("<h\(capped)>", "</h\(capped)>")
        case .orderedList:
            return ("<ol>", "</ol>")
        case .unorderedList:
            return ("<ul>", "</ul>")
        case .listItem:
            awaitingTaskMarker = true
            return ("<li>", "</li>")
        case .codeBlock(let languageHint):
            if let languageHint, !languageHint.isEmpty {
                return ("<pre><code class=\"language-\(escaped(languageHint))\">", "</code></pre>")
            }
            return ("<pre><code>", "</code></pre>")
        case .blockQuote:
            return ("<blockquote>", "</blockquote>")
        case .thematicBreak:
            return ("<hr>", "")
        case .table(let columns):
            tableColumns = columns
            return ("<table>", "</table>")
        case .tableHeaderRow:
            return ("<thead><tr>", "</tr></thead>")
        case .tableRow:
            return ("<tr>", "</tr>")
        case .tableCell(let columnIndex):
            let isHeader = path.contains { component in
                if case .tableHeaderRow = component.kind { return true }
                return false
            }
            let tag = isHeader ? "th" : "td"
            var style = ""
            if columnIndex < tableColumns.count {
                switch tableColumns[columnIndex].alignment {
                case .center: style = " style=\"text-align:center\""
                case .right: style = " style=\"text-align:right\""
                case .left: break
                @unknown default: break
                }
            }
            return ("<\(tag)\(style)>", "</\(tag)>")
        @unknown default:
            return ("", "")
        }
    }

    for run in attributed.runs {
        let path = run.presentationIntent.map { Array($0.components.reversed()) } ?? []

        var common = 0
        while common < min(stack.count, path.count), stack[common].component == path[common] {
            common += 1
        }
        for entry in stack[common...].reversed() {
            out += entry.close
        }
        stack.removeSubrange(common...)
        for component in path[common...] {
            let tag = tags(for: component, path: path)
            out += tag.open
            stack.append((component, tag.close))
        }

        let isThematicBreak = path.contains { component in
            if case .thematicBreak = component.kind { return true }
            return false
        }
        if isThematicBreak { continue }

        let inline = run.inlinePresentationIntent ?? []
        if inline.contains(.lineBreak) {
            out += "<br>"
            continue
        }
        if inline.contains(.softBreak) {
            out += hardBreaks ? "<br>" : " "
            continue
        }

        var text = String(attributed[run.range].characters)
        if awaitingTaskMarker {
            awaitingTaskMarker = false
            if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
                text = "☑ " + text.dropFirst(4)
            } else if text.hasPrefix("[ ] ") {
                text = "☐ " + text.dropFirst(4)
            }
        }

        var chunk = escaped(text)
        if inline.contains(.code) { chunk = "<code>\(chunk)</code>" }
        if inline.contains(.strikethrough) { chunk = "<del>\(chunk)</del>" }
        if inline.contains(.emphasized) { chunk = "<em>\(chunk)</em>" }
        if inline.contains(.stronglyEmphasized) { chunk = "<strong>\(chunk)</strong>" }
        if let link = run.link {
            chunk = "<a href=\"\(escaped(link.absoluteString))\">\(chunk)</a>"
        }
        out += chunk
    }

    for entry in stack.reversed() {
        out += entry.close
    }
    return out
}

private func escaped(_ text: String) -> String {
    text
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

private func htmlDocument(body: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
    body { font-family: -apple-system, Helvetica, sans-serif; font-size: 13px; }
    table { border-collapse: collapse; }
    th, td { border: 1px solid #b5b5b5; padding: 2px 8px; }
    code, pre { font-family: Menlo, monospace; }
    blockquote { margin-left: 12px; border-left: 3px solid #ccc; padding-left: 8px; }
    </style>
    </head>
    <body>
    \(body)
    </body>
    </html>
    """
}

// MARK: - RTF Generation

@MainActor
private func generateRTF(from attributed: AttributedString, fallbackHTML: String, hardBreaks: Bool = true) throws -> Data {
    let hasTable = attributed.runs.contains { run in
        run.presentationIntent?.components.contains {
            if case .table = $0.kind { return true }
            return false
        } ?? false
    }
    if hasTable {
        return try rtfData(fromHTML: fallbackHTML)
    }
    return try directRTFData(from: attributed, hardBreaks: hardBreaks)
}

@MainActor
private func directRTFData(from attributed: AttributedString, hardBreaks: Bool = true) throws -> Data {
    let out = NSMutableAttributedString()
    var lastBlockIdentity: Int?
    var isNewBlock = true

    for run in attributed.runs {
        let path = run.presentationIntent.map { Array($0.components.reversed()) } ?? []
        let inline = run.inlinePresentationIntent ?? []

        var isHeader = false
        var headerLevel = 0
        var isListItem = false
        var isCodeBlock = false
        var isBlockQuote = false
        var isThematicBreak = false

        for comp in path {
            switch comp.kind {
            case .header(let level):
                isHeader = true
                headerLevel = max(1, min(level, 6))
            case .listItem:
                isListItem = true
            case .codeBlock:
                isCodeBlock = true
            case .blockQuote:
                isBlockQuote = true
            case .thematicBreak:
                isThematicBreak = true
            default:
                break
            }
        }

        let currentIdentity = path.last?.identity
        if currentIdentity != lastBlockIdentity {
            if lastBlockIdentity != nil {
                out.append(NSAttributedString(string: "\n"))
            }
            lastBlockIdentity = currentIdentity
            isNewBlock = true
        }

        if isThematicBreak {
            out.append(NSAttributedString(string: "──────────\n", attributes: [.foregroundColor: NSColor.separatorColor]))
            continue
        }

        if inline.contains(.lineBreak) {
            out.append(NSAttributedString(string: "\n"))
            continue
        }
        if inline.contains(.softBreak) {
            out.append(NSAttributedString(string: hardBreaks ? "\n" : " "))
            continue
        }

        if isNewBlock {
            isNewBlock = false
            if isListItem {
                out.append(NSAttributedString(string: "•\t", attributes: [.font: NSFont.systemFont(ofSize: 13)]))
            }
        }

        var text = String(attributed[run.range].characters)
        if text.hasPrefix("[x] ") || text.hasPrefix("[X] ") {
            text = "☑ " + text.dropFirst(4)
        } else if text.hasPrefix("[ ] ") {
            text = "☐ " + text.dropFirst(4)
        }

        var fontSize: CGFloat = 13
        if isHeader {
            switch headerLevel {
            case 1: fontSize = 24
            case 2: fontSize = 18
            case 3: fontSize = 15
            case 4: fontSize = 14
            default: fontSize = 13
            }
        }

        var font: NSFont
        if isCodeBlock || inline.contains(.code) {
            font = NSFont.monospacedSystemFont(ofSize: max(11, fontSize - 1), weight: .regular)
        } else if isHeader || inline.contains(.stronglyEmphasized) {
            font = NSFont.boldSystemFont(ofSize: fontSize)
        } else {
            font = NSFont.systemFont(ofSize: fontSize)
        }

        if inline.contains(.emphasized) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }

        var attrs: [NSAttributedString.Key: Any] = [.font: font]
        if inline.contains(.strikethrough) {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if let link = run.link {
            attrs[.link] = link
        }
        if isBlockQuote {
            attrs[.foregroundColor] = NSColor.secondaryLabelColor
        }

        out.append(NSAttributedString(string: text, attributes: attrs))
    }

    return try out.data(
        from: NSRange(location: 0, length: out.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
}

@MainActor
private func rtfData(fromHTML html: String) throws -> Data {
    guard let attributed = NSAttributedString(
        html: Data(html.utf8),
        options: [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ],
        documentAttributes: nil
    ) else {
        throw RichcopyError.htmlConversionFailed
    }
    return try attributed.data(
        from: NSRange(location: 0, length: attributed.length),
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
}

// MARK: - Agent Skill Definition

public let richcopySkillDefinition = """
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
- **`--no-breaks`:** Preserve standard CommonMark soft line breaks (collapses single newlines into spaces). By default, `richcopy` treats single newlines as hard breaks (`<br>`) so multiline stacks paste cleanly into chat and notes.
- **Default (with RTF):** Use default `richcopy` (without `--no-rtf`) only when pasting specifically into **TextEdit** (in rich text mode) or other native Cocoa `NSTextView` applications.

### 3. Formatting Best Practices & Preferences

- **Slack Layout & Styling Preferences:**
  - **Section Whitespace:** Separate bold category headings with blank lines for easy visual scanning.
  - **Anchor Bolding Only (Personal Preference):** Restrict bolding to lead-in anchors (`* **Before:**`, `* **Why:**`). Never scatter bold words mid-sentence unless highlighting a critical keyword or explicitly requested.
  - **Nested Lists:** Slack fully supports multi-level nested lists; format sub-bullets with standard 2-space or 4-space markdown indentation.

### 4. Fallback
If `richcopy` is not installed or fails:
```bash
echo "$TEXT" | pbcopy
```
Notify the user that plain text was copied via `pbcopy` and `richcopy` can be installed via Homebrew.
"""

