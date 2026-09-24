//
//  Created by Eisuke Kusachi on 2026/09/26.
//

import Foundation

public extension NSError {

    convenience init(
        domain: String = "Core",
        code: Int = -1,
        title: String,
        message: String
    ) {
        self.init(
            domain: domain,
            code: code,
            userInfo: [
                NSLocalizedDescriptionKey: title,
                NSLocalizedFailureReasonErrorKey: message
            ]
        )
    }
}
