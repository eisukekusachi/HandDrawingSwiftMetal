//
//  CoreDataStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import CoreData

public final class CoreDataStorage<Entity: NSManagedObject>: CoreDataStorageProtocol {
    public let context: NSManagedObjectContext?

    public init(
        context: NSManagedObjectContext?
    ) {
        self.context = context
    }

    public func fetchRequest() -> NSFetchRequest<Entity> {
        let request = Entity.fetchRequest()
        request.fetchLimit = 1
        request.returnsObjectsAsFaults = false
        return request as! NSFetchRequest<Entity>
    }

    public func fetch() throws -> Entity? {
        try context?.fetch(fetchRequest()).first
    }
}
