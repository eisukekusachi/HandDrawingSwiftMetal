//
//  Aspect.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2023/03/26.
//

import Foundation

enum Aspect {
    
    static func getScaleToFill(_ src: CGSize, to dst: CGSize) -> CGFloat {
        
        let ratioWidth = dst.width / src.width
        let ratioHeight = dst.height / src.height
        
        return ratioWidth > ratioHeight ? ratioWidth : ratioHeight
    }
    static func getScaleToFit(_ src: CGSize, to dst: CGSize) -> CGFloat {
        
        let ratioWidth = dst.width / src.width
        let ratioHeight = dst.height / src.height
            
        return ratioWidth < ratioHeight ? ratioWidth : ratioHeight
    }
    
    static func getSizeToFit(aspectRatio: CGSize, boundingSize: CGSize) -> CGSize {
        var boundingSize = boundingSize
        
        let mW = boundingSize.width / aspectRatio.width
        let mH = boundingSize.height / aspectRatio.height

        if mH < mW {
            boundingSize.width = boundingSize.height / aspectRatio.height * aspectRatio.width
            
        } else if mW < mH {
            boundingSize.height = boundingSize.width / aspectRatio.width * aspectRatio.height
        }
        
        return boundingSize
    }
    static func getSizeToFill(aspectRatio: CGSize, minimumSize: CGSize) -> CGSize {
        var minimumSize = minimumSize
        
        let mW = minimumSize.width / aspectRatio.width
        let mH = minimumSize.height / aspectRatio.height

        if mH > mW {
            minimumSize.width = minimumSize.height / aspectRatio.height * aspectRatio.width
            
        } else if mW > mH {
            minimumSize.height = minimumSize.width / aspectRatio.width * aspectRatio.height
        }
        
        return minimumSize
    }
}
