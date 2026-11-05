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

    @Test(arguments: [10, 0])
    func `When textureMinimumLength is invalid, it is set to the minimum`(textureMinimumLength: Int) {
        let subject = Subject(textureMinimumLength: textureMinimumLength, textureSize: nil)

        #expect(subject.textureMinimumLength == 16)
    }

    @Test(
        arguments: [
            CGSize(width: 16, height: 16),
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
