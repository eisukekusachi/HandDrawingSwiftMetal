//
//  URLExtensionsTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2026/04/25.
//

import Testing
import UIKit

@testable import HandDrawingSwiftMetal

@MainActor
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

    @Suite
    struct UniqueProjectURLInDocuments {
        @Test
        func `uniqueProjectURLInDocuments appends suffix using injected exists`() throws {
            
            let fileName = "fileName"
            let fileSuffix = "zip"
            
            let url1 = FileManager.zipFileURL(projectName: fileName, suffix: fileSuffix)
            let url2 = FileManager.zipFileURL(projectName: "\(fileName)_2", suffix: fileSuffix)
            
            let uniqueURL = try URL.uniqueProjectURLInDocuments(
                fileName: fileName,
                fileSuffix: fileSuffix,
                exists: { url in
                    url == url1 || url == url2
                }
            )
            
            #expect(uniqueURL.deletingPathExtension().lastPathComponent == "\(fileName)_3")
            #expect(uniqueURL.pathExtension == fileSuffix)
        }
        
        @Test(
            arguments: [
                "   ",
                "////",
                ""
            ]
        )
        func `uniqueProjectURLInDocuments throws on invalid fileName`(name: String) {
            #expect(throws: Error.self) {
                _ = try URL.uniqueProjectURLInDocuments(
                    fileName: name,
                    fileSuffix: "zip",
                    exists: { _ in false }
                )
            }
        }
    }
}
