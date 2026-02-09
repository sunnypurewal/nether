//
//  NetherApp.swift
//  Nether
//
//  Created by Sunny on 2026-01-30.
//

import SwiftUI
import AVFoundation

/// The entry point of the Nether application.
@main
struct NetherApp: App {
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback ensures audio plays even if the silent switch is on.
            // .moviePlayback mode is optimized for high-dynamic-range content.
            try session.setCategory(.playback, mode: .moviePlayback, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
}
