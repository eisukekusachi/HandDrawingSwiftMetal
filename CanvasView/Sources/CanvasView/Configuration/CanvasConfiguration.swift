//
//  CanvasConfiguration.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/09/06.
//

import UIKit

@MainActor public struct CanvasConfiguration {
    public let textureSize: CGSize

    /// File extension used when saving a file
    public let fileSuffix: String

    public let undoCount: Int

    public let environmentConfiguration: EnvironmentConfiguration

    public init(
        textureSize: CGSize? = nil,
        fileSuffix: String = "",
        undoCount: Int = 24,
        environmentConfiguration: EnvironmentConfiguration = .init()
    ) {
        // The screen size is used when the value is nil
        self.textureSize = textureSize ?? CanvasView.screenSize
        self.fileSuffix = CanvasConfiguration.sanitizedFileExtension(fileSuffix)
        self.undoCount = undoCount
        self.environmentConfiguration = environmentConfiguration
    }

    /// Returns a sanitized file extension (without a leading dot)
    static func sanitizedFileExtension(_ input: String?) -> String {
        guard
            var ext = input?.trimmingCharacters(in: .whitespacesAndNewlines),
            !ext.isEmpty
        else { return "" }

        // Allow ".ext" style input
        if ext.hasPrefix(".") { ext.removeFirst() }

        ext = ext.lowercased()

        // Reject invalid characters
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        if ext.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return ""
        }

        // Reject unreasonable length
        guard (1...16).contains(ext.count) else {
            return ""
        }

        // Explicitly disallow common image formats
        if [
            "png",
            "jpg",
            "jpeg",
            "bmp"
        ].contains(ext) {
            return ""
        }

        return ext
    }
}
