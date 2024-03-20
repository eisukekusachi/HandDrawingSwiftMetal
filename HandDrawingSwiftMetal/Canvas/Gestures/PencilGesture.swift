//
//  PencilGesture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/28.
//

import UIKit

protocol PencilGestureSender {
    func sendLocations(_ gesture: PencilGesture?, touchPointArray: [TouchPoint], touchPhase: UITouch.Phase)
    func cancel(_ gesture: PencilGesture?)
}

class PencilGesture: UIGestureRecognizer {
    var output: PencilGestureSender?

    private var latestTouchForce: CGFloat?
    private var ignoreInitialInaccurateValueFlag: Bool = true

    init(output: PencilGestureSender? = nil) {
        super.init(target: nil, action: nil)

        self.output = output

        allowedTouchTypes = [UITouch.TouchType.pencil.rawValue as NSNumber]
    }
}

extension PencilGesture {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        latestTouchForce = nil
        ignoreInitialInaccurateValueFlag = true

        if let touch = event?.allTouches?.first,
           let coalescedTouches = event?.coalescedTouches(for: touch) {

            for index in 0 ..< coalescedTouches.count {
                let touch = coalescedTouches[index]
                updateIgnoreInitialInaccurateTouchFlag(touch.force)
            }
        }

        output?.sendLocations(self, touchPointArray: [], touchPhase: .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var locations: [TouchPoint] = []

        if let view = view,
           let touch = event?.allTouches?.first,
           let coalescedTouches = event?.coalescedTouches(for: touch) {

            for index in 0 ..< coalescedTouches.count {
                let touch = coalescedTouches[index]
                
                if touch.type == .pencil {
                    if !ignoreInitialInaccurateValueFlag {
                        locations.append(TouchPoint(touch: touch, view: view))
                    }

                    updateIgnoreInitialInaccurateTouchFlag(touch.force)
                }
            }
        }

        output?.sendLocations(self, touchPointArray: locations, touchPhase: .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        var locations: [TouchPoint] = []

        if let view = view,
           let touch = event?.allTouches?.first,
           let coalescedTouches = event?.coalescedTouches(for: touch) {

            for index in 0 ..< coalescedTouches.count {
                let touch = coalescedTouches[index]
                if touch.type == .pencil {

                    locations.append(TouchPoint(touch: touch, view: view))
                }
            }
        }

        output?.sendLocations(self, touchPointArray: locations, touchPhase: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        output?.cancel(self)
    }

    private func updateIgnoreInitialInaccurateTouchFlag(_ touchForce: CGFloat) {
        if ignoreInitialInaccurateValueFlag, let latestTouchForce, latestTouchForce != touchForce {
            ignoreInitialInaccurateValueFlag = false
        }
        latestTouchForce = touchForce
    }

    /*
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {

        var higherPrecisionPencilPoints: [PencilPoint] = []

        for touch in touches.enumerated() {
            if touch.element.type == .pencil,
               let updateIndex = touch.element.estimationUpdateIndex {

                let location = touch.element.preciseLocation(in: view)
                let pencilPoint = PencilPoint.init(estimationUpdateIndex: Int(truncating: updateIndex),
                                                   location: location,
                                                   force: touch.element.force)
                higherPrecisionPencilPoints.append(pencilPoint)
            }
        }

        output?.sendHigherPrecisionPencilPoints(higherPrecisionPencilPoints)
    }
    */
}
