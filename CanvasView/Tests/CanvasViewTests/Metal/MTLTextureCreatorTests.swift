//
//  Created by Eisuke Kusachi
//

import Metal
import Testing
@testable import CanvasView

struct MTLTextureCreatorTests {

    @Test
    func `When width or height is below the minimum, makeTexture returns nil`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())

        #expect(
            MTLTextureCreator.makeTexture(
                width: 15,
                height: 16,
                with: device
            ) == nil
        )
        #expect(
            MTLTextureCreator.makeTexture(
                width: 16,
                height: 15,
                with: device
            ) == nil
        )
    }

    @Test
    func `When width and height meet the minimum, makeTexture returns a texture`() throws {
        let device = try #require(MTLCreateSystemDefaultDevice())

        let texture = MTLTextureCreator.makeTexture(
            width: 16,
            height: 16,
            with: device
        )

        #expect(texture != nil)
        #expect(texture?.width == 16)
        #expect(texture?.height == 16)
    }
}
