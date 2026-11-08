//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

extension LocalTextureFileRepository {

    /// Default on-disk texture cache for the app (Application Support / `TextureStorage`).
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
