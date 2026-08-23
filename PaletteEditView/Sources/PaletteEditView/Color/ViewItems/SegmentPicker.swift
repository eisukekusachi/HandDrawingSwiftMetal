//
//  PaletteEditView
//
//  Created by Eisuke Kusachi on 2026/07/25.
//

import SwiftUI

struct SegmentPicker: View {

    @Binding private var selection: ColorPaletteSegment

    private let height: CGFloat = 32

    init(selection: Binding<ColorPaletteSegment>) {
        self._selection = selection
    }

    var body: some View {
        Picker("Segment", selection: $selection) {
            ForEach(ColorPaletteSegment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .frame(height: height)
    }
}

#if DEBUG
#Preview {
    ColorPaletteSegmentPickerPreview()
}

private struct ColorPaletteSegmentPickerPreview: View {
    @State private var selection: ColorPaletteSegment = .grid

    var body: some View {
        SegmentPicker(selection: $selection)
            .padding()
    }
}
#endif
