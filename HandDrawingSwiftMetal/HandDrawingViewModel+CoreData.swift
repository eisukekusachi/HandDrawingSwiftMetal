//
//  Created by Eisuke Kusachi
//

extension HandDrawingViewModel {

    /// Best-effort restore of palettes and project dates from Core Data.
    /// Missing entities are skipped; read failures are logged and do not propagate.
    func fetchDataFromCoreDataIfAvailable() {
        do {
            if let projectEntity = try dependencies.projectStorage.fetch() {
                project.apply(projectEntity)
            }
            if let drawingToolEntity = try dependencies.drawingToolStorage.fetch() {
                drawingTool.apply(drawingToolEntity)
            }
            if let brushEntity = try dependencies.brushPaletteStorage.fetch() {
                brushPalette.apply(brushEntity)
            }
            if let eraserEntity = try dependencies.eraserPaletteStorage.fetch() {
                eraserPalette.apply(eraserEntity)
            }
        } catch {
            Logger.error(error)
        }
    }
}
