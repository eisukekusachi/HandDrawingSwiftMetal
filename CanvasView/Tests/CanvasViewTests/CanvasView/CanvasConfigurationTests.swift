//
//  CanvasConfigurationTests.swift
//  CanvasViewTests
//
//  Created by Eisuke Kusachi on 2026/03/07.
//

import Testing
import CoreGraphics

@testable import CanvasView

@MainActor
struct CanvasConfigurationTests {

    typealias Subject = CanvasConfiguration

    @Test
    func `If textureSize is nil, the screen size is used`() {
        let subject: Subject = .init(textureSize: nil)

        #expect(subject.textureSize.equalTo(CanvasConfiguration.screenSize))
    }

    @Test(
        arguments: [
            CGSize(width: 10, height: 10),
            CGSize(width: 2000, height: 1500)
        ]
    )
    func `If textureSize is valid, the specified size is used`(textureSize: CGSize) {
        let subject: Subject = .init(textureSize: textureSize)

        #expect(subject.textureSize.equalTo(textureSize))
    }

    @Test
    func `Calling newTextureSize() returns a new configuration instance with the specified size`() {
        let subject: Subject = .init(
            textureSize: .init(width: 1000, height: 1000)
        )
        let newTextureSize: CGSize = .init(width: 2000, height: 2000)
        let newConfiguration = subject.newTextureSize(newTextureSize)

        #expect(newConfiguration.textureSize.equalTo(newTextureSize))
    }
}
