//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

public enum ColorPaletteSegment: String, CaseIterable, Identifiable, Sendable {
    case grid
    case spectrum
    case sliders

    public var id: String { rawValue }
}
