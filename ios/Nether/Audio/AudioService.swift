import Foundation
import AVFoundation

protocol AudioServiceProtocol {
    /// Plays a sound file with the given name and extension.
    /// - Parameters:
    ///   - name: The name of the sound file.
    ///   - ext: The file extension (e.g., "m4a").
    func playSound(named name: String, extension ext: String)
}

/// A service responsible for handling audio playback.
class AudioService: AudioServiceProtocol {
    private var audioPlayer: AVAudioPlayer?
    
    /// Plays a sound file with the given name and extension.
    /// - Parameters:
    ///   - name: The name of the sound file.
    ///   - ext: The file extension (e.g., "m4a").
    func playSound(named name: String, extension ext: String) {
        if let player = audioPlayer, player.isPlaying {
            return
        }
        
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing sound: \(error.localizedDescription)")
        }
    }
}
