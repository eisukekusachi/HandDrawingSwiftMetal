//
//  Created by Eisuke Kusachi
//

/// Displays the canvas on screen.
@MainActor
public protocol CanvasUpdating: AnyObject {

    /// Displays the canvas.
    func updateCanvasDisplay()
}
