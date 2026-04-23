//
//  ProjectArchiveModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/24.
//

import Foundation

struct ProjectArchiveModel: Codable, Sendable {

    public let createdAt: Date
    public let updatedAt: Date

    public init(
        createdAt: Date,
        updatedAt: Date
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension ProjectArchiveModel {
    @MainActor init(_ model: ProjectData) throws {
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}

extension ProjectArchiveModel: LocalFileConvertible {
    public static var fileName: String { "project" }
}
