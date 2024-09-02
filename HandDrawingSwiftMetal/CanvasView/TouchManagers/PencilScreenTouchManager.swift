//
//  PencilScreenTouchManager.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/07/29.
//

import UIKit

final class PencilScreenTouchManager {

    private (set) var touchArray: [CanvasTouchPoint] = []

    /// A variable used to get elements from the array starting from the next element after this point
    var latestCanvasTouchPoint: CanvasTouchPoint?
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

    func reset() {
        touchArray = []
        latestCanvasTouchPoint = nil
    }

}
