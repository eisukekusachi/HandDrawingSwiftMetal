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

    @MainActor
    struct ClearCanvas {

        @Test
        func `When clearing the open file, it updates updatedAt and re-sorts without writing the zip`() async throws {
            let fileManager = MockFileManager()
            let zipHandler = MockZipHandler()
            let (device, commandQueue) = try makeMetal()

            let firstURL = zipURL(named: "first", fileManager: fileManager)
            let secondURL = zipURL(named: "second", fileManager: fileManager)
            let thirdURL = zipURL(named: "third", fileManager: fileManager)
            fileManager.appendFile(at: firstURL)
            fileManager.appendFile(at: secondURL)
            fileManager.appendFile(at: thirdURL)

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager, zipHandler: zipHandler)
            )

            subject.project.update(projectName: "second", updatedAt: Date(timeIntervalSince1970: 1))
            let projectUpdatedAtBefore = subject.project.updatedAt

            subject.fileList.append(.init(updatedAt: Date(timeIntervalSince1970: 2), fileURL: firstURL))
            subject.fileList.append(.init(updatedAt: Date(timeIntervalSince1970: 1), fileURL: secondURL))
            subject.fileList.append(.init(updatedAt: Date(timeIntervalSince1970: 0), fileURL: thirdURL))
            subject.fileList.sortItems()

            #expect(subject.fileList.items.map(\.title) == ["first", "second", "third"])

            try await subject.clearCanvas(
                device: device,
                commandQueue: commandQueue
            )

            // Cleared row gets a new updatedAt; sortItems moves it to the top.
            #expect(subject.fileList.items.map(\.title) == ["second", "first", "third"])
            #expect(subject.fileList.items[0].updatedAt == subject.project.updatedAt)
            // In-memory project metadata matches the list row.
            #expect(subject.project.updatedAt > projectUpdatedAtBefore)
            // Clear does not write the zip; persistence waits until save.
            #expect(zipHandler.zipCalls.isEmpty)
        }
    }

    @MainActor
    struct DeleteFile {

        @Test
        func `When deleting a file, it removes the zip and the list entry`() async throws {
            let fileManager = MockFileManager()
            let (device, commandQueue) = try makeMetal()

            let firstURL = zipURL(named: "first", fileManager: fileManager)
            let secondURL = zipURL(named: "second", fileManager: fileManager)
            let thirdURL = zipURL(named: "third", fileManager: fileManager)
            fileManager.appendFile(at: firstURL)
            fileManager.appendFile(at: secondURL)
            fileManager.appendFile(at: thirdURL)

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager)
            )

            subject.project.update(projectName: "first")

            subject.fileList.append(.init(fileURL: firstURL))
            subject.fileList.append(.init(fileURL: secondURL))
            subject.fileList.append(.init(fileURL: thirdURL))

            let secondIndex = try #require(subject.fileList.index(fileURL: secondURL))

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

        @Test
        func `When index is out of bounds, it throws`() async throws {
            let (device, commandQueue) = try makeMetal()
            let fileManager = MockFileManager()

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager)
            )
            subject.fileList.append(.init(fileURL: zipURL(named: "first", fileManager: fileManager)))
            subject.fileList.append(.init(fileURL: zipURL(named: "second", fileManager: fileManager)))
            subject.fileList.append(.init(fileURL: zipURL(named: "third", fileManager: fileManager)))
            #expect(subject.fileList.items.count == 3)

            await #expect(throws: NSError.self) {
                try await subject.deleteFile(
                    index: 3,
                    device: device,
                    commandQueue: commandQueue
                )
            }
        }
    }

    @MainActor
    struct SaveFile {

        @Test
        func `When saving the open file, it updates updatedAt and re-sorts the list`() async throws {
            let fileManager = MockFileManager()
            let zipHandler = MockZipHandler()
            let (device, commandQueue) = try makeMetal()

            let firstURL = zipURL(named: "first", fileManager: fileManager)
            let secondURL = zipURL(named: "second", fileManager: fileManager)
            let thirdURL = zipURL(named: "third", fileManager: fileManager)
            fileManager.appendFile(at: firstURL)
            fileManager.appendFile(at: secondURL)
            fileManager.appendFile(at: thirdURL)

            let subject: Subject = .init(
                dependencies: dependencies(fileManager: fileManager),
                documentsDataStore: .init(fileManager: fileManager, zipHandler: zipHandler)
            )

            subject.project.update(projectName: "second", updatedAt: Date(timeIntervalSince1970: 1))
            let projectUpdatedAtBefore = subject.project.updatedAt

            subject.fileList.append(.init(updatedAt: Date(timeIntervalSince1970: 2), fileURL: firstURL))
            subject.fileList.append(.init(updatedAt: Date(timeIntervalSince1970: 1), fileURL: secondURL))
            subject.fileList.append(.init(updatedAt: Date(timeIntervalSince1970: 0), fileURL: thirdURL))
            subject.fileList.sortItems()

            try await subject.makeBlankCanvas(
                device: device,
                commandQueue: commandQueue
            )

            try await subject.saveFile(
                thumbnail: nil,
                zipFileURL: secondURL
            )

            // Saved row gets a new updatedAt; sortItems moves it to the top.
            #expect(subject.fileList.items.map(\.title) == ["second", "first", "third"])
            #expect(subject.fileList.items[0].updatedAt == subject.project.updatedAt)
            #expect(subject.project.updatedAt > projectUpdatedAtBefore)
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

