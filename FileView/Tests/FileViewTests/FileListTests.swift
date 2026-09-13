//
//  FileViewTests
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Foundation
import Testing
import UIKit
@testable import FileView

struct FileListTests {

    private typealias Subject = FileList

    @Suite
    @MainActor
    struct SetItem {
        @Test
        func `Verify that a new item is added if the title is different, and updated if the title is the same`() {
            let subject: Subject = .init(fileSuffix: "zip")

            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))
            let fileItemC = FileItem(fileURL: URL(fileURLWithPath: "/tmp/c.zip"))

            let newUpdatedAt = Date()
            let fileItemUpdated = FileItem(
                updatedAt: newUpdatedAt,
                fileURL: fileItemA.fileURL
            )

            subject.setItem(fileItemA)

            #expect(subject.items.count == 1)
            #expect(subject.items.map(\.fileURL) == [
                fileItemA.fileURL
            ])

            subject.setItem(fileItemB)

            #expect(subject.items.count == 2)
            #expect(subject.items.map(\.fileURL) == [
                fileItemA.fileURL,
                fileItemB.fileURL
            ])

            subject.setItem(fileItemC)

            #expect(subject.items.count == 3)
            #expect(subject.items.map(\.fileURL) == [
                fileItemA.fileURL,
                fileItemB.fileURL,
                fileItemC.fileURL
            ])

            subject.setItem(fileItemUpdated)

            #expect(subject.items.count == 3)
            // Same title keeps `fileURL` unchanged.
            #expect(subject.items.map(\.fileURL) == [
                fileItemA.fileURL,
                fileItemB.fileURL,
                fileItemC.fileURL
            ])
            // Updates `updatedAt`.
            #expect(subject.items[0].updatedAt == newUpdatedAt)
        }
    }

    @Suite
    @MainActor
    struct SortItems {
        @Test
        func `Verify that sortItems orders items by updatedAt with the newest first`() {
            let fileItemA = FileItem(
                updatedAt: Date(timeIntervalSince1970: 1_000),
                fileURL: URL(fileURLWithPath: "/tmp/a.zip")
            )
            let fileItemB = FileItem(
                updatedAt: Date(timeIntervalSince1970: 3_000),
                fileURL: URL(fileURLWithPath: "/tmp/b.zip")
            )
            let fileItemC = FileItem(
                updatedAt: Date(timeIntervalSince1970: 2_000),
                fileURL: URL(fileURLWithPath: "/tmp/c.zip")
            )

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [fileItemA, fileItemB, fileItemC]
            )

            #expect(subject.items.map(\.title) == ["a", "b", "c"])

            subject.sortItems()

            #expect(subject.items.map(\.title) == ["b", "c", "a"])
            #expect(subject.items.map(\.updatedAt) == [
                fileItemB.updatedAt,
                fileItemC.updatedAt,
                fileItemA.updatedAt
            ])
        }
    }

    @Suite
    @MainActor
    struct LoadItems {
        @Test
        func `Verify that loadItems builds sorted items from the given URLs`() async {
            let older = FileItem(
                updatedAt: Date(timeIntervalSince1970: 1_000),
                fileURL: URL(fileURLWithPath: "/tmp/older.zip")
            )
            let newer = FileItem(
                updatedAt: Date(timeIntervalSince1970: 2_000),
                fileURL: URL(fileURLWithPath: "/tmp/newer.zip")
            )
            let ignored = FileItem(
                updatedAt: Date(timeIntervalSince1970: 3_000),
                fileURL: URL(fileURLWithPath: "/tmp/ignored.txt")
            )

            let subject: Subject = .init(fileSuffix: "zip")

            await subject.loadItems(
                from: [
                    older.fileURL,
                    newer.fileURL,
                    ignored.fileURL
                ]
            ) { fileURL in
                // Production would create a FileItem here, the test reuses the fixtures above.
                [newer, older, ignored].first { $0.fileURL == fileURL }
            }

            // Only suffix-matching items remain, sorted by updatedAt descending.
            #expect(subject.items.map(\.fileURL) == [
                newer.fileURL,
                older.fileURL
            ])
        }

        @Test
        func `Verify that loadItems reuses existing titles and only builds new ones`() async {
            let existing = FileItem(
                updatedAt: Date(timeIntervalSince1970: 1_000),
                fileURL: URL(fileURLWithPath: "/tmp/existing.zip")
            )
            let newItem = FileItem(
                updatedAt: Date(timeIntervalSince1970: 2_000),
                fileURL: URL(fileURLWithPath: "/tmp/new.zip")
            )
            let removed = FileItem(
                updatedAt: Date(timeIntervalSince1970: 3_000),
                fileURL: URL(fileURLWithPath: "/tmp/removed.zip")
            )

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [existing, removed]
            )

            var madeURLs: [URL] = []

            await subject.loadItems(
                from: [existing.fileURL, newItem.fileURL]
            ) { fileURL in
                madeURLs.append(fileURL)
                // Production would create a FileItem here; the test reuses the fixtures above.
                return [newItem].first { $0.fileURL == fileURL }
            }

            // New titles are added,
            // existing titles are reused,
            // titles absent from the input URLs are removed.
            #expect(madeURLs == [newItem.fileURL])
            #expect(subject.items.map(\.fileURL) == [newItem.fileURL, existing.fileURL])
            #expect(subject.items.contains { $0 === existing })
            #expect(subject.items.contains { $0.title == "removed" } == false)
        }

        @Test
        func `Verify that loadItems does not refresh metadata for existing titles`() async {
            let existing = FileItem(
                updatedAt: Date(timeIntervalSince1970: 1_000),
                fileURL: URL(fileURLWithPath: "/tmp/existing.zip")
            )
            let newItem = FileItem(
                updatedAt: Date(timeIntervalSince1970: 9_000),
                thumbnail: UIImage(),
                fileURL: existing.fileURL
            )
            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [existing]
            )

            var madeURLs: [URL] = []

            await subject.loadItems(from: [existing.fileURL]) { fileURL in
                madeURLs.append(fileURL)
                // Production would create a FileItem here; the test reuses the fixtures above.
                return [newItem].first { $0.fileURL == fileURL }
            }

            // If the file URL is already registered, makeItem is skipped.
            #expect(madeURLs.isEmpty)
            #expect(subject.items.count == 1)
            #expect(subject.items[0] === existing)
            #expect(subject.items[0].updatedAt == existing.updatedAt)
            #expect(subject.items[0].thumbnail == nil)
        }
    }

    @Suite
    @MainActor
    struct IndexInItems {
        @Test
        func `Verify that index returns the position of the matching item`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [
                    .init(fileURL: urlA),
                    .init(fileURL: urlB)
                ]
            )

            #expect(subject.index(title: "a") == 0)
            #expect(subject.index(title: "b") == 1)
            #expect(subject.index(fileURL: urlB) == 1)
        }

        @Test
        func `Verify that index returns nil when no item matches`() {
            let urlA = URL(fileURLWithPath: "/tmp/a.zip")
            let urlB = URL(fileURLWithPath: "/tmp/b.zip")

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [
                    .init(fileURL: urlA),
                    .init(fileURL: urlB)
                ]
            )

            #expect(subject.index(title: "c") == nil)
            #expect(subject.index(fileURL: nil) == nil)
            #expect(subject.index(fileURL: URL(fileURLWithPath: "/tmp/c.zip")) == nil)
        }
    }

    @Suite
    @MainActor
    struct FileSuffixFilter {
        @Test
        func `Verify that init keeps only items matching fileSuffix`() {
            let zipItem = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let txtItem = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.txt"))

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [zipItem, txtItem]
            )

            #expect(subject.items.map(\.fileURL) == [zipItem.fileURL])
        }

        @Test
        func `Verify that setItem ignores items that do not match fileSuffix`() {
            let subject: Subject = .init(fileSuffix: "zip")
            let txtItem = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.txt"))

            subject.setItem(txtItem)

            #expect(subject.items.isEmpty)
        }
    }

    @Suite
    @MainActor
    struct RenameItem {
        @Test
        func `Verify that the name of the matching item is overwritten`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [fileItemA]
            )

            #expect(subject.items[0].title == "a")
            #expect(subject.items[0].fileURL == URL(fileURLWithPath: "/tmp/a.zip"))

            subject.renameItem(
                title: "a",
                newTitle: "b"
            )

            #expect(subject.items[0].title == "b")
            #expect(subject.items[0].fileURL == URL(fileURLWithPath: "/tmp/b.zip"))
        }

        @Test
        func `Verify that the items remain unchanged if the title does not match any item`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [fileItemA]
            )

            subject.renameItem(
                title: "c",
                newTitle: "b"
            )

            #expect(subject.items[0].title == fileItemA.title)
            #expect(subject.items[0].fileURL == fileItemA.fileURL)
        }
    }

    @Suite
    @MainActor
    struct DeleteItem {
        @Test
        func `Verify that the item is removed if its title matches an existing item`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [fileItemA, fileItemB]
            )

            #expect(subject.items.count == 2)

            subject.deleteItem(
                title: fileItemA.title
            )

            #expect(subject.items.count == 1)
            #expect(subject.items[0].fileURL == fileItemB.fileURL)
        }

        @Test
        func `Verify that the items remain unchanged if the title does not match any item`() {
            let fileItemA = FileItem(fileURL: URL(fileURLWithPath: "/tmp/a.zip"))
            let fileItemB = FileItem(fileURL: URL(fileURLWithPath: "/tmp/b.zip"))

            let subject: Subject = .init(
                fileSuffix: "zip",
                items: [fileItemA, fileItemB]
            )

            #expect(subject.items.count == 2)

            subject.deleteItem(
                title: "c"
            )

            #expect(subject.items.count == 2)
            #expect(subject.items[0].fileURL == fileItemA.fileURL)
            #expect(subject.items[1].fileURL == fileItemB.fileURL)
        }
    }
}

