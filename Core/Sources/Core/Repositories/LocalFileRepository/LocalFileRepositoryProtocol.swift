//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public protocol LocalFileRepositoryProtocol: Sendable {

    var workingDirectoryURL: URL { get }

    @discardableResult
    func createWorkingDirectory() throws -> URL

    func removeWorkingDirectory() throws

    func zipWorkingDirectory(to zipFileURL: URL) throws

    func unzipToWorkingDirectory(from zipFileURL: URL) async throws

    func removeItem(at url: URL) throws

    func moveItem(at sourceURL: URL, to destinationURL: URL) throws
}
