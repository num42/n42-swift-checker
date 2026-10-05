/// One problem found in one place.
public struct Finding: Hashable, Comparable, Sendable, Codable {
    public let rule: String
    public let path: String
    public let line: Int
    public let column: Int
    public let message: String

    public init(rule: String, path: String, line: Int, column: Int, message: String) {
        self.rule = rule
        self.path = path
        self.line = line
        self.column = column
        self.message = message
    }

    public static func < (lhs: Finding, rhs: Finding) -> Bool {
        (lhs.path, lhs.line, lhs.column, lhs.message) < (rhs.path, rhs.line, rhs.column, rhs.message)
    }
}
