//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public final class MockFileManager: FileManaging, @unchecked Sendable {

    private let lock = NSLock()
    private var _existingPaths: Set<String> = []
    private var _directoryContents: [String: [URL]] = [:]
    private var _fileContents: [String: Data] = [:]
    private var _moveCalls: [(URL, URL)] = []
    private var _copyCalls: [(URL, URL)] = []
    private var _removeCalls: [URL] = []
    private var _createDirectoryCalls: [URL] = []
    private var _unzipCalls: [(URL, URL)] = []
    private let mockDocumentsDirectoryURL: URL

    public var moveCalls: [(URL, URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _moveCalls
    }

    public var copyCalls: [(URL, URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _copyCalls
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

    public init() {
        mockDocumentsDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MockDocuments-\(UUID().uuidString)", isDirectory: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: mockDocumentsDirectoryURL)
    }

    public var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory
    }

    /// Stand-in for the app Documents directory; uses a unique folder under `tmp` so tests do not touch real user files.
    public var documentsDirectory: URL {
        mockDocumentsDirectoryURL
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

    /// Marks `url` as an existing file and creates it on disk for move/remove tests.
    public func appendFile(at url: URL) {
        let parentURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
        }

        lock.lock()
        defer { lock.unlock() }
        registerFileURL(url)
        if let data = FileManager.default.contents(atPath: url.path) {
            _fileContents[url.path] = data
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
        if _existingPaths.contains(where: { $0.lowercased() == path.lowercased() }) {
            return true
        }
        if _fileContents.keys.contains(where: { $0.lowercased() == path.lowercased() }) {
            return true
        }
        return FileManager.default.fileExists(atPath: path)
    }

    public func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool) throws {
        lock.lock()
        _createDirectoryCalls.append(url)
        _existingPaths.insert(url.path)
        lock.unlock()

        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates
        )
    }

    public func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?
    ) throws -> [URL] {
        lock.lock()
        let programmed = _directoryContents[url.path]
        lock.unlock()

        if let programmed {
            return programmed
        }

        return try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys
        )
    }

    public func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        _moveCalls.append((sourceURL, destinationURL))
        lock.unlock()

        try FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

        lock.lock()
        defer { lock.unlock() }
        relocateTrackedPaths(from: sourceURL.path, to: destinationURL.path)
    }

    public func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        _copyCalls.append((sourceURL, destinationURL))
        lock.unlock()

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

        lock.lock()
        defer { lock.unlock() }
        if let data = _fileContents[sourceURL.path] {
            _fileContents[destinationURL.path] = data
        }
        registerFileURL(destinationURL)
    }

    public func removeItem(at url: URL) throws {
        lock.lock()
        _removeCalls.append(url)
        lock.unlock()

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        lock.lock()
        defer { lock.unlock() }
        removeTrackedPaths(withPrefix: url.path)
    }

    public func contents(atPath path: String) -> Data? {
        lock.lock()
        let cached = _fileContents[path]
        lock.unlock()

        if let cached {
            return cached
        }

        return FileManager.default.contents(atPath: path)
    }

    public func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        lock.lock()
        let cached = _fileContents[path]
        lock.unlock()

        if let cached {
            return [.size: cached.count]
        }

        return try FileManager.default.attributesOfItem(atPath: path)
    }

    public func createFile(
        atPath path: String,
        contents data: Data?,
        attributes attr: [FileAttributeKey: Any]?
    ) -> Bool {
        let created = FileManager.default.createFile(atPath: path, contents: data, attributes: attr)
        guard created else { return false }

        lock.lock()
        defer { lock.unlock() }
        if let data {
            _fileContents[path] = data
        }
        registerFileURL(URL(fileURLWithPath: path))
        return true
    }

    public func replaceItemAt(
        _ originalItemURL: URL,
        withItemAt newItemURL: URL,
        backupItemName: String?,
        options: FileManager.ItemReplacementOptions
    ) throws -> URL? {
        let result = try FileManager.default.replaceItemAt(
            originalItemURL,
            withItemAt: newItemURL,
            backupItemName: backupItemName,
            options: options
        )

        lock.lock()
        defer { lock.unlock() }
        relocateTrackedPaths(from: newItemURL.path, to: originalItemURL.path)
        return result
    }

    public func unzipItem(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _unzipCalls.append((sourceURL, destinationURL))
    }
}

private extension MockFileManager {

    func registerFileURL(_ url: URL) {
        _existingPaths.insert(url.path)
        let directoryPath = url.deletingLastPathComponent().path
        var urls = _directoryContents[directoryPath] ?? []
        if !urls.contains(where: { $0.path == url.path }) {
            urls.append(url)
            _directoryContents[directoryPath] = urls
        }
    }

    func relocateTrackedPaths(from sourcePath: String, to destinationPath: String) {
        _fileContents = relocateDictionaryKeys(_fileContents, from: sourcePath, to: destinationPath)
        _existingPaths = relocatePathSet(_existingPaths, from: sourcePath, to: destinationPath)
        _directoryContents = relocateDirectoryContents(_directoryContents, from: sourcePath, to: destinationPath)
    }

    func removeTrackedPaths(withPrefix prefix: String) {
        _fileContents = _fileContents.filter { path, _ in
            path != prefix && !path.hasPrefix(prefix + "/")
        }
        _existingPaths = _existingPaths.filter { path in
            path != prefix && !path.hasPrefix(prefix + "/")
        }
        _directoryContents = _directoryContents.filter { path, _ in
            path != prefix && !path.hasPrefix(prefix + "/")
        }
    }

    func relocateDictionaryKeys(
        _ dictionary: [String: Data],
        from sourcePath: String,
        to destinationPath: String
    ) -> [String: Data] {
        var result: [String: Data] = [:]
        result.reserveCapacity(dictionary.count)

        for (path, data) in dictionary {
            if path == sourcePath || path.hasPrefix(sourcePath + "/") {
                let suffix = String(path.dropFirst(sourcePath.count))
                result[destinationPath + suffix] = data
            } else {
                result[path] = data
            }
        }

        return result
    }

    func relocatePathSet(
        _ paths: Set<String>,
        from sourcePath: String,
        to destinationPath: String
    ) -> Set<String> {
        Set(
            paths.map { path in
                if path == sourcePath || path.hasPrefix(sourcePath + "/") {
                    let suffix = String(path.dropFirst(sourcePath.count))
                    return destinationPath + suffix
                }
                return path
            }
        )
    }

    func relocateDirectoryContents(
        _ directories: [String: [URL]],
        from sourcePath: String,
        to destinationPath: String
    ) -> [String: [URL]] {
        var result: [String: [URL]] = [:]
        result.reserveCapacity(directories.count)

        for (path, urls) in directories {
            if path == sourcePath || path.hasPrefix(sourcePath + "/") {
                let suffix = String(path.dropFirst(sourcePath.count))
                let newPath = destinationPath + suffix
                result[newPath] = urls.map { url in
                    URL(fileURLWithPath: relocatePath(url.path, from: sourcePath, to: destinationPath))
                }
            } else {
                result[path] = urls
            }
        }

        return result
    }

    func relocatePath(_ path: String, from sourcePath: String, to destinationPath: String) -> String {
        if path == sourcePath || path.hasPrefix(sourcePath + "/") {
            let suffix = String(path.dropFirst(sourcePath.count))
            return destinationPath + suffix
        }
        return path
    }
}
