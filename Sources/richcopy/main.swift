import ArgumentParser
import Foundation
import RichcopyCore

// MARK: - Agent Skill Definition & Helpers

private let skillDefinition = """
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
"""

private func agentSkillPaths() -> [URL] {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    var paths: [URL] = []

    let claudeDir = home.appendingPathComponent(".claude/skills")
    let geminiDir = home.appendingPathComponent(".gemini/config/skills")

    if fm.fileExists(atPath: claudeDir.path) {
        paths.append(claudeDir.appendingPathComponent("richcopy"))
    }
    if fm.fileExists(atPath: geminiDir.path) {
        paths.append(geminiDir.appendingPathComponent("richcopy"))
    }
    if paths.isEmpty {
        paths.append(claudeDir.appendingPathComponent("richcopy"))
    }
    return paths
}

private func installAgentSkill() {
    let fm = FileManager.default
    let targets = agentSkillPaths()
    var installed: [String] = []

    for dir in targets {
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent("SKILL.md")
            try skillDefinition.write(to: fileURL, atomically: true, encoding: .utf8)
            installed.append(fileURL.path)
        } catch {
            fputs("richcopy: warning: failed to install skill to \(dir.path): \(error.localizedDescription)\n", stderr)
        }
    }

    if !installed.isEmpty {
        print("Installed richcopy skill:")
        for path in installed {
            print("  ✓ \(path)")
        }
    } else {
        fputs("richcopy: error: could not install skill to any location\n", stderr)
        exit(1)
    }
}

private func uninstallAgentSkill() {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let candidates = [
        home.appendingPathComponent(".claude/skills/richcopy"),
        home.appendingPathComponent(".gemini/config/skills/richcopy"),
    ]
    var removed: [String] = []

    for dir in candidates {
        if fm.fileExists(atPath: dir.path) {
            do {
                try fm.removeItem(at: dir)
                removed.append(dir.path)
            } catch {
                fputs("richcopy: warning: failed to remove \(dir.path): \(error.localizedDescription)\n", stderr)
            }
        }
    }

    if !removed.isEmpty {
        print("Removed richcopy skill:")
        for path in removed {
            print("  ✓ \(path)")
        }
    } else {
        print("No installed richcopy skills found.")
    }
}

// MARK: - CLI Command

struct Richcopy: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "richcopy",
        abstract: "Copies Markdown from your terminal to the macOS clipboard as rich text.",
        discussion: """
        Pastes with full formatting (bold, italics, links, lists) into Slack,
        Notion, Google Docs, Apple Mail, and other macOS apps.

        Examples:
          echo "**bold** [link](https://example.com)" | richcopy
          richcopy < file.md
          richcopy "Direct **markdown** string"
        """
    )

    @Flag(name: [.customShort("V"), .long], help: "Show the version.")
    var version = false

    @Flag(name: .customLong("no-rtf"), help: "Skip RTF generation for ultra-fast copying (HTML + plain text). Most macOS apps (Slack, Notion, Google Docs, Apple Mail, Apple Notes) paste rich text directly from HTML.")
    var noRTF = false

    @Flag(name: .customLong("install-skill"), help: "Install the richcopy skill for Claude Code and Antigravity agents.")
    var installSkill = false

    @Flag(name: .customLong("uninstall-skill"), help: "Uninstall the richcopy skill from agent directories.")
    var uninstallSkill = false

    @Flag(name: .customLong("print-skill"), help: "Print the SKILL.md definition to standard output.")
    var printSkill = false

    @Argument(help: "Markdown text to copy. If omitted, reads from standard input.")
    var text: [String] = []

    func run() throws {
        if version {
            print("0.1.0")
            return
        }
        if printSkill {
            print(skillDefinition)
            return
        }
        if installSkill {
            installAgentSkill()
            return
        }
        if uninstallSkill {
            uninstallAgentSkill()
            return
        }
        let input: String
        if !text.isEmpty {
            input = text.joined(separator: " ")
        } else {
            guard let data = try? FileHandle.standardInput.readToEnd(),
                  let stdinText = String(data: data, encoding: .utf8) else {
                fputs("richcopy: error reading from stdin\n", stderr)
                throw ExitCode.failure
            }
            input = stdinText
        }

        let skipRTF = noRTF
        let success = MainActor.assumeIsolated {
            do {
                let rendered = try render(markdown: input, includeRTF: !skipRTF)
                guard copy(rendered) else {
                    fputs("richcopy: error: failed to write to pasteboard\n", stderr)
                    return false
                }
                return true
            } catch {
                fputs("richcopy: error: \(error.localizedDescription)\n", stderr)
                return false
            }
        }

        if !success {
            throw ExitCode.failure
        }
    }
}

Richcopy.main()
