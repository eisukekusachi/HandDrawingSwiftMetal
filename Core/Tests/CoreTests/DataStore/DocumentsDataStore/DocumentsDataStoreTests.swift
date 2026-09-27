//
//  Created by Eisuke Kusachi on 2026/09/27.
//

import Foundation
import Testing
@testable import Core

@MainActor
struct DocumentsDataStoreTests {

    private typealias Subject = DocumentsDataStore

    @Test
    func `init uses TmpFolder when localFileRepository is nil`() {
        let fileManager = MockFileManager()
        let subject = Subject(
            fileManager: fileManager,
            localFileRepository: nil
        )

        #expect(
            subject.localFileRepository.workingDirectoryURL ==
            fileManager.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    }

    @MainActor
    struct ZipFileURL {
        @Test
        func `zipFileURL appends suffix when non-empty`() {
            let fileManager = MockFileManager()
            let subject = Subject(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )

            let url = subject.zipFileURL(projectName: "MyProject", suffix: "zip")

            #expect(url == fileManager.documentsDirectory.appendingPathComponent("MyProject.zip"))
        }

        @Test
        func `zipFileURL omits suffix when empty`() {
            let fileManager = MockFileManager()
            let subject = Subject(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )

            let url = subject.zipFileURL(projectName: "MyProject", suffix: "")

            #expect(url == fileManager.documentsDirectory.appendingPathComponent("MyProject"))
            #expect(url.pathExtension.isEmpty)
        }
    }

    @MainActor
    struct UniqueZipFileURL {
        @Test
        func `uniqueZipFileURL appends numeric suffix when names exist`() throws {
            let fileManager = MockFileManager()
            let subject = Subject(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )
            fileManager.setFileExists(
                true,
                atPath: subject.zipFileURL(projectName: "fileName", suffix: "zip").path
            )
            fileManager.setFileExists(
                true,
                atPath: subject.zipFileURL(projectName: "fileName_2", suffix: "zip").path
            )

            let uniqueURL = try subject.uniqueZipFileURL(
                fileName: "fileName",
                suffix: "zip"
            )

            #expect(uniqueURL.deletingPathExtension().lastPathComponent == "fileName_3")
            #expect(uniqueURL.pathExtension == "zip")
        }

        @Test
        func `uniqueZipFileURL keeps excludeURL even when it already exists`() throws {
            let fileManager = MockFileManager()
            let subject = Subject(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )
            let excludeURL = subject.zipFileURL(projectName: "fileName", suffix: "zip")
            fileManager.setFileExists(true, atPath: excludeURL.path)

            let uniqueURL = try subject.uniqueZipFileURL(
                fileName: "fileName",
                suffix: "zip",
                excludeURL: excludeURL
            )

            #expect(uniqueURL == excludeURL)
        }

        @Test
        func `uniqueZipFileURL treats excludeURL as same when only letter case differs`() throws {
            let fileManager = MockFileManager()
            let subject = Subject(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )
            let excludeURL = subject.zipFileURL(projectName: "fileName", suffix: "zip")
            let differentlyCasedURL = subject.zipFileURL(projectName: "FileName", suffix: "zip")
            fileManager.setFileExists(true, atPath: excludeURL.path)

            let uniqueURL = try subject.uniqueZipFileURL(
                fileName: "FileName",
                suffix: "zip",
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
        func `uniqueZipFileURL throws on invalid fileName`(name: String) {
            let fileManager = MockFileManager()
            let subject = Subject(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )

            #expect(throws: Error.self) {
                _ = try subject.uniqueZipFileURL(
                    fileName: name,
                    suffix: "zip"
                )
            }
        }
    }
}
