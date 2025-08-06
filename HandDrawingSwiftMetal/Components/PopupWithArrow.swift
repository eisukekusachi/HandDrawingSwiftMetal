//
//  PopupWithArrow.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2024/04/26.
//

import SwiftUI

struct PopupWithArrowView<Content: View>: View {

    @Binding var arrowPointX: CGFloat

    let arrowSize: CGSize
    let roundedCorner: CGFloat
    let lineWidth: CGFloat
    let backgroundColor: UIColor
    let content: () -> Content

    init(
        arrowPointX: Binding<CGFloat>,
        arrowSize: CGSize = CGSize(width: 20, height: 10),
        roundedCorner: CGFloat = 8,
        lineWidth: CGFloat = 0.5,
        backgroundColor: UIColor = UIColor.white.withAlphaComponent(0.95),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._arrowPointX = arrowPointX
        self.arrowSize = arrowSize
        self.roundedCorner = roundedCorner
        self.lineWidth = lineWidth
        self.backgroundColor = backgroundColor
        self.content = content
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                popupShape(in: geometry.size)
                    .fill(Color(backgroundColor))
                    .overlay(
                        popupShape(in: geometry.size)
                            .stroke(Color.black, lineWidth: lineWidth)
                    )
            }
            .id(arrowPointX)

            VStack {
                content()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(edgeInsets)
            }
        }
    }

    private func popupShape(in size: CGSize) -> Path {
        let minX0 = 0.0
        let minX1 = roundedCorner
        let maxX1 = size.width - roundedCorner
        let maxX0 = size.width

        let minY0 = arrowSize.height
        let minY1 = arrowSize.height + roundedCorner
        let maxY1 = size.height - roundedCorner
        let maxY0 = size.height

        let pointMinX = minX1 + arrowSize.width * 0.5
        let pointMaxX = maxX1 - arrowSize.width * 0.5
        let pointX = min(max(pointMinX, arrowPointX), pointMaxX)

        let arrowStartX = pointX - arrowSize.width * 0.5
        let arrowEndX = pointX + arrowSize.width * 0.5

        let minX0minY1 = CGPoint(x: minX0, y: minY1)
        let minX1minY0 = CGPoint(x: minX1, y: minY0)
        let maxX1minY0 = CGPoint(x: maxX1, y: minY0)
        let maxX0minY1 = CGPoint(x: maxX0, y: minY1)

        let maxX0maxY1 = CGPoint(x: maxX0, y: maxY1)
        let maxX1maxY0 = CGPoint(x: maxX1, y: maxY0)
        let minX1maxY0 = CGPoint(x: minX1, y: maxY0)
        let minX0maxY1 = CGPoint(x: minX0, y: maxY0)

        var path = Path()
        path.move(to: minX0minY1)
        path.addQuadCurve(to: minX1minY0, control: CGPoint(x: minX0, y: minY0))
        path.addLine(to: CGPoint(x: arrowStartX, y: minY0))
        path.addLine(to: CGPoint(x: pointX, y: 0.0))
        path.addLine(to: CGPoint(x: arrowEndX, y: minY0))
        path.addLine(to: maxX1minY0)
        path.addQuadCurve(to: maxX0minY1, control: CGPoint(x: maxX0, y: minY0))
        path.addLine(to: maxX0maxY1)
        path.addQuadCurve(to: maxX1maxY0, control: CGPoint(x: maxX0, y: maxY0))
        path.addLine(to: minX1maxY0)
        path.addQuadCurve(to: minX0maxY1, control: CGPoint(x: minX0, y: maxY0))
        path.closeSubpath()
        return path
    }

    private var edgeInsets: EdgeInsets {
        .init(
            top: roundedCorner + arrowSize.height,
            leading: roundedCorner,
            bottom: roundedCorner,
            trailing: roundedCorner
        )
    }
}

private struct PreviewView: View {
    @State var arrowX: CGFloat = 100

    var body: some View {
        PopupWithArrowView(
            arrowPointX: $arrowX
        ) {
            VStack(spacing: 8) {
                Text("Popup View")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.gray)
        }
        .frame(width: 200, height: 150)
    }
}
#Preview {
    PreviewView()
}
