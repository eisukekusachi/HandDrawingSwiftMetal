//
//  Created by Eisuke Kusachi
//

import CoreData
import Foundation

/// Core Data storage for one model (`.xcdatamodeld`).
final class CoreDataStorage {

    var viewContext: NSManagedObjectContext { container.viewContext }

    private let container: NSPersistentContainer

    /// Core Data stack backed by **SQLite on disk** (default for the app).
    init(xcdatamodeldName: String, excludeFromBackup: Bool = true) {
        let bundle: Bundle = .main

        guard
            let modelURL = bundle.url(forResource: xcdatamodeldName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load Core Data model '\(xcdatamodeldName)' from bundle: \(bundle)")
        }

        container = NSPersistentContainer(name: xcdatamodeldName, managedObjectModel: model)

        container.loadPersistentStores { _, error in
            precondition(error == nil, "Store load failed: \(error!)")
            if excludeFromBackup {
                Self.excludeStoreFilesFromBackup(container: self.container)
            }
        }

        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Core Data stack backed by **in-memory store** (discarded on `deinit`).
    init(inMemory xcdatamodeldName: String, bundle: Bundle = .main) {
        guard
            let modelURL = bundle.url(forResource: xcdatamodeldName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load Core Data model '\(xcdatamodeldName)' from bundle: \(bundle)")
        }

        container = NSPersistentContainer(name: xcdatamodeldName, managedObjectModel: model)

        // In-memory store. nothing is written to disk.
        // The store is discarded when this `CoreDataStorage` is deallocated.
        // When a test method’s locals go out of scope.
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            precondition(error == nil, "Store load failed: \(error!)")
        }

        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func excludeStoreFilesFromBackup(container: NSPersistentContainer) {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            guard store.type == NSSQLiteStoreType, let baseURL = store.url else { continue }

            let walURL = baseURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            let shmURL = baseURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

            [baseURL, walURL, shmURL].forEach { setExcludedFromBackup(true, for: $0) }
        }
    }

    private static func setExcludedFromBackup(_ exclude: Bool, for url: URL) {
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

// MARK: - Root entity fetch / clear

@MainActor
enum CoreDataRootEntityStore {

    static func fetchRequest<Entity: NSManagedObject>(
        for entityType: Entity.Type,
        in context: NSManagedObjectContext
    ) -> NSFetchRequest<Entity>? {
        let name = entityType.entity().name
        guard let entityName = name, !entityName.isEmpty else { return nil }

        guard
            let model = context.persistentStoreCoordinator?.managedObjectModel,
            model.entitiesByName[entityName] != nil
        else { return nil }

        let request = NSFetchRequest<Entity>(entityName: entityName)
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        return request
    }

    static func fetch<Entity: NSManagedObject>(
        for entityType: Entity.Type,
        in context: NSManagedObjectContext
    ) throws -> Entity? {
        guard let request = fetchRequest(for: entityType, in: context) else { return nil }
        return try context.fetch(request).first
    }

    static func clearAll<Entity: NSManagedObject>(
        for entityType: Entity.Type,
        in context: NSManagedObjectContext
    ) throws {
        guard let entityName = entityType.entity().name else { return }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        try context.execute(deleteRequest)
        context.reset()
    }
}
