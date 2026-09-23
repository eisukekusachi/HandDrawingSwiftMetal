//
//  FileViewTests
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Combine
import Foundation
import Testing
@testable import FileView

struct FileViewModelTests {

    private typealias Subject = FileViewModel

    @Suite
    @MainActor
    struct DeleteDisabled {
        @Test
        func `Verify that delete is enabled when a row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )

            subject.setup(
                selectedFileURL: fileItemB.fileURL
            )

            #expect(subject.selectedIndex == 1)
            #expect(subject.deleteDisabled == false)
        }

        @Test
        func `Verify that delete is disabled when the file list is empty`() {
            let subject: Subject = .init(
                fileList: .init(fileSuffix: "zip", items: [])
            )

            subject.setup(
                selectedFileURL: nil
            )

            #expect(subject.deleteDisabled == true)
        }

        @Test
        func `Verify that delete is disabled when no row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )

            subject.setup(
                selectedFileURL: nil
            )

            #expect(subject.selectedIndex == nil)
            #expect(subject.deleteDisabled == true)
        }

        @Test(
            arguments: [-1, 2]
        )
        func `Verify that delete is disabled when selectedIndex is out of bounds`(index: Int) {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )

            subject.setup(
                selectedFileURL: fileItemB.fileURL
            )

            subject.selectedIndex = index

            #expect(subject.deleteDisabled == true)
        }
    }

    @Suite
    @MainActor
    struct RenameDisabled {
        @Test
        func `Verify that rename is enabled when a row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )

            subject.setup(
                selectedFileURL: fileItemA.fileURL
            )

            #expect(subject.selectedIndex == 0)
            #expect(subject.renameDisabled == false)
        }

        @Test
        func `Verify that rename is disabled when the file list is empty`() {
            let subject: Subject = .init(
                fileList: .init(fileSuffix: "zip", items: [])
            )

            subject.setup(
                selectedFileURL: nil
            )

            #expect(subject.renameDisabled == true)
        }

        @Test
        func `Verify that rename is disabled when no row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )

            subject.setup(
                selectedFileURL: nil
            )

            #expect(subject.selectedIndex == nil)
            #expect(subject.renameDisabled == true)
        }

        @Test(
            arguments: [-1, 2]
        )
        func `Verify that rename is disabled when selectedIndex is out of bounds`(index: Int) {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )

            subject.setup(
                selectedFileURL: fileItemA.fileURL
            )

            subject.selectedIndex = index

            #expect(subject.renameDisabled == true)
        }
    }

    @Suite
    @MainActor
    struct SelectedIndex {
        @Test
        func `Verify that init keeps the current open file selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                ),
                currentOpenFileURL: fileItemB.fileURL
            )

            #expect(subject.selectedIndex == 1)
            #expect(subject.renameDisabled == false)
            #expect(subject.deleteDisabled == false)
        }

        @Test
        func `Verify that selectedIndex is cleared when the selected file is removed`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))
            let fileList: FileList = .init(
                fileSuffix: "zip",
                items: [fileItemA, fileItemB]
            )
            let subject: Subject = .init(
                fileList: fileList
            )
            subject.setup(
                selectedFileURL: fileItemB.fileURL
            )

            #expect(subject.selectedIndex == 1)

            fileList.deleteItem(title: fileItemB.title)

            #expect(subject.selectedIndex == nil)
        }
    }

    @Suite
    @MainActor
    struct OnTapItem {
        @Test
        func `Verify that tapping the selected item opens it when it is not the current file`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))
            var openedURL: URL?

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                ),
                eventHandler: .init(
                    onTapCreate: {},
                    onTapRename: { _, _ in
                        "renamed"
                    },
                    onTapDelete: { _ in },
                    onSelectItem: { openedURL = $0 }
                )
            )
            subject.setup(
                selectedFileURL: fileItemA.fileURL
            )

            // Highlight the item
            subject.onTapItem(at: 1)
            #expect(subject.selectedIndex == 1)

            // Open the item
            subject.onTapItem(at: 1)
            #expect(openedURL == fileItemB.fileURL)
        }

        @Test
        func `Verify that tapping the current file requests dismiss`() async {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )
            subject.setup(
                selectedFileURL: fileItemA.fileURL
            )

            var didRequestDismiss = false
            let cancellable = subject.requestingDismiss.sink {
                didRequestDismiss = true
            }

            subject.onTapItem(at: 0)

            #expect(didRequestDismiss == true)
            cancellable.cancel()
        }
    }

    @Suite
    @MainActor
    struct OnTapRename {
        @Test
        func `Verify that confirmRename sends the draft name and updates selection`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileList: FileList = .init(
                fileSuffix: "zip",
                items: [fileItemA]
            )
            var renamed: (Int, String)?

            let subject: Subject = .init(
                fileList: fileList,
                eventHandler: .init(
                    onTapCreate: {},
                    onTapRename: { index, name in
                        renamed = (index, name)
                        fileList.renameItem(title: "a", newTitle: name)
                        return name
                    },
                    onTapDelete: { _ in },
                    onSelectItem: { _ in }
                )
            )
            subject.setup(selectedFileURL: fileItemA.fileURL)

            subject.onTapRename()
            #expect(subject.isShowingRenameDialog == true)
            #expect(subject.draftName == "a")

            subject.draftName = "renamed"
            subject.confirmRename()

            #expect(renamed?.0 == 0)
            #expect(renamed?.1 == "renamed")
            #expect(subject.selectedIndex == 0)
        }

        @Test
        func `Verify that confirmRename keeps the open-file URL in sync when renaming the open file`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))
            let fileList: FileList = .init(
                fileSuffix: "zip",
                items: [fileItemA, fileItemB]
            )
            var didRequestDismiss = false
            var openedURL: URL?

            let subject: Subject = .init(
                fileList: fileList,
                currentOpenFileURL: fileItemA.fileURL,
                eventHandler: .init(
                    onTapCreate: {},
                    onTapRename: { _, name in
                        fileList.renameItem(title: "a", newTitle: name)
                        return name
                    },
                    onTapDelete: { _ in },
                    onSelectItem: { openedURL = $0 }
                )
            )
            let cancellable = subject.requestingDismiss.sink {
                didRequestDismiss = true
            }

            #expect(subject.isSelectedFileOpen == true)

            subject.onTapRename()
            subject.draftName = "renamed"
            subject.confirmRename()

            #expect(subject.isSelectedFileOpen == true)
            #expect(fileItemA.fileURL == URL(fileURLWithPath: "/tmp/renamed.zip"))

            subject.onTapItem(at: 0)

            #expect(didRequestDismiss == true)
            #expect(openedURL == nil)
            cancellable.cancel()
        }
    }

    @Suite
    @MainActor
    struct OnTapDelete {
        @Test
        func `Verify that onTapDelete shows the confirmation dialog when a row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )
            subject.setup(
                selectedFileURL: fileItemB.fileURL
            )

            #expect(subject.isShowingDeleteConfirmDialog == false)

            subject.onTapDelete()

            #expect(subject.isShowingDeleteConfirmDialog == true)
        }

        @Test
        func `Verify that onTapDelete does nothing when no row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                )
            )
            subject.setup(
                selectedFileURL: nil
            )

            subject.onTapDelete()

            #expect(subject.isShowingDeleteConfirmDialog == false)
        }

        @Test
        func `Verify that confirmDelete notifies the event handler with the selected index`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))
            var deletedIndex: Int?

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                ),
                eventHandler: .init(
                    onTapCreate: {},
                    onTapRename: { _, _ in nil },
                    onTapDelete: { deletedIndex = $0 },
                    onSelectItem: { _ in }
                )
            )
            subject.setup(
                selectedFileURL: fileItemB.fileURL
            )

            subject.confirmDelete()

            #expect(deletedIndex == 1)
        }

        @Test
        func `Verify that confirmDelete does nothing when no row is selected`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))
            var deletedIndex: Int?

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                ),
                eventHandler: .init(
                    onTapCreate: {},
                    onTapRename: { _, _ in nil },
                    onTapDelete: { deletedIndex = $0 },
                    onSelectItem: { _ in }
                )
            )
            subject.setup(
                selectedFileURL: nil
            )

            subject.confirmDelete()

            #expect(deletedIndex == nil)
        }

        @Test
        func `Verify that confirmation copy uses reset wording for the open file`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                ),
                currentOpenFileURL: fileItemA.fileURL
            )

            #expect(subject.isSelectedFileOpen == true)
            #expect(subject.deleteConfirmationTitle == "Reset this canvas?")
            #expect(subject.deleteConfirmationMessage == "The drawing will be cleared. The file will remain.")
            #expect(subject.deleteConfirmationButtonTitle == "Reset")
        }

        @Test
        func `Verify that confirmation copy uses delete wording for another file`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileList: .init(
                    fileSuffix: "zip",
                    items: [fileItemA, fileItemB]
                ),
                currentOpenFileURL: fileItemA.fileURL
            )
            subject.selectedIndex = 1

            #expect(subject.isSelectedFileOpen == false)
            #expect(subject.deleteConfirmationTitle == "Delete this file?")
            #expect(subject.deleteConfirmationMessage == "This file will be removed from the device")
            #expect(subject.deleteConfirmationButtonTitle == "Delete")
        }
    }

    @Suite
    @MainActor
    struct OnTapClose {
        @Test
        func `Verify that onTapClose requests dismiss`() async {
            let subject: Subject = .init(
                fileList: .init(fileSuffix: "zip", items: [])
            )

            var didRequestDismiss = false
            let cancellable = subject.requestingDismiss.sink {
                didRequestDismiss = true
            }

            subject.onTapClose()

            #expect(didRequestDismiss == true)
            cancellable.cancel()
        }
    }
}
