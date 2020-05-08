//
//  ViewController.swift
//  ObjectTracker
//
//  Created by Jeffrey Bergier on 6/8/17.
//  Edited by wireMuffin on 1/9/19.
//  Original Work Copyright © 2017 Saturday Apps. All rights reserved.
//  Modified Work Copyright © 2020 wireMuffin. All rights reserved.
//

import AVFoundation
import Vision
import UIKit

class TrackingViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var lostStartTime = Date()
    var isLost = false
    var isError = false
    
    let speechSynthesizer = AVSpeechSynthesizer()
    
    @IBOutlet private weak var cameraView: UIView!
    @IBOutlet private weak var highlightView: UIView? {
        didSet {
            self.highlightView?.layer.borderColor = UIColor.green.cgColor
            self.highlightView?.layer.borderWidth = 4
            self.highlightView?.backgroundColor = .clear
        }
    }
    
    private let visionSequenceHandler = VNSequenceRequestHandler()
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard
            let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: backCamera)
        else { return session }
        session.addInput(input)
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var timer = Timer()
        timer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.askToReselect), userInfo: nil, repeats: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(startNewTrackSection), name: NSNotification.Name("dismissView"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(selectFirstTime), name: NSNotification.Name("selectFirstTime"), object: nil)
        
        // hide the red focus area on load
        self.highlightView?.frame = .zero
        
        // make the camera appear on the screen
        self.cameraView?.layer.addSublayer(self.cameraLayer)
        
        // register to receive buffers from the camera
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        self.captureSession.addOutput(videoOutput)
        
        // begin the session
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // make sure the layer is the correct size
        self.cameraLayer.frame = self.cameraView?.bounds ?? .zero
    }
    
    private var lastObservation: VNDetectedObjectObservation?
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            // make sure the pixel buffer can be converted
            let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            // make sure that there is a previous observation we can feed into the request
            let lastObservation = self.lastObservation
        else { return }
        
        // create the request
        let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: self.handleVisionRequestUpdate)
        // set the accuracy to high
        // this is slower, but it works a lot better
        request.trackingLevel = .accurate
        
        // perform the request
        do {
            try self.visionSequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Throws: \(error)")
            self.isError = true
        }
    }
    
    @objc func askToReselect(){
        if (!isError) {return}
        
        self.isError = false
        self.isLost = false
        self.lostStartTime = Date()
        let alert = UIAlertController(title:"Object lost" , message: "Do you want to track the pedestrian again?", preferredStyle: UIAlertController.Style.alert)
        let cancelAction = UIAlertAction(title: "No", style: UIAlertAction.Style.default, handler: nil)
        let disableAction = UIAlertAction(title: "Yes", style: UIAlertAction.Style.default, handler: {
            action in
            UserDefaults.standard.set(nil, forKey: "posRectArr")
            let stb = UIStoryboard(name: "Main", bundle: nil)
            let detectViewController = stb.instantiateViewController(withIdentifier: "detectView") as! DetectionViewController
            self.present(detectViewController, animated: true, completion: nil)
        })
        alert.addAction(cancelAction)
        alert.addAction(disableAction)
        self.present(alert, animated: true){
            () -> Void in
        }
    }
    
    @objc func selectFirstTime(){
        self.isError = false
        self.isLost = false
        self.lostStartTime = Date()
        UserDefaults.standard.set(nil, forKey: "posRectArr")
        let stb = UIStoryboard(name: "Main", bundle: nil)
        let detectViewController = stb.instantiateViewController(withIdentifier: "detectView") as! DetectionViewController
        self.present(detectViewController, animated: true, completion: nil)
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?) {
        // Dispatch to the main queue because we are touching non-atomic, non-thread safe properties of the view controller
        DispatchQueue.main.async {
            // make sure we have an actual result
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else { return }
            
            // prepare for next loop
            self.lastObservation = newObservation
            
            // check the confidence level before updating the UI
//            guard newObservation.confidence >= 0.5 else {
//                // hide the rectangle when we lose accuracy so the user knows something is wrong
//                self.highlightView?.frame = .zero
//                return
//            }
            
            if newObservation.confidence <= 0.6 {
                self.highlightView?.layer.borderColor = UIColor.yellow.cgColor
                if newObservation.confidence <= 0.3{
                    self.highlightView?.layer.borderColor = UIColor.red.cgColor
                    if (!self.isLost) {
                        self.lostStartTime = Date()
                        self.isLost = true
                    }
                    print("losting time: \(Date().timeIntervalSince(self.lostStartTime))")
                    if (Date().timeIntervalSince(self.lostStartTime) >= 5){
                        self.isLost = false
                        self.lostStartTime = Date()
                        let alert = UIAlertController(title:"Object lost" , message: "Do you want to track the pedestrian again?", preferredStyle: UIAlertController.Style.alert)
                        let cancelAction = UIAlertAction(title: "No", style: UIAlertAction.Style.default, handler: nil)
                        let disableAction = UIAlertAction(title: "Yes", style: UIAlertAction.Style.default, handler: {
                            action in
                            UserDefaults.standard.set(nil, forKey: "posRectArr")
                            let stb = UIStoryboard(name: "Main", bundle: nil)
                            let detectViewController = stb.instantiateViewController(withIdentifier: "detectView") as! DetectionViewController
                            self.present(detectViewController, animated: true, completion: nil)
                        })
                        alert.addAction(cancelAction)
                        alert.addAction(disableAction)
                        self.present(alert, animated: true){
                            () -> Void in
                        }
                    }
                }
                
            } else {
                self.lostStartTime = Date()
                self.isLost = false
                self.highlightView?.layer.borderColor = UIColor.green.cgColor
            }
            // calculate view rect
            var transformedRect = newObservation.boundingBox
            if (newObservation.boundingBox.origin.y < 0.33){
                print("left")
                for _ in 1...2{
                    if #available(iOS 13.0, *) {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } else {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            } else if (newObservation.boundingBox.origin.y > 0.66){
                for _ in 1...3{
                    if #available(iOS 13.0, *) {
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                    } else {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                }
                print("right")
            } else {
                print("straight")
            }
//            print(newObservation.boundingBox)
            transformedRect.origin.y = 1 - transformedRect.origin.y
            let convertedRect = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
            
            // move the highlight view
            self.highlightView?.frame = convertedRect
        }
    }
    
    @objc func startNewTrackSection(){
        guard let rectPosArr = UserDefaults.standard.array(forKey: "posRectArr") else { return }
//        UserDefaults.standard.set(nil, forKey: "posRectArr")
//        let rectPos = CGRect(x: rectPosArr[0] as! CGFloat + 20, y: rectPosArr[1] as! CGFloat + 20, width: rectPosArr[2] as! CGFloat - 20, height: rectPosArr[3] as! CGFloat - 20)
//        self.highlightView?.frame = rectPos
        
        self.highlightView?.frame.size = CGSize(width: 120, height: 120)
        self.highlightView?.center = CGPoint(
            x: (rectPosArr[0] as! CGFloat) + ((rectPosArr[2] as! CGFloat) / 4),
            y: (rectPosArr[1] as! CGFloat) + ((rectPosArr[3] as! CGFloat) / 4)
        )
        
        // convert the rect for the initial observation
        let originalRect = self.highlightView?.frame ?? .zero
        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        
        // set the observation
        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.lastObservation = newObservation
        
    }
    
    @IBAction private func userTapped(_ sender: UITapGestureRecognizer) {
        // get the center of the tap
        
        self.highlightView?.frame.size = CGSize(width: 120, height: 120)
        self.highlightView?.center = sender.location(in: self.view)
        
        // convert the rect for the initial observation
        let originalRect = self.highlightView?.frame ?? .zero
        var convertedRect = self.cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        
        // set the observation
        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        self.lastObservation = newObservation
        
    }
    
    @IBAction func resetTapped(_ sender: UIBarButtonItem) {
        self.lastObservation = nil
        self.highlightView?.frame = .zero
    }
}

