//
//  TextureLayerCanvasProtocol.swift
//  TextureLayerCanvasView
//
//  Created by Eisuke Kusachi on 2026/10/01.
//

import CoreGraphics
import UIKit

public struct CanvasLayerSnapshot: Equatable {

    public let id: UUID

    public let alpha: Int

    public let isVisible: Bool

    public init(
        id: UUID,
        alpha: Int,
        isVisible: Bool
    ) {
        self.id = id
        self.alpha = alpha
        self.isVisible = isVisible
    }
}

@MainActor
public protocol TextureLayerCanvasProtocol: AnyObject {

    var textureSize: CGSize { get }

    var selectedLayerIndex: Int? { get }

    var layerSnapshots: [CanvasLayerSnapshot] { get }

    var selectedLayerSnapshot: CanvasLayerSnapshot? { get }

    func updateLayerThumbnail(_ id: UUID, thumbnail: UIImage?)
}
