/// Finds call arguments that pass the parameter's own default value, such as
/// `dismiss(animated: true, completion: nil)` or `VStack(alignment: .center)`.
///
/// Default values come from three places:
/// 1. every `func`, `init` and enum case declared in the checked files,
/// 2. memberwise initializers of structs that declare no `init`,
/// 3. a table of well-known Apple and library defaults (`KnownDefaults`).
///
/// A finding is only reported when every declaration that fits the call agrees that
/// the value is the default. The table is used only for calls that match no local
/// declaration. There is no type information, so functions that share a name and
/// argument labels are told apart by their parameter lists alone.
public struct RedundantDefaultArgumentRule: Rule {
    public static let identifier = "redundant-default-argument"
    public static let summary = "Arguments that repeat the parameter's default value and can be removed."

    private var declarations: [String: [Declaration]] = [:]

    public init() {}

    public mutating func collect(_ file: SourceFile) {
        let collector = DeclarationCollector()
        collector.walk(file.tree)
        for declaration in collector.declarations {
            var list = declarations[declaration.name, default: []]
            if !list.contains(declaration) { list.append(declaration) }
            declarations[declaration.name] = list
        }
    }

    public func check(_ file: SourceFile) -> [Finding] {
        let visitor = CallSiteVisitor(file: file, declarations: declarations, knownDefaults: KnownDefaults.table)
        visitor.walk(file.tree)
        return visitor.findings
    }
}
