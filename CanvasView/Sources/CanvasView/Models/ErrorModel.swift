//
//  ErrorModel.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/03.
//

import Foundation

public struct ErrorModel: Identifiable {
    public let id: UUID
    public let domain: String
    public let title: String
    public let message: String

    static func create(
        _ error: NSError?,
        title: String? = nil,
        message: String? = nil
    ) -> Self {
        ErrorModel(
            id: UUID(),
            domain: error?.domain ?? "",
            title: title ?? (error?.localizedDescription ?? ""),
            message: message ?? (error?.localizedFailureReason ?? "")
        )
    }
}
