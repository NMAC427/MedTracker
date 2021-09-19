//
//  DetectionResult.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import Foundation
import CoreGraphics
import Vision

struct ObjectDetectionResult {
    
    let boundingBox: CGRect
    let label: String
    let confidence: Float
    
    init(boundingBox: CGRect, label: String, confidence: Float) {
        self.boundingBox = boundingBox
        self.label = label
        self.confidence = confidence
    }
    
    init(observation: VNRecognizedObjectObservation) {
        self.boundingBox = observation.boundingBox
        self.label = observation.labels[0].identifier
        self.confidence = observation.labels[0].confidence
    }
    
    var medicationId: Medication.Identifier? {
        return Medication.Identifier.init(rawValue: label)
    }
    
}
