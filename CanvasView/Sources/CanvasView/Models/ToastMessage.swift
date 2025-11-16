//
//  ToastMessage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit

public typealias ToastMessageId = UUID

public struct ToastMessage: Identifiable {
    public let id: ToastMessageId
    public let title: String
    public let icon: UIImage?
    public let duration: Double

    public init(
        title: String,
        icon: UIImage?,
        duration: Double = 2.0
    ) {
        self.id = ToastMessageId()
        self.title = title
        self.icon = icon
        self.duration = duration
    }
}
