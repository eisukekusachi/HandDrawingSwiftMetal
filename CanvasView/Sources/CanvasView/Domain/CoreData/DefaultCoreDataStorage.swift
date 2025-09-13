//
//  DefaultCoreDataStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/05/03.
//

import Foundation
import CoreData

public final class DefaultCoreDataStorage: CoreDataStorage {
    public enum ModelLocation {
        case mainApp
        case swiftPackageManager
    }

    public let entityName: String

    public let persistentContainer: NSPersistentContainer

    public init(
        name persistentContainerName: String,
        entityName: String,
        type: ModelLocation
    ) {
        let bundle: Bundle = {
            switch type {
            case .mainApp: return .main
            case .swiftPackageManager: return .module
            }
        }()

        guard
            let modelURL = bundle.url(forResource: persistentContainerName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load Core Data model '\(persistentContainerName)' from bundle: \(bundle)")
        }

        let container = NSPersistentContainer(name: persistentContainerName, managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("CoreData Load Error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        container.viewContext.automaticallyMergesChangesFromParent = true

        self.entityName = entityName
        self.persistentContainer = container
    }

    public var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    public func saveContext() throws {
        if context.hasChanges { try context.save() }
    }
}
