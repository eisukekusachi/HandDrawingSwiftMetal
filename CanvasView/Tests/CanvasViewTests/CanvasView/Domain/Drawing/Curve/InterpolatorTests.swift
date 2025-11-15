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
                shouldIncludeEndPoint: false
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
        func `Create cubic curve points that include the end point`() {
            let result = Subject.createCubicCurvePoints(
                movePoint: .init(x: 0, y: 0),
                controlPoint1: .init(x: 10, y: 10),
                controlPoint2: .init(x: 20, y: 20),
                endPoint: .init(x: 20, y: 0),
                duration: 4,
                shouldIncludeEndPoint: true
            )

            #expect(result.count == 5)
            #expect(result == [
                .init(x: 0.0, y: 0.0),
                .init(x: 7.34375, y: 7.03125),
                .init(x: 13.75, y: 11.25),
                .init(x: 18.28125, y: 9.84375),
                .init(x: 20.0, y: 0.0)
            ])
        }
    }
}
