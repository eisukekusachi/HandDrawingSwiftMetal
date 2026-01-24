//
//  CanvasViewModelTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/12/30.
//

import Combine
import UIKit
import Testing

@testable import CanvasView

@MainActor
struct CanvasViewModelTests {

    private typealias Subject = CanvasViewModel

    @MainActor
    struct CanvasInitialize {

        private let dependencies: CanvasViewDependencies

        private let renderer = MockMTLRenderer()

        private let displayView = MockCanvasDisplayable(texture: nil)

        private let textureLayersDocumentsRepository: MockTextureLayersDocumentsRepository

        private let textureSize: CGSize = .init(
            width: canvasMinimumTextureLength,
            height: canvasMinimumTextureLength
        )

        private var formatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            return dateFormatter
        }

        init() {
            self.textureLayersDocumentsRepository = MockTextureLayersDocumentsRepository(
                renderer: renderer
            )

            self.dependencies = CanvasViewDependencies(
                canvasRenderer: CanvasRenderer(
                    renderer: renderer,
                    repository: textureLayersDocumentsRepository,
                    displayView: displayView
                ),
                textureLayers: .init(
                    textureLayers: TextureLayers(
                        renderer: renderer,
                        repository: nil
                    ),
                    renderer: renderer,
                    inMemoryRepository: nil
                ),
                textureLayersDocumentsRepository: textureLayersDocumentsRepository,
                undoTextureInMemoryRepository: UndoTextureInMemoryRepository(
                    renderer: renderer
                )
            )
        }

        @Test
        func `When textureLayersState exists, the canvas is initialized using textureLayersState`() async throws {
            let subject = Subject(
                dependencies: dependencies
            )

            var cancellable: AnyCancellable?
            let waitForEmission = Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    cancellable = subject.setupCompletion
                        .prefix(1)
                        .sink { _ in
                            continuation.resume()
                        }
                }
            }

            try await subject.setupCanvas(
                textureLayersState: .init(textureSize: textureSize),
                configuration: .init(
                    textureSize: textureSize
                )
            )

            await waitForEmission.value
            cancellable?.cancel()

            // Restore storage using the provided textureLayersState
            #expect(textureLayersDocumentsRepository.initializeStorage_textureLayersState_callCount == 1)
            #expect(textureLayersDocumentsRepository.initializeStorage_newTextureSize_callCount == 0)
        }

        @Test
        func `When textureLayersState is nil and the texture size is above the minimum threshold, the default canvas initialization is performed`() async throws {

            let subject = Subject(
                dependencies: dependencies
            )

            var cancellable: AnyCancellable?
            let waitForEmission = Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    cancellable = subject.setupCompletion
                        .prefix(1)
                        .sink { _ in
                            continuation.resume()
                        }
                }
            }

            try await subject.setupCanvas(
                textureLayersState: nil,
                configuration: .init(
                    textureSize: textureSize
                )
            )

            await waitForEmission.value
            cancellable?.cancel()

            // Initialize storage with a new texture size
            #expect(textureLayersDocumentsRepository.initializeStorage_textureLayersState_callCount == 0)
            #expect(textureLayersDocumentsRepository.initializeStorage_newTextureSize_callCount == 1)
        }

        @Test
        func `When textureLayersState is nil and the texture size is below the minimum threshold, an error is thrown`() async {
            let subject = Subject(
                dependencies: dependencies
            )

            var setupCompletion = false
            let cancellable = subject.setupCompletion.sink { _ in
                setupCompletion = true
            }
            defer { cancellable.cancel() }

            await #expect(throws: Error.self) {
                try await subject.setupCanvas(
                    textureLayersState: nil,
                    configuration: .init(textureSize: .zero)
                )
            }

            // No value is emitted
            #expect(setupCompletion == false)
        }

        @Test
        func `When textureLayersState exists, the canvas is restored from the documents directory`() async throws {
            let subject = Subject(
                dependencies: dependencies
            )

            var cancellable: AnyCancellable?
            let waitForEmission = Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    cancellable = subject.setupCompletion
                        .prefix(1)
                        .sink { _ in
                            continuation.resume()
                        }
                }
            }

            try await subject.restoreCanvasFromDocumentsFolder(
                workingDirectoryURL: URL(fileURLWithPath: "/tmp/MockTextures"),
                textureLayersState: .init(textureSize: textureSize)
            )

            await waitForEmission.value
            cancellable?.cancel()

            #expect(textureLayersDocumentsRepository.restoreStorage_callCount == 1)
        }
    }

    @MainActor
    struct ResolveDrawingRenderers {

        @Test
        func `When drawingRenderers are provided, they are passed through and configured`() {
            let drawingRenderers: [DrawingRenderer] = [
                BrushDrawingRenderer(),
                EraserDrawingRenderer()
            ]

            #expect(drawingRenderers[0].renderer == nil)
            #expect(drawingRenderers[1].renderer == nil)

            let resultRenderers = CanvasViewModel.resolveDrawingRenderers(
                renderer: MockMTLRenderer(),
                drawingRenderers: drawingRenderers
            )

            // Then the same instances are returned
            #expect(resultRenderers.count == 2)
            #expect(resultRenderers[0] === drawingRenderers[0])
            #expect(resultRenderers[1] === drawingRenderers[1])

            // Each renderer is configured with the provided renderer
            #expect(resultRenderers[0].renderer != nil)
            #expect(resultRenderers[1].renderer != nil)
        }

        @Test
        func `When drawingRenderers are not provided, new DrawingRenderer is created and configured`() {
            let drawingRenderers: [DrawingRenderer] = []

            let resultRenderers = CanvasViewModel.resolveDrawingRenderers(
                renderer: MockMTLRenderer(),
                drawingRenderers: drawingRenderers
            )

            // A default BrushDrawingRenderer is created
            #expect(resultRenderers.count == 1)
            #expect(resultRenderers[0] is BrushDrawingRenderer)
            #expect(resultRenderers[0].renderer != nil)
        }
    }
}
