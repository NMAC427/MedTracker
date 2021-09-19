//
//  TrackingStabilizer.swift
//  MedTracker
//
//  Created by Nicolas Camenisch on 18.09.21.
//

import Foundation
import CoreGraphics
import Vision
import Collections

/// Add temporal stabilization to the result of the vision object detection.
/// This should prevent pills from flickering in and out
class TrackingStabilizer {
    
    struct Observation {
        let boundingBox: CGRect
        let label: String
        let confidence: Float
        
        /// How often the observation has been made
        var count: Float
        
        init(observation: VNRecognizedObjectObservation) {
            self.boundingBox = observation.boundingBox
            self.label = observation.labels[0].identifier
            self.confidence = observation.labels[0].confidence
            self.count = 1.0
        }
        
        func intersectionPercentage(with other: Observation) -> CGFloat {
            let intersection = self.boundingBox.intersection(other.boundingBox)
            let totalArea = (self.boundingBox.area + other.boundingBox.area)
            return intersection.area / (totalArea - intersection.area)
        }
        
        func sameBoundingBox(as other: Observation) -> Bool {
            let intersectionPercentage = self.intersectionPercentage(with: other)
            return intersectionPercentage >= 0.85
        }
        
        func toObjectDetectionResult() -> ObjectDetectionResult {
            return ObjectDetectionResult(boundingBox: self.boundingBox,
                                         label: self.label,
                                         confidence: self.confidence)
        }
    }
    
    /// List of recent observations
    var deque = Deque<Array<Observation>>()
    let dequeLengthLimit = 5
    
    func add(observations: [Any]) {
        let objectObservations = observations
            .compactMap({ $0 as? VNRecognizedObjectObservation })
            .map({ Observation(observation: $0) })
            .filter({ $0.confidence >= 0.9 })
        
        deque.append(objectObservations)
        
        // Drop first elements to keep correct length
        while deque.count > dequeLengthLimit {
            _ = deque.popFirst()
        }
    }
    
    func getStabilizedDetectionResults() -> [ObjectDetectionResult] {
        var resultFrame = deque.last ?? []
        
        for (frameIndex, frame) in deque.reversed()[1...].enumerated() {
            for observation in frame {
                var matchingObservation = false
                for i in 0..<resultFrame.count {
                    if resultFrame[i].sameBoundingBox(as: observation) && resultFrame[i].label == observation.label {
                        resultFrame[i].count += 5.0 / Float(frameIndex + 5)
                        matchingObservation = true
                    }
                }
                
                if !matchingObservation {
                    resultFrame.append(observation)
                }
            }
        }
        
        // Make sure the pill has been recognized a few times
        resultFrame = resultFrame.filter({ $0.count >= 1.5 })
        
        // Merge the result frame into
        var mergedFrame = [Observation]()
        
        for observation in resultFrame {
            var matchFound = false
            for mergeObservation in mergedFrame {
                if mergeObservation.intersectionPercentage(with: observation) >= 0.20 && mergeObservation.label == observation.label {
                    matchFound = true
                    break
                }
            }
            
            if !matchFound {
                mergedFrame.append(observation)
            }
        }
        
        resultFrame = mergedFrame
        
        // In case no pills recognized (eg movement) -> take current frame
        if resultFrame.isEmpty {
            resultFrame = deque.last ?? []
        }
        
        return resultFrame.map { $0.toObjectDetectionResult() }
    }
    
}

fileprivate extension CGRect {
    var area: CGFloat {
        return self.width * self.height
    }
}
