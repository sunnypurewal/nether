//
//  ContentView.swift
//  Nether
//
//  Created by Sunny on 2026-01-30.
//

import SwiftUI
import Vision
import AVFoundation

struct ContentView: View {
    @State private var isHumanDetected = false

    @State private var audioPlayer: AVAudioPlayer?

    @StateObject private var cameraManager = CameraManager()
    
    @State private var detectionZone = CGRect(x: 0.39, y: 0.0, width: 0.16, height: 1.0)
    @State private var initialZone: CGRect?
    @State private var activeHandle: HandleType?

    private let handleHitboxSize: CGFloat = 60
    private let handleVisualSize: CGFloat = 15

    enum HandleType: Hashable {
        case topLeft, topCenter, topRight
        case middleLeft, middleRight
        case bottomLeft, bottomCenter, bottomRight
    }

    var body: some View {
        GeometryReader { screenGeometry in
            let screenWidth = screenGeometry.size.width
            let screenHeight = screenGeometry.size.height
            let screenAspectRatio = screenWidth / screenHeight
            
            // Fixed vertical padding (50px top + 50px bottom = 100px total)
            let totalVerticalPadding: CGFloat = 100
            let targetHeight = screenHeight - totalVerticalPadding
            let targetWidth = targetHeight * screenAspectRatio
            
            // Calculate horizontal padding to achieve the target width
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
                    
                    // Camera Switch Button
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
                    
                    // Detection Zone Overlay
                    GeometryReader { geometry in
                        let rect = CGRect(
                            x: detectionZone.origin.x * geometry.size.width,
                            y: detectionZone.origin.y * geometry.size.height,
                            width: detectionZone.width * geometry.size.width,
                            height: detectionZone.height * geometry.size.height
                        )
                        
                        ZStack {
                            // Main Rectangle
                            Rectangle()
                                .stroke(isHumanDetected ? Color.green : Color.purple, lineWidth: 4)
                                .background(Color.purple.opacity(0.1))
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if initialZone == nil { initialZone = detectionZone }
                                            if let initial = initialZone {
                                                let deltaX = value.translation.width / geometry.size.width
                                                let deltaY = value.translation.height / geometry.size.height
                                                
                                                var newX = initial.origin.x + deltaX
                                                var newY = initial.origin.y + deltaY
                                                
                                                // Clamp position
                                                newX = max(0, min(newX, 1 - initial.width))
                                                newY = max(0, min(newY, 1 - initial.height))
                                                
                                                detectionZone = CGRect(
                                                    x: newX,
                                                    y: newY,
                                                    width: initial.width,
                                                    height: initial.height
                                                )
                                            }
                                        }
                                        .onEnded { _ in initialZone = nil }
                                )

                            // Handles - Placed AFTER the rectangle to be on top
                            ForEach([
                                HandleType.topLeft, .topCenter, .topRight,
                                .middleLeft, .middleRight,
                                .bottomLeft, .bottomCenter, .bottomRight
                            ], id: \.self) { type in
                                handleView(for: type, rect: rect, size: geometry.size)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 50)
            .padding(.horizontal, horizontalPadding)
            .frame(width: screenWidth, height: screenHeight)
            .background(Color.black)
        }
    }

    private func handleView(for type: HandleType, rect: CGRect, size: CGSize) -> some View {
        let pos = position(for: type, in: rect)
        let isActive = activeHandle == type
        
        return Circle()
            .fill(Color.white)
            .frame(width: isActive ? handleHitboxSize : handleVisualSize, 
                   height: isActive ? handleHitboxSize : handleVisualSize)
            .overlay(Circle().stroke(Color.purple, lineWidth: 2))
            .frame(width: handleHitboxSize, height: handleHitboxSize) // Force large layout box
            .contentShape(Rectangle()) // Hitbox for the entire 60x60 area
            .position(pos)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isActive)
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if activeHandle == nil { 
                            activeHandle = type
                            initialZone = detectionZone 
                        }
                        updateZone(type: type, translation: value.translation, size: size)
                    }
                    .onEnded { _ in 
                        activeHandle = nil
                        initialZone = nil 
                    }
            )
    }

    private func position(for type: HandleType, in rect: CGRect) -> CGPoint {
        switch type {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topCenter: return CGPoint(x: rect.midX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .middleLeft: return CGPoint(x: rect.minX, y: rect.midY)
        case .middleRight: return CGPoint(x: rect.maxX, y: rect.midY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomCenter: return CGPoint(x: rect.midX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }

    private func updateZone(type: HandleType, translation: CGSize, size: CGSize) {
        guard let initial = initialZone else { return }
        
        let dx = translation.width / size.width
        let dy = translation.height / size.height
        
        var newRect = initial
        
        switch type {
        case .topLeft:
            newRect.origin.x = initial.origin.x + dx
            newRect.origin.y = initial.origin.y + dy
            newRect.size.width = initial.size.width - dx
            newRect.size.height = initial.size.height - dy
        case .topCenter:
            newRect.origin.y = initial.origin.y + dy
            newRect.size.height = initial.size.height - dy
        case .topRight:
            newRect.origin.y = initial.origin.y + dy
            newRect.size.width = initial.size.width + dx
            newRect.size.height = initial.size.height - dy
        case .middleLeft:
            newRect.origin.x = initial.origin.x + dx
            newRect.size.width = initial.size.width - dx
        case .middleRight:
            newRect.size.width = initial.size.width + dx
        case .bottomLeft:
            newRect.origin.x = initial.origin.x + dx
            newRect.size.width = initial.size.width - dx
            newRect.size.height = initial.size.height + dy
        case .bottomCenter:
            newRect.size.height = initial.size.height + dy
        case .bottomRight:
            newRect.size.width = initial.size.width + dx
            newRect.size.height = initial.size.height + dy
        }
        
        // Clamp bounds
        let maxX = max(0, min(newRect.origin.x, 1))
        let maxY = max(0, min(newRect.origin.y, 1))
        let maxW = max(0, min(newRect.width, 1 - maxX))
        let maxH = max(0, min(newRect.height, 1 - maxY))
        
        newRect = CGRect(x: maxX, y: maxY, width: maxW, height: maxH)

        // Prevent negative width/height and ensure minimum size
        if newRect.width > 0.05 && newRect.height > 0.05 {
            detectionZone = newRect
        }
    }

    @State private var frameCount = 0

    private func processCameraFrame(_ pixelBuffer: CVPixelBuffer) {
        frameCount += 1
        
        // Convert AVCaptureVideoOrientation to CGImagePropertyOrientation
        let orientation: CGImagePropertyOrientation
        switch cameraManager.videoOrientation {
        case .portrait: orientation = .right
        case .portraitUpsideDown: orientation = .left
        case .landscapeLeft: orientation = .down
        case .landscapeRight: orientation = .up
        @unknown default: orientation = .right
        }

        detectEverything(in: pixelBuffer, orientation: orientation)
    }

    private func playNetherSound() {
        guard let url = Bundle.main.url(forResource: "nether", withExtension: "m4a") else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
        }
    }

    private func detectEverything(in buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        let poseRequest = VNDetectHumanBodyPoseRequest()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: orientation, options: [:])
        do {
            try handler.perform([poseRequest])
            
            let observations = poseRequest.results ?? []
            
            let humanInZone = observations.contains { observation in
                // Check for head joints (nose, eyes, or ears)
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
            
            DispatchQueue.main.async {
                // If we see both head and feet in the zone, play the sound
                if humanInZone && !self.isHumanDetected {
                    self.playNetherSound()
                }
                
                self.isHumanDetected = humanInZone
            }
        } catch {
        }
    }
}