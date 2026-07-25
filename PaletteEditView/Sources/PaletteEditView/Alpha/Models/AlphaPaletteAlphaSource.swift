//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Combine

@MainActor
public protocol AlphaPaletteAlphaSource: ObservableObject {
    var selectedAlpha: Int { get }
    var selectedIndex: Int { get }
}
