//
//  BoundingBoxView.swift
//  FYP
//
//  Created by Shuichi Tsutsumi on 2020/03/22.
//  Modified by wireMuffin on 20/4/2020.
//  Original Work Copyright © 2018 Shuichi Tsutsumi. All rights reserved.
//  Modified Work Copyright © 2020 wireMuffin. All rights reserved.
//

import UIKit
import Vision
import AVFoundation.AVUtilities

class BoundingBoxView: UIView {
    private let strokeWidth: CGFloat = 2
    
    private var imageRect: CGRect = CGRect.zero
    var observations: [VNDetectedObjectObservation]!
    
    var lastSpeakingTime = Date() //for speaking the result
    
    func updateSize(for imageSize: CGSize) {
        imageRect = AVMakeRect(aspectRatio: imageSize, insideRect: self.bounds)
    }
    
    override func draw(_ rect: CGRect) {
        guard observations != nil && observations.count > 0 else {
//            NotificationCenter.default.post(name: Notification.Name("showAlert"), object: nil)
            return
        }
        subviews.forEach({ $0.removeFromSuperview() })

        let context = UIGraphicsGetCurrentContext()!
        
        var maxHumanArea : CGFloat = 0.0;
        var rectArr : [CGFloat] = []
        
        for i in 0..<observations.count {
            let observation = observations[i]
            let color = UIColor(hue: CGFloat(i) / CGFloat(observations.count), saturation: 1, brightness: 1, alpha: 1)
            let rect = drawBoundingBox(context: context, observation: observation, color: color)
            
            if #available(iOS 12.0, *), let recognizedObjectObservation = observation as? VNRecognizedObjectObservation {
                addLabel(on: rect, observation: recognizedObjectObservation, color: color)
                if let detectedClass = recognizedObjectObservation.labels.first?.identifier{
                    print(Date().timeIntervalSince(lastSpeakingTime))
                    if Date().timeIntervalSince(lastSpeakingTime) >= 5{
                        lastSpeakingTime = Date()
                        let speechSynthesizer = AVSpeechSynthesizer()
                        let message = "\(detectedClass) detected"
                        speechSynthesizer.speak(AVSpeechUtterance(string: message))
                        NotificationCenter.default.post(name: Notification.Name("dismissViewWithoutTracking"), object: nil)
                    }
                    
                    if (detectedClass == "person" && UserDefaults.standard.object(forKey: "posRectArr") == nil){
                        if (rect.size.width * rect.size.height) > maxHumanArea{
                            maxHumanArea = (rect.size.width * rect.size.height)
                            rectArr = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
                        }
                    }
                }
            }
        }
        if (UserDefaults.standard.object(forKey: "posRectArr") == nil && maxHumanArea > 0){
            UserDefaults.standard.set(rectArr, forKey: "posRectArr")
            NotificationCenter.default.post(name: Notification.Name("dismissView"), object: nil)
        }
    }
    
    private func drawBoundingBox(context: CGContext, observation: VNDetectedObjectObservation, color: UIColor) -> CGRect {
        let convertedRect = VNImageRectForNormalizedRect(observation.boundingBox, Int(imageRect.width), Int(imageRect.height))
        let x = convertedRect.minX + imageRect.minX
        let y = (imageRect.height - convertedRect.maxY) + imageRect.minY
        let rect = CGRect(origin: CGPoint(x: x, y: y), size: convertedRect.size)
        
//        print("the detect rect is at: \(rect)")
        
//        if (UserDefaults.standard.object(forKey: "posRectArr") == nil){
//            let rectArr = [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
//            UserDefaults.standard.set(rectArr, forKey: "posRectArr")
//            NotificationCenter.default.post(name: Notification.Name("dismissView"), object: nil)
//            //break this section
//        }
        
        context.setStrokeColor(color.cgColor)
        
        context.setLineWidth(strokeWidth)
//        context.stroke(CGRect(x: 0, y: 0, width: 100, height: 100))
        context.stroke(rect)
        
//        return CGRect(x: 0, y: 0, width: 100, height: 100)
        return rect
    }

    @available(iOS 12.0, *)
    private func addLabel(on rect: CGRect, observation: VNRecognizedObjectObservation, color: UIColor) {
        guard let firstLabel = observation.labels.first?.identifier else { return }
                
        let label = UILabel(frame: .zero)
        label.text = firstLabel
        label.font = UIFont.boldSystemFont(ofSize: 13)
        label.textColor = UIColor.black
        label.backgroundColor = color
        label.sizeToFit()
        label.frame = CGRect(x: rect.origin.x-strokeWidth/2,
                             y: rect.origin.y - label.frame.height,
                             width: label.frame.width,
                             height: label.frame.height)
        addSubview(label)
    }
}
