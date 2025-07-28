//
//  CalendarExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/11/04.
//

import Foundation

public extension Calendar {
    public static var currentDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .long
        dateFormatter.timeZone = .current

        return dateFormatter.string(from: Date())
    }
}
