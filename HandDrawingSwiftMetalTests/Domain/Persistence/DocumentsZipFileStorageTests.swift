//
//  Created by Eisuke Kusachi
//

import Core
import Foundation
import Testing
@testable import HandDrawingSwiftMetal

@MainActor
struct DocumentsZipFileStorageTests {

    private typealias Subject = DocumentsZipFileStorage

    @Test
    func `init uses TmpFolder under the temporary directory`() {
        let fileManager = MockFileManager()
        let subject = Subject(fileManager: fileManager)

        #expect(
            subject.stagingRootURL ==
            fileManager.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    }

    @Test
    func `init uses custom zip sessions directory name under the temporary directory`() {
        let fileManager = MockFileManager()
        let subject = Subject(fileManager: fileManager, stagingRootName: "CustomTmp")

        #expect(
            subject.stagingRootURL ==
            fileManager.temporaryDirectory.appendingPathComponent("CustomTmp")
        )
    }

    @Test
    func `init sanitizes stagingRootName`() {
        let fileManager = MockFileManager()
        let subject = Subject(fileManager: fileManager, stagingRootName: "  foo/bar  ")

        #expect(
            subject.stagingRootURL ==
            fileManager.temporaryDirectory.appendingPathComponent("foobar")
        )
    }

    @Test
    func `init falls back to TmpFolder when stagingRootName is empty after sanitization`() {
        let fileManager = MockFileManager()
        let subject = Subject(fileManager: fileManager, stagingRootName: "////")

        #expect(
            subject.stagingRootURL ==
            fileManager.temporaryDirectory.appendingPathComponent("TmpFolder")
        )
    }
}
