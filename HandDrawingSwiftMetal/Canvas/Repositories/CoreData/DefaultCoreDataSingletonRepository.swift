//
//  DefaultCoreDataSingletonRepository.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Combine
import CoreData
import Foundation

final class DefaultCoreDataSingletonRepository: CoreDataRepository {

    static let shared = DefaultCoreDataSingletonRepository()

    private let repository = DefaultCoreDataRepository(
        entityName: "CanvasStorageEntity",
        persistentContainerName: "CanvasStorage"
    )

    var entityName: String {
        repository.entityName
    }

    var persistentContainerName: String {
        repository.persistentContainerName
    }

    var context: NSManagedObjectContext {
        repository.context
    }

    func fetchEntity() throws -> NSManagedObject? {
        try repository.fetchEntity()
    }

    func saveContext() throws {
        try repository.saveContext()
    }
}
