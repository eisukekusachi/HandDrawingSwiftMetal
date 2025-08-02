//
//  DefaultCoreDataRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Foundation
import CoreData

final class DefaultCoreDataRepository: CoreDataRepository {

    let entityName: String
    let persistentContainerName: String

    init(
        entityName: String,
        persistentContainerName: String
    ) {
        self.entityName = entityName
        self.persistentContainerName = persistentContainerName
    }

    /*
    // Use the main bundle in the main app
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: persistentContainerName)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("CoreData Load Error: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    */

    // Use `module` when working with Swift Package Manager
    private lazy var persistentContainer: NSPersistentContainer = {
        guard let modelURL = Bundle.module.url(forResource: persistentContainerName, withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model from module bundle")
        }

        let container = NSPersistentContainer(name: persistentContainerName, managedObjectModel: model)

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("CoreData Load Error: \(error), \(error.userInfo)")
            }
        }

        return container
    }()

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func fetchEntity() throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    func saveContext() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}
