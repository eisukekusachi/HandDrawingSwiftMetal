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
}

private enum LogCategory: String {
     case standard = "Standard"
}
