//
//  UITouchDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import CanvasView
import UIKit

public final class UITouchDummy: UITouch {

    override public var phase: UITouch.Phase { _phase }
    override public var force: CGFloat { _force }
    override public var estimationUpdateIndex: NSNumber? { _estimationUpdateIndex }
    override public var timestamp: TimeInterval { _timestamp }

    private let _phase: UITouch.Phase
    private let _force: CGFloat
    private let _estimationUpdateIndex: NSNumber?
    private let _timestamp: TimeInterval

    init(
        phase: UITouch.Phase = .cancelled,
        force: CGFloat = 0.0,
        estimationUpdateIndex: NSNumber? = nil,
        timestamp: TimeInterval = 0.0
    ) {
        self._phase = phase
        self._force = force
        self._estimationUpdateIndex = estimationUpdateIndex
        self._timestamp = timestamp
        super.init()
    }
}
