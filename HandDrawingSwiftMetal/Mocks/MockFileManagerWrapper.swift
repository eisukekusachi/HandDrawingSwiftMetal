//
//  MockFileManagerWrapper.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/04/29.
//

import Foundation

final class MockFileManagerWrapper: FileManagerWrapping, @unchecked Sendable {

    private let lock = NSLock()
    private var _moveCalls: [(URL, URL)] = []
    private var _removeCalls: [URL] = []

    var moveCalls: [(URL, URL)] {
        lock.lock()
        defer { lock.unlock() }
        return _moveCalls
    }

    var removeCalls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return _removeCalls
    }

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _moveCalls.append((sourceURL, destinationURL))
    }

    func removeItem(at url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        _removeCalls.append(url)
    }
}
