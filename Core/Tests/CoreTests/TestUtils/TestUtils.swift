//
//  Created by Eisuke Kusachi
//

import CoreGraphics

/// Shared helpers for Core unit tests.
enum TestUtils {

    /// Matches `DocumentsTextureDataRepository` minimum texture side length.
    static let minimumTextureLength = 16

    /// Random canvas size within repository texture bounds.
    static func randomSize(
        width: ClosedRange<Int> = minimumTextureLength ... 4096,
        height: ClosedRange<Int> = minimumTextureLength ... 4096
    ) -> CGSize {
        CGSize(
            width: Int.random(in: width),
            height: Int.random(in: height)
        )
    }
}
