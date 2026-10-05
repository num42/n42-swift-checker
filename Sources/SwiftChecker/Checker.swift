import Foundation

/// Runs rules over Swift files and returns sorted findings.
public struct Checker {
    public var rules: [any Rule]

    public init(rules: [any Rule.Type] = Rules.all) {
        self.rules = rules.map { $0.init() }
    }

    /// Checks already parsed files. `context` files only feed the collect pass:
    /// rules learn from them, but findings are reported for `files` only.
    public mutating func run(_ files: [SourceFile], context: [SourceFile] = []) -> [Finding] {
        let checked = Set(files.map(\.path))
        for file in files + context.filter({ !checked.contains($0.path) }) {
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

    /// Reads and checks the files at `paths`. Files at `contextPaths` are read for declarations only.
    public mutating func run(paths: [String], contextPaths: [String] = []) throws -> [Finding] {
        run(try paths.map(Self.read), context: try contextPaths.map(Self.read))
    }

    private static func read(_ path: String) throws -> SourceFile {
        SourceFile(path: path, contents: try String(contentsOfFile: path, encoding: .utf8))
    }
}
