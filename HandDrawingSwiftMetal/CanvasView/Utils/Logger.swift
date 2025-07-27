//
//  Logger.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/12/21.
//

import Foundation
import os

public enum Logger {
    public static let standard: os.Logger = .init(
        subsystem: Bundle.main.bundleIdentifier!,
        category: LogCategory.standard.rawValue
    )

    public static func error(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ error: Error
    ) {
        let fileName = (file as NSString).lastPathComponent
        standard.error("[\(fileName):\(line)] \(function) - \(error)")
    }

    public static func info(
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        _ message: String
    ) {
        let fileName = (file as NSString).lastPathComponent
        standard.info("[\(fileName):\(line)] \(function) - \(message)")
    }
}

private enum LogCategory: String {
     case standard = "Standard"
}
