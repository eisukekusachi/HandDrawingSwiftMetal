//
//  TouchGestureState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class TouchGestureState {

    private(set) var status: TouchGestureType = .undetermined

    func update(
        _ touchHistories: TouchHistoriesOnScreen
    ) -> TouchGestureType {
        update(.init(from: touchHistories))
    }

    /// Update the status if the status is not yet determined.
    func update(
        _ type: TouchGestureType
    ) -> TouchGestureType {
        if status == .undetermined {
            status = type
        }
        return status
    }

    func reset() {
        status = .undetermined
    }
}
