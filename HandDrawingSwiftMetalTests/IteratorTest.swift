//
//  IteratorTest.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2023/04/03.
//

import XCTest
@testable import HandDrawingSwiftMetal

class IteratorTest: XCTestCase {
    func testDefaultIteratorNormalSenarios() {
        
        XCTContext.runActivity(named: "A normal scenario that the range of 4.") { _ in
            
            let fingerInput0: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
                .init(location: CGPoint(x: 20, y: 20), alpha: 0.2)
            ]
            let fingerInput1: [PointImpl] = [
                .init(location: CGPoint(x: 30, y: 30), alpha: 0.3)
            ]
            let fingerInput2: [PointImpl] = [
                .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
                .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
                .init(location: CGPoint(x: 60, y: 60), alpha: 0.6),
                .init(location: CGPoint(x: 70, y: 70), alpha: 0.7)
            ]
            
            let answers0: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
                .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
                .init(location: CGPoint(x: 30, y: 30), alpha: 0.3)
            ]
            let answers1: [[PointImpl]] = [
                [
                    .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
                    .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
                    .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
                    .init(location: CGPoint(x: 40, y: 40), alpha: 0.4)
                ],
                [
                    .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
                    .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
                    .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
                    .init(location: CGPoint(x: 50, y: 50), alpha: 0.5)
                ],
                [
                    .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
                    .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
                    .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
                    .init(location: CGPoint(x: 60, y: 60), alpha: 0.6)
                ],
                [
                    .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
                    .init(location: CGPoint(x: 50, y: 50), alpha: 0.5),
                    .init(location: CGPoint(x: 60, y: 60), alpha: 0.6),
                    .init(location: CGPoint(x: 70, y: 70), alpha: 0.7)
                ]
            ]
            
            let iterator = Iterator<Point>()
            var singleFingerLocationArray: [PointImpl] = []
            var count = 0
            
            
            // The number of elements is 3.
            singleFingerLocationArray.append(contentsOf: fingerInput0)
            iterator.update(elems: singleFingerLocationArray)
            XCTAssertEqual(iterator.array.count, 3)
            
            var notPassThroughBlock: Bool = true
            while let _ = iterator.next(range: 4) {
                notPassThroughBlock = false
            }
            XCTAssertTrue(notPassThroughBlock, "Not executed due to low array count.")
            
            
            // The number of elements is 4.
            singleFingerLocationArray.append(contentsOf: fingerInput1)
            iterator.update(elems: singleFingerLocationArray)
            XCTAssertEqual(iterator.array.count, 4)
            
            count = 0
            while let subsequece = iterator.next(range: 4) {
                
                XCTAssertEqual(subsequece.count, 4)
                XCTAssertEqual(subsequece[0] as? PointImpl, answers0[0])
                XCTAssertEqual(subsequece[1] as? PointImpl, answers0[1])
                XCTAssertEqual(subsequece[2] as? PointImpl, answers0[2])
                XCTAssertEqual(subsequece[3] as? PointImpl, answers0[3])
                
                count += 1
            }
            XCTAssertEqual(count, 1, "Executed once.")
            
            
            // The number of elements is 8.
            singleFingerLocationArray.append(contentsOf: fingerInput2)
            iterator.update(elems: singleFingerLocationArray)
            XCTAssertEqual(iterator.array.count, 8)
            
