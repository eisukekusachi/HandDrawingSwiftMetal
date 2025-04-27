//
//  TimeStampFormatter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import Foundation

enum TimeStampFormatter {

    static func currentDate() -> String {
        TimeStampFormatter.current(template: "MMM dd HH mm ss")
    }

    static func current(template: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current)
        return dateFormatter.string(from: Date())
    }
}
