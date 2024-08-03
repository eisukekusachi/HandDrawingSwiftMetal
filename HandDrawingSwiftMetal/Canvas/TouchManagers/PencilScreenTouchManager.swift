//
//  PencilScreenTouchManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

final class PencilScreenTouchManager {

    private (set) var touchArray: [TouchPoint] = []

}

extension PencilScreenTouchManager {

    var isEmpty: Bool {
        touchArray.isEmpty
    }

    func append(event: UIEvent?, in view: UIView) {
        event?.allTouches?.forEach { touch in
            guard
                touch.type == .pencil,
                let coalescedTouches = event?.coalescedTouches(for: touch)
            else { return }

            coalescedTouches.forEach { coalescedTouch in
                touchArray.append(
                    .init(touch: coalescedTouch, view: view)
                )
            }
        }
    }

    func removeIfLastElementMatches(phases conditions: [UITouch.Phase]) {
        conditions.forEach { condition in
            if touchArray.last?.phase == condition {
                touchArray = []
            }
        }
    }

    func reset() {
        touchArray = []
    }

}
