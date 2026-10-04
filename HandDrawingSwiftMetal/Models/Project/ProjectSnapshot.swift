//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

/// Snapshot of `ProjectData` used when saving and restoring.
struct ProjectSnapshot: Codable, Sendable {

    public let createdAt: Date
    public let updatedAt: Date

    public init(
        createdAt: Date,
        updatedAt: Date
    ) {
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    @MainActor
    init(_ model: ProjectData) {
        self.createdAt = model.createdAt
        self.updatedAt = model.updatedAt
    }
}

extension ProjectSnapshot: LocalFileConvertible {
    public static var fileName: String { "project" }
}
