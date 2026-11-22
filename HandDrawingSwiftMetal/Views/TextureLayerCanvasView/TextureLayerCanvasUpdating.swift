//
//  Created by Eisuke Kusachi
//

import CanvasView

/// Displays the canvas on screen.
@MainActor
public protocol TextureLayerCanvasUpdating: CanvasUpdating {

    /// Throws when the current stroke has not been written to Storage yet.
    func throwIfUnsavedDrawing() throws

    /// Reloads the selected layer into `currentTexture` and recomposites the canvas.
    func updateFullCanvas() async throws
}