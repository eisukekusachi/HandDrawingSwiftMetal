//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import UIKit

public class FileItem: Identifiable {
    /// Documents directory files have unique URLs, so `fileURL` is used as the identity.
    public var id: URL { fileURL }

    public private(set) var createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var thumbnail: UIImage?
    public private(set) var fileURL: URL

    public var title: String { fileURL.baseName }

    /// How `update(thumbnail:)` should treat the thumbnail.
    enum ThumbnailUpdate {
        /// Leave the current thumbnail as-is.
        case unchanged
        /// Replace the thumbnail (`nil` clears it).
        case set(UIImage?)
    }

    public init(
        createdAt: Date = .init(),
        updatedAt: Date = .init(),
        thumbnail: UIImage? = nil,
        fileURL: URL
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.thumbnail = thumbnail
        self.fileURL = fileURL
    }

    func update(
        fileURL: URL? = nil,
        updatedAt: Date? = nil,
        thumbnail: ThumbnailUpdate = .unchanged
    ) {
        if let fileURL { self.fileURL = fileURL }
        if let updatedAt { self.updatedAt = updatedAt }

        switch thumbnail {
        case .unchanged:
            break
        case .set(let image):
            self.thumbnail = image
        }
    }
}
