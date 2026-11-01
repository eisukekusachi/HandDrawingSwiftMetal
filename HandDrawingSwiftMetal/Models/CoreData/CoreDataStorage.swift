//
//  Created by Eisuke Kusachi
//

import CoreData
import Foundation

/// Core Data fetch / clear access for a single root entity type.
@MainActor
protocol CoreDataStorageProtocol<Entity>: AnyObject {
    associatedtype Entity: NSManagedObject
    var context: NSManagedObjectContext? { get }
    func fetchRequest() -> NSFetchRequest<Entity>?
    func fetch() throws -> Entity?
    func clearAll() throws
}

@MainActor
class CoreDataStorage<Entity: NSManagedObject>: CoreDataStorageProtocol {
    let context: NSManagedObjectContext?
    private let backend: (any CoreDataStorageProtocol<Entity>)?

    init(context: NSManagedObjectContext?) {
        self.context = context
        self.backend = nil
    }

    init(injecting backend: any CoreDataStorageProtocol<Entity>) {
        self.context = backend.context
        self.backend = backend
    }

    func fetchRequest() -> NSFetchRequest<Entity>? {
        if let backend {
            return backend.fetchRequest()
        }
        guard let context else { return nil }

        let name = Entity.entity().name
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

    func fetch() throws -> Entity? {
        if let backend {
            return try backend.fetch()
        }
        guard let context, let request = fetchRequest() else { return nil }
        return try context.fetch(request).first
    }

    func clearAll() throws {
        if let backend {
            try backend.clearAll()
            return
        }
        guard let context else { return }
        guard let entityName = Entity.entity().name else { return }

        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)

        try context.execute(deleteRequest)
        context.reset()
    }
}

@MainActor
extension CoreDataStorage {
    func resolvedContext() -> NSManagedObjectContext? {
        backend?.context ?? context
    }

    func resolvedFetchRequest() -> NSFetchRequest<Entity>? {
        fetchRequest()
    }
}
