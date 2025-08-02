//
//  SliderStyle.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/01/02.
//

import SwiftUI

protocol SliderStyleProtocol {
    var height: CGFloat { get }

    var track: AnyView { get }
    var trackThickness: CGFloat { get }
    var trackBorderColor: Color { get }
    var trackBorderWidth: CGFloat { get }
    var trackCornerRadius: CGFloat { get }

    var trackLeft: AnyView { get }
    var trackLeftColor: Color? { get }

    var trackRight: AnyView { get }
    var trackRightColor: Color? { get }

    var thumb: AnyView { get }
    var thumbThickness: CGFloat { get }
    var thumbColor: Color { get }
    var thumbCornerRadius: CGFloat { get }
    var thumbBorderColor: Color { get }
    var thumbBorderWidth: CGFloat { get }
    var thumbShadowColor: Color { get }
    var thumbShadowRadius: CGFloat { get }
    var thumbShadowX: CGFloat { get }
    var thumbShadowY: CGFloat { get }
}

struct DefaultSliderStyle: SliderStyleProtocol {
    var height: CGFloat

    var track: AnyView
    var trackThickness: CGFloat
    var trackBorderColor: Color
    var trackBorderWidth: CGFloat
    var trackCornerRadius: CGFloat

    var trackLeft: AnyView
    var trackLeftColor: Color? = .clear

    var trackRight: AnyView
    var trackRightColor: Color? = .clear

    var thumb: AnyView
    var thumbColor: Color
    var thumbThickness: CGFloat
    var thumbCornerRadius: CGFloat
    var thumbBorderColor: Color
    var thumbBorderWidth: CGFloat
    var thumbShadowColor: Color
    var thumbShadowRadius: CGFloat
    var thumbShadowX: CGFloat
    var thumbShadowY: CGFloat

    init(height: CGFloat? = nil,

         track: AnyView = AnyView(Rectangle().foregroundColor(.clear)),
         trackThickness: CGFloat = 8,
         trackBorderColor: UIColor = UIColor.gray.withAlphaComponent(0.5),
         trackBorderWidth: CGFloat = 1,
         trackCornerRadius: CGFloat? = nil,

         trackLeft: AnyView = AnyView(Rectangle()),
         trackLeftColor: UIColor? = .clear,

         trackRight: AnyView = AnyView(Rectangle()),
         trackRightColor: UIColor? = .clear,

         thumb: AnyView = AnyView(Rectangle()),
         thumbThickness: CGFloat = 16,
         thumbColor: UIColor = .white,
         thumbCornerRadius: CGFloat? = nil,
         thumbBorderColor: UIColor = .lightGray.withAlphaComponent(0.5),
         thumbBorderWidth: CGFloat = 1.0,

         thumbShadowColor: UIColor = UIColor.black.withAlphaComponent(0.25),
         thumbShadowRadius: CGFloat = 2,
         thumbShadowX: CGFloat = 1,
         thumbShadowY: CGFloat = 1
    ) {
        self.height = height ?? thumbThickness

        self.track = track
        self.trackThickness = trackThickness
        self.trackBorderColor = Color(uiColor: trackBorderColor)
        self.trackBorderWidth = trackBorderWidth
        self.trackCornerRadius = trackCornerRadius ?? trackThickness * 0.5

        self.trackLeft = trackLeft
        self.trackLeftColor = Color(uiColor: trackLeftColor ?? .clear)

        self.trackRight = trackRight
        self.trackRightColor = Color(uiColor: trackRightColor ?? .clear)

        self.thumb = thumb
        self.thumbThickness = thumbThickness
        self.thumbColor = Color(uiColor: thumbColor)
        self.thumbCornerRadius = thumbCornerRadius ?? thumbThickness * 0.5
        self.thumbBorderWidth = thumbBorderWidth
        self.thumbBorderColor = Color(uiColor: thumbBorderColor)
        self.thumbShadowColor = Color(uiColor: thumbShadowColor)
        self.thumbShadowRadius = thumbShadowRadius
        self.thumbShadowX = thumbShadowX
        self.thumbShadowY = thumbShadowY
    }
}
