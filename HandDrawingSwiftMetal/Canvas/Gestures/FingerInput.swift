//
//  FingerInput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol FingerGestureSender {
    func drawOnTexture(_ input: FingerInput, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func transformTexture(_ input: FingerInput, touchPointArrayDictionary: [Int: [TouchPoint]], touchState: TouchState)
    func touchEnded(_ input: FingerInput)
    func cancel(_ input: FingerInput)
}

class FingerInput: InputProtocol {
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

extension FingerInput: FingerGestureRecognizerSender {
    func sendLocations(_ gesture: FingerGestureRecognizer?, touchPointDictionary: [Int: TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? SmoothPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointDictionary)

        let actionState = ActionStateManager.getState(touchPointStorage.touchPointsDictionary)
        actionStateManager.updateState(actionState)

        switch actionStateManager.state {
        case .recognizing:
            break

        case .drawingOnCanvas:
            let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
            delegate?.drawOnTexture(self,
                                    iterator: iterator,
                                    touchState: touchState)

        case .transformingCanvas:
            delegate?.transformTexture(self,
                                       touchPointArrayDictionary: touchPointStorage.touchPointsDictionary,
                                       touchState: touchState)
        }

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }
    func cancel(_ gesture: FingerGestureRecognizer?) {
        delegate?.cancel(self)
    }
}
