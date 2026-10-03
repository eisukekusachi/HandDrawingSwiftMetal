//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

/// Snapshot of `DrawingTool` used when saving and restoring.
/// The tool type is stored as its raw `Int`.
struct DrawingToolSnapshot: Codable, Sendable {
    let type: Int
    let brushDiameter: Int
    let eraserDiameter: Int

    init(type: Int, brushDiameter: Int, eraserDiameter: Int) {
        self.type = type
        self.brushDiameter = brushDiameter
        self.eraserDiameter = eraserDiameter
    }

    @MainActor
    init(_ drawingTool: DrawingTool) {
        self.init(
            type: drawingTool.type.rawValue,
            brushDiameter: drawingTool.brushDiameter,
            eraserDiameter: drawingTool.eraserDiameter
        )
    }
}

extension DrawingToolSnapshot: LocalFileConvertible {
    static var fileName: String { "drawing_tool" }
}
