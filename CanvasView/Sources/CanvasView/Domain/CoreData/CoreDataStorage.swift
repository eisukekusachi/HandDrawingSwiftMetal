//
//  CoreDataStorage.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/15.
//

import CoreData

public protocol CoreDataStorageProtocol {
    associatedtype Entity: NSManagedObject
    var context: NSManagedObjectContext? { get }
    func fetchRequest() -> NSFetchRequest<Entity>?
    func fetch() throws -> Entity?
}

public final class CoreDataStorage<Entity: NSManagedObject>: CoreDataStorageProtocol {
    public let context: NSManagedObjectContext?

    public init(context: NSManagedObjectContext?) {
        self.context = context
    }

    public func fetchRequest() -> NSFetchRequest<Entity>? {
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

    public func fetch() throws -> Entity? {
        guard let context, let request = fetchRequest() else { return nil }
        return try context.fetch(request).first
    }
}
