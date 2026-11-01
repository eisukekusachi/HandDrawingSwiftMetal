//
//  Created by Eisuke Kusachi
//

import CanvasView
import UIKit

@preconcurrency import CoreData

@MainActor
final class CoreDataProjectStorage {

    private let storage: any CoreDataStorageProtocol<ProjectEntity>

    convenience init(context: NSManagedObjectContext) {
        self.init(storage: CoreDataStorage(context: context))
    }

    init(storage: any CoreDataStorageProtocol<ProjectEntity>) {
        self.storage = storage
    }
}

extension CoreDataProjectStorage {

    func fetch() throws -> ProjectEntity? {
        try storage.fetch()
    }

    func update(_ entity: ProjectEntity, project: ProjectData) {
        if let projectName = entity.projectName,
           let createdAt = entity.createdAt,
           let updatedAt = entity.updatedAt {
            project.update(
                projectName: projectName,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    func update(directoryURL: URL, projectName: String, project: ProjectData) throws {
        guard
            let result = try? ProjectSnapshot(in: directoryURL)
        else {
            let error = NSError(
                title: String(localized: "Error"),
                message: String(format: String(localized: "Failed to find file in %@."), directoryURL.absoluteString)
            )
            Logger.error(error)
            throw error
        }

        project.update(
            projectName: projectName,
            createdAt: result.createdAt,
            updatedAt: result.updatedAt
        )
    }

    func save(from project: ProjectData) async {
        guard
            let context = storage.context,
            let request = storage.fetchRequest()
        else { return }

        let projectName = project.currentProjectName
        let createdAt = project.createdAt
        let updatedAt = project.updatedAt

        await context.perform { [context] in
            do {
                let entity = try context.fetch(request).first ?? ProjectEntity(context: context)

                let currentProjectName = entity.projectName
                let currentCreatedAt = entity.createdAt
                let currentUpdatedAt = entity.updatedAt

                guard
                    currentProjectName != projectName ||
                    currentCreatedAt != createdAt ||
                    currentUpdatedAt != updatedAt
                else { return }

                if entity.projectName != projectName { entity.projectName = projectName }
                if entity.createdAt != createdAt { entity.createdAt = createdAt }
                if entity.updatedAt != updatedAt { entity.updatedAt = updatedAt }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                Logger.error(error)
            }
        }
    }
}
