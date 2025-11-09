//
//  UITouchDummy.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import CanvasView
import UIKit

public final class UITouchDummy: UITouch {

    public var location: CGPoint { _location }
    public var previousLocation: CGPoint { _previousLocation }
    override public var majorRadius: CGFloat { _majorRadius }
    override public var majorRadiusTolerance: CGFloat { _majorRadiusTolerance }
    public var preciseLocation: CGPoint { _preciseLocation }
    public var precisePreviousLocation: CGPoint { _precisePreviousLocation }
    override public var tapCount: Int { _tapCount }
    override public var timestamp: TimeInterval { _timestamp }
    override public var type: UITouch.TouchType { _type }
    override public var phase: UITouch.Phase { _phase }
    override public var force: CGFloat { _force }
    override public var maximumPossibleForce: CGFloat { _maximumPossibleForce }
    override public var altitudeAngle: CGFloat { _altitudeAngle }
    public var azimuthUnitVector: CGVector { _azimuthUnitVector }
    override public var rollAngle: CGFloat { _rollAngle }
    override public var estimatedProperties: UITouch.Properties { _estimatedProperties }
    override public var estimatedPropertiesExpectingUpdates: UITouch.Properties { _estimatedPropertiesExpectingUpdates }
    override public var estimationUpdateIndex: NSNumber? { _estimationUpdateIndex }

    private let _location: CGPoint
    private let _previousLocation: CGPoint
    private let _majorRadius: CGFloat
    private let _majorRadiusTolerance: CGFloat
    private let _preciseLocation: CGPoint
    private let _precisePreviousLocation: CGPoint
    private let _tapCount: Int
    private let _timestamp: TimeInterval
    private let _type: UITouch.TouchType
    private let _phase: UITouch.Phase
    private let _force: CGFloat
    private let _maximumPossibleForce: CGFloat
    private let _altitudeAngle: CGFloat
    private let _azimuthUnitVector: CGVector
    private let _rollAngle: CGFloat
    private let _estimatedProperties: UITouch.Properties
    private let _estimatedPropertiesExpectingUpdates: UITouch.Properties
    private let _estimationUpdateIndex: NSNumber?

    init(
        location: CGPoint,
        previousLocation: CGPoint,
        majorRadius: CGFloat,
        majorRadiusTolerance: CGFloat,
        preciseLocation: CGPoint,
        precisePreviousLocation: CGPoint,
        tapCount: Int,
        timestamp: TimeInterval,
        type: UITouch.TouchType,
        phase: UITouch.Phase,
        force: CGFloat,
        maximumPossibleForce: CGFloat,
        altitudeAngle: CGFloat,
        azimuthUnitVector: CGVector,
        rollAngle: CGFloat,
        estimatedProperties: UITouch.Properties,
        estimatedPropertiesExpectingUpdates: UITouch.Properties,
        estimationUpdateIndex: NSNumber?
    ) {
        self._location = location
        self._previousLocation = previousLocation
        self._majorRadius = majorRadius
        self._majorRadiusTolerance = majorRadiusTolerance
        self._preciseLocation = preciseLocation
        self._precisePreviousLocation = precisePreviousLocation
        self._tapCount = tapCount
        self._timestamp = timestamp
        self._type = type
        self._phase = phase
        self._force = force
        self._maximumPossibleForce = maximumPossibleForce
        self._altitudeAngle = altitudeAngle
        self._azimuthUnitVector = azimuthUnitVector
        self._rollAngle = rollAngle
        self._estimatedProperties = estimatedProperties
        self._estimatedPropertiesExpectingUpdates = estimatedPropertiesExpectingUpdates
        self._estimationUpdateIndex = estimationUpdateIndex
        super.init()
    }
}
