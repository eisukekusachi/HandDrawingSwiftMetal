//
//  ToastModel.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/05/04.
//

import Foundation

struct ToastModel {
    let title: String
    let systemName: String
    let duration: Double

    init(
        title: String,
        systemName: String,
        duration: Double = 2.0
    ) {
        self.title = title
        self.systemName = systemName
        self.duration = duration
    }

}
