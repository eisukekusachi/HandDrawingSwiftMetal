//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public protocol LocalFileRepositoryProtocol: Sendable {

    /// Root under which session directories are created (e.g. `TmpFolder`).
    var workingDirectoryURL: URL { get }

    /// Creates a unique session directory under `workingDirectoryURL`.
    func createSessionDirectory() throws -> URL

    func zipFile(from directoryURL: URL, to zipFileURL: URL) throws

    func unzipFile(from zipFileURL: URL, to directoryURL: URL) async throws

    func removeFile(at url: URL) throws

    func renameFile(at sourceURL: URL, to destinationURL: URL) throws
}
