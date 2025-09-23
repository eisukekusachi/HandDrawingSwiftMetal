//
//  CanvasError.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/03.
//

import Foundation

public struct CanvasError: Identifiable {
    public let id: UUID
    public let domain: String
    public let title: String
    public let message: String

    static func create(
        _ error: NSError?,
        title: String? = nil,
        message: String? = nil
    ) -> Self {
        .init(
            id: UUID(),
            domain: error?.domain ?? "",
            title: title ?? (error?.localizedDescription ?? ""),
            message: message ?? (error?.localizedFailureReason ?? "")
        )
    }
}
