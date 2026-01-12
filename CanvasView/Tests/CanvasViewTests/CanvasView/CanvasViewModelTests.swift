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

        private var currentProjectMetaData: ProjectMetaData {
            .init(
                projectName: "currentName",
                createdAt: formatter.date(from: "2000-1-1 00:00:00")!,
                updatedAt: formatter.date(from: "2000-12-31 00:00:00")!
            )
        }

        init() {
            self.textureLayersDocumentsRepository = MockTextureLayersDocumentsRepository(
                renderer: renderer
            )

            let coreDataMetaDataEntity = ProjectMetaDataEntity(context: CoreDataTestHelper.makeInMemoryContext())

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
                ),
                projectMetaDataStorage: CoreDataProjectMetaDataStorage(
                    storage: AnyCoreDataStorage(
                        MockCoreDataStorage<ProjectMetaDataEntity>(
                            context: nil,
                            value: coreDataMetaDataEntity
                        )
                    )
                )
            )

            coreDataMetaDataEntity.projectName = currentProjectMetaData.projectName
            coreDataMetaDataEntity.createdAt = currentProjectMetaData.createdAt
            coreDataMetaDataEntity.updatedAt = currentProjectMetaData.updatedAt
        }

        @Test
        func `When textureLayersState exists, the canvas is initialized using textureLayersState`() async throws {
            let subject = Subject(
                dependencies: dependencies
            )

            var cancellable: AnyCancellable?
            let waitForEmission = Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    cancellable = subject.didInitialize
                        .prefix(1)
                        .sink { _ in
                            continuation.resume()
                        }
                }
            }

            let now = Date()

            try await subject.setupCanvas(
                textureLayersState: .init(textureSize: textureSize),
                configuration: .init(
                    textureSize: textureSize
                )
            )

            await waitForEmission.value
            cancellable?.cancel()

            // If textureLayersState is provided, the project metadata is overwritten using Core Data,
            // and only updatedAt is updated to the current date.
            let metaData = subject.projectMetaDataStorage
            #expect(metaData.projectName == currentProjectMetaData.projectName)
            #expect(Int(metaData.createdAt.timeIntervalSince1970) == Int(currentProjectMetaData.createdAt.timeIntervalSince1970))
            #expect(Int(metaData.updatedAt.timeIntervalSince1970) == Int(now.timeIntervalSince1970))

            // Restore storage using the provided textureLayersState
            #expect(textureLayersDocumentsRepository.initializeStorage_textureLayersState_callCount == 1)
            #expect(textureLayersDocumentsRepository.initializeStorage_newTextureSize_callCount == 0)
        }

        @Test
        func `When textureLayersState is nil and the texture size is above the minimum threshold, the default canvas initialization is performed`() async throws {
            let newProjectName = "newProjectName"

            let subject = Subject(
                dependencies: dependencies
            )

            var cancellable: AnyCancellable?
            let waitForEmission = Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    cancellable = subject.didInitialize
                        .prefix(1)
                        .sink { _ in
                            continuation.resume()
                        }
                }
            }

            let now = Date()

            try await subject.setupCanvas(
                textureLayersState: nil,
                configuration: .init(
                    textureSize: textureSize,
                    projectConfiguration: .init(projectName: newProjectName)
                )
            )

            await waitForEmission.value
            cancellable?.cancel()

            // If textureLayersState is nil, the project metadata is updated
            // with the new project name and the current timestamp.
            #expect(subject.projectMetaDataStorage.projectName == newProjectName)
            #expect(Int(subject.projectMetaDataStorage.createdAt.timeIntervalSince1970) == Int(now.timeIntervalSince1970))
            #expect(Int(subject.projectMetaDataStorage.updatedAt.timeIntervalSince1970) == Int(now.timeIntervalSince1970))

            // Initialize storage with a new texture size
            #expect(textureLayersDocumentsRepository.initializeStorage_textureLayersState_callCount == 0)
            #expect(textureLayersDocumentsRepository.initializeStorage_newTextureSize_callCount == 1)
        }

        @Test
        func `When textureLayersState is nil and the texture size is below the minimum threshold, an error is thrown`() async {
            let subject = Subject(
                dependencies: dependencies
            )

            var didInitialize = false
            let cancellable = subject.didInitialize.sink { _ in
                didInitialize = true
            }
            defer { cancellable.cancel() }

            await #expect(throws: Error.self) {
                try await subject.setupCanvas(
                    textureLayersState: nil,
                    configuration: .init(textureSize: .zero)
                )
            }

            // No value is emitted
            #expect(didInitialize == false)
        }

        @Test
        func `When textureLayersState exists, the canvas is restored from the documents directory`() async throws {
            let subject = Subject(
                dependencies: dependencies
            )

            let newProjectMetaData: ProjectMetaData = .init(
                projectName: "dummyName",
                createdAt: formatter.date(from: "2024-1-1 00:00:00")!,
                updatedAt: formatter.date(from: "2024-12-31 00:00:00")!
            )

            var cancellable: AnyCancellable?
            let waitForEmission = Task { @MainActor in
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    cancellable = subject.didInitialize
                        .prefix(1)
                        .sink { _ in
                            continuation.resume()
                        }
                }
            }

            try await subject.restoreCanvasFromDocumentsFolder(
                workingDirectoryURL: URL(fileURLWithPath: "/tmp/MockTextures"),
                textureLayersState: .init(textureSize: textureSize),
                projectMetaData: newProjectMetaData
            )

            await waitForEmission.value
            cancellable?.cancel()

            // The project metadata is overwritten with the new projectMetadata
            #expect(subject.projectMetaDataStorage.projectName == newProjectMetaData.projectName)
            #expect(subject.projectMetaDataStorage.createdAt == newProjectMetaData.createdAt)
            #expect(subject.projectMetaDataStorage.updatedAt == newProjectMetaData.updatedAt)

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
