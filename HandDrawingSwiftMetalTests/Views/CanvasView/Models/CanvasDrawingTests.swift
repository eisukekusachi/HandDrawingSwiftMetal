//
//  CanvasDrawingTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/10/19.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class CanvasDrawingTests: XCTestCase {

    func testIsCurrentlyDrawing() {
        let drawing = CanvasDrawing()
        XCTAssertEqual(drawing.isCurrentlyDrawing, false)

        drawing.appendToIterator(.generate())
        XCTAssertEqual(drawing.isCurrentlyDrawing, true)

        drawing.reset()
        XCTAssertEqual(drawing.isCurrentlyDrawing, false)
    }

    /// Confirms that the drawing has finished
    func testIsDrawingComplete() {
        let drawing = CanvasDrawing()
        XCTAssertEqual(drawing.isDrawingComplete, false)

        drawing.setCurrentTouchPhase(.began)
        XCTAssertEqual(drawing.isDrawingComplete, false)

        drawing.setCurrentTouchPhase(.moved)
        XCTAssertEqual(drawing.isDrawingComplete, false)

        drawing.setCurrentTouchPhase(.ended)
        XCTAssertEqual(drawing.isDrawingComplete, true)

        drawing.setCurrentTouchPhase(.cancelled)
        XCTAssertEqual(drawing.isDrawingComplete, false)
    }

    /// Confirms that the drawing has finished, regardless of success or failure
    func testIsDrawingFinished() {
        let drawing = CanvasDrawing()

        XCTAssertEqual(drawing.isDrawingFinished, false)

        drawing.setCurrentTouchPhase(.began)
        XCTAssertEqual(drawing.isDrawingFinished, false)

        drawing.setCurrentTouchPhase(.moved)
        XCTAssertEqual(drawing.isDrawingFinished, false)

        drawing.setCurrentTouchPhase(.ended)
        XCTAssertEqual(drawing.isDrawingFinished, true)

        drawing.setCurrentTouchPhase(.cancelled)
        XCTAssertEqual(drawing.isDrawingFinished, true)
    }

    /// Confirms that the first curve has been drawn once
    func testHasArrayThreeElementsButNoFirstCurveDrawn() {
        let drawing = CanvasDrawing()

        drawing.appendToIterator([.generate()])
        XCTAssertEqual(drawing.hasArrayThreeElementsButNoFirstCurveCreated, false)

        drawing.appendToIterator([.generate()])
        XCTAssertEqual(drawing.hasArrayThreeElementsButNoFirstCurveCreated, false)

        drawing.appendToIterator([.generate()])
        XCTAssertEqual(drawing.hasArrayThreeElementsButNoFirstCurveCreated, true)

        drawing.setFirstCurveHasBeenCreated()
        XCTAssertEqual(drawing.hasArrayThreeElementsButNoFirstCurveCreated, false)
    }

    /// Confirm that the first curve array can be created
    func testMakeFirstCurvePoints() {
        struct Condition {
            let points: [CanvasGrayscaleDotPoint]
        }
        struct Expectation {
            let result: [CanvasGrayscaleDotPoint]
        }

        let testCases: [(condition: Condition, expectation: Expectation)] = [
            (
                /// The case with fewer than 3 points
                condition: .init(
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0)
                    ]
                ),
                expectation: .init(
                    result: []
                )
            ),
            (
                /// The start of the curve connects to the first point, and the end of the curve connects to the second point. The last point is used to create the Bezier curve handles.
                /// The first curve does not include the last point to connect with the next curve.
                condition: .init(
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0)
                    ]
                ),
                expectation: .init(
                    result: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 1.25, y: 1.25), diameter: 1.5, brightness: 1.5)
                        /// `(x: 2.0, y: 2.0)` is not included
                    ]
                )
            )
        ]

        for testCase in testCases {
            let condition = testCase.condition
            let expectation = testCase.expectation

            let drawing = CanvasDrawing()
            drawing.appendToIterator(condition.points)

            let result = drawing.makeFirstCurvePoints()
            XCTAssertEqual(result, expectation.result)
        }
    }

    /// Confirm that the curve array can be created
    func testMakeIntermediateCurvePoints() {
        struct Condition {
            let shouldIncludeEndPoint: Bool
            let points: [CanvasGrayscaleDotPoint]
        }
        struct Expectation {
            let result: [CanvasGrayscaleDotPoint]
        }

        let testCases: [(condition: Condition, expectation: Expectation)] = [
            /// The case with fewer than 4 points
            (
                /// Confirm that an empty array is returned if there are fewer than four points, as four points are required to create an array of Bezier curve points.
                condition: .init(
                    shouldIncludeEndPoint: true,
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0)
                    ]
                ),
                expectation: .init(
                    result: []
                )
            ),
            (
                /// Confirm that an empty array is returned if there are fewer than four points, as four points are required to create an array of Bezier curve points.
                condition: .init(
                    shouldIncludeEndPoint: false,
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0)
                    ]
                ),
                expectation: .init(
                    result: []
                )
            ),
            /// The case with 4 points
            (
                /// Confirm that the start of the curve is the second point and the end of the curve is the second-to-last point,
                /// since the first and last points are used for the Bezier curve handles.
                condition: .init(
                    shouldIncludeEndPoint: true,
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0),
                        .generate(location: .init(x: 5.0, y: 5.0), diameter: 4.0, brightness: 4.0)
                    ]
                ),
                expectation: .init(
                    result: [
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 2.75, y: 2.75), diameter: 2.5, brightness: 2.5),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0)
                    ]
                )
            ),
            (
                /// Confirm that the last point is not added
                condition: .init(
                    shouldIncludeEndPoint: false,
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0),
                        .generate(location: .init(x: 5.0, y: 5.0), diameter: 4.0, brightness: 4.0)
                    ]
                ),
                expectation: .init(
                    result: [
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 2.75, y: 2.75), diameter: 2.5, brightness: 2.5)
                    ]
                )
            ),

            /// The case with more than 4 points
            (
                /// Confirm that the start of the curve is the second point and the end of the curve is the second-to-last point,
                /// as the first and last points are used for the Bezier curve handles, even when there are more than four points.”
                condition: .init(
                    shouldIncludeEndPoint: true,
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0),
                        .generate(location: .init(x: 5.0, y: 5.0), diameter: 4.0, brightness: 4.0),
                        .generate(location: .init(x: 6.5, y: 6.5), diameter: 5.0, brightness: 5.0),
                        .generate(location: .init(x: 8.0, y: 8.0), diameter: 6.0, brightness: 6.0)
                    ]
                ),
                expectation: .init(
                    result: [
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 2.75, y: 2.75), diameter: 2.5, brightness: 2.5),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0),
                        .generate(location: .init(x: 4.25, y: 4.25), diameter: 3.5, brightness: 3.5),
                        .generate(location: .init(x: 5.0, y: 5.0), diameter: 4.0, brightness: 4.0),
                        .generate(location: .init(x: 5.75, y: 5.75), diameter: 4.5, brightness: 4.5),
                        .generate(location: .init(x: 6.5, y: 6.5), diameter: 5.0, brightness: 5.0)
                    ]
                )
            ),
            (
                /// Confirm that the last point is not added
                condition: .init(
                    shouldIncludeEndPoint: false,
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0),
                        .generate(location: .init(x: 5.0, y: 5.0), diameter: 4.0, brightness: 4.0),
                        .generate(location: .init(x: 6.5, y: 6.5), diameter: 5.0, brightness: 5.0),
                        .generate(location: .init(x: 8.0, y: 8.0), diameter: 6.0, brightness: 6.0)
                    ]
                ),
                expectation: .init(
                    result: [
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 2.75, y: 2.75), diameter: 2.5, brightness: 2.5),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0),
                        .generate(location: .init(x: 4.25, y: 4.25), diameter: 3.5, brightness: 3.5),
                        .generate(location: .init(x: 5.0, y: 5.0), diameter: 4.0, brightness: 4.0),
                        .generate(location: .init(x: 5.75, y: 5.75), diameter: 4.5, brightness: 4.5)
                    ]
                )
            )
        ]

        for testCase in testCases {
            let condition = testCase.condition
            let expectation = testCase.expectation

            let drawing = CanvasDrawing()
            drawing.appendToIterator(condition.points)

            let result = drawing.makeIntermediateCurvePoints(
                shouldIncludeEndPoint: condition.shouldIncludeEndPoint
            )
            XCTAssertEqual(result, expectation.result)
        }
    }

    /// Confirm that the last curve array can be created
    func testMakeLastCurvePoints() {
        struct Condition {
            let points: [CanvasGrayscaleDotPoint]
        }
        struct Expectation {
            let result: [CanvasGrayscaleDotPoint]
        }

        let testCases: [(condition: Condition, expectation: Expectation)] = [
            (
                /// The case with fewer than 3 points
                condition: .init(
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0)
                    ]
                ),
                expectation: .init(
                    result: []
                )
            ),
            (
                /// The start of the curve connects to the second point, and the end of the curve connects to the last point. The first point is used to create the Bezier curve handles.
                /// The last curve includes the last point since it does not connect with the next curve.
                condition: .init(
                    points: [
                        .generate(location: .init(x: 0.5, y: 0.5), diameter: 1.0, brightness: 1.0),
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0)
                    ]
                ),
                expectation: .init(
                    result: [
                        .generate(location: .init(x: 2.0, y: 2.0), diameter: 2.0, brightness: 2.0),
                        .generate(location: .init(x: 2.75, y: 2.75), diameter: 2.5, brightness: 2.5),
                        .generate(location: .init(x: 3.5, y: 3.5), diameter: 3.0, brightness: 3.0)
                    ]
                )
            )
        ]

        for testCase in testCases {
            let condition = testCase.condition
            let expectation = testCase.expectation

            let drawing = CanvasDrawing()
            drawing.appendToIterator(condition.points)

            let result = drawing.makeLastCurvePoints()
            XCTAssertEqual(result, expectation.result)
        }
    }

}
