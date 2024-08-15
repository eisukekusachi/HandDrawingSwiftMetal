//
//  TextureLayerProtocol.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/18.
//

import UIKit

protocol TextureLayerProtocol: Identifiable, Equatable {
    /// The unique identifier for the layer
    var id: UUID { get }
    /// The name of the layer
    var title: String { get set }
    /// The thumbnail image of the layer
    var thumbnail: UIImage? { get set }
    /// The opacity of the layer
    var alpha: Int { get set }
    /// Whether the layer is visible or not
    var isVisible: Bool { get set }

}
