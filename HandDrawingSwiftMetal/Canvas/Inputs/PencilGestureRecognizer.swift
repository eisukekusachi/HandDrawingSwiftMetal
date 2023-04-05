//
//  PencilGestureRecognizer.swift
//  HandDrawingSwiftMetal
//
//  Created by Eisuke Kusachi on 2022/11/28.
//

import UIKit

protocol PencilGestureRecognizerSender {
    
    func sendLocations(_ gesture: PencilGestureRecognizer?, touchLocations: [Point], touchState: TouchState)
    func cancel(_ gesture: PencilGestureRecognizer?)
}

class PencilGestureRecognizer: UIGestureRecognizer {
    
    var output: PencilGestureRecognizerSender?
    
    private var latestForceValue: CGFloat?
    private var isGestureActive: Bool = false
    
    init(output: PencilGestureRecognizerSender? = nil) {
        super.init(target: nil, action: nil)
        
        self.output = output
        
        allowedTouchTypes = [UITouch.TouchType.pencil.rawValue as NSNumber]
    }
}

extension PencilGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        latestForceValue = nil
        isGestureActive = false
        
        if let touch = event?.allTouches?.first,
           let coalescedTouches = event?.coalescedTouches(for: touch) {
      
            for index in 0 ..< coalescedTouches.count {
                let touch = coalescedTouches[index]
                latestForceValue = touch.force
            }
        }
        
        output?.sendLocations(self, touchLocations: [], touchState: .began)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        var locations: [Point] = []
        
        var isActiveFlag: Bool = false
        
        if let view = view,
           let touch = event?.allTouches?.first,
           let coalescedTouches = event?.coalescedTouches(for: touch) {
      
            for index in 0 ..< coalescedTouches.count {
                let touch = coalescedTouches[index]
                if touch.type == .pencil {
                    
                    if isGestureActive {
                        locations.append(PointImpl(touch: touch, view: view))
                    }
                    
                    if isActiveFlag == false, isGestureActive == false, let force = latestForceValue, force != touch.force {
                        isActiveFlag = true
                    }
                    
                    latestForceValue = touch.force
                }
            }
        }
        
        if isActiveFlag == true, isGestureActive == false {
            isGestureActive = true
        }
        
        output?.sendLocations(self, touchLocations: locations, touchState: .moved)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        var locations: [Point] = []
        
        if let view = view,
           let touch = event?.allTouches?.first,
           let coalescedTouches = event?.coalescedTouches(for: touch) {
            
            for index in 0 ..< coalescedTouches.count {
                let touch = coalescedTouches[index]
                if touch.type == .pencil {
                    
                    locations.append(PointImpl(touch: touch, view: view))
                }
            }
        }
        output?.sendLocations(self, touchLocations: locations, touchState: .ended)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        output?.cancel(self)
    }
    
    /*
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        
        var higherPrecisionPencilPoints: [PencilPoint] = []
        
        for touch in touches.enumerated() {
            if touch.element.type == .pencil,
               let updateIndex = touch.element.estimationUpdateIndex {
                
                let location = touch.element.preciseLocation(in: view)
                let pencilPoint = PencilPoint.init(estimationUpdateIndex: Int(truncating: updateIndex),
                                                   location: location,
                                                   force: touch.element.force)
                higherPrecisionPencilPoints.append(pencilPoint)
            }
        }
        
        output?.sendHigherPrecisionPencilPoints(higherPrecisionPencilPoints)
    }
    */
}
