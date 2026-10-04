//
//  Created by Eisuke Kusachi
//

import MetalKit

struct TextureLayer {
    let isVisible: Bool
    let alpha: Int
    let texture: MTLTexture?

    init(
        isVisible: Bool,
        alpha: Int,
        texture: MTLTexture?
    ) {
        self.isVisible = isVisible
        self.alpha = alpha
        self.texture = texture
    }
}
