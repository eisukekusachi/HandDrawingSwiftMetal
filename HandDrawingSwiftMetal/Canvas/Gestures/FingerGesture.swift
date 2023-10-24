//
//  FingerGesture.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol FingerGestureSender {
    func drawOnCanvas(_ gesture: FingerGesture, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func transformCanvas(_ gesture: FingerGesture, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState)
    func touchEnded(_ gesture: FingerGesture)
    func cancel(_ gesture: FingerGesture)
}

class FingerGesture: GestureProtocol {
    var gestureRecognizer: UIGestureRecognizer?
    var touchPointStorage: TouchPointStorageProtocol = SmoothPointStorage()

    var delegate: FingerGestureSender?

    /// A manager of one finger drag or two fingers pinch.
    private let actionStateManager = ActionStateManager()

    required init(view: UIView, delegate: AnyObject?) {
        self.delegate = delegate as? FingerGestureSender

        gestureRecognizer = FingerGestureRecognizer(output: self,
                                                    is3DTouchAvailable: view.traitCollection.forceTouchCapability == .available)
        view.addGestureRecognizer(gestureRecognizer!)
    }

    func clear() {
        touchPointStorage.clear()
        actionStateManager.reset()
    }
}

extension FingerGesture: FingerGestureRecognizerSender {
    func sendLocations(_ input: FingerGestureRecognizer?, touchPointDictionary: [Int: TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? SmoothPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointDictionary)

        let actionState = ActionStateManager.getState(touchPoints: touchPointStorage.storedPoints)
        actionStateManager.updateState(actionState)

        switch actionStateManager.state {
        case .recognizing:
            break

        case .drawingOnCanvas:
            let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
            delegate?.drawOnCanvas(self, 
                                   iterator: iterator,
                                   touchState: touchState)

        case .transformingCanvas:
            delegate?.transformCanvas(self,
                                      touchPointArrayDictionary: touchPointStorage.storedPoints,
                                      touchState: touchState)
        }

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }
    func cancel(_ input: FingerGestureRecognizer?) {
        delegate?.cancel(self)
    }
}
