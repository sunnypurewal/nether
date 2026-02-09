import Foundation
import Vision
import CoreImage
import Combine
import CoreVideo

/// Manages the detection state and coordinates between pose detection and audio feedback.
class DetectionManager: ObservableObject {
    @Published var isHumanDetected = false
    @Published var detectionZone = CGRect(x: 0.39, y: 0.0, width: 0.16, height: 1.0)
    
    private let poseDetector: PoseDetectorProtocol
    
    /// Initializes the DetectionManager with an optional pose detector.
    /// - Parameters:
    ///   - poseDetector: The pose detector to use for human body detection.
    init(poseDetector: PoseDetectorProtocol = PoseDetector()) {
        self.poseDetector = poseDetector
    }
    
    /// Processes a camera frame for pose detection.
    /// - Parameters:
    ///   - buffer: The pixel buffer containing the frame data.
    ///   - orientation: The orientation of the image.
    func processFrame(_ buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        poseDetector.detectPose(in: buffer, orientation: orientation) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let observations):
                let humanInZone = observations.contains { observation in
                    self.isObservationInZone(observation)
                }
                
                DispatchQueue.main.async {
                    self.isHumanDetected = humanInZone
                }
            case .failure(let error):
                print("Pose detection error: \(error.localizedDescription)")
            }
        }
    }
    
    private func isObservationInZone(_ observation: VNHumanBodyPoseObservation) -> Bool {
        let headJoints: [VNHumanBodyPoseObservation.JointName] = [.nose, .leftEye, .rightEye, .leftEar, .rightEar]
        let footJoints: [VNHumanBodyPoseObservation.JointName] = [.leftAnkle, .rightAnkle]
        
        var headInZone = false
        for joint in headJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                let normalizedPoint = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
                if detectionZone.contains(normalizedPoint) {
                    headInZone = true
                    break
                }
            }
        }
        
        var feetInZone = false
        for joint in footJoints {
            if let point = try? observation.recognizedPoint(joint), point.confidence > 0.3 {
                let normalizedPoint = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
                if detectionZone.contains(normalizedPoint) {
                    feetInZone = true
                    break
                }
            }
        }
        
        return headInZone && feetInZone
    }
}
