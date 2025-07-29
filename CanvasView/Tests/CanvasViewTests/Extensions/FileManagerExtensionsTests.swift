//
//  FileManagerExtensionsTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/07/13.
//

import Foundation
import Testing

@testable import HandDrawingSwiftMetal

struct FileManagerExtensionsTests {

    @Test
    func testContainsAll_allFilesExist() {
        let fileNames = ["a.txt", "b.txt"]
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.txt")
        ]
        #expect(FileManager.containsAll(fileNames: fileNames, in: fileURLs) == true)
    }

    @Test
    func testContainsAll_noFilesExist() {
        let fileNames = ["x.txt", "y.txt"]
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.txt")
        ]
        #expect(FileManager.containsAll(fileNames: fileNames, in: fileURLs) == false)
    }


}
