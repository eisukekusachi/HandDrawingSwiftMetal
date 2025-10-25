//
//  ProjectMetaDataArchiveModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/22.
//

import Foundation

public struct ProjectMetaDataArchiveModel: Codable, Sendable {
    public let projectName: String
    public let createdAt: Date
    public let updatedAt: Date

    public static let fileName = "project"

    public init(
        projectName: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.projectName = projectName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@MainActor
extension ProjectMetaDataArchiveModel {
    public init(project: ProjectMetaDataProtocol) {
        self.projectName = project.projectName
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
    }

    /// Initializes by decoding a JSON file at the given URL
    public init(fileURL: URL) throws {
        do {
            let data = try Data(contentsOf: fileURL)
            self = try JSONDecoder().decode(ProjectMetaDataArchiveModel.self, from: data)
        } catch {
            let className = String(describing: ProjectMetaDataArchiveModel.self)
            let nsError = NSError(
                domain: className,
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to decode \(className) from JSON.",
                    NSUnderlyingErrorKey: error,
                    "fileURL": fileURL.path
                ]
            )
            Logger.error(nsError)
            throw nsError
        }
    }
}

extension ProjectMetaDataArchiveModel: LocalFileConvertible {
    public var fileName: String { "project" }

    public static func read(from url: URL) throws -> Self {
        let data = try Data(contentsOf: url.appendingPathComponent(ProjectMetaDataArchiveModel.fileName))
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

@MainActor
extension ProjectMetaDataArchiveModel {
    static func namedItem(from project: ProjectMetaDataProtocol) -> LocalFileNamedItem<Self> {
        .init(
            fileName: "\(Self.fileName)",
            item: .init(
                projectName: project.projectName,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt
            )
        )
    }
}
