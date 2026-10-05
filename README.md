# n42-swift-checker

Checks Swift code for things SwiftLint cannot see. SwiftLint's custom rules are regular expressions over one file at a time. This tool parses the whole code base with [swift-syntax](https://github.com/swiftlang/swift-syntax), Apple's Swift parser, so a rule can use facts from other files, such as the default value a parameter was declared with.

It is independent of SwiftLint and needs no Xcode project. Output uses Xcode's `file:line:column: warning:` format, so findings show up in Xcode's issue navigator when the tool runs as a build phase.

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
num42/n42-swift-checker@0.1.0
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

Folders are searched for `.swift` files. Hidden folders, `build`, `DerivedData`, `Pods`, `Carthage`, `vendor` and generated protobuf files (`*.pb.swift`, `*.grpc.swift`) are skipped.

### Options

- `-e, --exclude <path>` — path to skip. Repeat the flag for several paths.
- `--rule <id>` — only run this rule. Repeat the flag for several rules.
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

## Xcode build phase

With XcodeGen, add a script phase to the target (or to a `LintedTarget` template):

```yaml
postCompileScripts:
  - name: n42-swift-checker
    script: |
      export PATH="bin:$PATH"
      bin/mint run --no-install n42-swift-checker Sources SyncedSources
    basedOnDependencyAnalysis: false
```

Xcode shows every finding as a warning at the right line.

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
