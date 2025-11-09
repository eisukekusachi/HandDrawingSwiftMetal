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
    func `returns true if all file names are present`(fileNames: [String]) {
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.txt")
        ]
        #expect(FileManager.containsAllFileNames(fileNames: fileNames, in: fileURLs) == true)
    }

    @Test(
        arguments: [
            [""],
            ["x.txt", "y.txt"],
            ["a.txt", "b.txt", "c.txt", "d.txt"]
        ]
    )
    func `returns false if any file name does not exist`(fileNames: [String]) {
        let fileURLs = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.txt")
        ]
        #expect(FileManager.containsAllFileNames(fileNames: fileNames, in: fileURLs) == false)
    }
}
