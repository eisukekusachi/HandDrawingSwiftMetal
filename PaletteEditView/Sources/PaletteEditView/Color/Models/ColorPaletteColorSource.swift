//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Combine
import UIKit

@MainActor
public protocol ColorPaletteColorSource: ObservableObject {
    var selectedColor: UIColor { get }
    var selectedIndex: Int { get }
}
