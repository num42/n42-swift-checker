import SwiftSyntax

/// Reads every callable declaration of a file and its default values.
final class DeclarationCollector: SyntaxVisitor {
    private(set) var declarations: [Declaration] = []

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if let first = name.unicodeScalars.first, first == "_" || first.properties.isAlphabetic {
            declarations.append(Declaration(name: name, parameters: parameters(of: node.signature.parameterClause)))
        }
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        if let typeName = enclosingTypeName(of: node) {
            declarations.append(Declaration(name: typeName, parameters: parameters(of: node.signature.parameterClause)))
        }
        return .visitChildren
    }

    override func visit(_ node: EnumCaseDeclSyntax) -> SyntaxVisitorContinueKind {
        for element in node.elements {
            guard let clause = element.parameterClause else { continue }
            let parameters = clause.parameters.map { parameter in
                Parameter(
                    label: parameter.firstName.flatMap { $0.text == "_" ? nil : $0.text },
                    defaultValue: parameter.defaultValue.map { ExpressionText.normalized($0.value) }
                )
            }
            declarations.append(Declaration(name: element.name.text, parameters: parameters))
        }
        return .skipChildren
    }

    /// A struct without its own `init` gets a memberwise initializer.
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let members = node.memberBlock.members.map(\.decl)
        guard !members.contains(where: { $0.is(InitializerDeclSyntax.self) }) else { return .visitChildren }

        var parameters: [Parameter] = []
        for member in members {
            guard let variable = member.as(VariableDeclSyntax.self) else { continue }
            guard let memberParameters = memberwiseParameters(of: variable) else { return .visitChildren }
            parameters += memberParameters
        }
        declarations.append(Declaration(name: node.name.text, parameters: parameters))
        return .visitChildren
    }

    // MARK: - Helpers

    private func parameters(of clause: FunctionParameterClauseSyntax) -> [Parameter] {
        clause.parameters.map { parameter in
            Parameter(
                label: parameter.firstName.text == "_" ? nil : parameter.firstName.text,
                defaultValue: parameter.defaultValue.map { ExpressionText.normalized($0.value) },
                isVariadic: parameter.ellipsis != nil
            )
        }
    }

    private func enclosingTypeName(of node: some SyntaxProtocol) -> String? {
        var current: Syntax? = Syntax(node).parent
        while let node = current {
            if let decl = node.as(StructDeclSyntax.self) { return decl.name.text }
            if let decl = node.as(ClassDeclSyntax.self) { return decl.name.text }
            if let decl = node.as(EnumDeclSyntax.self) { return decl.name.text }
            if let decl = node.as(ActorDeclSyntax.self) { return decl.name.text }
            if let decl = node.as(ProtocolDeclSyntax.self) { return decl.name.text }
            if let decl = node.as(ExtensionDeclSyntax.self) { return typeName(of: decl.extendedType) }
            current = node.parent
        }
        return nil
    }

    private func typeName(of type: TypeSyntax) -> String? {
        if let identifier = type.as(IdentifierTypeSyntax.self) { return identifier.name.text }
        if let member = type.as(MemberTypeSyntax.self) { return member.name.text }
        return nil
    }

    /// Parameters a stored property adds to the memberwise initializer. Returns nil when the
    /// property is too unusual to be sure (attributes such as property wrappers, `lazy`, `static`).
    private func memberwiseParameters(of variable: VariableDeclSyntax) -> [Parameter]? {
        let modifiers = variable.modifiers.map(\.name.text)
        if modifiers.contains("static") || modifiers.contains("class") { return [] }
        guard variable.attributes.isEmpty, !modifiers.contains("lazy") else { return nil }

        var parameters: [Parameter] = []
        for binding in variable.bindings {
            guard let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text else { return nil }
            if isComputed(binding.accessorBlock) { continue }

            let isLet = variable.bindingSpecifier.tokenKind == .keyword(.let)
            if let initializer = binding.initializer {
                if isLet { continue } // a constant with a value is not a parameter
                parameters.append(Parameter(label: name, defaultValue: ExpressionText.normalized(initializer.value)))
            } else if !isLet, let type = binding.typeAnnotation?.type, isOptional(type) {
                parameters.append(Parameter(label: name, defaultValue: "nil"))
            } else {
                parameters.append(Parameter(label: name, defaultValue: nil))
            }
        }
        return parameters
    }

    private func isComputed(_ accessorBlock: AccessorBlockSyntax?) -> Bool {
        guard let accessorBlock else { return false }
        switch accessorBlock.accessors {
        case .getter:
            return true
        case .accessors(let accessors):
            let observers: Set<String> = ["willSet", "didSet"]
            return accessors.contains { !observers.contains($0.accessorSpecifier.text) }
        }
    }

    private func isOptional(_ type: TypeSyntax) -> Bool {
        type.is(OptionalTypeSyntax.self) || type.is(ImplicitlyUnwrappedOptionalTypeSyntax.self)
            || type.as(IdentifierTypeSyntax.self)?.name.text == "Optional"
    }
}
