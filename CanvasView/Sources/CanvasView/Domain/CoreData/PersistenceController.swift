//
//  PersistenceController.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/23.
//

import CoreData

public final class PersistenceController {
    public enum ModelLocation {
        case mainApp
        case swiftPackageManager
    }

    public var viewContext: NSManagedObjectContext { container.viewContext }

    private let container: NSPersistentContainer

    public init(xcdatamodeldName: String, location: ModelLocation, excludeFromBackup: Bool = true) {
        let bundle: Bundle = {
            switch location {
            case .mainApp: return .main
            case .swiftPackageManager: return .module
            }
        }()

        guard
            let modelURL = bundle.url(forResource: xcdatamodeldName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load Core Data model '\(xcdatamodeldName)' from bundle: \(bundle)")
        }

        container = NSPersistentContainer(name: xcdatamodeldName, managedObjectModel: model)

        container.loadPersistentStores { storeDescription, _error in
            precondition(_error == nil, "Store load failed: \(_error!)")

            if excludeFromBackup {
                self.excludeStoreFilesFromBackup()
            }
        }

        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
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
