import Foundation
import SwiftSyntax

/// Finds call arguments that repeat the default value of the parameter.
final class CallSiteVisitor: SyntaxVisitor {
    private let file: SourceFile
    private let declarations: [String: [Declaration]]
    private let knownDefaults: [String: [String: String]]
    private(set) var findings: [Finding] = []

    init(file: SourceFile, declarations: [String: [Declaration]], knownDefaults: [String: [String: String]]) {
        self.file = file
        self.declarations = declarations
        self.knownDefaults = knownDefaults
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard !node.arguments.isEmpty, !isPattern(node), let name = calleeName(node.calledExpression) else {
            return .visitChildren
        }

        let arguments = node.arguments.map { argument in
            CallArgument(label: argument.label?.text, value: ExpressionText.normalized(argument.expression), node: argument)
        }
        let candidates = declarations[name] ?? []
        let matches = candidates.compactMap { declaration in
            declaration.match(arguments).map { (declaration: declaration, mapping: $0) }
        }

        for (index, argument) in arguments.enumerated() {
            if matches.isEmpty {
                guard let label = argument.label,
                      let known = knownDefaults[name]?[label],
                      known == argument.value,
                      !candidates.contains(where: { $0.parameters.contains { $0.label == label && $0.defaultValue == nil } })
                else { continue }
                report(argument, callee: name)
            } else {
                // Every declaration that fits the call must agree that the value is the default.
                let agree = matches.allSatisfy { match in
                    match.declaration.parameters[match.mapping[index]].defaultValue == argument.value
                }
                guard agree else { continue }
                let signatures = Set(matches.map(\.declaration.signature)).sorted()
                report(argument, callee: signatures.count == 1 ? signatures[0] : name, position: index + 1)
            }
        }
        return .visitChildren
    }

    // MARK: - Helpers

    private func report(_ argument: CallArgument, callee: String, position: Int? = nil) {
        let location = file.location(of: argument.node)
        let shown = argument.node.with(\.trailingComma, nil).trimmedDescription
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
        let what = argument.label != nil ? "'\(shown)'" : "'\(shown)' at position \(position ?? 0)"
        findings.append(Finding(
            rule: RedundantDefaultArgumentRule.identifier,
            path: file.path,
            line: location.line,
            column: location.column,
            message: "Argument \(what) equals the default value in '\(callee)'. Remove it."
        ))
    }

    /// The name a call is looked up by: the function name, the type name for `Type(...)`
    /// and `Type.init(...)`, or the member name for `.member(...)` and `base.member(...)`.
    private func calleeName(_ expression: ExprSyntax) -> String? {
        if let reference = expression.as(DeclReferenceExprSyntax.self) {
            return reference.baseName.text
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            let name = member.declName.baseName.text
            guard name == "init" else { return name }
            return member.base.flatMap { calleeName($0) }
        }
        if let generic = expression.as(GenericSpecializationExprSyntax.self) {
            return calleeName(generic.expression)
        }
        return nil
    }

    /// `case .foo(bar: nil)` is parsed as a call, but it is a pattern, not a call.
    private func isPattern(_ node: FunctionCallExprSyntax) -> Bool {
        var current: Syntax? = Syntax(node).parent
        while let node = current {
            if node.is(ExpressionPatternSyntax.self) { return true }
            if node.is(CodeBlockItemSyntax.self) || node.is(ClosureExprSyntax.self) || node.is(MemberBlockItemSyntax.self) {
                return false
            }
            current = node.parent
        }
        return false
    }
}
