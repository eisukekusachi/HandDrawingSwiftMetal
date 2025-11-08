//
//  DefaultDrawingCurveTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/09/07.
//

import Testing

@testable import CanvasView

struct DefaultDrawingCurveTests {

    private typealias Subject = DefaultDrawingCurve

    @Suite
    struct DrawingCurveTest {

        @Test
        func `Verify the creation of curve points`() {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 10, y: 10)),
                .generate(location: .init(x: 20, y: 20)),
                .generate(location: .init(x: 30, y: 30)),
                .generate(location: .init(x: 40, y: 40))
            ]

            subject.append(points: points, touchPhase: .ended)

            #expect(
                subject.curvePoints(
                    firstDuration: 2,
                    intermediateDuration: 2,
                    lastDuration: 2
                ).map { $0.location } ==
                [
                    .init(x: 0, y: 0),
                    .init(x: 5, y: 5),
                    .init(x: 10, y: 10),
                    .init(x: 15, y: 15),
                    .init(x: 20, y: 20),
                    .init(x: 25, y: 25),
                    .init(x: 30, y: 30),
                    .init(x: 35, y: 35),
                    .init(x: 40, y: 40)
                ]
            )

            subject.reset()

            #expect(
                subject.curvePoints(
                    firstDuration: 2,
                    intermediateDuration: 2,
                    lastDuration: 2
                ).map { $0.location } == []
            )
        }

        @Test
        func `Verify the creation of the first curve points`() {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 10, y: 10)),
                .generate(location: .init(x: 20, y: 20)),
                .generate(location: .init(x: 30, y: 30))
            ]

            subject.append(points: points, touchPhase: .began)

            #expect(
                subject.makeFirstCurvePoints(duration: 2).map { $0.location } ==
                [
                    .init(x: 0, y: 0),
                    .init(x: 5, y: 5)
                ]
            )
        }

        @Test
        func `Verify the creation of the intermediate curve points`() {
            let subject = Subject()

            subject.append(
                points: [
                    .generate(location: .init(x: 0, y: 0)),
                    .generate(location: .init(x: 10, y: 10)),
                    .generate(location: .init(x: 20, y: 20)),
                    .generate(location: .init(x: 30, y: 30))
                ],
                touchPhase: .moved
            )

            #expect(
                subject.makeIntermediateCurvePoints(duration: 2).map { $0.location } ==
                [
                    .init(x: 10, y: 10),
                    .init(x: 15, y: 15)
                ]
            )

            subject.append(
                points: [
                    .generate(location: .init(x: 40, y: 40))
                ],
                touchPhase: .moved
            )

            #expect(
                subject.makeIntermediateCurvePoints(duration: 2).map { $0.location } ==
                [
                    .init(x: 20, y: 20),
                    .init(x: 25, y: 25)
                ]
            )
        }

        @Test
        func `Verify the creation of the last curve points`() {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .generate(location: .init(x: 0, y: 0)),
                .generate(location: .init(x: 10, y: 10)),
                .generate(location: .init(x: 20, y: 20)),
                .generate(location: .init(x: 30, y: 30)),
                .generate(location: .init(x: 40, y: 40))
            ]

            subject.append(points: points, touchPhase: .moved)

            #expect(
                subject.makeLastCurvePoints(duration: 2).map { $0.location } ==
                [
                    .init(x: 30, y: 30),
                    .init(x: 35, y: 35),
                    .init(x: 40, y: 40)
                ]
            )
        }
    }

    @Suite
    struct IsFirstCurveNeededTest {
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
}
