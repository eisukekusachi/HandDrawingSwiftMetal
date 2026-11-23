//
//  Created by Eisuke Kusachi
//

import Core
import Foundation

/// HandDrawing NSError domain and codes. Add codes here to avoid collisions.
enum HandDrawingNSError {

    static let domain = "HandDrawing"

    enum Code: Int {
        case textureLayerCanvasDrawingSaveInProgress = 1

        var nsError: NSError {
            NSError(
                domain: HandDrawingNSError.domain,
                code: rawValue,
                title: String(localized: "error.title"),
                message: message
            )
        }

        private var message: String {
            switch self {
            case .textureLayerCanvasDrawingSaveInProgress:
                String(localized: "textureLayerCanvasDrawing.saveInProgress")
            }
        }
    }
}