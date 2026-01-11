//
//  CoreDataProjectMetaDataStorage.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/21.
//

import Combine
import UIKit

@preconcurrency import CoreData

/// Project meta data managed by Core Data
@MainActor
public final class CoreDataProjectMetaDataStorage: ProjectMetaDataProtocol, ObservableObject {

    public var projectName: String {
        project.projectName
    }

    public var createdAt: Date {
        project.createdAt
    }

    public var updatedAt: Date {
        project.updatedAt
    }

    var zipFileURL: URL {
        project.zipFileURL
    }

    private var project = ProjectMetaData()

    private let storage: AnyCoreDataStorage<ProjectMetaDataEntity>?

    private var cancellables = Set<AnyCancellable>()

    init(
        storage: AnyCoreDataStorage<ProjectMetaDataEntity>?
    ) {
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

extension CoreDataProjectMetaDataStorage {
    public func fetch() throws -> ProjectMetaDataEntity? {
        try storage?.fetch()
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

    public func update(_ model: ProjectMetaData) {
        update(
            projectName: model.projectName,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    public func update(_ entity: ProjectMetaDataEntity) {
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


private extension CoreDataProjectMetaDataStorage {
    func save(_ target: ProjectMetaData) async {
        guard
            let storage,
            let context = storage.context
        else { return }

        let projectName = target.projectName
        let createdAt = target.createdAt
        let updatedAt = target.updatedAt

        let request = storage.fetchRequest()

        await context.perform { [context] in
            do {
                // Fetch or create root
                let entity = try context.fetch(request).first ?? ProjectMetaDataEntity(context: context)

                // Return if no changes
                guard
                    entity.projectName != projectName || entity.createdAt != createdAt || entity.updatedAt != updatedAt
                else { return }

                // Update entities only if values have actually changed
                if entity.projectName != projectName {
                    entity.projectName = projectName
                }
                if entity.createdAt != createdAt {
                    entity.createdAt = createdAt
                }
                if entity.updatedAt != updatedAt {
                    entity.updatedAt = updatedAt
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                Logger.error(error)
            }
        }
    }
}
