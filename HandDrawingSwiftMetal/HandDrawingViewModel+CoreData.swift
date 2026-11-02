//
//  Created by Eisuke Kusachi
//

extension HandDrawingViewModel {

    /// Restores domain models from Core Data when the canvas loads.
    func fetchDataFromCoreDataIfAvailable() throws {
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
    }
}
