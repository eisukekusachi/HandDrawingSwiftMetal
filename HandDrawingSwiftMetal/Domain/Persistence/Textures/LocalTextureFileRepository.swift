//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

/// On-disk pixels for the current project
extension LocalTextureFileRepository {

    /// App-wide instance of that directory.
    @MainActor
    public static let shared: LocalTextureFileRepository = {
        do {
            return try LocalTextureFileRepository(
                storageDirectoryURL: URL.applicationSupport,
                directoryName: "TextureStorage",
                fileManager: FileManagerWrapper()
            )
        } catch {
            fatalError("Failed to initialize LocalTextureFileRepository: \(error)")
        }
    }()
}
