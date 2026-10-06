import Foundation
import SwiftChecker
import Testing

@Suite struct FileFinderTests {
    @Test func skipsBuildFoldersAndGeneratedFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for path in ["Sources/A.swift", "Sources/Model.pb.swift", ".build/B.swift", "Pods/C.swift", "Skip/D.swift", ".claude/E.swift", "Android/build/F.swift", "Sources/Generated/G.swift", "Sources/Readme.md"] {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: url)
        }

        let files = FileFinder.swiftFiles(under: [root.path], excluding: [root.path + "/Skip"])
        #expect(files == [root.path + "/Sources/A.swift"])
    }
}
