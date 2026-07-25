//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Testing
@testable import PaletteEditView

@MainActor
struct AlphaPaletteStateTests {

    private typealias Subject = AlphaPaletteState

    @Test
    func `Default state is full alpha`() {
        let subject = Subject()

        #expect(subject.alpha == 255)
    }

    @Test
    func `setAlpha sets alpha without notifying onChanged`() {
        var callbackCount = 0
        let subject = Subject(onChanged: { _ in
            callbackCount += 1
        })

        subject.setAlpha(128)

        #expect(subject.alpha == 128)
        #expect(callbackCount == 0)
    }

    @Test
    func `updateAlpha updates alpha and notifies onChanged`() {
        var outputAlpha = 0
        let subject = Subject(onChanged: { newAlpha in
            outputAlpha = newAlpha
        })

        subject.setAlpha(64)
        subject.updateAlpha(200)

        #expect(subject.alpha == 200)
        #expect(outputAlpha == 200)
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

        subject.updateAlpha(value)

        #expect(subject.alpha == expected)
    }
}
