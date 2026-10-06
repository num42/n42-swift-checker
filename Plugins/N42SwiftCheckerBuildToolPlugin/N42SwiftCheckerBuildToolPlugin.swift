import Foundation
import PackagePlugin

/// Runs n42-swift-checker on every build of a target. Findings show up as warnings in Xcode.
///
/// The target's Swift files are checked. The whole package or project folder is passed as
/// context, so default values declared in other modules are known too.
@main
struct N42SwiftCheckerBuildToolPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let module = target.sourceModule else { return [] }
        return try commands(
            tool: context.tool(named: "n42-swift-checker").url,
            targetName: target.name,
            files: module.sourceFiles(withSuffix: "swift").map(\.url),
            root: context.package.directoryURL,
            workDirectory: context.pluginWorkDirectoryURL
        )
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension N42SwiftCheckerBuildToolPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        try commands(
            tool: context.tool(named: "n42-swift-checker").url,
            targetName: target.displayName,
            files: target.inputFiles.filter { $0.type == .source && $0.url.pathExtension == "swift" }.map(\.url),
            root: context.xcodeProject.directoryURL,
            workDirectory: context.pluginWorkDirectoryURL
        )
    }
}
#endif

extension N42SwiftCheckerBuildToolPlugin {
    /// One build command per target. The marker file is its only output, so the command runs
    /// when one of the target's Swift files changed. Xcode would otherwise warn on every build
    /// that the command has no outputs. The marker is a comment-only Swift file: SwiftPM adds
    /// a command's outputs to the target, and a file of any other type would become a resource.
    func commands(tool: URL, targetName: String, files allFiles: [URL], root: URL, workDirectory: URL) -> [Command] {
        let files = allFiles.filter { !isGenerated($0) }
        guard !files.isEmpty else { return [] }
        let marker = workDirectory.appending(path: "N42SwiftCheckerRan.swift")
        return [
            .buildCommand(
                displayName: "n42-swift-checker: \(targetName)",
                executable: tool,
                arguments: files.map(\.path) + ["--declarations-from", root.path, "--marker", marker.path],
                inputFiles: files,
                outputFiles: [marker]
            ),
        ]
    }

    /// Generated code is skipped. Script phases often write it during the build, and Xcode runs
    /// plugin commands before script phases. Listing such a file as an input would make the plugin
    /// wait for the script and the script wait for the plugin: a dependency cycle.
    func isGenerated(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return url.pathComponents.contains { $0.caseInsensitiveCompare("Generated") == .orderedSame }
            || name.hasPrefix("Generated")
            || name.hasSuffix(".pb.swift")
            || name.hasSuffix(".grpc.swift")
    }
}
