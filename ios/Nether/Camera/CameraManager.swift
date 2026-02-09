import SwiftUI
import AVFoundation
import Combine
import ImageIO

/// Manages the camera session, device selection, and orientation tracking.
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var session = AVCaptureSession()
    @Published var frameOrientation: CGImagePropertyOrientation = .up
    @Published var currentDevice: AVCaptureDevice?

    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    var currentCameraLabel: String {
        guard let device = currentDevice else { return "1x" }
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "0.5x"
        case .builtInWideAngleCamera:
            return "1x"
        case .builtInTelephotoCamera:
            return "2x"
        default:
            return "1x"
        }
    }

    var onFrameUpdate: ((CVPixelBuffer) -> Void)?

    override init() {
        super.init()
        checkPermission()
    }

    /// Switches between available back cameras (e.g., Ultra Wide, Wide, Telephoto).
    func switchCamera() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        
        let devices = discoverySession.devices
        guard devices.count > 1, let current = currentDevice else { return }
        
        guard let currentIndex = devices.firstIndex(of: current) else { return }
        let nextIndex = (currentIndex + 1) % devices.count
        let nextDevice = devices[nextIndex]
        
        session.beginConfiguration()
        if let currentInput = session.inputs.first as? AVCaptureDeviceInput {
            session.removeInput(currentInput)
        }
        
        do {
            let nextInput = try AVCaptureDeviceInput(device: nextDevice)
            if session.canAddInput(nextInput) {
                session.addInput(nextInput)
                self.currentDevice = nextDevice
                setupRotationCoordinator(for: nextDevice)
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        session.commitConfiguration()
    }

    /// AVCaptureVideoDataOutputSampleBufferDelegate method called when a new video frame is captured.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameUpdate?(pixelBuffer)
    }

    private func setupRotationCoordinator(for device: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
        self.rotationCoordinator = coordinator
        
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
            let angle = coordinator.videoRotationAngleForHorizonLevelCapture
            DispatchQueue.main.async {
                self?.updateRotationAngle(angle)
            }
        }
    }

    private func updateRotationAngle(_ angle: CGFloat) {
        session.beginConfiguration()
        for output in session.outputs {
            if let connection = output.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(angle) {
                    connection.videoRotationAngle = angle
                }
            }
        }
        session.commitConfiguration()
        
        // Since we rotate the connection, the buffer is now upright.
        self.frameOrientation = .up
    }
    
    /// Checks for camera permissions and sets up the session if authorized.
    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupSession()
                    }
                }
            }
        default:
            break
        }
    }
    
    /// Configures and starts the AVCaptureSession.
    func setupSession() {
        session.beginConfiguration()
        
        let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) ??
                     AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        guard let device = device else {
            session.commitConfiguration()
            return
        }
        
        self.currentDevice = device
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
            
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
            
            session.commitConfiguration()
            
            setupRotationCoordinator(for: device)
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            session.commitConfiguration()
        }
    }
}
