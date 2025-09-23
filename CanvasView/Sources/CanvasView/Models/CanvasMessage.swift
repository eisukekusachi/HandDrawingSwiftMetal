//
//  CanvasMessage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit

public struct CanvasMessage: Identifiable {
    public let id: UUID
    public let title: String
    public let icon: UIImage?
    public let duration: Double

    public init(
        id: UUID = UUID(),
        title: String,
        icon: UIImage?,
        duration: Double = 2.0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.duration = duration
    }
}
