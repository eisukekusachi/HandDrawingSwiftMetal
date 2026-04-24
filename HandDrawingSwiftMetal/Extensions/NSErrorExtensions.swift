//
//  NSErrorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/08/03.
//

import Foundation

extension NSError {

    convenience init(
        domain: String = "HandDrawingSwiftMetal",
        file: String = #file,
        function: String = #function,
        line: Int = #line,
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

extension Error {

    var nsErrorDescription: String {
        let ns = self as NSError
        return ns.localizedFailureReason ?? ns.localizedDescription
    }
}
