//
//  PaletteView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import Foundation

public struct AlphaPaletteItem: Identifiable, Equatable {
    public let id: UUID
    public var alpha: Int

    public init(id: UUID = UUID(), alpha: Int) {
        self.id = id
        self.alpha = Self.clamped(alpha)
    }

    public static func clamped(_ alpha: Int) -> Int {
        min(max(0, alpha), 255)
    }
}
