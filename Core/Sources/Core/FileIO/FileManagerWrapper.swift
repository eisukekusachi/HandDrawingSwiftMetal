//
//  Created by Eisuke Kusachi
//

import Foundation
import ZIPFoundation

public protocol FileManaging: Sendable {
    var temporaryDirectory: URL { get }
    var documentsDirectory: URL { get }

    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?) throws -> [URL]
    func moveItem(at sourceURL: URL, to destinationURL: URL) throws
    func copyItem(at sourceURL: URL, to destinationURL: URL) throws
    func removeItem(at url: URL) throws
    func contents(atPath path: String) -> Data?
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
    func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool
    @discardableResult
    func replaceItemAt(
        _ originalItemURL: URL,
        withItemAt newItemURL: URL,
        backupItemName: String?,
        options: FileManager.ItemReplacementOptions
    ) throws -> URL?
    func unzipItem(at sourceURL: URL, to destinationURL: URL) throws
}

public extension FileManaging {
    /// Writes `src` to `dst`, creating `dst` when missing or replacing it atomically when present.
    ///
    /// Uses ``replaceItemAt(_:withItemAt:backupItemName:options:)`` when `dst` already exists so a failed
    /// replace leaves the previous file at `dst` intact.
    func overwriteItem(src: URL, dst: URL) throws {
        if fileExists(atPath: dst.path) {
            try replaceItemAt(
                dst,
                withItemAt: src,
                backupItemName: nil,
                options: []
            )
        } else {
            try createDirectory(
                at: dst.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try moveItem(at: src, to: dst)
        }
    }
}

/// Thin wrapper around `FileManager.default`.
public struct FileManagerWrapper: FileManaging {
    public init() {}

    public var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    public var documentsDirectory: URL {
        guard
            let url = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first
        else {
            fatalError("Failed to resolve Documents directory URL")
        }
        return url
    }

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates
        )
    }

    public func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys
        )
    }

    public func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    public func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func contents(atPath path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    public func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        try FileManager.default.attributesOfItem(atPath: path)
    }

    public func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool {
        FileManager.default.createFile(atPath: path, contents: data, attributes: attr)
    }

    public func replaceItemAt(
        _ originalItemURL: URL,
        withItemAt newItemURL: URL,
        backupItemName: String?,
        options: FileManager.ItemReplacementOptions
    ) throws -> URL? {
        try FileManager.default.replaceItemAt(
            originalItemURL,
            withItemAt: newItemURL,
            backupItemName: backupItemName,
            options: options
        )
    }

    public func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.unzipItem(at: sourceURL, to: destinationURL)
    }
}
