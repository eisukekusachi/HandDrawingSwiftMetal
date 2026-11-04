//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public final class MockZipHandler: ZipHandling, @unchecked Sendable {

    private let lock = NSLock()
    private var _zipCalls: [(sourceURLs: [URL], zipFileURL: URL)] = []
    private var _unzipCalls: [(sourceURL: URL, destinationURL: URL)] = []

    public var zipCalls: [(sourceURLs: [URL], zipFileURL: URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _zipCalls
    }

    public var unzipCalls: [(sourceURL: URL, destinationURL: URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _unzipCalls
    }

    public init() {}

    public func zip(sourceURLs: [URL], to zipFileURL: URL) throws {
        lock.lock()
        _zipCalls.append((sourceURLs, zipFileURL))
        lock.unlock()

        try FileManager.default.createDirectory(
            at: zipFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard FileManager.default.createFile(atPath: zipFileURL.path, contents: Data(), attributes: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    public func unzip(sourceURL: URL, to destinationURL: URL, priority: TaskPriority?) async throws {
        recordUnzip(sourceURL: sourceURL, destinationURL: destinationURL)
    }

    private func recordUnzip(sourceURL: URL, destinationURL: URL) {
        lock.lock()
        defer { lock.unlock() }
        _unzipCalls.append((sourceURL, destinationURL))
    }
}
