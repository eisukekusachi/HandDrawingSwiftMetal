//
//  PencilGestureWithStorage.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/15.
//

import UIKit

protocol PencilGestureWithStorageSender {
    func drawOnTexture(_ input: PencilGestureWithStorage, iterator: Iterator<TouchPoint>, touchState: TouchState)
    func touchEnded(_ input: PencilGestureWithStorage)
    func cancel(_ input: PencilGestureWithStorage)
}

class PencilGestureWithStorage: GestureWithStorageProtocol {
    var gestureRecognizer: UIGestureRecognizer?
    var touchPointStorage: TouchPointStorageProtocol = DefaultTouchPointStorage()

    var delegate: PencilGestureWithStorageSender?

    required init(view: UIView, delegate: AnyObject?) {
        self.delegate = delegate as? PencilGestureWithStorageSender

        gestureRecognizer = PencilGesture(output: self)
        view.addGestureRecognizer(gestureRecognizer!)
    }

    func clear() {
        touchPointStorage.clear()
    }
}

extension PencilGestureWithStorage: PencilGestureSender {
    func sendLocations(_ gesture: PencilGesture?, touchPointArray: [TouchPoint], touchState: TouchState) {
        guard let touchPointStorage = (touchPointStorage as? DefaultTouchPointStorage) else { return }

        touchPointStorage.appendPoints(touchPointArray)

        let iterator = touchPointStorage.getIterator(endProcessing: touchState == .ended)
        delegate?.drawOnTexture(self, iterator: iterator, touchState: touchState)

        if touchState == .ended {
            delegate?.touchEnded(self)
        }
    }

    func cancel(_ gesture: PencilGesture?) {
        delegate?.cancel(self)
    }
}
