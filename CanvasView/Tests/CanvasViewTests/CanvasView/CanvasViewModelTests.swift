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

struct CanvasViewModelTests {

    private typealias Subject = CanvasViewModel

    @MainActor
    @Suite("Canvas initialize")
    struct CanvasInitializeTests {

        private let renderer = MockMTLRenderer()

        private let textureSize: CGSize = .init(
            width: canvasMinimumTextureLength,
            height: canvasMinimumTextureLength
        )

        var formatter: DateFormatter {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            return dateFormatter
        }

        var currentProjectMetaData: ProjectMetaData {
            .init(
                projectName: "currentName",
                createdAt: formatter.date(from: "2000-1-1 00:00:00")!,
                updatedAt: formatter.date(from: "2000-12-31 00:00:00")!
            )
        }

        @Test
        func `When textureLayersState exists, the canvas is initialized using textureLayersState`() async throws {
            let subject = Subject(
                projectMetaData: currentProjectMetaData,
                renderer: renderer
            )

            let repository = MockTextureLayersDocumentsRepository(
                renderer: renderer
            )
            subject.setup(
                dependencies: .init(
                    textureLayersDocumentsRepository: repository,
                    renderer: renderer
                ),
                environmentConfiguration: EnvironmentConfiguration()
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

            try? await subject.initializeCanvas(
                textureLayersState: .init(textureSize: textureSize),
                configuration: .init(
                    textureSize: textureSize
                )
            )

            await waitForEmission.value
            cancellable?.cancel()

            // The metadata is overwritten from Core Data.
            // And only updatedAt is set to the current date
            let metaData = subject.projectMetaDataStorage
            #expect(metaData.projectName != currentProjectMetaData.projectName)
            #expect(Int(metaData.createdAt.timeIntervalSince1970) != Int(currentProjectMetaData.createdAt.timeIntervalSince1970))
            #expect(Int(metaData.updatedAt.timeIntervalSince1970) == Int(Date().timeIntervalSince1970))

            #expect(repository.initializeStorage_textureLayersState_callCount == 1)
            #expect(repository.initializeStorage_newTextureSize_callCount == 0)
            #expect(true)
        }

        @Test
        func `When textureLayersState is nil and the texture size is above the minimum threshold, the default canvas initialization is performed`() async throws {
            let newProjectName = "newProjectName"

            let subject = Subject(
                projectMetaData: currentProjectMetaData,
                renderer: renderer
            )

            let repository = MockTextureLayersDocumentsRepository(
                renderer: renderer
            )
            subject.setup(
                dependencies: .init(
                    textureLayersDocumentsRepository: repository,
                    renderer: renderer
                ),
                environmentConfiguration: EnvironmentConfiguration()
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

            try? await subject.initializeCanvas(
                textureLayersState: nil,
                configuration: .init(
                    textureSize: textureSize,
                    projectConfiguration: .init(projectName: newProjectName)
                )
            )

            await waitForEmission.value
            cancellable?.cancel()

            // The project metadata is updated with the new name and the current timestamp
            #expect(subject.projectMetaDataStorage.projectName == newProjectName)
            #expect(Int(subject.projectMetaDataStorage.createdAt.timeIntervalSince1970) == Int(Date().timeIntervalSince1970))
            #expect(Int(subject.projectMetaDataStorage.updatedAt.timeIntervalSince1970) == Int(Date().timeIntervalSince1970))

            #expect(repository.initializeStorage_textureLayersState_callCount == 0)
            #expect(repository.initializeStorage_newTextureSize_callCount == 1)
            #expect(true)
        }

        @Test
        func `When textureLayersState is nil and the texture size is below the minimum threshold, an error is thrown`() async {
            let subject = Subject(
                projectMetaData: currentProjectMetaData,
                renderer: renderer
            )

            var didInitialize = false
            let cancellable = subject.didInitialize.sink { _ in
                didInitialize = true
            }
            defer { cancellable.cancel() }


            let repository = MockTextureLayersDocumentsRepository(
                renderer: renderer
            )
            subject.setup(
                dependencies: .init(
                    textureLayersDocumentsRepository: repository,
                    renderer: renderer
                ),
                environmentConfiguration: EnvironmentConfiguration()
            )

            await #expect(throws: Error.self) {
                try await subject.initializeCanvas(
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
                projectMetaData: currentProjectMetaData,
                renderer: renderer
            )

            let newProjectMetaData: ProjectMetaData = .init(
                projectName: "dummyName",
                createdAt: formatter.date(from: "2024-1-1 00:00:00")!,
                updatedAt: formatter.date(from: "2024-12-31 00:00:00")!
            )

            let repository = MockTextureLayersDocumentsRepository(
                renderer: renderer
            )
            subject.setup(
                dependencies: .init(
                    textureLayersDocumentsRepository: repository,
                    renderer: renderer
                ),
                environmentConfiguration: EnvironmentConfiguration()
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

            try? await subject.restoreCanvasFromDocumentsFolder(
                workingDirectoryURL: URL(fileURLWithPath: "/tmp/MockTextures"),
                textureLayersState: .init(textureSize: textureSize),
                projectMetaData: newProjectMetaData
            )

            await waitForEmission.value
            cancellable?.cancel()

            // The projectMetaDataStorage is overwritten with the new projectMetadata
            #expect(subject.projectMetaDataStorage.projectName == newProjectMetaData.projectName)
            #expect(subject.projectMetaDataStorage.createdAt == newProjectMetaData.createdAt)
            #expect(subject.projectMetaDataStorage.updatedAt == newProjectMetaData.updatedAt)

            #expect(repository.restoreStorage_callCount == 1)
            #expect(true)
        }
    }
}
