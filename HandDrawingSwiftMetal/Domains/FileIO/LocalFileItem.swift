//
//  LocalFileItem.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/24.
//

import UIKit

public class LocalFileItem: Identifiable {
    public let id: UUID = UUID()
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var image: UIImage?
    public var fileURL: URL {
        _fileURL
    }
    private var _fileURL: URL

    public init(
        title: String,
        createdAt: Date,
        updatedAt: Date,
        image: UIImage?,
        fileURL: URL
    ) {
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.image = image
        self._fileURL = fileURL
    }
}
