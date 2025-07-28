//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
import MetalKit

/// A class that renders textures from `TextureRepository` onto the canvas
@MainActor
final class CanvasRenderer: ObservableObject {

    var frameSize: CGSize = .zero

    var matrix: CGAffineTransform = .identity

    /// The background color of the canvas
    var backgroundColor: UIColor = .white

    /// The base background color of the canvas. this color that appears when the canvas is rotated or moved.
    var baseBackgroundColor: UIColor = .lightGray

    private let renderer: MTLRendering

    /// The texture that combines the background color and the textures of `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`
    private(set) var canvasTexture: MTLTexture?

    /// A texture that combines the textures of all layers below the selected layer.
    private var unselectedBottomTexture: MTLTexture!

    /// The texture of the selected layer.
    private(set) var selectedTexture: MTLTexture!

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(
        renderer: MTLRendering = MTLRenderer.shared
    ) {
        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.renderer = renderer
    }

    func initialize(
        environmentConfiguration: CanvasEnvironmentConfiguration
    ) {
        self.backgroundColor = environmentConfiguration.backgroundColor
        self.baseBackgroundColor = environmentConfiguration.baseBackgroundColor
    }

    func initTextures(textureSize: CGSize) {
        guard
            Int(textureSize.width) >= MTLRenderer.threadGroupLength &&
            Int(textureSize.height) >= MTLRenderer.threadGroupLength
        else {
            assert(false, "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return
        }

        guard
            let unselectedBottomTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let selectedTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let unselectedTopTexture = MTLTextureCreator.makeBlankTexture(size: textureSize, with: device),
            let canvasTexture = MTLTextureCreator.makeTexture(size: textureSize, with: device)
        else {
            assert(false, "Failed to generate texture")
            return
        }

        self.unselectedBottomTexture = unselectedBottomTexture
        self.selectedTexture = selectedTexture
        self.unselectedTopTexture = unselectedTopTexture
        self.canvasTexture = canvasTexture

        self.unselectedBottomTexture?.label = "unselectedBottomTexture"
        self.selectedTexture?.label = "selectedTexture"
        self.unselectedTopTexture?.label = "unselectedTopTexture"
        self.canvasTexture?.label = "canvasTexture"
    }
}

extension CanvasRenderer {
    func bottomLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: 0, upper: selectedIndex - 1).filter { $0.isVisible }
    }
    func topLayers(selectedIndex: Int, layers: [TextureLayerModel]) -> [TextureLayerModel] {
        layers.safeSlice(lower: selectedIndex + 1, upper: layers.count - 1).filter { $0.isVisible }
    }

    /// Updates `unselectedBottomTexture`, `selectedTexture` and `unselectedTopTexture`.
    /// This textures are pre-merged from `textureRepository` necessary for drawing.
    /// By using them, the drawing performance remains consistent regardless of the number of layers.
    func updateDrawingTextures(
        canvasState: CanvasState,
        textureLayerRepository: TextureLayerRepository,
        with commandBuffer: MTLCommandBuffer,
        onCompleted: (() -> Void)?
    ) {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex
        else {
            return
        }

        // The selected texture is kept opaque here because transparency is applied when used
        let opaqueLayer: TextureLayerModel = .init(model: selectedLayer, alpha: 255)

        Task {
            let textures = try await textureLayerRepository.copyTextures(
                uuids: canvasState.layers.map { $0.id }
            )

            Task { @MainActor in
                async let bottomTexture: Void = try await drawLayerTextures(
                    textures: textures,
                    layers: bottomLayers(
                        selectedIndex: selectedIndex,
                        layers: canvasState.layers
                    ),
                    on: unselectedBottomTexture,
                    with: commandBuffer
                )

                async let selectedTexture: Void = try await drawLayerTextures(
                    textures: textures,
                    layers: [opaqueLayer],
                    on: selectedTexture,
                    with: commandBuffer
                )

                async let topTexture: Void = try await drawLayerTextures(
                    textures: textures,
                    layers: topLayers(
                        selectedIndex: selectedIndex,
                        layers: canvasState.layers
                    ),
                    on: unselectedTopTexture,
                    with: commandBuffer
                )

                _ = try await (bottomTexture, selectedTexture, topTexture)

                onCompleted?()
            }
        }
    }

    /// Updates the canvas using `unselectedBottomTexture`, `selectedTexture`, `unselectedTopTexture`
    func updateCanvasView(
        _ canvasView: CanvasDisplayable?,
        realtimeDrawingTexture: MTLTexture? = nil,
        selectedLayer: TextureLayerModel,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let canvasTexture else { return }

        renderer.fillTexture(
            texture: canvasTexture,
            withRGB: backgroundColor.rgb,
            with: commandBuffer
        )

        renderer.mergeTexture(
            texture: unselectedBottomTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        if selectedLayer.isVisible {
            renderer.mergeTexture(
                texture: realtimeDrawingTexture ?? selectedTexture,
                alpha: selectedLayer.alpha,
                into: canvasTexture,
                with: commandBuffer
            )
        }

        renderer.mergeTexture(
            texture: unselectedTopTexture,
            into: canvasTexture,
            with: commandBuffer
        )

        updateCanvasView(
            canvasView,
            with: commandBuffer
        )
    }

    func updateCanvasView(
        _ canvasView: CanvasDisplayable?,
        with commandBuffer: MTLCommandBuffer
    ) {
        guard let displayTexture = canvasView?.displayTexture else { return }

        renderer.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            backgroundColor: baseBackgroundColor,
            on: displayTexture,
            device: device,
            with: commandBuffer
        )
        canvasView?.setNeedsDisplay()
    }

    func drawLayerTextures(
        textures: [IdentifiedTexture],
        layers: [TextureLayerModel],
        on destination: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) async throws {
        guard let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer() else {
            throw TextureLayerError.failedToUnwrap
        }

        renderer.clearTexture(texture: destination, with: commandBuffer)

        let textureDictionary = IdentifiedTexture.dictionary(from: Set(textures))

        for layer in layers {
            if let resultTexture = textureDictionary[layer.id] {
                renderer.mergeTexture(
                    texture: resultTexture,
                    alpha: layer.alpha,
                    into: destination,
                    with: commandBuffer
                )
            }
        }

        try await withCheckedThrowingContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }
    }
}
