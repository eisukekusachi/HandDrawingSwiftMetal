//
//  SmoothDrawingCurveTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/21.
//

import Testing

@testable import CanvasView

struct SmoothDrawingCurveTests {

    private typealias Subject = SmoothDrawingCurve

    @Suite
    struct IsFirstCurveNeededTests {
        @Test
        func `Verify that it becomes true only once when there are more than three points`() {
            let subject = Subject()

            subject.append(points: [
                .generate(),
                .generate(),
                .generate(),
                .generate()
            ], touchPhase: .moved)

            #expect(subject.isFirstCurveNeeded() == true)

            subject.append(points: [.generate()], touchPhase: .moved)
            #expect(subject.isFirstCurveNeeded() == false)
        }

        @Test
        func `Verify that it becomes true only once when there are three points`() async throws {
            let subject = Subject()

            subject.append(points: [.generate()], touchPhase: .began)
            #expect(subject.isFirstCurveNeeded() == false)

            subject.append(points: [.generate()], touchPhase: .moved)
            #expect(subject.isFirstCurveNeeded() == false)

            subject.append(points: [.generate()], touchPhase: .moved)
            #expect(subject.isFirstCurveNeeded() == true)

            subject.append(points: [.generate()], touchPhase: .moved)
            #expect(subject.isFirstCurveNeeded() == false)
        }
    }

    @Suite
    struct SmoothPointsTests {
        @Test
        func `Verify that the average values are added`() async throws {
            let subject = Subject()

            subject.append(points: [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 10, y: 10)),
                .generate(location: .init(x: 20, y: 20)),
                .generate(location: .init(x: 30, y: 30))
            ], touchPhase: .ended)

            #expect(subject.array[0].location == .init(x: 0, y: 0))
            #expect(subject.array[1].location == .init(x: 5, y: 5))
            #expect(subject.array[2].location == .init(x: 15, y: 15))
            #expect(subject.array[3].location == .init(x: 25, y: 25))
            #expect(subject.array[4].location == .init(x: 30, y: 30))
        }

        @Test
        func `Verify that the average value is added`() async throws {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 10, y: 10)),
                .generate(location: .init(x: 20, y: 20)),
                .generate(location: .init(x: 30, y: 30)),
                .generate(location: .init(x: 40, y: 40))
            ]

            // At least two points are required to obtain the average value.
            subject.append(points: [points[0]], touchPhase: .began)
            #expect(subject.array.isEmpty == true)

            subject.append(points: [points[1]], touchPhase: .moved)
            // Add the first point during the initial process.
            #expect(subject.array[0].location == .init(x: 0, y: 0))
            #expect(subject.array[1].location == .init(x: 5, y: 5))

            subject.append(points: [points[2]], touchPhase: .moved)
            #expect(subject.array[2].location == .init(x: 15, y: 15))

            subject.append(points: [points[3]], touchPhase: .moved)
            #expect(subject.array[3].location == .init(x: 25, y: 25))

            subject.append(points: [points[4]], touchPhase: .ended)
            #expect(subject.array[4].location == .init(x: 35, y: 35))
            // Add the last point during the final process.
            #expect(subject.array[5].location == .init(x: 40, y: 40))
        }
    }
}
