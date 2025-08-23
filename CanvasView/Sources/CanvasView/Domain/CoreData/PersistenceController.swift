//
//  PersistenceController.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import CoreData

public final class PersistenceController {

    public var context: NSManagedObjectContext { container.viewContext }

    private let container: NSPersistentContainer

    public init(modelName: String, excludeFromBackup: Bool = true) {
        container = NSPersistentContainer(name: modelName)

        container.loadPersistentStores { storeDescription, _error in
            precondition(_error == nil, "Store load failed: \(_error!)")

            if excludeFromBackup {
                self.excludeStoreFilesFromBackup()
            }
        }

        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    public func saveIfNeeded() throws {
        if context.hasChanges { try context.save() }
    }

    private func excludeStoreFilesFromBackup() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            guard store.type == NSSQLiteStoreType, let baseURL = store.url else { continue }

            let walURL = baseURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let shmURL = baseURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

            [baseURL, walURL, shmURL].forEach { setExcludedFromBackup(true, for: $0) }
        }
    }

    private func setExcludedFromBackup(_ exclude: Bool, for url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            var values = URLResourceValues()
            values.isExcludedFromBackup = exclude
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        } catch {
            print("⚠️ Failed to set isExcludedFromBackup for \(url.lastPathComponent): \(error)")
        }
    }
}
