//
//  ToastModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

public struct ToastModel {
    public let title: String
    public let systemName: String
    public let duration: Double

    public init(
        title: String,
        systemName: String,
        duration: Double = 2.0
    ) {
        self.title = title
        self.systemName = systemName
        self.duration = duration
    }
}
