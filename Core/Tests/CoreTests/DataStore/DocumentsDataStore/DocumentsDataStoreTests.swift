//
//  Created by Eisuke Kusachi on 2026/09/27.
//

import Foundation
import Testing
@testable import Core

@MainActor
struct DocumentsDataStoreTests {

    @Test
    func `init uses TmpFolder when localFileRepository is nil`() {
        let fileManager = MockFileManager()
        let dataStore = DocumentsDataStore(
            fileManager: fileManager,
            localFileRepository: nil
        )

        #expect(
            dataStore.localFileRepository.workingDirectoryURL ==
            fileManager.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    }

    @MainActor
    struct ZipFileURL {
        @Test
        func `zipFileURL appends suffix when non-empty`() {
            let fileManager = MockFileManager()
            let dataStore = DocumentsDataStore(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )

            let url = dataStore.zipFileURL(projectName: "MyProject", suffix: "zip")

            #expect(url == fileManager.documentsDirectory.appendingPathComponent("MyProject.zip"))
        }

        @Test
        func `zipFileURL omits suffix when empty`() {
            let fileManager = MockFileManager()
            let dataStore = DocumentsDataStore(
                fileManager: fileManager,
                localFileRepository: MockLocalFileRepository()
            )

            let url = dataStore.zipFileURL(projectName: "MyProject", suffix: "")

            #expect(url == fileManager.documentsDirectory.appendingPathComponent("MyProject"))
            #expect(url.pathExtension.isEmpty)
        }
    }
}
