//
//  SliderValue.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2025/07/04.
//

import SwiftUI

class SliderValue: ObservableObject {

    @Published var value: Int = 0

    @Published var isHandleDragging: Bool = false

    var temporaryStoredValue: Int?

    init(value: Int = 0) {
        self.value = value
    }

}
