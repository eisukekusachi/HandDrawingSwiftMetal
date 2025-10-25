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
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
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

extension ProjectMetaDataArchiveModel: LocalFileLoadable {}
