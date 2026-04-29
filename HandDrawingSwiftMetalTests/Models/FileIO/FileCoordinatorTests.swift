//
//  FileCoordinatorTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2026/04/25.
//

import Foundation
import Testing

@testable import HandDrawingSwiftMetal

struct FileCoordinatorTests {

    typealias Subject = FileCoordinator

    @Suite
    @MainActor
    struct UpsertFileList {
        let dependencies = HandDrawingViewDependencies(
            localFileRepository: MockLocalFileRepository(),
            textureLayersDocumentsRepository: nil
        )

        @Test
        func `Verify that a new item is added if the name is different, and overwritten if the name is the same`() {
            let subject: Subject = .init(dependencies: dependencies)

            let idA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
            let idB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
            let idC = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
            let idD = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!

            subject.upsertFileList(
                .init(
                    id: idA,
                    title: "A"
                )
            )

            #expect(subject.fileList.count == 1)
            #expect(subject.fileList.map(\.title) == ["A"])
            #expect(subject.fileList.map(\.id) == [idA])

            subject.upsertFileList(
                .init(
                    id: idB,
                    title: "B"
                )
            )

            #expect(subject.fileList.count == 2)
            #expect(subject.fileList.map(\.title) == ["A", "B"])
            #expect(subject.fileList.map(\.id) == [idA, idB])

            subject.upsertFileList(
                .init(
                    id: idC,
                    title: "C"
                )
            )

            #expect(subject.fileList.count == 3)
            #expect(subject.fileList.map(\.title) == ["A", "B", "C"])
            #expect(subject.fileList.map(\.id) == [idA, idB, idC])

            subject.upsertFileList(
                .init(
                    id: idD,
                    title: "A"
                )
            )

            #expect(subject.fileList.count == 3)
            #expect(subject.fileList.map(\.title) == ["A", "B", "C"])
            #expect(subject.fileList.map(\.id) == [idD, idB, idC])
        }
    }

    @Suite
    @MainActor
    struct RenameItem {
        let dependencies = HandDrawingViewDependencies(
            localFileRepository: MockLocalFileRepository()
        )

        @Test
        func `Verify that the name of the item at the specified index in the fileList is overwritten`() throws {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        fileURL: urlA
                    )
                ],
                dependencies: dependencies,
                fileManagerWrapper: MockFileManagerWrapper()
            )

            #expect(subject.fileList.count == 1)

            try subject.renameFile(
                index: 0,
                oldFileURL: urlA,
                newFileURL: urlB
            )

            #expect(subject.fileList.count == 1)
            #expect(subject.fileList[0].title == urlB.baseName)
            #expect(subject.fileList[0].fileURL == urlB)
        }

        @Test(
            arguments: [-1, 1]
        )
        func `Verify that the fileList remains unchanged if the specified index is out of bounds`(index: Int) throws {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        fileURL: urlA
                    )
                ],
                dependencies: dependencies,
                fileManagerWrapper: MockFileManagerWrapper()
            )

            #expect(subject.fileList.count == 1)

            try subject.renameFile(
                index: index,
                oldFileURL: urlA,
                newFileURL: urlB
            )

            #expect(subject.fileList.count == 1)
            #expect(subject.fileList[0].title == urlA.baseName)
            #expect(subject.fileList[0].fileURL == urlA)
        }
    }

    @Suite
    @MainActor
    struct DeleteItem {
        let dependencies = HandDrawingViewDependencies(
            localFileRepository: MockLocalFileRepository()
        )

        @Test
        func `Verify that the item is removed if its URL matches an item in the fileList`() throws {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        fileURL: urlA
                    ),
                    .init(
                        title: urlB.baseName,
                        fileURL: urlB
                    )
                ],
                dependencies: dependencies,
                fileManagerWrapper: MockFileManagerWrapper()
            )

            #expect(subject.fileList.count == 2)

            try subject.deleteFile(
                fileURL: urlA
            )

            #expect(subject.fileList.count == 1)
            #expect(subject.fileList[0].fileURL == urlB)
        }

        @Test
        func `Verify that the fileList remains unchanged if the URL does not match any item in the fileList`() throws {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")
            let urlC = URL(fileURLWithPath: "/tmp/c.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        fileURL: urlA
                    ),
                    .init(
                        title: urlB.baseName,
                        fileURL: urlB
                    )
                ],
                dependencies: dependencies,
                fileManagerWrapper: MockFileManagerWrapper()
            )

            #expect(subject.fileList.count == 2)

            try subject.deleteFile(
                fileURL: urlC
            )

            #expect(subject.fileList.count == 2)
            #expect(subject.fileList[0].fileURL == urlA)
            #expect(subject.fileList[1].fileURL == urlB)
        }
    }

    @Suite
    @MainActor
    struct SortFileList {
        let dependencies = HandDrawingViewDependencies(
            localFileRepository: MockLocalFileRepository()
        )

        @Test
        func `Verify that sortFileList orders items by updatedAt with the newest first`() {
            let older = Date(timeIntervalSince1970: 1_000)
            let middle = Date(timeIntervalSince1970: 2_000)
            let newest = Date(timeIntervalSince1970: 3_000)

            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")
            let urlC = URL(fileURLWithPath: "/tmp/c.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        updatedAt: older,
                        fileURL: urlA
                    ),
                    .init(
                        title: urlB.baseName,
                        updatedAt: newest,
                        fileURL: urlB
                    ),
                    .init(
                        title: urlC.baseName,
                        updatedAt: middle,
                        fileURL: urlC
                    )
                ],
                dependencies: dependencies
            )

            #expect(subject.fileList.map(\.title) == ["a", "b", "c"])

            subject.sortFileList()

            #expect(subject.fileList.map(\.title) == ["b", "c", "a"])
            #expect(subject.fileList.map(\.updatedAt) == [newest, middle, older])
        }
    }

    @Suite
    @MainActor
    struct IndexInFileList {
        let dependencies = HandDrawingViewDependencies(
            localFileRepository: MockLocalFileRepository()
        )

        @Test
        func `Verify that index returns the position of the item with the matching URL`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        fileURL: urlA
                    ),
                    .init(
                        title: urlB.baseName,
                        fileURL: urlB
                    )
                ],
                dependencies: dependencies
            )

            #expect(subject.index(url: urlA) == 0)
            #expect(subject.index(url: urlB) == 1)
        }

        @Test
        func `Verify that index returns nil when no item has the matching URL`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")
            let urlC = URL(fileURLWithPath: "/tmp/c.zip")

            let subject: Subject = .init(
                fileList: [
                    .init(
                        title: urlA.baseName,
                        fileURL: urlA
                    ),
                    .init(
                        title: urlB.baseName,
                        fileURL: urlB
                    )
                ],
                dependencies: dependencies
            )

            #expect(subject.index(url: urlC) == nil)
        }
    }
}
