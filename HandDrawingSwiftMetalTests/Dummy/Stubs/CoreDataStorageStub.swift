//
//  Created by Eisuke Kusachi
//

@preconcurrency import CoreData
@testable import HandDrawingSwiftMetal

/// In-memory `CoreDataStorageProtocol` for unit tests (no SQLite stack required).
@MainActor
final class CoreDataStorageStub<Entity: NSManagedObject>: CoreDataStorageProtocol {

    var context: NSManagedObjectContext?

    var fetchedEntity: Entity?
    var clearAllCallCount = 0

    func fetchRequest() -> NSFetchRequest<Entity>? { nil }

    func fetch() throws -> Entity? {
        fetchedEntity
    }

    func clearAll() throws {
        clearAllCallCount += 1
        fetchedEntity = nil
    }
}
