//
//  CanvasConfigurationTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/03/07.
//

import Testing
import CoreGraphics

@testable import CanvasView

@MainActor
struct CanvasConfigurationTests {

    @Test
    func `If textureSize is nil, the screen size is used`() {
        let configuration = CanvasConfiguration(textureSize: nil)

        #expect(configuration.textureSize.equalTo(CanvasConfiguration.screenSize))
    }

    @Test
    func `If textureSize is smaller than the minimum allowed size, it is clamped to the minimum size`() {
        let smallSize = CGSize(width: 10, height: 10)
        let configuration = CanvasConfiguration(textureSize: smallSize)
        let expected: CGSize = .init(width: canvasMinimumTextureLength, height: canvasMinimumTextureLength)

        #expect(configuration.textureSize.equalTo(expected))
    }

    @Test
    func `If textureSize is valid, the specified size is used`() {
        let textureSize = CGSize(width: 2000, height: 1500)
        let configuration = CanvasConfiguration(textureSize: textureSize)

        #expect(configuration.textureSize.equalTo(textureSize))
    }

    @Test
    func `Calling textureSize() returns a new configuration instance with the specified size`() {
        let configuration = CanvasConfiguration(
            textureSize: .init(width: 1000, height: 1000),
            backgroundColor: .red
        )
        let newTextureSize: CGSize = .init(width: 2000, height: 2000)
        let newConfiguration = configuration.textureSize(newTextureSize)

        #expect(newConfiguration.textureSize.equalTo(newTextureSize))
        #expect(newConfiguration.backgroundColor == .red)
    }
}
