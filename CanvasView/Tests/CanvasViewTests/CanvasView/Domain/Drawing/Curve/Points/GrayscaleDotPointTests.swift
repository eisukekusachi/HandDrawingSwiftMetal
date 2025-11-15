//
//  GrayscaleDotPointTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/15.
//

import Testing

@testable import CanvasView

struct GrayscaleDotPointTests {

    private typealias Subject = GrayscaleDotPoint

    @Test
    func `the average of the two points`() {
        #expect(
            Subject.average(
                .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10)
            )
            == .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5)
        )

        #expect(
            Subject.average(
                .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5),
                .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5)
            )
            == .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5)
        )
    }
}
