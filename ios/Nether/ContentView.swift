//
//  ContentView.swift
//  Nether
//
//  Created by Sunny on 2026-01-30.
//

import SwiftUI
import CoreVideo

/// The main view of the application, orchestrating the camera and detection components.
struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var detectionManager = DetectionManager()
    private let audioService = AudioService()

    var body: some View {
        GeometryReader { screenGeometry in
            let screenWidth = screenGeometry.size.width
            let screenHeight = screenGeometry.size.height
            let screenAspectRatio = screenWidth / screenHeight
            
            let totalVerticalPadding: CGFloat = 100
            let targetHeight = screenHeight - totalVerticalPadding
            let targetWidth = targetHeight * screenAspectRatio
            let horizontalPadding = (screenWidth - targetWidth) / 2
            
            VStack {
                ZStack {
                    CameraPreview(cameraManager: cameraManager)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onAppear {
                            cameraManager.onFrameUpdate = { buffer in
                                processCameraFrame(buffer)
                            }
                        }
                    
                    DetectionZoneView(
                        detectionZone: $detectionManager.detectionZone,
                        isHumanDetected: detectionManager.isHumanDetected
                    )
                    
                    cameraSwitchButton
                }
            }
            .onChange(of: detectionManager.isHumanDetected) { oldValue, newValue in
                if newValue && !oldValue {
                    audioService.playSound(named: "nether", extension: "m4a")
                }
            }
            .padding(.vertical, 50)
            .padding(.horizontal, horizontalPadding)
            .frame(width: screenWidth, height: screenHeight)
            .background(Color.black)
        }
    }

    private var cameraSwitchButton: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: {
                    cameraManager.switchCamera()
                }) {
                    Text(cameraManager.currentCameraLabel)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(16)
            }
            Spacer()
        }
    }

    private func processCameraFrame(_ pixelBuffer: CVPixelBuffer) {
        detectionManager.processFrame(pixelBuffer, orientation: cameraManager.frameOrientation)
    }
}
