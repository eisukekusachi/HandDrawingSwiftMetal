//
//  FileViewTests
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Foundation
import Testing
@testable import FileView

struct URLExtensionsTests {

    @Test
    func `fileURL appends projectName under the directory`() {
        let directory = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let fileURL = URL.fileURL(
            in: directory,
            name: "fileName",
            fileSuffix: "zip"
        )
        #expect(fileURL == URL(fileURLWithPath: "/tmp/fileName.zip"))
    }

    @Test
    func `trimmedName returns fallbackName when newName is blank`() {
        #expect(URL.trimmedName(fallbackName: "fileName", newName: "   ") == "fileName")
        #expect(URL.trimmedName(fallbackName: "fileName", newName: "") == "fileName")
    }

    @Test
    func `normalizedName sanitizes and falls back when empty`() {
        #expect(URL.normalizedName(fallbackName: "fileName", newName: "a/b") == "ab")
        #expect(URL.normalizedName(fallbackName: "fileName", newName: "   ") == "fileName")
    }
}
