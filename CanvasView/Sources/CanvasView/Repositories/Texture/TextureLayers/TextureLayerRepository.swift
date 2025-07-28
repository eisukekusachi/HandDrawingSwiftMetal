//
//  TextureLayerRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/17.
//

import Combine
import UIKit

/// A protocol that defines a repository for managing textures and in-memory thumbnails
protocol TextureLayerRepository: TextureRepository {

    /// A subject that notifies SwiftUI of upcoming changes
    var objectWillChangeSubject: PassthroughSubject<Void, Never> { get }

    /// Gets the thumbnail image for UUID
    func thumbnail(_ uuid: UUID) -> UIImage?
}
