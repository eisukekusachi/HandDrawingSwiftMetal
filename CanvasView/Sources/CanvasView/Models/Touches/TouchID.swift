//
//  TouchID.swift
//  CanvasView
//
//  Created by Eisuke Kusachi on 2026/03/31.
//

import UIKit

struct TouchID: Hashable {
    private let id: ObjectIdentifier

    init(_ touch: UITouch) {
        self.id = ObjectIdentifier(touch)
    }
}
