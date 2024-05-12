//
//  LayerViewPresentation.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/26.
//

import SwiftUI

class LayerViewPresentation: ObservableObject {

    let arrowSize: CGSize = .init(width: 18, height: 14)
    let roundedCorner: CGFloat = 12

    var arrowPointX: CGFloat = 0.0

    var edgeInsets: EdgeInsets {
        .init(
            top: roundedCorner + arrowSize.height,
            leading: roundedCorner,
            bottom: roundedCorner,
            trailing: roundedCorner
        )
    }

    func viewWithTopArrow(
        arrowSize: CGSize,
        roundedCorner: CGFloat
    ) -> some View {
        GeometryReader { geometry in
            let minX0 = 0.0
            let minX1 = roundedCorner
            let maxX1 = geometry.size.width - roundedCorner
            let maxX0 = geometry.size.width

            let minY0 = arrowSize.height
            let minY1 = arrowSize.height + roundedCorner
            let maxY1 = geometry.size.height - roundedCorner
            let maxY0 = geometry.size.height

            let pointMinX = minX1 + arrowSize.width * 0.5
            let pointMaxX = maxX1 - arrowSize.width * 0.5
            let pointX = min(max(pointMinX, self.arrowPointX), pointMaxX)

            let arrowStartX = pointX - arrowSize.width * 0.5
            let arrowEndX = pointX + arrowSize.width * 0.5

            let minX0minY1: CGPoint = .init(x: minX0, y: minY1)
            let minX1minY0: CGPoint = .init(x: minX1, y: minY0)
            let maxX1minY0: CGPoint = .init(x: maxX1, y: minY0)
            let maxX0minY1: CGPoint = .init(x: maxX0, y: minY1)

            let maxX0maxY1: CGPoint = .init(x: maxX0, y: maxY1)
            let maxX1maxY0: CGPoint = .init(x: maxX1, y: maxY0)
            let minX1maxY0: CGPoint = .init(x: minX1, y: maxY0)
            let minX0maxY1: CGPoint = .init(x: minX0, y: maxY1)

            Path { path in
                path.move(to: minX0minY1)
                path.addQuadCurve(to: minX1minY0,
                                  control: .init(x: minX0, y: minY0))

                path.addLine(to: .init(x: arrowStartX, y: minY0))
                path.addLine(to: .init(x: pointX, y: 0.0))
                path.addLine(to: .init(x: arrowEndX, y: minY0))

                path.addLine(to: maxX1minY0)
                path.addQuadCurve(to: maxX0minY1,
                                  control: .init(x: maxX0, y: minY0))
                path.addLine(to: maxX0maxY1)
                path.addQuadCurve(to: maxX1maxY0,
                                  control: .init(x: maxX0, y: maxY0))
                path.addLine(to: minX1maxY0)
                path.addQuadCurve(to: minX0maxY1,
                                  control: .init(x: minX0, y: maxY0))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.9))

            // For iOS 15 compatibility
            Path { path in
                path.move(to: minX0minY1)
                path.addQuadCurve(to: minX1minY0,
                                  control: .init(x: minX0, y: minY0))

                path.addLine(to: .init(x: arrowStartX, y: minY0))
                path.addLine(to: .init(x: pointX, y: 0.0))
                path.addLine(to: .init(x: arrowEndX, y: minY0))

                path.addLine(to: maxX1minY0)
                path.addQuadCurve(to: maxX0minY1,
                                  control: .init(x: maxX0, y: minY0))
                path.addLine(to: maxX0maxY1)
                path.addQuadCurve(to: maxX1maxY0,
                                  control: .init(x: maxX0, y: maxY0))
                path.addLine(to: minX1maxY0)
                path.addQuadCurve(to: minX0maxY1,
                                  control: .init(x: minX0, y: maxY0))
                path.closeSubpath()
            }
            .stroke(lineWidth: 0.5)
            .fill(Color.black)
        }
    }

}
