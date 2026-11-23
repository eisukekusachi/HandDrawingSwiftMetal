//
//  Created by Eisuke Kusachi
//

import Foundation

/// Default and shared NSError `domain` values for the Core package.
public enum NSErrorDomain {

    public static let core = "Core"
}

public extension NSError {

    static func matches(
        _ error: Error,
        domain: String,
        code: Int
    ) -> Bool {
        let nsError = error as NSError
        return nsError.domain == domain && nsError.code == code
    }
}