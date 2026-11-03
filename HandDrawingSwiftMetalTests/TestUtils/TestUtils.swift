//
//  Created by Eisuke Kusachi
//

import CanvasView
import CoreGraphics

/// Shared helpers for unit tests.
enum TestUtils {

    /// Random canvas size within app-supported texture bounds.
    static func randomSize(
        width: ClosedRange<Int> = canvasMinimumTextureLength ... 4096,
        height: ClosedRange<Int> = canvasMinimumTextureLength ... 4096
    ) -> CGSize {
        CGSize(
            width: Int.random(in: width),
            height: Int.random(in: height)
        )
    }
}
