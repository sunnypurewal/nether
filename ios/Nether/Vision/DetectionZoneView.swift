import SwiftUI

enum HandleType: Hashable {
    case topLeft, topCenter, topRight
    case middleLeft, middleRight
    case bottomLeft, bottomCenter, bottomRight
}

/// A view that renders the interactive detection zone overlay.
struct DetectionZoneView: View {
    @Binding var detectionZone: CGRect
    var isHumanDetected: Bool
    
    @State private var initialZone: CGRect?
    @State private var activeHandle: HandleType?
    
    private let handleHitboxSize: CGFloat = 60
    private let handleVisualSize: CGFloat = 15
    
    var body: some View {
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

                // Handles
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
    
    private func handleView(for type: HandleType, rect: CGRect, size: CGSize) -> some View {
        let pos = position(for: type, in: rect)
        let isActive = activeHandle == type
        
        return Circle()
            .fill(Color.white)
            .frame(width: isActive ? handleHitboxSize : handleVisualSize, 
                   height: isActive ? handleHitboxSize : handleVisualSize)
            .overlay(Circle().stroke(Color.purple, lineWidth: 2))
            .frame(width: handleHitboxSize, height: handleHitboxSize)
            .contentShape(Rectangle())
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
        
        let maxX = max(0, min(newRect.origin.x, 1))
        let maxY = max(0, min(newRect.origin.y, 1))
        let maxW = max(0, min(newRect.width, 1 - maxX))
        let maxH = max(0, min(newRect.height, 1 - maxY))
        
        newRect = CGRect(x: maxX, y: maxY, width: maxW, height: maxH)

        if newRect.width > 0.05 && newRect.height > 0.05 {
            detectionZone = newRect
        }
    }
}
