import SwiftUI
import AVFoundation

/// A SwiftUI wrapper for displaying the camera preview.
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    /// Creates the preview view and associates it with the camera session.
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    /// Updates the preview view when the camera manager changes.
    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let device = cameraManager.currentDevice {
            uiView.updateDevice(device)
        }
    }
}

/// A UIView that displays the video feed from an AVCaptureSession and handles its own rotation.
class PreviewView: UIView {
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    private var currentDevice: AVCaptureDevice?

    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }

    func updateDevice(_ device: AVCaptureDevice) {
        guard device != currentDevice else { return }
        currentDevice = device
        
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)
        rotationCoordinator = coordinator
        
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelPreview
            DispatchQueue.main.async {
                if let connection = self?.videoPreviewLayer.connection {
                    if connection.isVideoRotationAngleSupported(angle) {
                        connection.videoRotationAngle = angle
                    }
                }
            }
        }
    }
}
