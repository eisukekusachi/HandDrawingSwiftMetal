//
//  FileManagerExtensionsTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2025/07/13.
//

import Foundation
import Testing

@testable import CanvasView

struct FileManagerExtensionsTests {

    @Test(
        arguments: [
            ["a.txt"],
            ["a.txt", "b.txt"],
            ["a.txt", "b.txt", "c.txt"]
        ]
    )
    func testContainsAll_allFilesExist(fileNames: [String]) {
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
