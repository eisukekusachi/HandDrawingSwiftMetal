//
//  TextureLayerViewModelTests.swift
//  TextureLayerViewTests
//
//  Created by Eisuke Kusachi on 2026/08/23.
//

import CoreGraphics
import Testing

@testable import TextureLayerView

@MainActor
struct TextureLayerViewModelTests {

    private typealias Subject = TextureLayerViewModel

    private let textureSize: CGSize = .init(width: 1, height: 1)

    @Test
    func `setCurrentAlpha clamps values below 0`() {
        let subject = makeSubject()

        subject.setCurrentAlpha(-1)

        #expect(subject.currentAlpha == 0)
    }

    @Test
    func `setCurrentAlpha clamps values above 255`() {
        let subject = makeSubject()

        subject.setCurrentAlpha(256)

        #expect(subject.currentAlpha == 255)
    }

    @Test
    func `onChangeCurrentAlpha clamps the selected layer alpha`() {
        let subject = makeSubject()

        subject.onChangeCurrentAlpha(-1)

        #expect(subject.currentAlpha == 0)
        #expect(subject.textureLayers.selectedLayer?.alpha == 0)

        subject.onChangeCurrentAlpha(300)

        #expect(subject.currentAlpha == 255)
        #expect(subject.textureLayers.selectedLayer?.alpha == 255)
    }

    private func makeSubject() -> Subject {
        Subject(
            textureLayers: TextureLayersState(
                textureLayers: .init(textureSize: textureSize)
            )
        )
    }
}
