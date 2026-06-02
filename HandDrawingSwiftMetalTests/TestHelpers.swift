//
//  TestHelpers.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/30.
//

import UIKit

enum TestHelpers {

    static func randomInt(
        range: ClosedRange<Int> = 1...100
    ) -> Int {
        Int.random(in: range)
    }

    static func randomSize(
        widthRange: ClosedRange<CGFloat> = 1...100,
        heightRange: ClosedRange<CGFloat> = 1...100
    ) -> CGSize {
        CGSize(
            width: .random(in: widthRange),
            height: .random(in: heightRange)
        )
    }
}
