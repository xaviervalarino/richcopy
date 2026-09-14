import AppKit
import Foundation

public enum RichcopyError: Error, LocalizedError {
    case emptyInput

    public var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "empty markdown input"
        }
    }
}

/// The three pasteboard flavors generated from one Markdown source.
public struct RenderedMarkdown {
    public let rtf: Data
    public let html: Data
    public let plainText: String
}

/// Parses CommonMark and renders RTF, HTML, and plain-text representations.
public func render(markdown: String) throws -> RenderedMarkdown {
    let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw RichcopyError.emptyInput
    }

    let attributed = try NSAttributedString(markdown: markdown)
    let range = NSRange(location: 0, length: attributed.length)
    let rtf = try attributed.data(
        from: range,
        documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
    )
    let html = try attributed.data(
        from: range,
        documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
    )
    return RenderedMarkdown(rtf: rtf, html: html, plainText: attributed.string)
}

/// Registers all three flavors on the pasteboard in a single atomic write.
/// Destination apps pick the richest representation they support.
@discardableResult
public func copy(_ rendered: RenderedMarkdown, to pasteboard: NSPasteboard = .general) -> Bool {
    pasteboard.clearContents()
    let rtfOK = pasteboard.setData(rendered.rtf, forType: .rtf)
    let htmlOK = pasteboard.setData(rendered.html, forType: .html)
    let stringOK = pasteboard.setString(rendered.plainText, forType: .string)
    return rtfOK && htmlOK && stringOK
}
