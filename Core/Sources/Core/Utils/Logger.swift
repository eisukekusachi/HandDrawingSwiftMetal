//
//  Created by Eisuke Kusachi
//

import Foundation
import os

public enum Logger {
    #if DEBUG
    private static let standard: os.Logger = .init(
        subsystem: Bundle.main.bundleIdentifier ?? "com.unknown.app",
        category: LogCategory.standard.rawValue
    )
    #endif

    public static func error(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ error: Error
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        standard.error("[\(fileName):\(line)] \(function) - \(String(describing: error))")
        #endif
    }

    public static func error(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ message: String
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        standard.error("[\(fileName):\(line)] \(function) - \(message)")
        #endif
    }

    public static func info(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ message: String
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        standard.info("[\(fileName):\(line)] \(function) - \(message)")
        #endif
    }
}

private enum LogCategory: String {
    case standard = "Standard"
}
