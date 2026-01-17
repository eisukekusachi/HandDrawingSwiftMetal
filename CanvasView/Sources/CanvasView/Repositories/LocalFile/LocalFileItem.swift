//
//  LocalFileItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/17.
//

import UIKit

public class LocalFileItem: Identifiable {
    public let id: UUID = UUID()
    public var title: String
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var image: UIImage?
    public var fileURL: URL {
        _fileURL
    }
    private var _fileURL: URL

    public init(title: String, image: UIImage?, fileURL: URL) {
        self.title = title
        self.image = image
        self._fileURL = fileURL
    }

    public init(metaData: ProjectMetaDataArchiveModel, image: UIImage?, fileURL: URL) {
        self.title = metaData.projectName
        self.createdAt = metaData.createdAt
        self.updatedAt = metaData.updatedAt
        self.image = image
        self._fileURL = fileURL
    }

    @MainActor
    public init(metaData: ProjectMetaData, image: UIImage?, fileURL: URL) {
        self.title = metaData.projectName
        self.createdAt = metaData.createdAt
        self.updatedAt = metaData.updatedAt
        self.image = image
        self._fileURL = fileURL
    }

    public func update(_ metaData: ProjectMetaDataArchiveModel) {
        self.title = metaData.projectName
        self.createdAt = metaData.createdAt
        self.updatedAt = metaData.updatedAt
    }
}
