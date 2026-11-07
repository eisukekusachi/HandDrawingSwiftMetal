//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation
import Testing
@testable import Core

struct URLExtensionsTests {

    @Test
    func `sanitizedName replaces invalid characters`() {
        let sanitized = URL.sanitizedName("File/\\:?%*|\"<>_Name")
        #expect(!sanitized.contains("/"))
        #expect(!sanitized.contains("\\"))
        #expect(!sanitized.contains(":"))
        #expect(!sanitized.contains("?"))
        #expect(!sanitized.contains("%"))
        #expect(!sanitized.contains("*"))
        #expect(!sanitized.contains("|"))
        #expect(!sanitized.contains("\""))
        #expect(!sanitized.contains("<"))
        #expect(!sanitized.contains(">"))
        #expect(sanitized.contains("File_Name"))
    }

    @Test
    func `fileName appends fileSuffix when non-empty`() {
        #expect(URL.fileName(name: "fileName", fileSuffix: "") == "fileName")
        #expect(URL.fileName(name: "fileName", fileSuffix: "zip") == "fileName.zip")
    }

    @Test
    func `fileName sanitizes fileSuffix`() {
        #expect(URL.fileName(name: "fileName", fileSuffix: ".zip") == "fileName.zip")
        #expect(URL.fileName(name: "fileName", fileSuffix: " .z.i.p ") == "fileName.zip")
        #expect(URL.fileName(name: "fileName", fileSuffix: "z/ip") == "fileName.zip")
        #expect(URL.fileName(name: "fileName", fileSuffix: "////") == "fileName")
    }

    @Suite
    struct UniqueFileURL {
        @Test
        func `uniqueFileURL appends numeric suffix when names exist`() throws {
            let fileManager = MockFileManager()
            let directory = fileManager.documentsDirectory
            fileManager.setFileExists(
                true,
                atPath: directory
                    .appendingPathComponent(URL.fileName(name: "fileName", fileSuffix: "zip")).path
            )
            fileManager.setFileExists(
                true,
                atPath: directory
                    .appendingPathComponent(URL.fileName(name: "fileName_2", fileSuffix: "zip")).path
            )

            let uniqueURL = try URL.uniqueFileURL(
                name: "fileName",
                in: directory,
                fileSuffix: "zip",
                fileExists: { fileManager.fileExists(atPath: $0.path) }
            )

            #expect(uniqueURL.deletingPathExtension().lastPathComponent == "fileName_3")
            #expect(uniqueURL.pathExtension == "zip")
        }

        @Test
        func `uniqueFileURL keeps excludeURL even when it already exists`() throws {
            let fileManager = MockFileManager()
            let directory = fileManager.documentsDirectory
            let excludeURL = directory.appendingPathComponent(
                URL.fileName(name: "fileName", fileSuffix: "zip")
            )
            fileManager.setFileExists(true, atPath: excludeURL.path)

            let uniqueURL = try URL.uniqueFileURL(
                name: "fileName",
                in: directory,
                fileSuffix: "zip",
                fileExists: { fileManager.fileExists(atPath: $0.path) },
                excludeURL: excludeURL
            )

            #expect(uniqueURL == excludeURL)
        }

        @Test
        func `uniqueFileURL treats excludeURL as same when only letter case differs`() throws {
            let fileManager = MockFileManager()
            let directory = fileManager.documentsDirectory
            let excludeURL = directory.appendingPathComponent(
                URL.fileName(name: "fileName", fileSuffix: "zip")
            )
            let differentlyCasedURL = directory.appendingPathComponent(
                URL.fileName(name: "FileName", fileSuffix: "zip")
            )
            fileManager.setFileExists(true, atPath: excludeURL.path)

            let uniqueURL = try URL.uniqueFileURL(
                name: "FileName",
                in: directory,
                fileSuffix: "zip",
                fileExists: { fileManager.fileExists(atPath: $0.path) },
                excludeURL: excludeURL
            )

            #expect(uniqueURL == differentlyCasedURL)
        }

        @Test(
            arguments: [
                "   ",
                "////",
                ""
            ]
        )
        func `uniqueFileURL throws on invalid name`(name: String) {
            let fileManager = MockFileManager()

            #expect(throws: Error.self) {
                _ = try URL.uniqueFileURL(
                    name: name,
                    in: fileManager.documentsDirectory,
                    fileSuffix: "zip",
                    fileExists: { fileManager.fileExists(atPath: $0.path) }
                )
            }
        }
    }
}
