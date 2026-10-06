# n42-swift-checker

Checks Swift code for things SwiftLint cannot see. SwiftLint's custom rules are regular expressions over one file at a time. This tool parses the whole code base with [swift-syntax](https://github.com/swiftlang/swift-syntax), Apple's Swift parser, so a rule can use facts from other files, such as the default value a parameter was declared with.

It is independent of SwiftLint. It runs as a command line tool or as an Xcode build tool plugin. Output uses Xcode's `file:line:column: warning:` format, so findings show up in Xcode's issue navigator.

## Rules

### `redundant-default-argument`

Finds call arguments that pass the parameter's own default value. The argument can be removed.

```swift
viewController.dismiss(animated: true, completion: nil)   // completion: nil is the default
VStack(alignment: .center, spacing: 8) { ... }             // alignment: .center is the default
RoundedTextButton(title: "Save", height: 75)               // height defaults to 75 in its init
```

Default values come from three places:

1. every `func`, `init` and enum case declared in the checked files,
2. the memberwise initializer of structs that declare no `init` (`var x: Int = 0` and `var y: Int?` both have a default),
3. a table of well-known Apple and library defaults in `KnownDefaults.swift` (SwiftUI, UIKit, Foundation, Combine, RxSwift, XCTest, Swift Testing, SnapshotTesting).

Arguments are matched to parameters with Swift's rules: order is kept, parameters with defaults may be skipped, unlabeled parameters match by position, variadics take any number of arguments. A finding is only reported when **every** declaration that fits the call agrees that the value is the default. The table is only used for calls that fit no local declaration. Patterns such as `case .detail(animated: true)` are not calls and are skipped.

There is no type information, so two functions that share a name and a parameter list cannot be told apart. In practice this is rare, because the labels and the exact default value have to match as well.

## Installation

### Mint

```
mint install num42/n42-swift-checker
```

Or add it to your `Mintfile`:

```
num42/n42-swift-checker@0.2.1
```

### Build from source

```
swift build -c release
```

The binary is then at `.build/release/n42-swift-checker`.

## Usage

```bash
# Check the current folder
n42-swift-checker

# Check some folders, skip one path
n42-swift-checker Sources SyncedSources --exclude Sources/Assets/Base/Generated

# Only one rule
n42-swift-checker --rule redundant-default-argument

# Fail the build or the CI job when there are findings
n42-swift-checker --strict

# Machine readable
n42-swift-checker --json

# Which rules exist?
n42-swift-checker --list-rules
```

Folders are searched for `.swift` files. Hidden folders, `build`, `DerivedData`, `Generated`, `Pods`, `Carthage`, `vendor` and generated protobuf files (`*.pb.swift`, `*.grpc.swift`) are skipped.

### Options

- `-e, --exclude <path>` — path to skip. Repeat the flag for several paths.
- `--rule <id>` — only run this rule. Repeat the flag for several rules.
- `--declarations-from <path>` — folder whose declarations are read but whose files are not checked. Repeat the flag for several folders.
- `--strict` — print findings as errors and exit with status 1 when there are any.
- `--json` — print findings as JSON.
- `--list-rules` — list the available rules.

### Exit codes

- `0` — no findings, or findings printed as warnings
- `1` — findings and `--strict` was given

### Example output

```
iOS/Sources/AppModule/Base/Views/Detail/DetailView.swift:42:17: warning: Argument 'alignment: .center' equals the default value in 'VStack'. Remove it. [redundant-default-argument]
iOS/Sources/UIKitBase/Base/Coordinator.swift:88:52: warning: Argument 'completion: nil' equals the default value in 'dismiss'. Remove it. [redundant-default-argument]
Checked 771 file(s), found 2 issue(s).
```

The summary line goes to stderr, the findings to stdout.

## Xcode build tool plugin

The package ships a SwiftPM build tool plugin, `N42SwiftCheckerBuildToolPlugin`. It runs the checker on a target whenever one of the target's Swift files changed, and Xcode shows every finding as a warning at the right line. The whole project folder is passed as context, so default values declared in other modules are known too.

### XcodeGen

Add the package and use the plugin in a target template, next to SwiftLint's plugin:

```yaml
packages:
  n42-swift-checker:
    url: https://github.com/num42/n42-swift-checker
    from: 0.2.1

targetTemplates:
  LintedTarget:
    buildToolPlugins:
      - package: SwiftLintPlugins
        plugin: SwiftLintBuildToolPlugin
      - package: n42-swift-checker
        plugin: N42SwiftCheckerBuildToolPlugin
```

### Xcode project

Add the package under *Package Dependencies*, then in the target's *Build Phases* open *Run Build Tool Plug-ins* and add `N42SwiftCheckerBuildToolPlugin`. Xcode asks once to trust the plugin.

### Swift package

```swift
dependencies: [
    .package(url: "https://github.com/num42/n42-swift-checker", from: "0.2.1"),
],
targets: [
    .target(
        name: "MyModule",
        plugins: [.plugin(name: "N42SwiftCheckerBuildToolPlugin", package: "n42-swift-checker")]
    ),
]
```

### Notes

- The plugin builds the checker from source the first time. swift-syntax takes a few minutes once; later builds reuse it. App repos that already use swift-syntax for macros share the checkout.
- Only the target's files are checked, so one finding is never reported twice.
- Generated files are skipped: files in a `Generated` folder, files whose name starts with `Generated`, and `*.pb.swift` / `*.grpc.swift`. Script phases often write such files during the build. Xcode runs plugin commands before script phases, so listing them as inputs would cause a dependency cycle.
- The command runs when one of the target's Swift files changed, like any build step with inputs and outputs. A clean build checks everything. Its output is a comment-only Swift file in the plugin's work folder, because SwiftPM would copy a file of any other type into the product as a resource.
- `--strict` is not used by the plugin. To fail CI, run the command line tool with `--strict` in a CI step instead.

## Checking one module with the context of the whole project

The plugin uses `--declarations-from`. You can do the same on the command line:

```bash
n42-swift-checker iOS/Sources/AppModule --declarations-from iOS
```

Files under `--declarations-from` are parsed for declarations only. Findings are reported for the checked paths only.

## CI

```bash
mint run n42-swift-checker iOS/Sources iOS/SyncedSources > PersistedLogs/warnings/swift-checker.log
```

Store the log the same way as the SwiftLint and Periphery logs, and the dashboard can count its lines.

## Adding a known default

When a redundant argument of an Apple or library API slips through, add the function or type name, the argument label and the default value to `KnownDefaults.swift`, written as in the API docs:

```swift
"sheet": ["onDismiss": "nil"],
```

## Adding a rule

A rule is a type that conforms to `Rule` in `Sources/SwiftChecker/Rules`. It gets every file in `collect` first, so it can learn facts from the whole code base, and then reports findings per file in `check`. Register it in `Rules.all`.

## Development

```bash
swift build
swift test
```

Dependencies: [swift-syntax](https://github.com/swiftlang/swift-syntax) and [swift-argument-parser](https://github.com/apple/swift-argument-parser), both Apache-2.0.
