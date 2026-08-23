//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/02.
//

import SwiftUI
import UIKit

private struct GradientSliderMetrics: Equatable {
    var controlHeight: CGFloat = 31
    var trackHeight: CGFloat = 4
    var horizontalInset: CGFloat = 14
    var trackVerticalOffset: CGFloat = 13.5

    static let `default` = GradientSliderMetrics()
}

struct GradientSlider: View {
    @Binding var value: Int

    @State private var metrics = GradientSliderMetrics.default

    private let gradientColors: [UIColor]

    init(
        value: Binding<Int>,
        gradientColors: [UIColor]
    ) {
        self._value = value
        self.gradientColors = gradientColors
    }

    var body: some View {
        ZStack(alignment: .top) {
            trackBackground
                .frame(maxWidth: .infinity)
                .frame(height: metrics.trackHeight)
                .padding(.top, metrics.trackVerticalOffset)
                .padding(.horizontal, metrics.horizontalInset)

            GradientSliderControl(value: $value, metrics: $metrics)
                .frame(height: metrics.controlHeight)
        }
        .frame(height: metrics.controlHeight)
    }
}

private extension GradientSlider {
    var trackBackground: some View {
        ZStack {
            CheckerboardBackground()
            LinearGradient(
                colors: gradientColors.map { Color(uiColor: $0) },
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .clipShape(Capsule())
    }
}

/// Uses `UISlider` so the system track stays hidden while keeping the native handle.
private struct GradientSliderControl: UIViewRepresentable {
    @Binding var value: Int
    @Binding var metrics: GradientSliderMetrics

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, metrics: $metrics)
    }

    func makeUIView(context: Context) -> MetricsReportingSlider {
        let slider = MetricsReportingSlider()
        slider.minimumValue = 0
        slider.maximumValue = 255
        slider.minimumTrackTintColor = .clear
        slider.maximumTrackTintColor = .clear
        let coordinator = context.coordinator
        slider.onMetricsChange = { newMetrics in
            Task { @MainActor in
                coordinator.updateMetrics(newMetrics)
            }
        }
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return slider
    }

    func updateUIView(_ slider: MetricsReportingSlider, context: Context) {
        let targetValue = Float(value)
        let boundsChanged = context.coordinator.lastBounds != slider.bounds
        context.coordinator.lastBounds = slider.bounds

        guard !slider.isTracking else { return }

        if slider.value != targetValue || boundsChanged {
            slider.setValue(targetValue, animated: false)
        }

        slider.reportMetricsIfNeeded()
    }

    final class Coordinator: NSObject {
        private var value: Binding<Int>
        private var metrics: Binding<GradientSliderMetrics>
        var lastBounds: CGRect = .zero

        init(value: Binding<Int>, metrics: Binding<GradientSliderMetrics>) {
            self.value = value
            self.metrics = metrics
        }

        @MainActor
        func updateMetrics(_ newMetrics: GradientSliderMetrics) {
            guard metrics.wrappedValue != newMetrics else { return }
            metrics.wrappedValue = newMetrics
        }

        @MainActor
        @objc func valueChanged(_ sender: UISlider) {
            value.wrappedValue = Int(sender.value.rounded())
        }
    }
}

private final class MetricsReportingSlider: UISlider {
    var onMetricsChange: ((GradientSliderMetrics) -> Void)?
    private var lastReportedMetrics: GradientSliderMetrics?

    override func layoutSubviews() {
        super.layoutSubviews()
        reportMetricsIfNeeded()
    }

    func reportMetricsIfNeeded() {
        let metrics = makeGradientSliderMetrics()
        guard metrics != lastReportedMetrics else { return }
        lastReportedMetrics = metrics
        onMetricsChange?(metrics)
    }
}

private extension UISlider {
    func makeGradientSliderMetrics() -> GradientSliderMetrics {
        layoutIfNeeded()

        let bounds = bounds
        guard bounds.width > 0 else { return .default }

        let trackRect = trackRect(forBounds: bounds)
        let thumbRect = thumbRect(
            forBounds: bounds,
            trackRect: trackRect,
            value: minimumValue
        )

        let controlHeight: CGFloat = {
            let intrinsicHeight = intrinsicContentSize.height
            if intrinsicHeight > 0 { return intrinsicHeight }
            return max(thumbRect.height, bounds.height)
        }()

        return GradientSliderMetrics(
            controlHeight: controlHeight,
            trackHeight: trackRect.height,
            horizontalInset: thumbRect.width / 2,
            trackVerticalOffset: trackRect.minY
        )
    }
}

private struct CheckerboardBackground: View {
    private let patternSize: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let light = Color.white
            let dark = Color(white: 0.92)

            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = 0
                while x < size.width {
                    let isLight = (Int(x / patternSize) + Int(y / patternSize)).isMultiple(of: 2)
                    let rect = CGRect(x: x, y: y, width: patternSize, height: patternSize)
                    context.fill(Path(rect), with: .color(isLight ? light : dark))
                    x += patternSize
                }
                y += patternSize
            }
        }
    }
}

#if DEBUG
private struct GradientSliderPreview: View {
    @State private var value = 255

    var body: some View {
        GradientSlider(
            value: $value,
            gradientColors: [
                UIColor(intRed: 0, green: 0, blue: 0, alpha: 255),
                UIColor(intRed: 255, green: 0, blue: 0, alpha: 255)
            ]
        )
        .padding()
    }
}

#Preview {
    GradientSliderPreview()
}
#endif
