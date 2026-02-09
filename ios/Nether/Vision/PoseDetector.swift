import Foundation
import Vision
import CoreGraphics
import CoreVideo

protocol PoseDetectorProtocol {
    /// Detects human body poses in the provided pixel buffer.
    /// - Parameters:
    ///   - buffer: The pixel buffer containing the frame data.
    ///   - orientation: The orientation of the image.
    ///   - completion: A closure called with the result of the detection.
    func detectPose(in buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, completion: @escaping (Result<[VNHumanBodyPoseObservation], Error>) -> Void)
}

/// A detector that uses the Vision framework to identify human body poses.
class PoseDetector: PoseDetectorProtocol {
    /// Detects human body poses in the provided pixel buffer.
    /// - Parameters:
    ///   - buffer: The pixel buffer containing the frame data.
    ///   - orientation: The orientation of the image.
    ///   - completion: A closure called with the result of the detection.
    func detectPose(in buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, completion: @escaping (Result<[VNHumanBodyPoseObservation], Error>) -> Void) {
        let poseRequest = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:])
        
        do {
            try handler.perform([poseRequest])
            let observations = poseRequest.results ?? []
            completion(.success(observations))
        } catch {
            completion(.failure(error))
        }
    }
}
