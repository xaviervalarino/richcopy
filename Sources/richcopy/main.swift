import ArgumentParser
import Foundation
import RichcopyCore

// MARK: - Agent Skill Helpers

private struct AgentSkillTarget {
    let name: String
    let directory: URL
    var fileURL: URL { directory.appendingPathComponent("SKILL.md") }
}

private func detectedSkillTargets() -> [AgentSkillTarget] {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    var targets: [AgentSkillTarget] = []

    let claudeDir = home.appendingPathComponent(".claude/skills/richcopy")
    let geminiDir = home.appendingPathComponent(".gemini/config/skills/richcopy")

    if fm.fileExists(atPath: home.appendingPathComponent(".claude/skills").path) {
        targets.append(AgentSkillTarget(name: "Claude Code", directory: claudeDir))
    }
    if fm.fileExists(atPath: home.appendingPathComponent(".gemini/config/skills").path) {
        targets.append(AgentSkillTarget(name: "Antigravity", directory: geminiDir))
    }
    if targets.isEmpty {
        targets.append(AgentSkillTarget(name: "Claude Code", directory: claudeDir))
    }
    return targets
}

private func installAgentSkill() {
    let fm = FileManager.default
    let targets = detectedSkillTargets()
    var installed: [String] = []

    for target in targets {
        do {
            try fm.createDirectory(at: target.directory, withIntermediateDirectories: true)
            try richcopySkillDefinition.write(to: target.fileURL, atomically: true, encoding: .utf8)
            installed.append("  ✓ \(target.name) (\(target.fileURL.path))")
        } catch {
            fputs("richcopy: warning: failed to install skill to \(target.name): \(error.localizedDescription)\n", stderr)
        }
    }

    if !installed.isEmpty {
        print("Installed richcopy skill:")
        for line in installed {
            print(line)
        }
        print("\nFor other agents (ChatGPT, Cursor, OpenCode):")
        print("  richcopy --print-skill > <your-agent-rules-file>")
    } else {
        fputs("richcopy: error: could not install skill to any location\n", stderr)
        exit(1)
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

    @Flag(name: .customLong("no-rtf"), help: "Skip RTF generation for ultra-fast copying (HTML + plain text). Most macOS apps (Slack, Notion, Google Docs, Apple Mail, Apple Notes) paste rich text directly from HTML.")
    var noRTF = false

    @Flag(name: .customLong("install-skill"), help: "Install the agent skill into detected directories (supported: Claude Code, Antigravity).")
    var installSkill = false

    @Flag(name: .customLong("print-skill"), help: "Print the SKILL.md definition to standard output (for ChatGPT, Cursor, OpenCode, or custom prompts).")
    var printSkill = false

    @Flag(name: [.customShort("V"), .long], help: "Show the version.")
    var version = false

    @Argument(help: "Markdown text to copy. If omitted, reads from standard input.")
    var text: [String] = []

    func run() throws {
        if version {
            print("0.1.0")
            return
        }
        if printSkill {
            print(richcopySkillDefinition)
            return
        }
        if installSkill {
            installAgentSkill()
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
