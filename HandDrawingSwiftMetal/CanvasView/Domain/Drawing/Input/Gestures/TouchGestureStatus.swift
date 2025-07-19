//
//  TouchGestureStatus.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class TouchGestureStatus {

    private(set) var status: TouchGestureType = .undetermined

    func update(
        _ touchArrayDictionary: [TouchHashValue: [TouchPoint]]
    ) -> TouchGestureType {
        update(.init(from: touchArrayDictionary))
    }

    /// Update the status if the status is not yet determined.
    func update(
        _ newStatus: TouchGestureType
    ) -> TouchGestureType {
        if status == .undetermined {
            status = newStatus
        }
        return status
    }

    func reset() {
        status = .undetermined
    }
}
