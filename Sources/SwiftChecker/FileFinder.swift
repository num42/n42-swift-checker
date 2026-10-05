import Foundation

/// Lists the Swift files under the given paths.
public enum FileFinder {
    /// Folder names that never hold app code. Hidden folders (`.build`, `.git`, `.claude`, ...) are skipped too.
    public static let defaultExcludedDirectories: Set<String> = [
        "build", "Carthage", "DerivedData", "Pods", "vendor",
    ]

    /// File name endings of generated code that is not worth checking.
    public static let defaultExcludedSuffixes: [String] = [".pb.swift", ".grpc.swift"]

    public static func swiftFiles(
        under paths: [String],
        excluding excluded: [String] = [],
        fileManager: FileManager = .default
    ) -> [String] {
        var result: [String] = []
        let excludedPaths = excluded.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 }

        func isExcluded(_ path: String) -> Bool {
            excludedPaths.contains { path == $0 || path.hasPrefix($0 + "/") }
        }

        for path in paths {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else { continue }

            if !isDirectory.boolValue {
                if path.hasSuffix(".swift"), !isExcluded(path) { result.append(path) }
                continue
            }

            let root = URL(fileURLWithPath: path)
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let relative = relativePath(of: url, under: root, prefix: path)
                if isDir {
                    let name = url.lastPathComponent
                    if name.hasPrefix(".") || defaultExcludedDirectories.contains(name) || isExcluded(relative) {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                guard url.pathExtension == "swift" else { continue }
                guard !defaultExcludedSuffixes.contains(where: { url.lastPathComponent.hasSuffix($0) }) else { continue }
                guard !isExcluded(relative) else { continue }
                result.append(relative)
            }
        }
        return result.sorted()
    }

    /// Keeps the path the user typed as the prefix, so output matches their working directory.
    private static func relativePath(of url: URL, under root: URL, prefix: String) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath + "/") else { return filePath }
        let tail = filePath.dropFirst(rootPath.count + 1)
        return prefix == "." ? String(tail) : prefix.hasSuffix("/") ? prefix + tail : prefix + "/" + tail
    }
}
