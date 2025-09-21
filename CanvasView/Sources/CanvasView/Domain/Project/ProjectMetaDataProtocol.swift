//
//  ProjectMetaDataProtocol.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/22.
//

import Foundation

@MainActor
public protocol ProjectMetaDataProtocol {
    var projectName: String { get }
    var createdAt: Date { get }
    var updatedAt: Date { get }
}
