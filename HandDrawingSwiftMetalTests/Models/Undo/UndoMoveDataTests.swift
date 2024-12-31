//
//  UndoMoveDataTests.swift
//  HandDrawingSwiftMetalTests
//
//  Created by Eisuke Kusachi on 2024/12/31.
//

import XCTest
@testable import HandDrawingSwiftMetal

final class UndoMoveDataTests: XCTestCase {

    /// Confirms the behavior of the undo operation for movement
    func testUndoMoveData() {
        struct Condition {
            let layers: [TextureLayer]
            let selectedIndex: Int
            let source: Int
            let destination: Int
        }
        struct Expectation {
            let layers: [TextureLayer]
            let selectedIndex: Int
        }

        let cases: [(Condition, Expectation)] = [
            // When moving a selected layer
            // Case where the first element is selected and moved to the last position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 0,
                    source: 0,
                    destination: 2
                ),
                .init(
                    layers: [.generate(title: "b"), .generate(title: "c"), .generate(title: "a")],
                    selectedIndex: 2
                )
            ),
            // Case where the last element is selected and moved to the first position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 2,
                    source: 2,
                    destination: 0
                ),
                .init(
                    layers: [.generate(title: "c"), .generate(title: "a"), .generate(title: "b")],
                    selectedIndex: 0
                )
            ),
            // When moving an unselected layer
            // Case where the first element is selected and the second element is moved to the last position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 0,
                    source: 1,
                    destination: 2
                ),
                .init(
                    layers: [.generate(title: "a"), .generate(title: "c"), .generate(title: "b")],
                    selectedIndex: 0
                )
            ),
            // Case where the first element is selected and the last element is moved to the second position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 0,
                    source: 1,
                    destination: 2
                ),
                .init(
                    layers: [.generate(title: "a"), .generate(title: "c"), .generate(title: "b")],
                    selectedIndex: 0
                )
            ),
            // Case where the last element is selected and the first element is moved to the second position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 2,
                    source: 0,
                    destination: 1
                ),
                .init(
                    layers: [.generate(title: "b"), .generate(title: "a"), .generate(title: "c")],
                    selectedIndex: 2
                )
            ),
            // Case where the last element is selected and the second element is moved to the first position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 2,
                    source: 1,
                    destination: 0
                ),
                .init(
                    layers: [.generate(title: "b"), .generate(title: "a"), .generate(title: "c")],
                    selectedIndex: 2
                )
            ),
            // Case where the second element is selected and the first element is moved to the last position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 1,
                    source: 0,
                    destination: 2
                ),
                .init(
                    layers: [.generate(title: "b"), .generate(title: "c"), .generate(title: "a")],
                    selectedIndex: 0
                )
            ),
            // Case where the second element is selected and the last element is moved to the first position
            (
                .init(
                    layers: [.generate(title: "a"), .generate(title: "b"), .generate(title: "c")],
                    selectedIndex: 1,
                    source: 2,
                    destination: 0
                ),
                .init(
                    layers: [.generate(title: "c"), .generate(title: "a"), .generate(title: "b")],
                    selectedIndex: 2
                )
            )
        ]

        cases.forEach {
            let condition = $0.0
            let expectation = $0.1

            let fromIndex = UndoMoveData.getMoveFromIndex(source: condition.source, destination: condition.destination)
            let toIndex = UndoMoveData.getMoveToIndex(source: condition.source, destination: condition.destination)

            let layers: TextureLayers = .init()
            layers.initLayers(
                index: condition.selectedIndex,
                layers: condition.layers
            )

            let selectedIndexAfterMove = UndoMoveData.makeSelectedIndexAfterMove(
                source: condition.source,
                destination: condition.destination,
                selectedIndex: condition.selectedIndex
            )

            let layer = layers.layers[condition.source]

            layers.moveLayer(
                fromIndex: fromIndex,
                toIndex: toIndex,
                selectedIndex: UndoMoveData.makeSelectedIndexAfterMove(
                    source: condition.source,
                    destination: UndoMoveData.getMoveDestination(fromIndex: fromIndex, toIndex: toIndex),
                    selectedIndex: condition.selectedIndex
                ),
                layer: layer
            )

            XCTAssertEqual(layers.index, expectation.selectedIndex)
            XCTAssertEqual(layers.layers.map { $0.title }.joined(), expectation.layers.map { $0.title }.joined())

            let undoData: UndoMoveData = .init(
                source: condition.source,
                destination: UndoMoveData.getMoveDestination(fromIndex: fromIndex, toIndex: toIndex),
                selectedIndex: condition.selectedIndex,
                selectedIndexAfterMove: selectedIndexAfterMove
            )
            layers.moveLayer(
                fromIndex: undoData.fromIndex,
                toIndex: undoData.toIndex,
                selectedIndex: undoData.selectedIndex,
                layer: layer
            )

            XCTAssertEqual(layers.index, condition.selectedIndex)
            XCTAssertEqual(layers.layers.map { $0.title }.joined(), condition.layers.map { $0.title }.joined())
        }
    }

}
