//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Testing
import UIKit
@testable import PaletteEditView

@MainActor
struct ColorPaletteStateTests {

    private typealias Subject = ColorPaletteState

    @Test
    func `Default state is black with full alpha and grid segment`() {
        let subject = Subject()

        #expect(subject.selectedSegment == .grid)
        #expect(subject.alpha == 255)
        #expect(subject.rgbColor == .black)
        #expect(subject.color == .black)
    }

    @Test
    func `setColor separates RGB and alpha from the source color`() {
        let subject = Subject()

        let sourceColor = UIColor(paletteRed: 10, green: 20, blue: 30, alpha: 128)

        subject.setColor(sourceColor)

        #expect(subject.alpha == 128)
        #expect(subject.rgbColor == UIColor(paletteRed: 10, green: 20, blue: 30, alpha: 255))
        #expect(subject.color == sourceColor)
    }

    @Test
    func `setColor does not notify onChanged`() {
        var callbackCount = 0
        let subject = Subject(onChanged: { _ in
            callbackCount += 1
        })

        subject.setColor(.red)

        #expect(callbackCount == 0)
    }

    @Test
    func `updateColor notifies onChanged with the current color`() {
        var outputColor: UIColor?
        let subject = Subject(onChanged: { newColor in
            outputColor = newColor
        })

        let sourceColor = UIColor(paletteRed: 64, green: 128, blue: 192, alpha: 200)
        subject.setColor(sourceColor)
        subject.updateColor()

        #expect(subject.color == sourceColor)
        #expect(outputColor == subject.color)
    }

    @Test
    func `updateAlpha updates alpha and notifies onChanged`() {
        var outputColor: UIColor?
        let subject = Subject(onChanged: { newColor in
            outputColor = newColor
        })

        subject.setColor(UIColor(paletteRed: 0, green: 0, blue: 0, alpha: 128))
        subject.updateAlpha(255)

        #expect(subject.alpha == 255)
        #expect(subject.color == .black)
        #expect(outputColor == .black)
    }

    @Test(
        arguments: [
            (-1, 0),
            (0, 0),
            (128, 128),
            (255, 255),
            (300, 255)
        ]
    )
    func `updateAlpha clamps values to 0 through 255`(value: Int, expected: Int) {
        let subject = Subject()

        subject.setColor(.black)

        subject.updateAlpha(value)

        #expect(subject.alpha == expected)
        #expect(subject.color == UIColor(paletteRed: 0, green: 0, blue: 0, alpha: expected))
    }
}
