//
//  TextureLayerRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import UIKit

/// A repository that manages textures and in-memory thumbnails
protocol TextureLayerRepository: TextureRepository {

    /// A publisher that notifies SwiftUI about a thumbnail update for a specific layer
    var thumbnailUpdateRequestedPublisher: AnyPublisher<UUID, Never> { get }

    /// Gets the thumbnail image for UUID
    func getThumbnail(_ uuid: UUID) -> UIImage?

    /// Updates all thumbnails
    func updateAllThumbnails(textureSize: CGSize) -> AnyPublisher<Void, Error>

}
