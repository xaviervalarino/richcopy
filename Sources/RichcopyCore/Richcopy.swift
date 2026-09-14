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
    public let rtf: Data
    public let html: Data
    public let plainText: String
}

/// Parses CommonMark + GFM (tables, strikethrough, autolinks) and renders
/// HTML, RTF, and plain-text representations.
///
/// Apple's parser emits semantic presentation intents rather than visual
/// styling, so this walks the intent tree and emits real HTML; the RTF
/// flavor is derived from that HTML. The plain-text flavor is the original
/// Markdown source, which is lossless and pastes cleanly into editors.
@MainActor
public func render(markdown: String) throws -> RenderedMarkdown {
    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw RichcopyError.emptyInput
    }

    let attributed = try AttributedString(
        markdown: markdown,
        options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible)
    )
    let html = htmlDocument(body: htmlBody(from: attributed))
    return RenderedMarkdown(
        rtf: try rtfData(fromHTML: html),
        html: Data(html.utf8),
        plainText: trimmed
    )
}

/// Registers all three flavors on the pasteboard in a single atomic write.
/// Destination apps pick the richest representation they support.
@MainActor
@discardableResult
public func copy(_ rendered: RenderedMarkdown, to pasteboard: NSPasteboard = .general) -> Bool {
    pasteboard.clearContents()
    let rtfOK = pasteboard.setData(rendered.rtf, forType: .rtf)
    let htmlOK = pasteboard.setData(rendered.html, forType: .html)
    let stringOK = pasteboard.setString(rendered.plainText, forType: .string)
    return rtfOK && htmlOK && stringOK
}

// MARK: - Intent tree → HTML

func htmlBody(from attributed: AttributedString) -> String {
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
            out += " "
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

// MARK: - HTML → RTF

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
