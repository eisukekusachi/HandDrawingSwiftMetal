//
//  FileView
//
//  Created by Eisuke Kusachi on 2026/09/01.
//

import Combine
import Core
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

    /// Appends an item to the list.
    public func append(_ item: FileItem) {
        var items = self.items
        items.append(item)
        self.items = items
    }

    /// Updates the row with the same title.
    public func update(_ item: FileItem) {
        guard let index = index(title: item.title) else { return }

        let items = self.items
        items[index].update(
            updatedAt: item.updatedAt,
            thumbnail: .set(item.thumbnail)
        )
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

    /// Updates the list from `fileURLs` (one row per URL, sorted by `order`).
    ///
    /// Rows whose title is already in memory are reused unchanged; `makeItemFromDocuments` runs only for new titles.
    public func updateItems(
        from fileURLs: [URL],
        by order: (FileItem, FileItem) -> Bool = { $0.updatedAt > $1.updatedAt },
        makeItemFromDocuments: (URL) async throws -> FileItem?
    ) async rethrows {
        let supportedURLs = fileURLs.filter(naming.isSupportedFileURL)

        let existingItemDictionary = Dictionary(
            uniqueKeysWithValues: items.map { ($0.title, $0) }
        )

        var loadedItems: [FileItem] = []
        loadedItems.reserveCapacity(supportedURLs.count)

        for fileURL in supportedURLs {
            let title = fileURL.baseName

            // Reuse the in-memory row; otherwise load from disk.
            if let existing = existingItemDictionary[title] {
                loadedItems.append(existing)
            } else if let newRow = try await makeItemFromDocuments(fileURL) {
                loadedItems.append(newRow)
            }
        }

        loadedItems.sort(by: order)
        self.items = loadedItems
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

        let items = self.items
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
