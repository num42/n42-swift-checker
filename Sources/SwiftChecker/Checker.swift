import Foundation

/// Runs rules over Swift files and returns sorted findings.
public struct Checker {
    public var rules: [any Rule]

    public init(rules: [any Rule.Type] = Rules.all) {
        self.rules = rules.map { $0.init() }
    }

    /// Checks already parsed files.
    public mutating func run(_ files: [SourceFile]) -> [Finding] {
        for file in files {
            for index in rules.indices {
                rules[index].collect(file)
            }
        }
        return files.flatMap { file in rules.flatMap { $0.check(file) } }.sorted()
    }

    /// Parses `sources` (path to contents) and checks them. Handy for tests.
    public mutating func run(sources: [String: String]) -> [Finding] {
        run(sources.sorted { $0.key < $1.key }.map { SourceFile(path: $0.key, contents: $0.value) })
    }

    /// Reads and checks the files at `paths`.
    public mutating func run(paths: [String]) throws -> [Finding] {
        let files = try paths.map { path in
            SourceFile(path: path, contents: try String(contentsOfFile: path, encoding: .utf8))
        }
        return run(files)
    }
}
