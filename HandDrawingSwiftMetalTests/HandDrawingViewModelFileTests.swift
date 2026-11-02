//
//  Created by Eisuke Kusachi
//

import Core
import CoreGraphics
import FileView
import Foundation
import MetalKit
import Testing

@testable import HandDrawingSwiftMetal

@MainActor
struct HandDrawingViewModelFileTests {

    private typealias Subject = HandDrawingViewModel

    /// Exercises `deleteFile` only: invalid index, non-open row (remove zip + list row).
    /// List selection is covered in FileViewModel tests.
    @MainActor
    struct DeleteFile {

        @Test
        func `When index is out of bounds, it throws`() async throws {
            let (device, commandQueue) = try makeMetal()
            let fileManager = MockFileManager()

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager)
            )
            subject.fileList.setItem(.init(fileURL: zipURL(named: "first", fileManager: fileManager)))
            subject.fileList.setItem(.init(fileURL: zipURL(named: "second", fileManager: fileManager)))
            subject.fileList.setItem(.init(fileURL: zipURL(named: "third", fileManager: fileManager)))
            #expect(subject.fileList.items.count == 3)

            await #expect(throws: NSError.self) {
                try await subject.deleteFile(
                    index: 3,
                    device: device,
                    commandQueue: commandQueue
                )
            }
        }

        @Test
        func `When the open file is selected, it throws`() async throws {
            let fileManager = MockFileManager()
            let (device, commandQueue) = try makeMetal()

            let firstURL = zipURL(named: "first", fileManager: fileManager)
            fileManager.setExistingFiles(at: [firstURL])

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager)
            )
            subject.project.update(projectName: "first")
            subject.fileList.setItem(.init(fileURL: firstURL))

            await #expect(throws: NSError.self) {
                try await subject.deleteFile(
                    index: 0,
                    device: device,
                    commandQueue: commandQueue
                )
            }
        }

        @Test
        func `When deleting a file that is not open, it removes the zip and the list entry`() async throws {
            let fileManager = MockFileManager()
            let (device, commandQueue) = try makeMetal()

            let firstURL = zipURL(named: "first", fileManager: fileManager)
            let secondURL = zipURL(named: "second", fileManager: fileManager)
            let thirdURL = zipURL(named: "third", fileManager: fileManager)
            fileManager.setExistingFiles(at: [firstURL, secondURL, thirdURL])

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager)
            )

            subject.project.update(projectName: "first")

            subject.fileList.setItem(.init(fileURL: firstURL))
            subject.fileList.setItem(.init(fileURL: secondURL))
            subject.fileList.setItem(.init(fileURL: thirdURL))

            let secondIndex = try #require(subject.fileList.index(fileURL: secondURL))

            // `first` is the open project; `second` is not open.
            try await subject.deleteFile(
                index: secondIndex,
                device: device,
                commandQueue: commandQueue
            )

            // Drop only the deleted row; the open project and the other saved file remain in the list.
            #expect(subject.fileList.items.count == 2)
            #expect(Set(subject.fileList.items.map(\.title)) == Set(["first", "third"]))

            // Remove the zip for the deleted file only.
            #expect(fileManager.removeCalls == [secondURL])
            #expect(fileManager.fileExists(atPath: secondURL.path) == false)
            #expect(fileManager.fileExists(atPath: firstURL.path))
            #expect(fileManager.fileExists(atPath: thirdURL.path))
        }
    }

    @MainActor
    struct ClearCanvas {

        @Test
        func `When clearing the open file, it updates updatedAt without writing the zip`() async throws {
            let fileManager = MockFileManager()
            let zipHandler = MockZipHandler()
            let (device, commandQueue) = try makeMetal()

            let firstURL = zipURL(named: "first", fileManager: fileManager)
            let secondURL = zipURL(named: "second", fileManager: fileManager)
            let thirdURL = zipURL(named: "third", fileManager: fileManager)
            fileManager.setExistingFiles(at: [firstURL, secondURL, thirdURL])

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager, zipHandler: zipHandler)
            )

            // `loadFile` does not refresh list rows; only the open project's metadata changes.
            let staleUpdatedAt = Date(timeIntervalSince1970: 0)
            let middleUpdatedAt = Date(timeIntervalSince1970: 100)
            let newestUpdatedAt = Date(timeIntervalSince1970: 200)
            subject.project.update(projectName: "second", updatedAt: staleUpdatedAt)
            let projectUpdatedAtBefore = subject.project.updatedAt

            subject.fileList.setItem(.init(updatedAt: newestUpdatedAt, fileURL: firstURL))
            subject.fileList.setItem(.init(updatedAt: staleUpdatedAt, fileURL: secondURL))
            subject.fileList.setItem(.init(updatedAt: middleUpdatedAt, fileURL: thirdURL))
            subject.fileList.sortItems()

            // Open project is the oldest row in the list until clear runs.
            #expect(subject.fileList.items.map(\.title) == ["first", "third", "second"])

            try await subject.clearCanvas(
                device: device,
                commandQueue: commandQueue
            )

            // Clear bumps the open row's updatedAt and re-sorts; disk zips are untouched until save.
            #expect(subject.fileList.items.count == 3)
            #expect(subject.fileList.items.map(\.title) == ["second", "first", "third"])
            #expect(subject.fileList.items[0].updatedAt == subject.project.updatedAt)
            #expect(subject.project.updatedAt > projectUpdatedAtBefore)

            #expect(fileManager.fileExists(atPath: firstURL.path))
            #expect(fileManager.fileExists(atPath: secondURL.path))
            #expect(fileManager.fileExists(atPath: thirdURL.path))
            #expect(zipHandler.zipCalls.isEmpty)
        }
    }
}

@MainActor
fileprivate func zipURL(named name: String, fileManager: MockFileManager) -> URL {
    fileManager.documentsDirectory.appendingPathComponent("\(name).zip")
}

@MainActor
fileprivate func dependencies(fileManager: MockFileManager = MockFileManager()) -> HandDrawingViewDependencies {
    .init(
        fileManager: fileManager,
        textureDataRepository: TextureRepositoryStub(),
        projectCoreDataStorage: CoreDataStorage(
            inMemory: "ProjectStorage",
            bundle: Bundle(for: CoreDataProjectStorage.self)
        ),
        textureLayersCoreDataStorage: CoreDataStorage(
            inMemory: "TextureLayerStorage",
            bundle: Bundle(for: CoreDataTextureLayerStorage.self)
        ),
        drawingToolCoreDataStorage: CoreDataStorage(
            inMemory: "DrawingToolStorage",
            bundle: Bundle(for: CoreDataDrawingToolStorage.self)
        )
    )
}

@MainActor
fileprivate func makeMetal() throws -> (MTLDevice, MTLCommandQueue) {
    let device = try #require(MTLCreateSystemDefaultDevice())
    let commandQueue = try #require(device.makeCommandQueue())
    return (device, commandQueue)
}

