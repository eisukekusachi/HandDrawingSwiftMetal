//
//  Created by Eisuke Kusachi
//

@preconcurrency import CoreData

@MainActor
final class CoreDataProjectStorage: CoreDataStorage<ProjectEntity> {

    init(context: NSManagedObjectContext) {
        super.init(context: context)
    }

    init(storage: any CoreDataStorageProtocol<ProjectEntity>) {
        super.init(injecting: storage)
    }
}

extension CoreDataProjectStorage {

    func save(from project: ProjectData) async {
        guard
            let context = resolvedContext(),
            let request = resolvedFetchRequest()
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
