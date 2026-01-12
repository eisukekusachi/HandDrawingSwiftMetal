//
//  CoreDataTestHelper.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/01/11.
//

import CoreData

enum CoreDataTestHelper {
    static func makeInMemoryContext(modelName: String = "CanvasStorage") -> NSManagedObjectContext {
        // Load model from Bundle.module
        guard
            let modelURL = Bundle.module.url(forResource: modelName, withExtension: "momd"),
            let model = NSManagedObjectModel(contentsOf: modelURL)
        else {
            fatalError("Failed to load \(modelName).momd from Bundle.module")
        }

        // Create container with in-memory store
        let container = NSPersistentContainer(name: modelName, managedObjectModel: model)

        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]

        container.loadPersistentStores { _, error in
            precondition(error == nil, "Failed to load in-memory store: \(error!)")
        }

        return container.viewContext
    }
}
