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
    static var tmp: URL {
        URL(fileURLWithPath: NSHomeDirectory() + NSHomeDirectory() + "/Documents/tmp")
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
