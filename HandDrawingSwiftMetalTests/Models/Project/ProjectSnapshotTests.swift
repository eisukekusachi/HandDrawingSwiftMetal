//
//  Created by Eisuke Kusachi
//

import Foundation
import Testing
@testable import HandDrawingSwiftMetal

struct ProjectSnapshotTests {

    private typealias Subject = ProjectSnapshot

    @Test
    func `Confirms saving sets updatedAt to now and keeps createdAt`() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        let savedAt = Date(timeIntervalSince1970: 2_000)
        let subject = Subject(createdAt: createdAt, updatedAt: createdAt)

        let saved = Subject(from: subject, updatedAt: savedAt)

        #expect(saved.createdAt == createdAt)
        #expect(saved.updatedAt == savedAt)
    }

    @Test
    func `Confirms the project file name is project`() {
        #expect(Subject.fileName == "project")
    }

    @Test
    func `Confirms Codable round-trips timestamps`() throws {
        let subject = Subject(
            createdAt: Date(timeIntervalSince1970: 1_000),
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let data = try JSONEncoder().encode(subject)
        let decoded = try JSONDecoder().decode(Subject.self, from: data)

        #expect(decoded == subject)
    }
}