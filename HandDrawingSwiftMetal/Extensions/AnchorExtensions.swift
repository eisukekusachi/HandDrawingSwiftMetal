//
//  AnchorExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2026/05/30.
//

import SwiftUI

extension Anchor where Value == CGRect {
    func frame(in proxy: GeometryProxy) -> CGRect {
        proxy[self]
    }
}
