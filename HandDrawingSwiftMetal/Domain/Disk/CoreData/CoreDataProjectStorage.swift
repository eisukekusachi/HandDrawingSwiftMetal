//
//  Created by Eisuke Kusachi
//

@preconcurrency import CoreData

/// Core Data read/write for project metadata.
@MainActor
final class CoreDataProjectStorage {

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func fetch() throws -> ProjectEntity? {
        try CoreDataRootEntityStore.fetch(for: ProjectEntity.self, in: context)
    }

    func clearAll() throws {
        try CoreDataRootEntityStore.clearAll(for: ProjectEntity.self, in: context)
    }

    func save(from project: ProjectData) async {
        guard let request = CoreDataRootEntityStore.fetchRequest(for: ProjectEntity.self, in: context) else {
            return
        }

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
