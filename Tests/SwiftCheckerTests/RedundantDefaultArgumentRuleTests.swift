import SwiftChecker
import Testing

@Suite struct RedundantDefaultArgumentRuleTests {
    private func findings(_ sources: [String: String]) -> [Finding] {
        var checker = Checker(rules: [RedundantDefaultArgumentRule.self])
        return checker.run(sources: sources)
    }

    private func findings(_ source: String) -> [Finding] {
        findings(["Test.swift": source])
    }

    @Test func functionDefaultsAreFound() {
        let result = findings("""
            func load(force: Bool = false, completion: (() -> Void)? = nil) {}
            load(force: false, completion: nil)
            load(force: true, completion: nil)
            load(force: true) { }
            """)
        #expect(result.map(\.line) == [2, 2, 3])
        #expect(result.map(\.column) == [6, 20, 19])
        #expect(result[0].message == "Argument 'force: false' equals the default value in 'load(force:completion:)'. Remove it.")
    }

    @Test func overloadWithoutDefaultBlocksTheFinding() {
        let result = findings("""
            func load(force: Bool = false) {}
            func load(force: Bool, extra: Int = 0) {}
            load(force: false)           // both overloads fit and disagree about `force`: not reported
            load(force: false, extra: 0) // only the second overload fits: `force` is required, `extra` is redundant
            """)
        #expect(result.map { "\($0.line):\($0.column)" } == ["4:20"])
    }

    @Test func protocolRequirementBlocksTheFinding() {
        let result = findings("""
            protocol P { func ping(verbose: Bool) }
            struct S: P { func ping(verbose: Bool = false) {} }
            S().ping(verbose: false)
            """)
        #expect(result.isEmpty)
    }

    @Test func initializersUseTheTypeName() {
        let result = findings("""
            final class Foo {
                init(name: String, items: [String: (Int, Int)] = [:], result: Result<Int, Error>? = nil) {}
            }
            extension Foo {
                convenience init(count: Int = 0) { self.init(name: "") }
            }
            _ = Foo(name: "n", items: [:], result: nil)
            _ = Foo(count: 0)
            _ = Foo.init(count: 0)
            _ = Foo(name: "n", items: ["a": (1, 2)])
            """)
        #expect(result.map(\.line) == [7, 7, 8, 9])
    }

    @Test func memberwiseInitializerOfStructs() {
        let result = findings("""
            import SwiftUI
            struct Card: View {
                var title: String
                var subtitle: String? = nil
                var detail: String?
                var count: Int = 0
                let fixed = 1
                @State var flag = false
                @State
                var other = false
                var computed: Int { 1 }
                var observed: Int = 5 { didSet {} }
                var onTap: (() -> Void)? = nil
                var body: some View { EmptyView() }
            }
            _ = Card(title: "x", subtitle: nil, detail: nil, count: 0, observed: 5, onTap: nil)
            _ = Card(title: "x", count: 1)
            """)
        // @State properties stop the memberwise analysis: nothing is reported for Card.
        #expect(result.isEmpty)

        let plain = findings("""
            struct Point {
                var x: Int = 0
                var y: Int?
                let label: String
            }
            _ = Point(x: 0, y: nil, label: "a")
            _ = Point(x: 1, label: "a")
            """)
        #expect(plain.map(\.column) == [11, 17])
    }

    @Test func structWithExplicitInitHasNoMemberwiseInit() {
        let result = findings("""
            struct Point {
                var x: Int = 0
                init(x: Int) { self.x = x }
            }
            _ = Point(x: 0)
            """)
        #expect(result.isEmpty)
    }

    @Test func enumCasesWithDefaults() {
        let result = findings("""
            enum Route { case detail(id: Int, animated: Bool = true) }
            let a = Route.detail(id: 1, animated: true)
            let b: Route = .detail(id: 1, animated: false)
            switch a {
            case .detail(id: 1, animated: true): break
            default: break
            }
            """)
        #expect(result.map(\.line) == [2])
    }

    @Test func unlabeledArgumentsMatchByPosition() {
        let result = findings("""
            func f(_ a: Int = 0, b: Int = 1, _ c: Int = 2) {}
            f(0)
            f(2)
            f(b: 1, 2)
            f(0, b: 0)
            """)
        #expect(result.map { "\($0.line):\($0.column)" } == ["2:3", "4:3", "4:9", "5:3"])
        #expect(result[0].message.contains("at position 1"))
    }

    @Test func variadicParameters() {
        let result = findings("""
            func log(_ items: Any..., separator: String = " ") {}
            log(1, 2, 3, separator: " ")
            log(1, separator: "-")
            """)
        #expect(result.map(\.line) == [2])
    }

    @Test func knownAppleDefaults() {
        let result = findings("""
            import UIKit
            func show(vc: UIViewController) {
                vc.dismiss(animated: true, completion: nil)
                vc.present(vc, animated: true, completion: { })
                print("x", terminator: "\\n")
                print("x", separator: " ", terminator: "")
                print("x", separator: "")
            }
            """)
        #expect(result.map { "\($0.line):\($0.column)" } == ["3:32", "5:16", "6:16"])
    }

    @Test func localDeclarationWithoutDefaultBlocksKnownDefault() {
        let result = findings("""
            func open(url: URL, options: [String: Any]) {}
            open(URL(string: "x")!, options: [:])
            """)
        #expect(result.isEmpty)
    }

    @Test func declarationsAreSharedBetweenFiles() {
        let result = findings([
            "A.swift": "struct Config { init(debug: Bool = false) {} }",
            "B.swift": "let c = Config(debug: false)",
        ])
        #expect(result.map(\.path) == ["B.swift"])
    }

    @Test func textInStringsAndCommentsIsIgnored() {
        let result = findings("""
            func show(x: Int, y: String = "nil") -> String { "" }
            // show(x: 1, y: "nil")
            let s = "show(x: 1, y: \\"nil\\") \\(show(x: 1, y: "nil"))"
            let t = show(x: 1, y: "nil")
            let u = show(x: 1, y: "nil ")
            """)
        #expect(result.map(\.line) == [3, 4])
    }

    @Test func numbersCompareWithoutTrailingZeros() {
        let result = findings("""
            func scale(by factor: Double = 1.0) {}
            scale(by: 1)
            scale(by: 1.00)
            scale(by: 1.5)
            """)
        #expect(result.map(\.line) == [2, 3])
    }
}
