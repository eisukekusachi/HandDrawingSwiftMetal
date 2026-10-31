//
//  Created by Eisuke Kusachi
//

import CanvasView

/// Displays the canvas on screen.
@MainActor
public protocol TextureLayerCanvasUpdating: CanvasUpdating {

    /// Updates the whole canvas.
    func updateFullCanvas() async throws
}
