//
//  CoreDataProjectStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import Combine
import UIKit

@preconcurrency import CoreData

@MainActor public final class CoreDataProjectStorage: ObservableObject {

    public var projectName: String { project.projectName }
    public var createdAt: Date { project.createdAt }
    public var updatedAt: Date { project.updatedAt }

    private var project = ProjectData()
    private let storage: AnyCoreDataStorage<ProjectEntity>?
    private var cancellables = Set<AnyCancellable>()

    private let entityNameInModel = "ProjectStorage"

    init(storage: AnyCoreDataStorage<ProjectEntity>?) {
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

    public var metaData: ProjectData {
        .init(
            projectName: project.projectName,
            createdAt: project.createdAt,
            updatedAt: project.updatedAt
        )
    }

    public func fetch() throws -> ProjectEntity? {
        guard let storage, let context = storage.context else { return nil }
        guard hasEntityInModel(named: entityNameInModel, context: context) else {
            // Entity was removed from the model; skip fetch to avoid crash.
            return nil
        }
        return try storage.fetch()
    }

    public func updateAll(newProjectName: String) {
        project.updateAll(newProjectName: newProjectName)
    }

    public func updateUpdatedAt() {
        project.updateUpdatedAt()
    }

    public func update(
        projectName: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        project.projectName = projectName
        project.createdAt = createdAt
        project.updatedAt = updatedAt
    }

    public func update(_ model: ProjectData) {
        update(
            projectName: model.projectName,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public func update(_ entity: ProjectEntity) {
        if let projectName = entity.projectName,
           let createdAt = entity.createdAt,
           let updatedAt = entity.updatedAt {
            update(
                projectName: projectName,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }
}

private extension CoreDataProjectStorage {

    func hasEntityInModel(named name: String, context: NSManagedObjectContext) -> Bool {
        guard !name.isEmpty else { return false }
        guard let model = context.persistentStoreCoordinator?.managedObjectModel else { return false }
        return model.entitiesByName[name] != nil
    }

    func save(_ target: ProjectData) async {
        guard let storage, let context = storage.context else { return }
        guard hasEntityInModel(named: entityNameInModel, context: context) else {
            return
        }

        let projectName = target.projectName
        let createdAt = target.createdAt
        let updatedAt = target.updatedAt

        let request = storage.fetchRequest()

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
