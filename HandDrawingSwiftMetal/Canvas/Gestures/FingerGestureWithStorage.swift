//
//  FingerGestureWithStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol FingerGestureWithStorageSender {
    func drawOnTexture(_ input: FingerGestureWithStorage, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func transformTexture(_ input: FingerGestureWithStorage, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState)
    func touchEnded(_ input: FingerGestureWithStorage)
    func cancel(_ input: FingerGestureWithStorage)
}

class FingerGestureWithStorage: GestureWithStorageProtocol {
    var gestureRecognizer: UIGestureRecognizer?
    var touchPointStorage: TouchPointStorageProtocol = SmoothPointStorage()

    var delegate: FingerGestureWithStorageSender?

    /// A manager of one finger drag or two fingers pinch.
    private let actionStateManager = ActionStateManager()

    required init(view: UIView, delegate: AnyObject?) {
        self.delegate = delegate as? FingerGestureWithStorageSender

        gestureRecognizer = FingerGesture(output: self,
                                          is3DTouchAvailable: view.traitCollection.forceTouchCapability == .available)
        view.addGestureRecognizer(gestureRecognizer!)
    }

    func clear() {
        touchPointStorage.clear()
        actionStateManager.reset()
    }
}

extension FingerGestureWithStorage: FingerGestureSender {
    func sendLocations(_ gesture: FingerGesture?, touchPointDictionary: [Int: TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? SmoothPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointDictionary)

        let actionState = ActionStateManager.getState(touchPointStorage.touchPointsDictionary)
        actionStateManager.updateState(actionState)

        switch actionStateManager.state {
        case .recognizing:
            break

        case .drawing:
            let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
            delegate?.drawOnTexture(self,
                                    iterator: iterator,
                                    touchState: touchState)

        case .transforming:
            delegate?.transformTexture(self,
                                       touchPointArrayDictionary: touchPointStorage.touchPointsDictionary,
                                       touchState: touchState)
        }

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }
    func cancel(_ gesture: FingerGesture?) {
        delegate?.cancel(self)
    }
}
