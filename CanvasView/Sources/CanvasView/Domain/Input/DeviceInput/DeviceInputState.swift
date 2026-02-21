//
//  DeviceInputState.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

public final class DeviceInputState {

    public typealias T = DeviceInputType

    private(set) var state: T = .undetermined

    public init(_ state: T = .undetermined) {
        self.state = state
    }
}

public extension DeviceInputState {

    var isUndetermined: Bool {
        state == .undetermined
    }
    var isFinger: Bool {
        state == .finger
    }
    var isPencil: Bool {
        state == .pencil
    }
    var isNotPencil: Bool {
        state != .pencil
    }

    /// Update the state if it is not `.pencil`
    /// `.pencil` takes precedence over `.finger`
    @discardableResult
    func update(_ type: T) -> T {
        if state != .pencil {
            state = type
        }
        return state
    }

    func reset() {
        state = .undetermined
    }
}
