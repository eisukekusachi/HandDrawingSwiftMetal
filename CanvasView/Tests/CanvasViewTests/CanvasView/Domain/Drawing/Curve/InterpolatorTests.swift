//
//  InterpolatorTests.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2025/11/15.
//

import Testing

@testable import CanvasView

struct InterpolatorTests {

    private typealias Subject = Interpolator

    @Suite
    struct CubicCurve {
        @Test
        func `Create cubic curve points`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 4,
                shouldAddEndPoint: false
            )

            #expect(result.count == 4)

            #expect(result == [
                .init(x: 0.0, y: 0.0),
                .init(x: 7.34375, y: 7.03125),
                .init(x: 13.75, y: 11.25),
                .init(x: 18.28125, y: 9.84375)
            ])
        }

        @Test
        func `Create cubic curve points include the end point`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 4,
                shouldAddEndPoint: true
            )

            // Because the end point is added, the result is the duration plus 1
            #expect(result.count == 5)

            #expect(result == [
                .init(x: 0.0, y: 0.0),
                .init(x: 7.34375, y: 7.03125),
                .init(x: 13.75, y: 11.25),
                .init(x: 18.28125, y: 9.84375),
                .init(x: 20.0, y: 0.0)
            ])
        }

        @Test
        func `When the duration is 1 and shouldAddEndPoint is false”`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 1,
                shouldAddEndPoint: false
            )

            #expect(result.count == 1)

            #expect(result == [
                .init(x: 0.0, y: 0.0)
            ])
        }

        @Test
        func `When the duration is 1 and shouldAddEndPoint is true”`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 1,
                shouldAddEndPoint: true
            )

            // Because the end point is added, the result is the duration plus 1
            #expect(result.count == 2)

            #expect(result == [
                .init(x: 0, y: 0),
                .init(x: 20, y: 0)
            ])
        }

        @Test
        func `When the duration is 0 and shouldAddEndPoint is false”`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 0,
                shouldAddEndPoint: false
            )

            #expect(result.isEmpty)

            #expect(result == [])
        }

        @Test
        func `When the duration is 0 and shouldAddEndPoint is true”`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 0,
                shouldAddEndPoint: true
            )

            // Because the end point is added, the result is the duration plus 1
            #expect(result.count == 1)

            #expect(result == [
                .init(x: 20, y: 0)
            ])
        }
    }

    @Suite
    struct LinearInterpolation {

        @Test
        func `Create linear interpolation values`() {
            let result = Subject.createLinearInterpolationValues(
                begin: 0,
                end: 10,
                duration: 4,
                shouldAddEndPoint: false
            )

            #expect(result.count == 4)

            #expect(result == [
                0.0,
                2.5,
                5.0,
                7.5
            ])
        }

        @Test
        func `Create linear interpolation values include the end value`() {
            let result = Subject.createLinearInterpolationValues(
                begin: 0,
                end: 10,
                duration: 4,
                shouldAddEndPoint: true
            )

            // Because the end point is added, the result is the duration plus 1
            #expect(result.count == 5)

            #expect(result == [
                0.0,
                2.5,
                5.0,
                7.5,
                10.0
            ])
        }

        @Test
        func `When the duration is 1 and shouldAddEndPoint is false”`() {
            let result = Subject.createLinearInterpolationValues(
                begin: 0,
                end: 10,
                duration: 1,
                shouldAddEndPoint: false
            )

            #expect(result.count == 1)

            #expect(result == [
                0.0
            ])
        }

        @Test
        func `When the duration is 1 and shouldAddEndPoint is true”`() {
            let result = Subject.createLinearInterpolationValues(
                begin: 0,
                end: 10,
                duration: 1,
                shouldAddEndPoint: true
            )

            #expect(result.count == 2)

            #expect(result == [
                0.0,
                10.0
            ])
        }

        @Test
        func `When the duration is 0 and shouldAddEndPoint is false”`() {
            let result = Subject.createLinearInterpolationValues(
                begin: 0,
                end: 10,
                duration: 0,
                shouldAddEndPoint: false
            )

            #expect(result.isEmpty)

            #expect(result == [])
        }

        @Test
        func `When the duration is 0 and shouldAddEndPoint is true”`() {
            let result = Subject.createLinearInterpolationValues(
                begin: 0,
                end: 10,
                duration: 0,
                shouldAddEndPoint: true
            )

            #expect(result.count == 1)

            #expect(result == [
                10.0
            ])
        }
    }
}
