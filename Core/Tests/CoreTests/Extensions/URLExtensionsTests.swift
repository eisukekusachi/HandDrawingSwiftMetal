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
    func `projectName appends fileSuffix when non-empty`() {
        #expect(URL.projectName(name: "fileName", fileSuffix: "") == "fileName")
        #expect(URL.projectName(name: "fileName", fileSuffix: "zip") == "fileName.zip")
    }
}
