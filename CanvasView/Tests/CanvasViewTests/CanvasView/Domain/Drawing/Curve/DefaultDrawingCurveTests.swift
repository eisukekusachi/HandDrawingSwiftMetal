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
    struct IsFirstCurveNeededTest {
        @Test
        func `Verify that it returns true when DefaultDrawingCurve has three points`() {
            let subject = Subject()

            subject.append(points: [.generate()], touchPhase: .began)
            #expect(subject.isFirstCurveNeeded() == false)

            subject.append(points: [.generate()], touchPhase: .moved)
            #expect(subject.isFirstCurveNeeded() == false)

            subject.append(points: [.generate()], touchPhase: .moved)
            #expect(subject.isFirstCurveNeeded() == true)
        }

        @Test
        func `Verify that it returns true when DefaultDrawingCurve has more than three points`() {
            let subject = Subject()

            subject.append(points: [
                .generate(),
                .generate(),
                .generate(),
                .generate()
            ], touchPhase: .moved)

            #expect(subject.isFirstCurveNeeded() == true)
        }
    }

    @Suite
    struct DrawingCurveTest {
        @Test
        func `Verify the creation of curve points`() {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30),
                .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40)
            ]

            subject.append(points: points, touchPhase: .ended)

            #expect(
                subject.curvePoints(
                    firstDuration: 2,
                    intermediateDuration: 2,
                    lastDuration: 2
                ) == [
                    .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                    .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5),
                    .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                    .init(location: .init(x: 15, y: 15), brightness: 15, diameter: 15, blurSize: 15),
                    .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                    .init(location: .init(x: 25, y: 25), brightness: 25, diameter: 25, blurSize: 25),
                    .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30),
                    .init(location: .init(x: 35, y: 35), brightness: 35, diameter: 35, blurSize: 35),
                    .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40)
                ]
            )
        }

        @Test
        func `Verify the creation of the first curve points`() {
            let subject = Subject()

            subject.append(
                points: [
                    .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                    .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                    .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                    .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30),
                ],
                touchPhase: .began
            )

            #expect(
                subject.makeFirstCurvePoints(duration: 2) ==
                [
                    .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                    .init(location: .init(x: 5, y: 5), brightness: 5, diameter: 5, blurSize: 5),
                ]
            )
        }

        @Test
        func `Verify the creation of the intermediate curve points`() {
            let subject = Subject()

            subject.append(
                points: [
                    .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                    .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                    .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                    .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30)
                ],
                touchPhase: .moved
            )

            #expect(
                subject.makeIntermediateCurvePoints(duration: 2) ==
                [
                    .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                    .init(location: .init(x: 15, y: 15), brightness: 15, diameter: 15, blurSize: 15),
                ]
            )

            subject.append(
                points: [
                    .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40),
                ],
                touchPhase: .moved
            )

            #expect(
                subject.makeIntermediateCurvePoints(duration: 2) ==
                [
                    .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                    .init(location: .init(x: 25, y: 25), brightness: 25, diameter: 25, blurSize: 25)
                ]
            )
        }

        @Test
        func `Verify the creation of the last curve points`() {
            let subject = Subject()

            let points: [GrayscaleDotPoint] = [
                .init(location: .init(x: 0, y: 0), brightness: 0, diameter: 0, blurSize: 0),
                .init(location: .init(x: 10, y: 10), brightness: 10, diameter: 10, blurSize: 10),
                .init(location: .init(x: 20, y: 20), brightness: 20, diameter: 20, blurSize: 20),
                .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30),
                .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40)
            ]

            subject.append(points: points, touchPhase: .moved)

            #expect(
                subject.makeLastCurvePoints(duration: 2) ==
                [
                    .init(location: .init(x: 30, y: 30), brightness: 30, diameter: 30, blurSize: 30),
                    .init(location: .init(x: 35, y: 35), brightness: 35, diameter: 35, blurSize: 35),
                    .init(location: .init(x: 40, y: 40), brightness: 40, diameter: 40, blurSize: 40)
                ]
            )
        }
    }

    @Suite
    struct EmptyTest {
        @Test
        func `Verify that nothing is produced when the array is empty.`() {
            let subject = Subject()

            subject.append(points: [], touchPhase: .began)
            #expect(subject.makeFirstCurvePoints(duration: 2) == [])

            subject.append(points: [], touchPhase: .moved)
            #expect(subject.makeIntermediateCurvePoints(duration: 2) == [])

            subject.append(points: [], touchPhase: .ended)
            #expect(subject.makeLastCurvePoints(duration: 2) == [])

            #expect(subject.curvePoints(firstDuration: 2, intermediateDuration: 2, lastDuration: 2) == [])
        }
    }

    @Suite
    struct ResetTest {
        @Test
        func `Verify that the values are reset by reset()`() {
            let subject = Subject()

            #expect(subject.count == 0)
            #expect(subject.touchPhase == .cancelled)
            #expect(subject.hasFirstCurveBeenDrawn == false)

            subject.append(points: [
                .generate(),
                .generate(),
                .generate(),
                .generate()
            ], touchPhase: .moved)
            subject.markFirstCurveAsDrawn()

            #expect(subject.count == 4)
            #expect(subject.touchPhase == .moved)
            #expect(subject.hasFirstCurveBeenDrawn == true)

            subject.reset()

            #expect(subject.count == 0)
            #expect(subject.touchPhase == .cancelled)
            #expect(subject.hasFirstCurveBeenDrawn == false)
        }
    }
}
