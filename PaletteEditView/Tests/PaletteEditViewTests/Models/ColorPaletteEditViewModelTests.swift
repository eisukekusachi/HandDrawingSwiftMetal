//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/08/02.
//

import Combine
import Foundation
import Testing
import UIKit
@testable import PaletteEditView

@MainActor
private final class MockColorSource: ColorPaletteSource {
    @Published var selectedIndex = 0
    @Published var canRemoveSelected: Bool

    private let colors: [UIColor]

    init(
        colors: [UIColor] = [.black],
        canRemoveSelected: Bool? = nil
    ) {
        self.colors = colors
        self.canRemoveSelected = canRemoveSelected ?? (colors.count > 1)
    }

    var selectedColor: UIColor {
        colors[selectedIndex]
    }
}

@MainActor
struct ColorPaletteEditViewModelTests {

    private typealias Subject = ColorPaletteEditViewModel

    @Test
    func `Default selected segment is grid and color matches source`() {
        let source = MockColorSource(colors: [.red])
        let subject = Subject(colorSource: source)

        #expect(subject.selectedSegment == .grid)
        #expect(subject.color.rgbaComponents() == UIColor.red.rgbaComponents())
    }

    @Test
    func `setColor updates color without notifying onChanged`() {
        var callbackCount = 0
        let subject = Subject(
            colorSource: MockColorSource(),
            onChanged: { _ in callbackCount += 1 }
        )

        subject.setColor(.red)

        #expect(subject.color.rgbaComponents() == UIColor.red.rgbaComponents())
        #expect(callbackCount == 0)
    }

    @Test
    func `updateColor updates color and notifies onChanged`() {
        var callbackCount = 0
        let subject = Subject(
            colorSource: MockColorSource(),
            onChanged: { _ in callbackCount += 1 }
        )

        subject.updateColor(.red)

        #expect(subject.color.rgbaComponents() == UIColor.red.rgbaComponents())
        #expect(callbackCount == 1)
    }

    @Test
    func `updateColor skips notification when color is unchanged`() {
        var callbackCount = 0
        let color = UIColor(red: 64, green: 128, blue: 192, alpha: 200)
        let source = MockColorSource(colors: [color])
        let subject = Subject(
            colorSource: source,
            onChanged: { _ in callbackCount += 1 }
        )

        subject.updateColor(color)

        #expect(callbackCount == 0)
    }

    @Test
    func `Syncs color when source selection changes`() async {
        let source = MockColorSource(colors: [.black, .blue])
        let subject = Subject(colorSource: source)

        source.selectedIndex = 1

        await flushMainRunLoop()

        #expect(subject.color.rgbaComponents() == UIColor.blue.rgbaComponents())
    }

    @Test
    func `Disables remove when the source has only one color`() {
        let source = MockColorSource(colors: [.red])
        let subject = Subject(colorSource: source)

        #expect(!subject.canRemoveSelected)
    }

    @Test
    func `Enables remove when the source has more than one color`() {
        let source = MockColorSource(colors: [.red, .blue])
        let subject = Subject(colorSource: source)

        #expect(subject.canRemoveSelected)
    }

    @Test
    func `Syncs canRemoveSelected when the source drops to one color`() async {
        let source = MockColorSource(colors: [.black, .blue])
        let subject = Subject(colorSource: source)

        #expect(subject.canRemoveSelected)

        source.canRemoveSelected = false
        await flushMainRunLoop()

        #expect(!subject.canRemoveSelected)
    }
}

private extension ColorPaletteEditViewModelTests {
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
