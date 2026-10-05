import SwiftParser
import SwiftSyntax

/// One parsed Swift file.
public struct SourceFile {
    public let path: String
    public let tree: SourceFileSyntax
    public let locationConverter: SourceLocationConverter

    public init(path: String, contents: String) {
        self.path = path
        tree = Parser.parse(source: contents)
        locationConverter = SourceLocationConverter(fileName: path, tree: tree)
    }

    /// Line and column (both 1-based) of a node, ignoring its leading whitespace and comments.
    public func location(of node: some SyntaxProtocol) -> (line: Int, column: Int) {
        let location = locationConverter.location(for: node.positionAfterSkippingLeadingTrivia)
        return (location.line, location.column)
    }
}
