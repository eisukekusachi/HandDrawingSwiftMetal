//
//  URLExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

extension URL {

    static var documents: URL {
        URL(fileURLWithPath: NSHomeDirectory() + "/Documents")
    }

    static var applicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    /// A temporary folder URL used for file input and output
    static let tmpFolderURL = URL.applicationSupport.appendingPathComponent("TmpFolder")

    static func zipFileURL(projectName: String) -> URL {
        URL.documents.appendingPathComponent(projectName + "." + URL.zipSuffix)
    }

    static var zipSuffix: String {
        "zip"
    }
    static var thumbnailPath: String {
        "thumbnail.png"
    }
    static var jsonFileName: String {
        "data"
    }

    var fileName: String {
        self.lastPathComponent.components(separatedBy: ".").first ?? self.lastPathComponent
    }

    static var workInProgress: URL {
        URL(fileURLWithPath: NSHomeDirectory() + NSHomeDirectory() + "/Documents/workinprogress")
    }

    func allFileURLs(suffix: String = "") -> [URL] {
        if FileManager.default.fileExists(atPath: self.path) {
            do {
                let urls = try FileManager.default.contentsOfDirectory(at: self,
                                                                       includingPropertiesForKeys: nil)
                return urls.filter {
                    suffix.count == 0 || $0.lastPathComponent.hasSuffix(suffix)
                }

            } catch {
                print(error)
            }
        }
        return []
    }

}
