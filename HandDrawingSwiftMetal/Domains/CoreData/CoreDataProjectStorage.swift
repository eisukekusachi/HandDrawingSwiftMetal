//
//  CoreDataProjectStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import CanvasView
import Combine
import UIKit

@preconcurrency import CoreData

@MainActor
final class CoreDataProjectStorage {

    private let project: ProjectData

    private let storage: AnyCoreDataStorage<ProjectEntity>?
    private var cancellables = Set<AnyCancellable>()

    private let entityNameInModel = "ProjectEntity"

    init(project: ProjectData, storage: AnyCoreDataStorage<ProjectEntity>?) {
        self.project = project
        self.storage = storage

        // Save to Core Data when the properties are updated
        Publishers.Merge3(
            self.project.$projectName.map { _ in () }.eraseToAnyPublisher(),
            self.project.$updatedAt.map { _ in () }.eraseToAnyPublisher(),
            self.project.$createdAt.map { _ in () }.eraseToAnyPublisher()
        )
        .debounce(for: .milliseconds(saveDebounceMilliseconds), scheduler: RunLoop.main)
        .sink { [weak self] in
            guard let self else { return }
            Task {
                await self.save(self.project)
            }
        }
        .store(in: &cancellables)
    }
}

extension CoreDataProjectStorage {

    func fetch() throws -> ProjectEntity? {
        guard
            let storage,
            let context = storage.context,
            // Skip fetch to avoid a crash if an entity was removed from the model
            hasEntityInModel(named: entityNameInModel, context: context)
        else { return nil }
        return try storage.fetch()
    }

    func update(_ entity: ProjectEntity) {
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

    func update(directoryURL: URL) throws {
        // Do nothing if an error occurs, since nothing can be done
        guard
            let result = try? ProjectArchiveModel(in: directoryURL)
        else {
            let nsError = NSError(
                domain: String(describing: Self.self),
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to find file in \(directoryURL).",
                    "directoryURL": directoryURL.path
                ]
            )
            Logger.error(nsError)
            throw nsError
        }

        project.update(
            projectName: result.projectName,
            createdAt: result.createdAt,
            updatedAt: result.updatedAt
        )
    }
}

private extension CoreDataProjectStorage {

    func hasEntityInModel(named name: String, context: NSManagedObjectContext) -> Bool {
        guard !name.isEmpty else { return false }
        guard let model = context.persistentStoreCoordinator?.managedObjectModel else { return false }
        return model.entitiesByName[name] != nil
    }

    func save(_ target: ProjectData) async {
        guard
            let storage,
            let context = storage.context,
            let request = storage.fetchRequest()
        else { return }

        guard hasEntityInModel(named: entityNameInModel, context: context) else {
            return
        }

        let projectName = target.projectName
        let createdAt = target.createdAt
        let updatedAt = target.updatedAt

        await context.perform { [context] in
            do {
                // Fetch or create root
                let entity = try context.fetch(request).first ?? ProjectEntity(context: context)

                // Return if no changes
                guard
                    entity.projectName != projectName ||
                    entity.createdAt != createdAt ||
                    entity.updatedAt != updatedAt
                else { return }

                // Update entities only if values have actually changed
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
