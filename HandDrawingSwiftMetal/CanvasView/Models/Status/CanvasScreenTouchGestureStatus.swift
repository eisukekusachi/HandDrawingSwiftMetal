//
//  CanvasScreenTouchGestureStatus.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class CanvasScreenTouchGestureStatus {

    typealias T = CanvasScreenTouchGestureType

    private(set) var status: T = .undetermined

    func update(_ touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]) -> T {
        let newStatus: T = .init(from: touchArrayDictionary)
        return update(newStatus)
    }

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
