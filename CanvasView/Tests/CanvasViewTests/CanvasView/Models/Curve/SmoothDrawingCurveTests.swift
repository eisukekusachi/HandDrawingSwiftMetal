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
    struct SmoothPointsTests {
        @Test
        func `Verify that the average values are added`() async throws {
            let subject = Subject()

            subject.append(points: [
                .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30)
            ], touchPhase: .ended)

            #expect(subject.array == [
                .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5),
                .init(location: .init(x: 15, y: 15), brightness: 15, diameter: 15, blurSize: 15),
                .init(location: .init(x: 25, y: 25), brightness: 25, diameter: 25, blurSize: 25),
                .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30)
            ])
        }

        @Test
        func `Verify that the average value is added`() async throws {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30),
                .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40)
            ]

            // At least two points are required to obtain the average value.
            subject.append(points: [points[0]], touchPhase: .began)
            #expect(subject.array.isEmpty == true)

            subject.append(points: [points[1]], touchPhase: .moved)
            // Add the first point during the initial process.
            #expect(subject.array[0] == .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0))
            #expect(subject.array[1] == .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5))

            subject.append(points: [points[2]], touchPhase: .moved)
            #expect(subject.array[2] == .init(location: .init(x: 15, y: 15), brightness: 15, diameter: 15, blurSize: 15))

            subject.append(points: [points[3]], touchPhase: .moved)
            #expect(subject.array[3] == .init(location: .init(x: 25, y: 25), brightness: 25, diameter: 25, blurSize: 25))

            subject.append(points: [points[4]], touchPhase: .ended)
            #expect(subject.array[4] == .init(location: .init(x: 35, y: 35), brightness: 35, diameter: 35, blurSize: 35))
            // Add the last point during the final process.
            #expect(subject.array[5] == .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40))
        }
    }
}
