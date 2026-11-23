//
//  Created by Eisuke Kusachi
//

import UIKit

typealias ToastMessageId = UUID

struct ToastMessage: Identifiable {
    let id: ToastMessageId
    let title: String
    let icon: UIImage?
    let duration: Double

    init(
        id: ToastMessageId = ToastMessageId(),
        title: String,
        icon: UIImage?,
        duration: Double = 2.0
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.duration = duration
    }

    init(
        id: ToastMessageId = ToastMessageId(),
        error: Error,
        icon: UIImage? = nil,
        duration: Double = 2.0
    ) {
        self.id = id
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            self.title = description
        } else {
            let nsError = error as NSError
            self.title = nsError.localizedFailureReason ?? nsError.localizedDescription
        }
        self.icon = icon
        self.duration = duration
    }
}

extension ToastMessage {
    static var success: ToastMessage {
        .init(
            title: String(localized: "Success"),
            icon: UIImage(systemName: "hand.thumbsup.fill")
        )
    }
}