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

    static func from(_ error: NSError) -> ErrorModel {
        ErrorModel(
            id: UUID(),
            domain: error.domain,
            title: error.localizedDescription,
            message: error.localizedFailureReason ?? ""
        )
    }
}
