//
//  DetectionViewController.swift
//  FYP
//
//  Created by Shuichi Tsutsumi on 2018/06/20.
//  Modified by wireMuffin on 20/4/2020.
//  Original Work Copyright © 2018 Shuichi Tsutsumi. All rights reserved.
//  Modified Work Copyright © 2020 wireMuffin. All rights reserved.
//

import UIKit
import CoreML
import Vision
import AVFoundation

class DetectionViewController: UIViewController {

    private var videoCapture: VideoCapture!
    private let serialQueue = DispatchQueue(label: "com.wireMuffin.coremlplayground.serialqueue")
    
    private let videoSize = CGSize(width: 1280, height: 720)
    private let preferredFps: Int32 = 2
    
    private var modelUrls: [URL]!
    private var selectedVNModel: VNCoreMLModel?
    private var selectedModel: MLModel?
    
    ///for voice output
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var lastNotFoundTime = Date()
    

    private var cropAndScaleOption: VNImageCropAndScaleOption = .scaleFit
    
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var resultView: UIView!
    @IBOutlet private weak var resultLabel: UILabel!
    @IBOutlet private weak var othersLabel: UILabel!
    @IBOutlet private weak var bbView: BoundingBoxView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(dismissView), name: NSNotification.Name("dismissView"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismissView), name: NSNotification.Name("dismissViewWithoutTracking"), object: nil)

        let spec = VideoSpec(fps: preferredFps, size: videoSize)
        let frameInterval = 1.0 / Double(preferredFps)
        
        videoCapture = VideoCapture(cameraType: .back,
                                    preferredSpec: spec,
                                    previewContainer: previewView.layer)
        videoCapture.imageBufferHandler = {[unowned self] (imageBuffer, timestamp, outputBuffer) in
            let delay = CACurrentMediaTime() - timestamp.seconds
            if delay > frameInterval {
                return
            }

            self.serialQueue.async {
                self.runModel(imageBuffer: imageBuffer)
            }
        }
        
        let modelPaths = Bundle.main.paths(forResourcesOfType: "mlmodel", inDirectory: "models")
        
        modelUrls = []
        for modelPath in modelPaths {
            let url = URL(fileURLWithPath: modelPath)
            let compiledUrl = try! MLModel.compileModel(at: url)
            modelUrls.append(compiledUrl)
        }
        
        selectModel(url: modelUrls.last!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let videoCapture = videoCapture else {return}
        videoCapture.startCapture()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let videoCapture = videoCapture else {return}
        videoCapture.resizePreview()
        self.bbView.updateSize(for: CGSize(width: videoSize.height, height: videoSize.width))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        guard let videoCapture = videoCapture else {return}
        videoCapture.stopCapture()
        super.viewWillDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Private
    private func selectModel(url: URL) {
        selectedModel = try! MLModel(contentsOf: url)
        do {
            selectedVNModel = try VNCoreMLModel(for: selectedModel!)
        }
        catch {
            fatalError("Fatal error: \(error)")
        }
    }
    
    private func runModel(imageBuffer: CVPixelBuffer) {
        guard let model = selectedVNModel else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: imageBuffer)
        
        let request = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
            if let results = request.results as? [VNClassificationObservation] {
                self.processClassificationObservations(results)
            } else if #available(iOS 12.0, *), let results = request.results as? [VNRecognizedObjectObservation] {
                self.processObjectDetectionObservations(results)
            }
        })
        
        request.preferBackgroundProcessing = true
        request.imageCropAndScaleOption = cropAndScaleOption
        
        do {
            try handler.perform([request])
        } catch {
            print("failed to perform")
        }
    }

    @available(iOS 12.0, *)
    private func processObjectDetectionObservations(_ results: [VNRecognizedObjectObservation]) {
        bbView.observations = results
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.resultView.isHidden = true
            self.bbView.isHidden = false
            self.bbView.setNeedsDisplay()
        }
    }
    
    //TODO: Change the function name
    ///this function have been modified to show "No Object Found"
    private func processClassificationObservations(_ results: [VNClassificationObservation]) {
        DispatchQueue.main.async(execute: {
            self.bbView.isHidden = true
            self.resultView.isHidden = false
            self.resultLabel.text = "No Object Found."
            self.othersLabel.text = "Please adjust camera position."
            
            if (Date().timeIntervalSince(self.lastNotFoundTime) >= 10){
                self.lastNotFoundTime = Date()
                AudioServicesPlayAlertSoundWithCompletion(SystemSoundID(kSystemSoundID_Vibrate)) { }
                let message = "No object found, please adjust your camera position"
                let speechUtterance = AVSpeechUtterance(string: message)
                self.speechSynthesizer.speak(speechUtterance)
            }
        })
    }
    
    @objc func dismissView(){
        self.dismiss(animated: true, completion: nil)
    }
    
}

extension URL {
    var modelName: String {
        return lastPathComponent.replacingOccurrences(of: ".mlmodelc", with: "")
    }
}
