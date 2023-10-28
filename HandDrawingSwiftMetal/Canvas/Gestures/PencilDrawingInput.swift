//
//  PencilDrawingInput.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol PencilDrawingInputSender {
    func drawOnTexture(_ input: PencilDrawingInput, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func touchEnded(_ input: PencilDrawingInput)
    func cancel(_ input: PencilDrawingInput)
}

class PencilDrawingInput: InputProtocol {
    var gestureRecognizer: UIGestureRecognizer?
    var touchPointStorage: TouchPointStorageProtocol = DefaultPointStorage()

    var delegate: PencilDrawingInputSender?

    required init(view: UIView, delegate: AnyObject?) {
        self.delegate = delegate as? PencilDrawingInputSender

        gestureRecognizer = PencilGestureRecognizer(output: self)
        view.addGestureRecognizer(gestureRecognizer!)
    }

    func clear() {
        touchPointStorage.clear()
    }
}

extension PencilDrawingInput: PencilGestureRecognizerSender {
    func sendLocations(_ gesture: PencilGestureRecognizer?, touchPointArray: [TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? DefaultPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointArray)

        let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
        delegate?.drawOnTexture(self, iterator: iterator, touchState: touchState)

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }

    func cancel(_ gesture: PencilGestureRecognizer?) {
        delegate?.cancel(self)
    }
}
