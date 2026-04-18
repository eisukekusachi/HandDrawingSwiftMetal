//
//  ToastMessage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import UIKit

typealias ToastMessageId = UUID

struct ToastMessage: Identifiable {
    let id: ToastMessageId
    let title: String
    let icon: UIImage?
    let duration: Double

    init(
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
