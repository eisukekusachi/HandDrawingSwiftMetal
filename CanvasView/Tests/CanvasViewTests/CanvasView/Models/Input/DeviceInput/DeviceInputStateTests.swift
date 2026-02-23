//
//  DeviceInputStateTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/08/09.
//

import Testing
@testable import CanvasView

struct InputDeviceStateTests {

    private typealias Subject = DeviceInputState

    @Test
    func `Initial state is .undetermined`() {
        let subject: Subject = .init()
        #expect(subject.state == .undetermined)
    }

    @Test
    func `State is .pencil`() {
        let subject: Subject = .init(.pencil)
        #expect(subject.isPencil == true)
    }

    @Test(
        arguments: [
            InputDeviceType.undetermined,
            InputDeviceType.finger
        ]
    )
    func `State is not .pencil`(type: InputDeviceType) {
        let subject: Subject = .init(type)
        #expect(subject.isNotPencil == true)
    }

    @Test
    func `Verify that updating to .finger sets the state to .finger`() {
        let subject: Subject = .init()

        subject.update(.finger)
        #expect(subject.state == .finger)
    }

    @Test
    func `Verify that updating to .pencil sets the state to .pencil and keeps it even when later updated to .finger`() {
        let subject: Subject = .init(.finger)

        subject.update(.pencil)
        #expect(subject.state == .pencil)

        subject.update(.finger)
        #expect(subject.state == .pencil)
    }

    @Test
    func `Verify that reset sets the state to .undetermined`() {
        let subject: Subject = .init(.pencil)

        subject.reset()
        #expect(subject.state == .undetermined)
    }
}
