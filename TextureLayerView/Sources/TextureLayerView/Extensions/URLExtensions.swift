//
//  URLExtensions.swift
//  TextureLayerView
//
//  Created by Eisuke Kusachi on 2026/03/28.
//

import Foundation

public extension URL {

    /// A URL to store persistent and temporary data
    static var applicationSupport: URL {
        guard let url = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            fatalError("Failed to resolve Application Support directory URL")
        }
        return url
    }
}
