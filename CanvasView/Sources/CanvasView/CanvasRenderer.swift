//
//  CanvasRenderer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/04/06.
//

import Combine
@preconcurrency import MetalKit

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

    private let displayView: CanvasDisplayable

    /// A texture that combines the textures of all layers above the selected layer.
    private var unselectedTopTexture: MTLTexture!

    private var flippedTextureBuffers: MTLTextureBuffers?

    private var cancellables = Set<AnyCancellable>()

    private let device: MTLDevice = MTLCreateSystemDefaultDevice()!

    init(
        displayView: CanvasDisplayable,
        renderer: MTLRendering
    ) {
        self.renderer = renderer

        self.flippedTextureBuffers = MTLBuffers.makeTextureBuffers(
            nodes: .flippedTextureNodes,
            with: device
        )

        self.displayView = displayView
    }

    func initialize(
        environmentConfiguration: CanvasEnvironmentConfiguration
    ) {
        self.backgroundColor = environmentConfiguration.backgroundColor
        self.baseBackgroundColor = environmentConfiguration.baseBackgroundColor
    }

    func initTextures(textureSize: CGSize) {
        guard
            Int(textureSize.width) >= canvasMinimumTextureLength &&
            Int(textureSize.height) >= canvasMinimumTextureLength
        else {
            assert(false, "Texture size is below the minimum: \(textureSize.width) \(textureSize.height)")
            return
        }

        guard
            let unselectedBottomTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            ),
            let selectedTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            ),
            let unselectedTopTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            ),
            let canvasTexture = MTLTextureCreator.makeTexture(
                width: Int(textureSize.width),
                height: Int(textureSize.height),
                with: device
            )
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
    var drawableSize: CGSize? {
        displayView.displayTexture?.size
    }

    func resetCommandBuffer() {
        displayView.resetCommandBuffer()
    }
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
        textureRepository: TextureRepository,
        onCompleted: (() -> Void)?
    ) {
        guard
            let selectedLayer = canvasState.selectedLayer,
            let selectedIndex = canvasState.selectedIndex,
            let commandBuffer = device.makeCommandQueue()?.makeCommandBuffer()
        else {
            return
        }

        // The selected texture is kept opaque here because transparency is applied when used
        let opaqueLayer: TextureLayerModel = .init(
            id: selectedLayer.id,
            title: selectedLayer.title,
            alpha: 255,
            isVisible: selectedLayer.isVisible
        )

        Task {
            let textures = try await textureRepository.copyTextures(
                uuids: canvasState.layers.map { $0.id }
            )
            let bottomLayers = bottomLayers(
                selectedIndex: selectedIndex,
                layers: canvasState.layers.map { .init(item: $0) }
            )
            let topLayers = topLayers(
                selectedIndex: selectedIndex,
                layers: canvasState.layers.map { .init(item: $0) }
            )

            Task { @MainActor in
                try await drawLayerTextures(
                    textures: textures,
                    layers: bottomLayers,
                    on: unselectedBottomTexture,
                    with: commandBuffer
                )

                try await drawLayerTextures(
                    textures: textures,
                    layers: [opaqueLayer],
                    on: selectedTexture,
                    with: commandBuffer
                )

                try await drawLayerTextures(
                    textures: textures,
                    layers: topLayers,
                    on: unselectedTopTexture,
                    with: commandBuffer
                )

                try await withCheckedThrowingContinuation { continuation in
                    commandBuffer.addCompletedHandler { @Sendable _ in
                        continuation.resume()
                    }
                    commandBuffer.commit()
                }

                onCompleted?()
            }
        }
    }

    /// Updates the canvas using `unselectedBottomTexture`, `selectedTexture`, `unselectedTopTexture`
    func updateCanvasView(
        realtimeDrawingTexture: MTLTexture? = nil,
        selectedLayer: TextureLayerModel
    ) {
        guard
            let commandBuffer = displayView.commandBuffer,
            let canvasTexture
        else { return }

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

        updateCanvasView()
    }

    func updateCanvasView() {
        guard
            let commandBuffer = displayView.commandBuffer,
            let displayTexture = displayView.displayTexture
        else { return }

        renderer.drawTexture(
            texture: canvasTexture,
            matrix: matrix,
            frameSize: frameSize,
            backgroundColor: baseBackgroundColor,
            on: displayTexture,
            device: device,
            with: commandBuffer
        )
        displayView.setNeedsDisplay()
    }

    func drawLayerTextures(
        textures: [IdentifiedTexture],
        layers: [TextureLayerModel],
        on destination: MTLTexture,
        with commandBuffer: MTLCommandBuffer
    ) async throws {

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
    }
}
