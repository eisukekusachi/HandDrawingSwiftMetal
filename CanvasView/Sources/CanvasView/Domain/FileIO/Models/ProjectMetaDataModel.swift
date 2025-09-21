//
//  ProjectMetaDataModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/22.
//

import Foundation

public struct ProjectMetaDataModel: Codable, Sendable {
    public let projectName: String
    public let createdAt: Date
    public let updatedAt: Date

    public static let jsonFileName = "project"

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
extension ProjectMetaDataModel {
    public init(project: ProjectMetaDataProtocol) {
        self.projectName = project.projectName
        self.createdAt = project.createdAt
        self.updatedAt = project.updatedAt
    }

    /// Initializes by decoding a JSON file at the given URL
    public init(fileURL: URL) throws {
        let data = try Data(contentsOf: fileURL)
        do {
            self = try JSONDecoder().decode(ProjectMetaDataModel.self, from: data).model()
        } catch {
            let className = String(describing: ProjectMetaDataModel.self)
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

extension ProjectMetaDataModel: LocalFileConvertible {
    public func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }
}

@MainActor
extension ProjectMetaDataModel {
    static func namedItem(from project: ProjectMetaDataProtocol) -> LocalFileNamedItem<Self> {
        .init(
            fileName: "\(Self.jsonFileName)",
            item: .init(
                projectName: project.projectName,
                createdAt: project.createdAt,
                updatedAt: project.updatedAt
            )
        )
    }

    static func anyNamedItem(from project: ProjectMetaDataProtocol) -> AnyLocalFileNamedItem {
        AnyLocalFileNamedItem(Self.namedItem(from: project))
    }
}

extension ProjectMetaDataModel: ProjectMetaDataConvertible {
    public func model() -> Self {
        self
    }
}

extension ProjectMetaDataModel: LocalFileLoadable {}

public protocol ProjectMetaDataConvertible: Decodable {
    func model() -> ProjectMetaDataModel
}
