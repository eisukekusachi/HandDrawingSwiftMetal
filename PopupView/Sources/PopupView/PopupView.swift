//
//  PopupView
//
//  Created by Eisuke Kusachi on 2026/08/10.
//

import SwiftUI

/// Reports the measured height of the popup for positioning.
private struct PopupCardHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Placement of the popup relative to its anchor.
public enum PopupPlacement {
    /// Places the popup directly above the anchor.
    case aboveAnchor
    /// Places the popup directly below the anchor.
    case belowAnchor
}

public struct PopupView<Content: View>: View {

    @ObservedObject private var viewModel: PopupViewModel

    /// Placement of the popup relative to its anchor.
    private let placement: PopupPlacement

    /// Content provided by the caller.
    private let content: () -> Content

    /// Close action. When set, the popup shows an X button.
    private let onClose: (() -> Void)?

    private let cornerRadius: CGFloat
    private let padding: EdgeInsets
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let backgroundColor: Color

    public init(
        _ viewModel: PopupViewModel,
        placement: PopupPlacement,
        @ViewBuilder content: @escaping () -> Content,
        onClose: (() -> Void)? = nil,
        cornerRadius: CGFloat = 26,
        padding: EdgeInsets = .init(
            top: 16,
            leading: 16,
            bottom: 16,
            trailing: 16
        ),
        borderColor: Color = .primary.opacity(0.12),
        borderWidth: CGFloat = 1,
        backgroundColor: Color = Color(uiColor: .secondarySystemBackground)
    ) {
        self.viewModel = viewModel
        self.placement = placement
        self.content = content
        self.onClose = onClose
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        if !viewModel.isHidden {
            GeometryReader { proxy in
                let popupRect = viewModel.popupRect(
                    containerWidth: proxy.size.width,
                    containerHeight: proxy.size.height,
                    placement: placement
                )

                Color.clear
                    .allowsHitTesting(false)
                    .overlay(alignment: .topLeading) {
                        popupView(width: popupRect.width)
                            .offset(
                                x: popupRect.minX,
                                y: popupRect.minY
                            )
                        // Concealed for a short delay so layout can finish before the popup appears.
                            .opacity(viewModel.isConcealed ? 0 : 1)
                            .allowsHitTesting(!viewModel.isConcealed)
                    }
            }
            .zIndex(Double(viewModel.stackingOrder))
            .transaction { $0.disablesAnimations = true }
        }
    }
}

private extension PopupView {
    @ViewBuilder
    func popupView(width: CGFloat) -> some View {
        popupContent
            .padding(padding)
            .frame(width: width, alignment: .top)
            // Width is fixed, height follows the content size.
            .fixedSize(horizontal: false, vertical: true)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: PopupCardHeightKey.self,
                        value: proxy.size.height
                    )
                }
            }
            .onPreferenceChange(PopupCardHeightKey.self) { measuredHeight in
                guard measuredHeight > 0 else { return }
                viewModel.updateMeasuredHeight(measuredHeight)
            }
            .background {
                cardShape.fill(backgroundColor)
            }
            .overlay {
                cardShape.strokeBorder(
                    borderColor,
                    lineWidth: borderWidth
                )
            }
            .clipShape(cardShape)
    }

    @ViewBuilder
    var popupContent: some View {
        // Show the close button when a close action is provided.
        if let onClose {
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Color(uiColor: .systemGray))
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)

                content()
            }
        } else {
            content()
        }
    }

    var cardShape: RoundedRectangle {
        .init(
            cornerRadius: cornerRadius,
            style: .continuous
        )
    }
}

#if DEBUG

#Preview("Above anchor") {
    PopupPreview(placement: .aboveAnchor)
}

#Preview("Below anchor") {
    PopupPreview(placement: .belowAnchor)
}

private struct PreviewAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

private struct PopupPreview: View {
    let placement: PopupPlacement

    @StateObject private var viewModel = PopupViewModel(
        revealDelayNanoseconds: 0
    )

    var body: some View {
        GeometryReader { geometry in
            VStack {
                if placement == .belowAnchor {
                    anchorTarget
                        .padding(.top, 36)
                    Spacer()
                } else {
                    Spacer()
                    anchorTarget
                        .padding(.bottom, 36)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .gray))
            .overlayPreferenceValue(PreviewAnchorKey.self) { anchor in
                if let anchor {
                    // Bounds of the preview target, resolved from the anchor into this container.
                    popupOverlay(targetAnchorFrame: geometry[anchor])
                }
            }
        }
        .ignoresSafeArea()
    }

    private var anchorTarget: some View {
        Text("AnchorTarget")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 220, height: 44)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .anchorPreference(
                key: PreviewAnchorKey.self,
                value: .bounds,
                transform: { $0 }
            )
    }

    /// Preview popup, positioned from the target's anchor frame.
    @ViewBuilder
    private func popupOverlay(targetAnchorFrame: CGRect) -> some View {
        ZStack {
            PopupView(
                viewModel,
                placement: placement,
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Popup")
                            .font(.headline)
                        Text("Preview content")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                },
                onClose: {
                    viewModel.hide()
                }
            )
        }
        .onAppear {
            viewModel.setTargetFrame(targetAnchorFrame)
            viewModel.show()
        }
        .onChange(of: targetAnchorFrame) { newTargetAnchorFrame in
            viewModel.setTargetFrame(newTargetAnchorFrame)
        }
    }
}

#endif
