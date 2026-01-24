//
//  CalendarExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/01/23.
//

import Foundation

public extension Calendar {
    static var currentDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        dateFormatter.timeZone = .current

        return dateFormatter.string(from: Date())
    }
}
