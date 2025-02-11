//
//  CanvasScreenTouchGestureStatus.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class CanvasScreenTouchGestureStatus {

    private(set) var status: CanvasScreenTouchGestureType = .undetermined

    func update(
        _ touchArrayDictionary: [CanvasTouchHashValue: [CanvasTouchPoint]]
    ) -> CanvasScreenTouchGestureType {
        update(.init(from: touchArrayDictionary))
    }

    /// Update the status if the status is not yet determined.
    func update(
        _ newStatus: CanvasScreenTouchGestureType
    ) -> CanvasScreenTouchGestureType {
        if status == .undetermined {
            status = newStatus
        }
        return status
    }

    func reset() {
        status = .undetermined
    }

}
