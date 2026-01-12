//
//  MockCoreDataStorage.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/01/11.
//

import CoreData

struct MockCoreDataStorage<E: NSManagedObject>: CoreDataStorageProtocol {
    let context: NSManagedObjectContext?
    let value: E?

    func fetchRequest() -> NSFetchRequest<E> { NSFetchRequest<E>() }
    func fetch() throws -> E? { value }
}
