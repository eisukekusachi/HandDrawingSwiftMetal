//
//  Created by Eisuke Kusachi
//

import Core
import CoreGraphics

/// Shared helpers for unit tests.
enum TestUtils {

    /// Random canvas size within app-supported texture bounds.
    static func randomSize(
        width: ClosedRange<Int> = textureMinimumLength ... 4096,
        height: ClosedRange<Int> = textureMinimumLength ... 4096
    ) -> CGSize {
        CGSize(
            width: Int.random(in: width),
            height: Int.random(in: height)
        )
    }
}
