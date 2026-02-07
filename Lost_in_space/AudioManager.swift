// AudioManager.swift

import Foundation
import AVFoundation

// MARK: 1. Conform to NSObject and AVAudioPlayerDelegate
class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    
    private var backgroundMusic: AVAudioPlayer?
    private let possibleTracks = ["track1", "track2", "track3", "track4", "track5", "track6", "track7", "track8", "track9"]

    override init() {
        super.init() // Required for NSObject subclasses
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Error setting up audio session: \(error.localizedDescription)")
        }
        
        NotificationCenter.default.addObserver(forName: Notification.Name("VolumeChanged"), object: nil, queue: .main) { [weak self] _ in
            self?.updateVolume()
        }
    }
    
    func startMusic() {
        if backgroundMusic?.isPlaying == true {
            print("AudioManager: Music is already playing, letting it continue.")
            return
        }
        
        // Ensure we don't pick the same track twice in a row (optional but nice)
        let currentTrackURL = backgroundMusic?.url
        var randomTrackName: String?
        
        repeat {
            randomTrackName = possibleTracks.randomElement()
        } while (possibleTracks.count > 1 && randomTrackName != nil && Bundle.main.url(forResource: randomTrackName!, withExtension: "mp3") == currentTrackURL)
        
        guard let trackName = randomTrackName,
              let url = Bundle.main.url(forResource: trackName, withExtension: "mp3") else {
            print("⚠️ AudioManager: Could not find or select a background music track.")
            return
        }
        
        do {
            backgroundMusic = try AVAudioPlayer(contentsOf: url)
            
            // MARK: 2. Set the delegate to self
            // This tells the player to notify AudioManager when it's done.
            backgroundMusic?.delegate = self
            
            // MARK: 3. Set loops to 0
            // We want it to play only ONCE, then the delegate will start the next song.
            backgroundMusic?.numberOfLoops = 0
            
            updateVolume()
            backgroundMusic?.prepareToPlay()
            backgroundMusic?.play()
            print("✅ AudioManager: Playlist started with track '\(trackName)'.")
            
        } catch {
            print("Music playback failed for \(trackName): \(error)")
        }
    }
    
    func stopMusic(fadeDuration: TimeInterval = 1.0) {
        // MARK: 4. Unset the delegate
        // This is important to prevent the playlist from restarting after we manually stop it.
        backgroundMusic?.delegate = nil
        
        backgroundMusic?.setVolume(0, fadeDuration: fadeDuration)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeDuration) { [weak self] in
            self?.backgroundMusic?.stop()
            self?.backgroundMusic = nil
            print("⏹️ AudioManager: Music and playlist stopped.")
        }
    }
    
    func updateVolume() {
        let musicVolume = UserDefaults.standard.float(forKey: "musicVolume")
        backgroundMusic?.volume = musicVolume
        print("🔊 AudioManager: Volume updated to \(musicVolume).")
    }
    
    // MARK: 5. Implement the delegate method
    // This function is automatically called by the system when the audio player finishes.
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("🎵 AudioManager: Track finished. Playing next song in playlist...")
            // The song finished successfully, so we start the next one.
            startMusic()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
