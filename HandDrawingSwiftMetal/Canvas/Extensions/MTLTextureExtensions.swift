//
//  MTLTextureExtensions.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/10/14.
//

import MetalKit
import Accelerate

extension MTLTexture {
    var size: CGSize {
        return CGSize(width: self.width, height: self.height)
    }
    
    var bytes: [UInt8] {
        let bytesPerPixel = 4

        let imageByteCount = self.width * self.height * bytesPerPixel
        let bytesPerRow = self.width * bytesPerPixel

        var result = [UInt8](repeating: 0, count: Int(imageByteCount))
        let region = MTLRegionMake2D(0, 0, self.width, self.height)

        self.getBytes(&result, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)

        return result
    }
    var uiImage: UIImage? {
        guard let data = UIImage.makeCFData(self, flipY: true),
              let image = UIImage.makeImage(cfData: data,
                                            width: self.width,
                                            height: self.height) else { return nil }
        return image
    }
}