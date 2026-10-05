import ArgumentParser
import Foundation
import SwiftChecker

@main
struct N42SwiftChecker: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "n42-swift-checker",
        abstract: "Checks Swift code for things SwiftLint cannot see, such as arguments that repeat a default value.",
        discussion: """
            Pass folders or files. Folders are searched for .swift files; .build, DerivedData, Pods, \
            vendor and generated protobuf files are skipped. Output uses Xcode's format, so the tool \
            can run as a build phase and the findings show up in the issue navigator.
            """
    )

    @Argument(help: "Folders or Swift files to check. Defaults to the current folder.")
    var paths: [String] = ["."]

    @Option(name: [.short, .long], help: "Path to skip. Repeat the flag to skip several paths.")
    var exclude: [String] = []

    @Option(name: .long, help: "Only run this rule. Repeat the flag for several rules. Default: all rules.")
    var rule: [String] = []

    @Flag(name: .long, help: "Print findings as errors and exit with status 1 when there are any.")
    var strict = false

    @Flag(name: .long, help: "Print findings as JSON instead of Xcode's format.")
    var json = false

    @Flag(name: .long, help: "List the available rules and exit.")
    var listRules = false

    mutating func run() throws {
        if listRules {
            for rule in Rules.all {
                print("\(rule.identifier)\n    \(rule.summary)")
            }
            return
        }

        let selected: [any Rule.Type] = try rule.isEmpty ? Rules.all : rule.map { identifier in
            guard let rule = Rules.rule(named: identifier) else {
                throw ValidationError("Unknown rule '\(identifier)'. Use --list-rules to see the available rules.")
            }
            return rule
        }

        let files = FileFinder.swiftFiles(under: paths, excluding: exclude)
        var checker = Checker(rules: selected)
        let findings = try checker.run(paths: files)

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(findings), as: UTF8.self))
        } else {
            let severity = strict ? "error" : "warning"
            for finding in findings {
                print("\(finding.path):\(finding.line):\(finding.column): \(severity): \(finding.message) [\(finding.rule)]")
            }
        }

        let summary = "Checked \(files.count) file(s), found \(findings.count) issue(s)."
        FileHandle.standardError.write(Data((summary + "\n").utf8))

        if strict, !findings.isEmpty {
            throw ExitCode(1)
        }
    }
}
