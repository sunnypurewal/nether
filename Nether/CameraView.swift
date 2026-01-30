import SwiftUI
import AVFoundation
import Combine

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = cameraManager.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if let connection = uiView.videoPreviewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = cameraManager.videoOrientation
            }
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    @Published var session = AVCaptureSession()
    @Published var videoOrientation: AVCaptureVideoOrientation = .portrait
    @Published var currentDevice: AVCaptureDevice?

    var currentCameraLabel: String {
        guard let device = currentDevice else { return "1x" }
        switch device.deviceType {
        case .builtInUltraWideCamera:
            return "0.5x"
        case .builtInWideAngleCamera:
            return "1x"
        case .builtInTelephotoCamera:
            // This is a simplification; actual optical zoom varies by device, 
            // but for UI labels, 2x/3x are the standard conventions.
            return "2x"
        default:
            return "1x"
        }
    }

    var onFrameUpdate: ((CVPixelBuffer) -> Void)?

    override init() {
        super.init()
        checkPermission()
        setupOrientationTracking()
    }

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
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        session.commitConfiguration()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameUpdate?(pixelBuffer)
    }

    private func setupOrientationTracking() {
        updateOrientation()
        NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { _ in
            self.updateOrientation()
        }
    }

    private func updateOrientation() {
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portrait:
            videoOrientation = .portrait
        case .landscapeLeft:
            videoOrientation = .landscapeRight
        case .landscapeRight:
            videoOrientation = .landscapeLeft
        case .portraitUpsideDown:
            videoOrientation = .portraitUpsideDown
        default:
            break
        }
    }
    
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
    
    func setupSession() {
        session.beginConfiguration()
        
        // Prefer the ultra-wide camera (0.5x) if available, otherwise fallback to wide-angle.
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
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            session.commitConfiguration()
        }
    }
}