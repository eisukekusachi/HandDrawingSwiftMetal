//
//  Created by Eisuke Kusachi
//

import Foundation

extension Collection where Index == Int {

    func safeSlice(lower: Int, upper: Int) -> SubSequence {
        guard
            lower <= upper,
            indices.contains(lower),
            indices.contains(upper)
        else {
            return self[startIndex ..< startIndex]
        }

        return self[lower ... upper]
    }
}
