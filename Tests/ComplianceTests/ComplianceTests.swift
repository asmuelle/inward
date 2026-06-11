import DesignSystem
import Foundation
import SafetyKit
import Testing

/// Invariant #1 as CI: the regulated vocabulary never appears in user-facing
/// copy, and never sneaks into production sources either. The single allowed
/// home of the lexicon is SafetyKit/BannedTerms.swift, which carries the
/// `compliance-lexicon-definition` marker and is exempted below.
@Suite("Compliance — banned-terms enforcement")
struct ComplianceTests {
    @Test("all user-facing copy is free of the regulated vocabulary")
    func copyIsClean() {
        for string in Copy.allStrings {
            let violations = BannedTerms.violations(in: string)
            #expect(violations.isEmpty, "banned term \(violations.map(\.term)) in copy: \"\(string)\"")
        }
    }

    @Test("static support resources are free of the regulated vocabulary")
    func supportResourcesAreClean() {
        for resource in SupportResource.bundled {
            for text in [resource.name, resource.detail] {
                let violations = BannedTerms.violations(in: text)
                #expect(violations.isEmpty, "banned term \(violations.map(\.term)) in resource: \"\(text)\"")
            }
        }
    }

    @Test("no production source file contains a banned term")
    func productionSourcesAreClean() throws {
        // Arrange
        let roots = sourceRoots()
        #expect(!roots.isEmpty, "could not locate source roots from #filePath")

        var scannedFiles = 0
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                guard !isExemptLexiconFile(fileURL) else { continue }

                // Act
                let contents = try String(contentsOf: fileURL, encoding: .utf8)
                let violations = BannedTerms.violations(in: contents)

                // Assert
                #expect(
                    violations.isEmpty,
                    "banned term \(violations.map(\.term)) in \(fileURL.lastPathComponent)"
                )
                scannedFiles += 1
            }
        }
        #expect(scannedFiles > 10, "scan looks broken — only \(scannedFiles) files found")
    }

    /// Production source roots, located relative to this test file.
    private func sourceRoots() -> [URL] {
        let repoRoot = URL(fileURLWithPath: #filePath) // .../Tests/ComplianceTests/ComplianceTests.swift
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return ["Sources", "App"].compactMap { name in
            let url = repoRoot.appendingPathComponent(name, isDirectory: true)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }

    private func isExemptLexiconFile(_ url: URL) -> Bool {
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return contents.contains("compliance-lexicon-definition")
    }
}
