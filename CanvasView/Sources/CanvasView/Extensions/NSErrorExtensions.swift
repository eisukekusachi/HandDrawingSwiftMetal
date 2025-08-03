//
//  NSErrorExtensions.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/03.
//

import Foundation

public extension NSError {
    convenience init(
        domain: String = "CanvasView",
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
