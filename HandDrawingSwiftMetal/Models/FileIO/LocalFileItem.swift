//
//  LocalFileItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/24.
//

import UIKit

public class LocalFileItem: Identifiable {
    public let id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var thumbnail: UIImage?
    public var fileURL: URL {
        _fileURL
    }
    private var _fileURL: URL

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .init(),
        updatedAt: Date = .init(),
        thumbnail: UIImage? = nil,
        suffix: String = "",
        fileURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.thumbnail = thumbnail
        if let fileURL {
            self._fileURL = fileURL
        } else {
            self._fileURL = FileManager.zipFileURL(
                projectName: title,
                suffix: suffix
            )
        }
    }

    func update(
        title: String? = nil,
        fileURL: URL? = nil,
        updatedAt: Date? = nil,
        thumbnail: UIImage? = nil
    ) {
        if let title { self.title = title }
        if let fileURL { self._fileURL = fileURL }
        if let updatedAt { self.updatedAt = updatedAt }
        if let thumbnail { self.thumbnail = thumbnail }
    }
}
