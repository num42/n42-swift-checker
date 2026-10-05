/// A check that runs over a whole set of files.
///
/// Rules get two passes. `collect` sees every file first, so a rule can learn
/// facts (such as declared default values) from the whole code base.
/// `check` then reports findings per file.
public protocol Rule: Sendable {
    /// Stable kebab-case name, used on the command line and in the output.
    static var identifier: String { get }
    /// One sentence that says what the rule finds.
    static var summary: String { get }

    init()

    mutating func collect(_ file: SourceFile)
    func check(_ file: SourceFile) -> [Finding]
}

public enum Rules {
    /// Every rule the tool knows, in the order they are listed to the user.
    public static let all: [any Rule.Type] = [
        RedundantDefaultArgumentRule.self,
    ]

    public static func rule(named identifier: String) -> (any Rule.Type)? {
        all.first { $0.identifier == identifier }
    }
}
