//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/12.
//

import Foundation
import UIKit

/// Sendable snapshot used to build a `FileItem` after background I/O.
public struct SendableFileItem: Sendable {
    public let createdAt: Date
    public let updatedAt: Date
    public let thumbnailData: Data?
    public let fileURL: URL

    public init(
        createdAt: Date = .init(),
        updatedAt: Date = .init(),
        thumbnailData: Data? = nil,
        fileURL: URL
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.thumbnailData = thumbnailData
        self.fileURL = fileURL
    }

    public func makeFileItem() -> FileItem {
        FileItem(
            createdAt: createdAt,
            updatedAt: updatedAt,
            thumbnail: thumbnailData.flatMap(UIImage.init(data:)),
            fileURL: fileURL
        )
    }
}
