//
//  FileViewTests
//
//  Created by Eisuke Kusachi on 2026/09/13.
//

import Foundation
import Testing
@testable import FileView

struct FileNamingTests {

    @Suite
    struct FileSuffix {
        @Test
        func `Verify that leading dots are stripped from fileSuffix`() {
            #expect(FileNaming(fileSuffix: ".zip").fileSuffix == "zip")
            #expect(FileNaming(fileSuffix: "..zip").fileSuffix == "zip")
        }
    }

    @Suite
    struct SupportedFileURL {
        @Test
        func `Verify that matching file URLs are supported`() {
            let naming = FileNaming(fileSuffix: "zip")

            #expect(naming.isSupportedFileURL(URL(fileURLWithPath: "/tmp/a.zip")))
            #expect(!naming.isSupportedFileURL(URL(fileURLWithPath: "/tmp/a.txt")))
        }
    }

    @Suite
    struct UniqueTitle {
        @Test
        func `Verify that uniqueTitle returns the base name when unused`() {
            let naming = FileNaming(fileSuffix: "zip")

            #expect(
                naming.uniqueTitle(from: "canvas", existingTitles: []) == "canvas"
            )
        }

        @Test
        func `Verify that uniqueTitle suffixes when a title collides`() {
            let naming = FileNaming(fileSuffix: "zip")

            #expect(
                naming.uniqueTitle(from: "canvas", existingTitles: ["canvas"]) == "canvas_2"
            )
        }

        @Test
        func `Verify that uniqueTitle keeps incrementing the suffix until unused`() {
            let naming = FileNaming(fileSuffix: "zip")

            #expect(
                naming.uniqueTitle(
                    from: "canvas",
                    existingTitles: ["canvas", "canvas_2"]
                ) == "canvas_3"
            )
        }
    }
}
