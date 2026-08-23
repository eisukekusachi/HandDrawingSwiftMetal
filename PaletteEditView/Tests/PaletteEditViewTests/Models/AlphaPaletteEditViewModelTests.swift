//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/08/02.
//

import Combine
import Foundation
import Testing
@testable import PaletteEditView

@MainActor
private final class MockAlphaSource: AlphaPaletteSource {
    @Published var selectedIndex = 0
    @Published var canRemoveSelected: Bool

    private var alphas: [Int]

    init(
        alphas: [Int] = [255],
        canRemoveSelected: Bool? = nil
    ) {
        self.alphas = alphas
        self.canRemoveSelected = canRemoveSelected ?? (alphas.count > 1)
    }

    var selectedAlpha: Int {
        alphas[selectedIndex]
    }
}

@MainActor
struct AlphaPaletteEditViewModelTests {

    private typealias Subject = AlphaPaletteEditViewModel

    @Test
    func `Default alpha matches source`() {
        let source = MockAlphaSource(alphas: [200])
        let subject = Subject(alphaSource: source)

        #expect(subject.alpha == 200)
    }

    @Test
    func `updateAlpha clamps values to 0`() {
        let subject = Subject(alphaSource: MockAlphaSource())

        subject.updateAlpha(-1)
        #expect(subject.alpha == 0)
    }

    @Test
    func `updateAlpha clamps values to 255`() {
        let subject = Subject(alphaSource: MockAlphaSource())

        subject.updateAlpha(256)
        #expect(subject.alpha == 255)
    }

    @Test
    func `setAlpha updates alpha without notifying onChanged`() {
        var callbackCount = 0
        let subject = Subject(
            alphaSource: MockAlphaSource(),
            onChanged: { _ in callbackCount += 1 }
        )

        subject.setAlpha(128)

        #expect(subject.alpha == 128)
        #expect(callbackCount == 0)
    }

    @Test
    func `updateAlpha updates alpha and notifies onChanged`() {
        var callbackCount = 0
        let subject = Subject(
            alphaSource: MockAlphaSource(),
            onChanged: { _ in callbackCount += 1 }
        )

        subject.updateAlpha(128)

        #expect(subject.alpha == 128)
        #expect(callbackCount == 1)
    }

    @Test
    func `updateAlpha skips notification when alpha is unchanged`() {
        var callbackCount = 0
        let source = MockAlphaSource(alphas: [128])
        let subject = Subject(
            alphaSource: source,
            onChanged: { _ in callbackCount += 1 }
        )

        subject.updateAlpha(128)

        #expect(callbackCount == 0)
    }

    @Test
    func `Syncs alpha when source selection changes`() async {
        let source = MockAlphaSource(alphas: [64, 192])
        let subject = Subject(alphaSource: source)

        source.selectedIndex = 1

        await flushMainRunLoop()

        #expect(subject.alpha == 192)
    }

    @Test
    func `Disables remove when the source has only one alpha`() {
        let source = MockAlphaSource(alphas: [128])
        let subject = Subject(alphaSource: source)

        #expect(!subject.canRemoveSelected)
    }

    @Test
    func `Enables remove when the source has more than one alpha`() {
        let source = MockAlphaSource(alphas: [64, 192])
        let subject = Subject(alphaSource: source)

        #expect(subject.canRemoveSelected)
    }

    @Test
    func `Syncs canRemoveSelected when the source drops to one alpha`() async {
        let source = MockAlphaSource(alphas: [64, 192])
        let subject = Subject(alphaSource: source)

        #expect(subject.canRemoveSelected)

        source.canRemoveSelected = false
        await flushMainRunLoop()

        #expect(!subject.canRemoveSelected)
    }
}

private extension AlphaPaletteEditViewModelTests {
    func flushMainRunLoop() async {
        for _ in 0 ..< 3 {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                RunLoop.main.perform {
                    continuation.resume()
                }
            }
        }
    }
}
