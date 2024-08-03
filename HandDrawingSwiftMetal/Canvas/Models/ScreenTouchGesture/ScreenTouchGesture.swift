//
//  ScreenTouchGesture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class ScreenTouchGesture {

    typealias T = ScreenTouchGestureStatus

    private (set) var status: T = .undetermined

    /// Update the status if the status is not yet determined.
    func update(_ newStatus: T) -> T {
        if status == .undetermined {
            status = newStatus
        }
        return status
    }

    func reset() {
        status = .undetermined
    }

}
