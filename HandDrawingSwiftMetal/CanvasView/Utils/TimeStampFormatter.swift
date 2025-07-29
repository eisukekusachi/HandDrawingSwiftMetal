//
//  TimeStampFormatter.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import Foundation

public enum TimeStampFormatter {

    public static var currentDate: String {
        TimeStampFormatter.current(template: "MMM dd HH mm ss")
    }

    public static func current(template: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: .current)
        return dateFormatter.string(from: Date())
    }
}
