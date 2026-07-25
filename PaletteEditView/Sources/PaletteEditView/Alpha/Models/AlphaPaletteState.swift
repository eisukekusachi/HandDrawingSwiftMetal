//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import Combine

@MainActor
public final class AlphaPaletteState: ObservableObject {

    @Published public var alpha: Int = 255

    private let onChanged: ((Int) -> Void)?

    public init(onChanged: ((Int) -> Void)? = nil) {
        self.onChanged = onChanged
    }

    public func setAlpha(_ value: Int) {
        alpha = min(max(0, value), 255)
    }

    public func updateAlpha(_ value: Int) {
        alpha = min(max(0, value), 255)
        onChanged?(alpha)
    }
}
