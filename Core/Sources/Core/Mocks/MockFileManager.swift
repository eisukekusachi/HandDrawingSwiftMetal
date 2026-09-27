//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public final class MockFileManager: FileManaging, @unchecked Sendable {

    private let lock = NSLock()
    private var _existingPaths: Set<String> = []
    private var _directoryContents: [String: [URL]] = [:]
    private var _moveCalls: [(URL, URL)] = []
    private var _removeCalls: [URL] = []
    private var _createDirectoryCalls: [URL] = []
    private var _unzipCalls: [(URL, URL)] = []

    public var moveCalls: [(URL, URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _moveCalls
    }

    public var removeCalls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _removeCalls
    }

    public var createDirectoryCalls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _createDirectoryCalls
    }

    public var unzipCalls: [(URL, URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _unzipCalls
    }

    public init() {}

    public var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    public var documentsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("MockDocuments")
    }

    public func setFileExists(_ exists: Bool, atPath path: String) {
        lock.lock()
        defer { lock.unlock() }
        if exists {
            _existingPaths.insert(path)
        } else {
            _existingPaths.remove(path)
        }
    }

    public func setContentsOfDirectory(_ urls: [URL], at directoryURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        _directoryContents[directoryURL.path] = urls
    }

    public func fileExists(atPath path: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        // Match FileManager on case-insensitive volumes (e.g. iOS Documents).
        return _existingPaths.contains { $0.lowercased() == path.lowercased() }
    }

    public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        _createDirectoryCalls.append(url)
        _existingPaths.insert(url.path)
    }

    public func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _directoryContents[url.path] ?? []
    }

    public func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _moveCalls.append((sourceURL, destinationURL))
        _existingPaths.remove(sourceURL.path)
        _existingPaths.insert(destinationURL.path)
    }

    public func removeItem(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _removeCalls.append(url)
        _existingPaths.remove(url.path)
        _directoryContents.removeValue(forKey: url.path)
    }

    public func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _unzipCalls.append((sourceURL, destinationURL))
    }
}
