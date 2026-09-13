//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Combine
import Foundation

/// Presentation state for the saved-file list shown in FileView.
///
/// - Note: `FileItem.title` values under the Documents directory are unique,
///   so they are used as the lookup key.
/// - Note: Only items that match `naming` are kept.
@MainActor
public final class FileList: ObservableObject {

    /// Domain rules for file names and supported extensions.
    public let naming: FileNaming

    /// Path extension without `.` accepted by this list.
    public var fileSuffix: String { naming.fileSuffix }

    /// Files shown in the list
    @Published public private(set) var items: [FileItem] = []

    public init(
        naming: FileNaming,
        items: [FileItem] = []
    ) {
        self.naming = naming
        self.items = items.filter { naming.isSupportedFileURL($0.fileURL) }
    }

    public convenience init(
        fileSuffix: String,
        items: [FileItem] = []
    ) {
        self.init(
            naming: .init(fileSuffix: fileSuffix),
            items: items
        )
    }
}

extension FileList {
    /// Returns the index of the first item that matches the specified title
    public func index(title: String) -> Int? {
        items.firstIndex(where: { $0.title == title })
    }

    /// Returns the index of the item whose title matches `fileURL.baseName`.
    public func index(fileURL: URL?) -> Int? {
        guard let fileURL else { return nil }
        return index(title: fileURL.baseName)
    }

    public func item(_ index: Int) -> FileItem? {
        guard index >= 0 && index < items.count else {
            return nil
        }
        return items[index]
    }

    /// Sets an item by title: updates the matching item, or appends if not found.
    /// Items that do not match `naming` are ignored.
    public func setItem(_ item: FileItem) {
        guard naming.isSupportedFileURL(item.fileURL) else { return }

        var items = self.items

        if let index = items.firstIndex(where: { $0.title == item.title }) {
            items[index].update(
                updatedAt: item.updatedAt,
                thumbnail: item.thumbnail
            )
        } else {
            items.append(item)
        }

        self.items = items
    }

    /// Sorts items using the given predicate.
    public func sortItems(
        by order: (FileItem, FileItem) -> Bool = { $0.updatedAt > $1.updatedAt }
    ) {
        var items = self.items
        items.sort(by: order)
        self.items = items
    }

    /// Loads items from the given file URLs.
    ///
    /// Existing titles are reused so `makeItem` runs only for new URLs.
    /// That matters when `makeItem` is expensive (e.g. unzip).
    public func loadItems(
        from fileURLs: [URL],
        by order: (FileItem, FileItem) -> Bool = { $0.updatedAt > $1.updatedAt },
        makeItem: (URL) async -> FileItem?
    ) async {
        let fileURLs = fileURLs.filter(naming.isSupportedFileURL)

        let existingByTitle = Dictionary(
            uniqueKeysWithValues: items.map { ($0.title, $0) }
        )

        var items: [FileItem] = []

        for fileURL in fileURLs {
            let title = fileURL.baseName
            if let existing = existingByTitle[title] {
                if existing.fileURL != fileURL {
                    existing.update(fileURL: fileURL)
                }
                items.append(existing)
            } else if let item = await makeItem(fileURL) {
                items.append(item)
            }
        }

        items.sort(by: order)
        self.items = items.filter { naming.isSupportedFileURL($0.fileURL) }
    }

    /// Renames the item with the matching title
    public func renameItem(
        title: String,
        newTitle: String
    ) {
        guard let index = index(title: title) else { return }

        let item = items[index]
        let newFileURL = URL.fileURL(
            in: item.fileURL.deletingLastPathComponent(),
            name: newTitle,
            fileSuffix: naming.fileSuffix
        )

        var items = self.items
        items[index].update(
            fileURL: newFileURL
        )
        self.items = items
    }

    /// Removes the matching item from the list
    public func deleteItem(title: String) {
        var items = self.items
        items.removeAll { $0.title == title }
        self.items = items
    }
}
