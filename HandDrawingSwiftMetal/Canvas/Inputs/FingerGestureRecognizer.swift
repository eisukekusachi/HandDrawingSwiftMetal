//
//  FingerGestureRecognizer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/28.
//

import UIKit

protocol FingerGestureRecognizerSender {
    
    func sendLocations(_ input: FingerGestureRecognizer?, touchLocations: [Int: Point], touchState: TouchState)
    func cancel(_ input: FingerGestureRecognizer?)
}

class FingerGestureRecognizer: UIGestureRecognizer {
    
    var output: FingerGestureRecognizerSender?
    
    private var is3DTouchAvailable: Bool = false
    
    init(output: FingerGestureRecognizerSender? = nil, is3DTouchAvailable: Bool = false) {
        super.init(target: nil, action: nil)
        
        self.output = output
        self.is3DTouchAvailable = is3DTouchAvailable
        
        allowedTouchTypes = [UITouch.TouchType.direct.rawValue as NSNumber]
    }
}

extension FingerGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var locations: [Int: Point] = [:]
        
        event?.allTouches?.forEach { touch in
            if touch.type == .direct, let view = view {
                let key = ObjectIdentifier(touch).hashValue
                
                locations[key] = PointImpl(touch: touch, view: view, alpha: !is3DTouchAvailable ? 1.0 : nil)
            }
        }
        output?.sendLocations(self, touchLocations: locations, touchState: .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var locations: [Int: Point] = [:]
        
        event?.allTouches?.forEach { touch in
            if touch.type == .direct, let view = view {
                let key = ObjectIdentifier(touch).hashValue
                
                locations[key] = PointImpl(touch: touch, view: view, alpha: !is3DTouchAvailable ? 1.0 : nil)
            }
        }
        output?.sendLocations(self, touchLocations: locations, touchState: .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        var locations: [Int: Point] = [:]
        
        event?.allTouches?.forEach { touch in
            if touch.type == .direct, let view = view {
                let key = ObjectIdentifier(touch).hashValue
                
                locations[key] = PointImpl(touch: touch, view: view, alpha: !is3DTouchAvailable ? 1.0 : nil)
            }
        }
        output?.sendLocations(self, touchLocations: locations, touchState: .ended)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        output?.cancel(self)
    }
}
