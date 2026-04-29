//
//  FileViewModelTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2026/04/26.
//

import Foundation
import Testing

@testable import HandDrawingSwiftMetal

struct FileViewModelTests {

    typealias Subject = FileViewModel

    @Suite
    @MainActor
    struct CreateDisabled {

        private func fileCoordinator(
            fileURLs: [URL] = []
        ) -> FileCoordinator {
            let dependencies = HandDrawingViewDependencies(
                localFileRepository: MockLocalFileRepository()
            )
            let items: [LocalFileItem] = fileURLs.map { url in
                LocalFileItem(
                    title: url.baseName,
                    fileURL: url
                )
            }
            return FileCoordinator(
                fileList: items,
                dependencies: dependencies,
                fileSuffix: "zip",
                fileManagerWrapper: MockFileManagerWrapper()
            )
        }

        @Test
        func `Verify that create is enabled when createAction exists`() {
            let subject: Subject = .init(
                fileCoordinator: fileCoordinator()
            )

            subject.configure(
                canCreate: true
            )

            #expect(subject.createDisabled == false)
        }

        @Test
        func `Verify that create is disabled when createAction is nil`() {
            let subject: Subject = .init(
                fileCoordinator: fileCoordinator()
            )

            subject.configure(
                canCreate: false
            )

            #expect(subject.createDisabled == true)
        }
    }

    @Suite
    @MainActor
    struct DeleteDisabled {

        private func fileCoordinator(
            fileURLs: [URL]
        ) -> FileCoordinator {
            let dependencies = HandDrawingViewDependencies(
                localFileRepository: MockLocalFileRepository()
            )
            let items: [LocalFileItem] = fileURLs.map { url in
                LocalFileItem(
                    title: url.baseName,
                    fileURL: url
                )
            }
            return FileCoordinator(
                fileList: items,
                dependencies: dependencies,
                fileSuffix: "zip",
                fileManagerWrapper: MockFileManagerWrapper()
            )
        }

        @Test
        func `Verify that delete is enabled when deleteAction exists and the selection is not the open file`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                currentOpenFileURL: urlA,
                selectedFileURL: urlB,
                canDelete: true
            )

            #expect(subject.selectedIndex == 1)
            #expect(subject.deleteDisabled == false)
        }

        @Test
        func `Verify that delete is disabled when deleteAction is nil`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                currentOpenFileURL: urlA,
                selectedFileURL: urlB,
                canDelete: false
            )

            #expect(subject.deleteDisabled == true)
        }

        @Test
        func `Verify that delete is disabled when no row is selected`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                currentOpenFileURL: urlA,
                selectedFileURL: nil,
                canDelete: true
            )

            #expect(subject.selectedIndex == nil)
            #expect(subject.deleteDisabled == true)
        }

        @Test(
            arguments: [-1, 2]
        )
        func `Verify that delete is disabled when selectedIndex is out of bounds`(index: Int) {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                currentOpenFileURL: urlA,
                selectedFileURL: urlB,
                canDelete: true
            )

            subject.selectedIndex = index

            #expect(subject.deleteDisabled == true)
        }

        @Test
        func `Verify that delete is disabled when the selected row is the currently open file`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                currentOpenFileURL: urlA,
                selectedFileURL: urlA,
                canDelete: true
            )

            #expect(subject.selectedIndex == 0)
            #expect(subject.deleteDisabled == true)
        }
    }

    @Suite
    @MainActor
    struct RenameDisabled {

        private func fileCoordinator(
            fileURLs: [URL]
        ) -> FileCoordinator {
            let dependencies = HandDrawingViewDependencies(
                localFileRepository: MockLocalFileRepository()
            )
            let items: [LocalFileItem] = fileURLs.map { url in
                LocalFileItem(
                    title: url.baseName,
                    fileURL: url
                )
            }
            return FileCoordinator(
                fileList: items,
                dependencies: dependencies,
                fileSuffix: "zip",
                fileManagerWrapper: MockFileManagerWrapper()
            )
        }

        @Test
        func `Verify that rename is enabled when renameAction exists and a row is selected`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                selectedFileURL: urlA,
                canRename: true
            )

            #expect(subject.selectedIndex == 0)
            #expect(subject.renameDisabled == false)
        }

        @Test
        func `Verify that rename is disabled when renameAction is nil`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                selectedFileURL: urlA,
                canRename: false
            )

            #expect(subject.selectedIndex == 0)
            #expect(subject.renameDisabled == true)
        }

        @Test
        func `Verify that rename is disabled when no row is selected`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                selectedFileURL: nil,
                canRename: true
            )

            #expect(subject.selectedIndex == nil)
            #expect(subject.renameDisabled == true)
        }

        @Test(
            arguments: [-1, 2]
        )
        func `Verify that rename is disabled when selectedIndex is out of bounds`(index: Int) {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileCoordinator: fileCoordinator(fileURLs: [urlA, urlB])
            )

            subject.configure(
                selectedFileURL: urlA,
                canRename: true
            )

            subject.selectedIndex = index

            #expect(subject.renameDisabled == true)
        }
    }
}
