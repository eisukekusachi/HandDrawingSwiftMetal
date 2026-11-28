//
//  Created by Eisuke Kusachi
//

import Core

extension HandDrawingViewModel {

    /// Best-effort restore of palettes and project dates from Core Data.
    /// Missing entities are skipped; read failures are logged and do not propagate.
    func fetchDataFromCoreDataIfAvailable() {
        do {
            if let projectEntity = try dependencies.projectStorage.fetch() {
                project.apply(projectEntity)
            }
            try dependencies.drawingToolStorage.load(into: drawingTool)
            try dependencies.brushPaletteStorage.load(into: brushPalette)
            try dependencies.eraserPaletteStorage.load(into: eraserPalette)
        } catch {
            Core.Logger.error(error)
        }
    }
}
