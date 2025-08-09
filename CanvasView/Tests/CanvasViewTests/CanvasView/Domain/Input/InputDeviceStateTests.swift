//
//  InputDeviceStateTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import Testing
@testable import CanvasView

@Suite("InputDeviceState Tests")
struct InputDeviceStateTests {

    @Test("Initial state is .undetermined.")
    func initialState() {
        let subject = InputDeviceState()
        #expect(subject.state == .undetermined)
    }

    @Test("Update to .finger sets state to .finger.")
    func updateToFinger() {
        let subject = InputDeviceState()

        subject.update(.finger)
        #expect(subject.state == .finger)
    }

    @Test("Updating to .pencil sets the state to .pencil and keeps it .pencil even if later updated to .finger..")
    func updateToPencil() {
        let subject = InputDeviceState(.finger)

        subject.update(.pencil)
        #expect(subject.state == .pencil)

        subject.update(.finger)
        #expect(subject.state == .pencil)
    }

    @Test("Reset returns state to .undetermined.")
    func reset() {
        let subject = InputDeviceState(.pencil)

        subject.reset()
        #expect(subject.state == .undetermined)
    }
}
