//
//  ScanViewController.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import UIKit
import AVFoundation
import Vision

class ScanViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: MEDICATION
    var medication: Medication!
    var delegate: ScanViewControllerDelgate?
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var dosageLabel: UILabel!
    
    // MARK: VISION
    var bufferSize: CGSize = .zero
    var rootLayer: CALayer! = nil
    private var detectionOverlay: CALayer! = nil
    
    @IBOutlet weak private var previewView: UIView!
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    private let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var requests = [VNRequest]()
    
    private let trackingStabilizer = TrackingStabilizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = medication.name
        setupScrollView()
        
        setupAVCapture()
    }
    
    // MARK: VIEW
    func setupScrollView() {
        self.nameLabel.text = medication.name
        self.descriptionLabel.text = medication.instruction
        self.imageView.image = medication.image
        
        self.dosageLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        self.dosageLabel.textColor = .white
        self.dosageLabel.backgroundColor = .systemRed
        self.dosageLabel.layer.cornerRadius = 8
        self.dosageLabel.layer.masksToBounds = true
        self.dosageLabel.text = "0/\(medication.dosage)"
    }
    
    @IBAction func takeButtonPressed(_ sender: Any) {
        
        let alertController = UIAlertController(title: "Take \(medication.dosage) \(medication.name)",
                                                message: medication.instruction, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in }))
        alertController.addAction(UIAlertAction(title: "Take", style: .default, handler: { _ in
            self.delegate?.medicationTaken(self.medication)
            self.navigationController?.popViewController(animated: true)
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: VISION
    @discardableResult
    func setupVision() -> NSError? {
        // Setup Vision parts
        let error: NSError! = nil
        
        guard let modelURL = Bundle.main.url(forResource: "MedDetect", withExtension: "mlmodelc") else {
            return NSError(domain: "VisionObjectRecognitionViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file is missing"])
        }
        do {
            let visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL))
            let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                DispatchQueue.main.async(execute: {
                    // perform all the UI updates on the main queue
                    if let results = request.results {
                        self.handleVisionRequestResults(results)
                    }
                })
            })
            self.requests = [objectRecognition]
        } catch let error as NSError {
            print("Model loading went wrong: \(error)")
        }
        
        return error
    }
    
    func drawResults(_ results: [ObjectDetectionResult]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil
        
        for observation in results {
            guard observation.confidence >= 0.95 else {
                continue
            }
            
            let objectBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            let shapeColor = (observation.medicationId == medication.identifier) ? UIColor.green : UIColor.red
            
            let shapeLayer = self.createRoundedRectLayer(withBounds: objectBounds, color: shapeColor)
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: observation.label,
                                                            confidence: observation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func handleVisionRequestResults(_ results: [Any]) {
        
        // Stabilize results
        self.trackingStabilizer.add(observations: results)
        let objectDetectionResults = trackingStabilizer.getStabilizedDetectionResults()
        
        self.drawResults(objectDetectionResults)
        
        // Process Results
        let dosageGoal = self.medication.dosage
        var foundDosage = 0
        
        for object in objectDetectionResults {
            guard object.confidence >= 0.95 else {
                continue
            }
            
            if object.medicationId == self.medication.identifier {
                foundDosage += 1
            }
        }
        
        // 
        self.dosageLabel.text = "\(foundDosage)/\(dosageGoal)"
        self.dosageLabel.backgroundColor = (foundDosage == dosageGoal) ? .systemGreen : .systemRed
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    
    func setupAVCapture() {
        var deviceInput: AVCaptureDeviceInput!
        
        // Select a video device, make an input
        let videoDevice = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back).devices.first
        do {
            deviceInput = try AVCaptureDeviceInput(device: videoDevice!)
        } catch {
            print("Could not create video device input: \(error)")
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080 // Model image size is smaller.
        
        // Add a video input
        guard session.canAddInput(deviceInput) else {
            print("Could not add video device input to the session")
            session.commitConfiguration()
            return
        }
        session.addInput(deviceInput)
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            // Add a video data output
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            session.commitConfiguration()
            return
        }
        let captureConnection = videoDataOutput.connection(with: .video)
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try  videoDevice!.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions((videoDevice?.activeFormat.formatDescription)!)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            videoDevice!.unlockForConfiguration()
        } catch {
            print(error)
        }
        session.commitConfiguration()
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        rootLayer = previewView.layer
        previewLayer.frame = rootLayer.bounds
        rootLayer.addSublayer(previewLayer)
        
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        setupVision()
        
        // start the capture
        startCaptureSession()
    }
    
    func startCaptureSession() {
        session.startRunning()
    }
    
    // Clean up capture setup
    func teardownAVCapture() {
        previewLayer.removeFromSuperlayer()
        previewLayer = nil
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didDrop didDropSampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // print("frame dropped")
    }
    
    public func exifOrientationFromDeviceOrientation() -> CGImagePropertyOrientation {
        let curDeviceOrientation = UIDevice.current.orientation
        let exifOrientation: CGImagePropertyOrientation
        
        switch curDeviceOrientation {
        case UIDeviceOrientation.portraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = .left
        case UIDeviceOrientation.landscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = .upMirrored
        case UIDeviceOrientation.landscapeRight:      // Device oriented horizontally, home button on the left
            exifOrientation = .down
        case UIDeviceOrientation.portrait:            // Device oriented vertically, home button on the bottom
            exifOrientation = .up
        default:
            exifOrientation = .up
        }
        return exifOrientation
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 30.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayer(withBounds bounds: CGRect, color: UIColor) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        
        shapeLayer.borderColor = color.cgColor
        shapeLayer.borderWidth = 2
        shapeLayer.backgroundColor = color.cgColor.copy(alpha: 0.2)
        shapeLayer.cornerRadius = 16
        return shapeLayer
    }
    
}

protocol ScanViewControllerDelgate {
    func medicationTaken(_ medication: Medication)
}
