//
//  AnyCoreDataStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import CoreData

/// The debounce duration before performing a save operation.
public let saveDebounceMilliseconds: Int = 500

public protocol CoreDataStorageProtocol {
    associatedtype Entity: NSManagedObject
    var context: NSManagedObjectContext? { get }
    func fetchRequest() -> NSFetchRequest<Entity>
    func fetch() throws -> Entity?
}

public struct AnyCoreDataStorage<Entity: NSManagedObject>: CoreDataStorageProtocol {
    public let context: NSManagedObjectContext?

    private let _fetchRequest: () -> NSFetchRequest<Entity>
    private let _fetch: () throws -> Entity?

    public init<S: CoreDataStorageProtocol>(_ storage: S) where S.Entity == Entity {
        self.context = storage.context
        self._fetchRequest = storage.fetchRequest
        self._fetch = storage.fetch
    }

    public func fetchRequest() -> NSFetchRequest<Entity> { _fetchRequest() }
    public func fetch() throws -> Entity? { try _fetch() }
}
