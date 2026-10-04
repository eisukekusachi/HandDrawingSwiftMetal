//
//  Created by Eisuke Kusachi
//

import Testing

@testable import TextureLayerView

@MainActor
struct TextureLayerViewModelTests {

    private typealias Subject = TextureLayerViewModel

    @Test
    func `setCurrentAlpha clamps values below 0`() {
        let subject = makeSubject()

        subject.setCurrentAlpha(-1)

        #expect(subject.currentAlpha == 0)
    }

    @Test
    func `setCurrentAlpha clamps values above 255`() {
        let subject = makeSubject()

        subject.setCurrentAlpha(256)

        #expect(subject.currentAlpha == 255)
    }

    @Test
    func `onChangeCurrentAlpha clamps the selected layer alpha`() {
        let layer = TextureLayerItem(id: LayerId(), title: "layer", alpha: 128, isVisible: true)
        let textureLayers = PreviewTextureLayers(layers: [layer], selectedLayerId: layer.id)
        let subject = Subject(textureLayers: textureLayers)

        subject.onChangeCurrentAlpha(-1)

        #expect(subject.currentAlpha == 0)
        #expect(subject.selectedLayer?.alpha == 0)

        subject.onChangeCurrentAlpha(300)

        #expect(subject.currentAlpha == 255)
        #expect(subject.selectedLayer?.alpha == 255)
    }

    private func makeSubject() -> Subject {
        let layer = TextureLayerItem(id: LayerId(), title: "layer", alpha: 255, isVisible: true)
        return Subject(
            textureLayers: PreviewTextureLayers(
                layers: [layer],
                selectedLayerId: layer.id
            )
        )
    }
}
