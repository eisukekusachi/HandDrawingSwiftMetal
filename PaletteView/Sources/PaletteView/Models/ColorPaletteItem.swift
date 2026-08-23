//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import UIKit

public struct ColorPaletteItem: Identifiable, Equatable {
    public let id: UUID
    public var color: UIColor

    public init(id: UUID = UUID(), color: UIColor) {
        self.id = id
        self.color = color
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.color == rhs.color
    }
}