            count = 0
            while let subsequece = iterator.next(range: 4) {
                
                XCTAssertEqual(subsequece.count, 4)
                XCTAssertEqual(subsequece[0] as? PointImpl, answers1[count][0])
                XCTAssertEqual(subsequece[1] as? PointImpl, answers1[count][1])
                XCTAssertEqual(subsequece[2] as? PointImpl, answers1[count][2])
                XCTAssertEqual(subsequece[3] as? PointImpl, answers1[count][3])
                
                count += 1
            }
            XCTAssertEqual(count, 4, "Executed 4 times.")
        }
        
        XCTContext.runActivity(named: "A normal scenario that the range of 1.") { _ in
            
            let fingerInput: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
                .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
                .init(location: CGPoint(x: 30, y: 30), alpha: 0.3)
            ]
            
            let iterator = Iterator<Point>()
            iterator.update(elems: fingerInput)
            XCTAssertEqual(iterator.array.count, 4)
            
            var index = 0
            while let subsequece = iterator.next(range: 1) {
                if index == 0 {
                    XCTAssertTrue(iterator.isFirstProcessing)
                }
                
                XCTAssertEqual(subsequece.count, 1)
                XCTAssertEqual(subsequece[0] as? PointImpl, fingerInput[index + 0])
                
                index += 1
            }
        }
    }
    
    func testDefaultIteratorNonNormalSenarios() {
        
        XCTContext.runActivity(named: "Non-normal scenarios") { _ in
            
            let fingerInput: [PointImpl] = [
                .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
                .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
                .init(location: CGPoint(x: 20, y: 20), alpha: 0.2)
            ]
            
            let iterator = Iterator<Point>()
            var notPassThroughBlock: Bool = true
            
            iterator.update(elems: fingerInput)
            XCTAssertEqual(iterator.array.count, fingerInput.count)
            XCTAssertEqual(iterator.array.count, 3)
            
            notPassThroughBlock = true
            while let _ = iterator.next(range: 0) {
                notPassThroughBlock = false
            }
            XCTAssertTrue(notPassThroughBlock, "Because the range is 0.")
            
            
            iterator.reset()
            
            iterator.update(elems: fingerInput)
            XCTAssertEqual(iterator.array.count, fingerInput.count)
            XCTAssertEqual(iterator.array.count, 3)
            
            notPassThroughBlock = true
            while let _ = iterator.next(range: 4) {
                notPassThroughBlock = false
            }
            XCTAssertTrue(notPassThroughBlock, "Because the range is greater than the number of array elements.")
        }
    }
    
    func testSmoothIterator() {
    
        let fingerInput: [PointImpl] = [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0),
            .init(location: CGPoint(x: 10, y: 10), alpha: 0.1),
            .init(location: CGPoint(x: 20, y: 20), alpha: 0.2),
            .init(location: CGPoint(x: 30, y: 30), alpha: 0.3),
            .init(location: CGPoint(x: 40, y: 40), alpha: 0.4),
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5)
        ]
        
        let answers: [[PointImpl]] = [
            [
            .init(location: CGPoint(x: 0, y: 0), alpha: 0.0), // Use the first point.
            .init(location: CGPoint(x: 5, y: 5), alpha: 0.05), // Use the value of the average.
            .init(location: CGPoint(x: 15, y: 15), alpha: 0.15),
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25)
            ],
            [
            .init(location: CGPoint(x: 5, y: 5), alpha: 0.05),
            .init(location: CGPoint(x: 15, y: 15), alpha: 0.15),
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25),
            .init(location: CGPoint(x: 35, y: 35), alpha: 0.35)
            ],
            [
            .init(location: CGPoint(x: 15, y: 15), alpha: 0.15),
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25),
            .init(location: CGPoint(x: 35, y: 35), alpha: 0.35),
            .init(location: CGPoint(x: 45, y: 45), alpha: 0.45)
            ],
            [
            .init(location: CGPoint(x: 25, y: 25), alpha: 0.25),
            .init(location: CGPoint(x: 35, y: 35), alpha: 0.35),
            .init(location: CGPoint(x: 45, y: 45), alpha: 0.45), // Use the value of the average.
            .init(location: CGPoint(x: 50, y: 50), alpha: 0.5) // Use the last point.
            ]
        ]
        
        
        let iterator = Iterator<Point>()
        var smoothIterator = Iterator<Point>()
        
        iterator.update(elems: fingerInput)
        SmoothPointStorage.makeSmoothIterator(src: iterator, dst: &smoothIterator, endProcessing: true)
        
        var count: Int = 0
        while let subsequece = smoothIterator.next(range: 4) {
            if var point0 = subsequece[0] as? PointImpl,
               var point1 = subsequece[1] as? PointImpl,
               var point2 = subsequece[2] as? PointImpl,
               var point3 = subsequece[3] as? PointImpl {
                
                // It is just rounding the alpha values for testing.
                point0.alpha = round(point0.alpha * 100) / 100
                point1.alpha = round(point1.alpha * 100) / 100
                point2.alpha = round(point2.alpha * 100) / 100
                point3.alpha = round(point3.alpha * 100) / 100
                
                XCTAssertEqual([point0, point1, point2, point3], answers[count])
            }
            
            count += 1
        }
    }
}
