//
//  ImageExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/12/31.
//

import SwiftUI

extension Image {

    func buttonModifier(diameter: CGFloat, _ uiColor: UIColor = .systemBlue) -> some View {
        self
            .resizable()
            .scaledToFit()
            .frame(width: diameter, height: diameter)
            .foregroundColor(Color(uiColor: uiColor))
    }

}
