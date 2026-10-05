import SwiftSyntax

/// One parameter of a function, initializer, enum case or memberwise initializer.
struct Parameter: Hashable {
    /// The argument label at the call site, or nil for `_`.
    let label: String?
    /// The default value with all whitespace removed, or nil when the caller must pass it.
    let defaultValue: String?
    let isVariadic: Bool

    init(label: String?, defaultValue: String?, isVariadic: Bool = false) {
        self.label = label
        self.defaultValue = defaultValue
        self.isVariadic = isVariadic
    }
}

/// Something that can be called with labeled arguments.
struct Declaration: Hashable {
    /// The function name, the type name for initializers, or the case name for enum cases.
    let name: String
    let parameters: [Parameter]

    /// `name(label:_:)` for messages.
    var signature: String {
        name + "(" + parameters.map { ($0.label ?? "_") + ":" }.joined() + ")"
    }

    /// Maps each call argument to a parameter index, or nil when the arguments do not fit.
    ///
    /// Follows Swift's rules: arguments keep the parameter order, parameters with defaults
    /// may be skipped, and a variadic parameter takes any number of unlabeled arguments.
    func match(_ arguments: [CallArgument]) -> [Int]? {
        var mapping: [Int] = []
        var next = 0
        var lastWasVariadic = false

        for argument in arguments {
            while true {
                guard next < parameters.count else { return nil }
                let parameter = parameters[next]
                let fits = parameter.label == argument.label
                if fits {
                    mapping.append(next)
                    lastWasVariadic = parameter.isVariadic
                    if !parameter.isVariadic { next += 1 }
                    break
                }
                if lastWasVariadic, argument.label == nil {
                    mapping.append(next - 1)
                    break
                }
                guard parameter.defaultValue != nil || parameter.isVariadic else { return nil }
                next += 1
                lastWasVariadic = false
            }
        }
        return mapping
    }
}

struct CallArgument {
    let label: String?
    let value: String
    let node: LabeledExprSyntax
}

enum ExpressionText {
    /// The source text of a node without comments and whitespace. `1.0` becomes `1`.
    static func normalized(_ node: some SyntaxProtocol) -> String {
        var text = ""
        for token in node.tokens(viewMode: .sourceAccurate) {
            if case .floatLiteral(let literal) = token.tokenKind {
                text += normalizedFloat(literal)
            } else {
                text += token.text
            }
        }
        return text
    }

    private static func normalizedFloat(_ literal: String) -> String {
        let parts = literal.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[1].allSatisfy({ $0 == "0" }), !parts[0].isEmpty else { return literal }
        return String(parts[0])
    }
}
