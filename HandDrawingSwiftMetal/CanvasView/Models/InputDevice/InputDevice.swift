//
//  InputDevice.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/08/03.
//

import Foundation

final class InputDevice {

    typealias T = CanvasInputDeviceType

    private (set) var status: T = .undetermined

    /// Update the status if it is not .pencil
    func update(_ newStatus: T) -> T {
        if status != .pencil {
            status = newStatus
        }
        return status
    }

    func reset() {
        status = .undetermined
    }

}
