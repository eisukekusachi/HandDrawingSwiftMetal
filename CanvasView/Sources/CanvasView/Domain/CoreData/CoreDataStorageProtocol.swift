//
//  CoreDataStorageProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/01/11.
//

import CoreData

public protocol CoreDataStorageProtocol {
    associatedtype Entity: NSManagedObject
    var context: NSManagedObjectContext { get }
    func fetchRequest() -> NSFetchRequest<Entity>
    func fetch() throws -> Entity?
}
