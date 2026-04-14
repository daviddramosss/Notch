
/*
 
 Es el cerebro del widget. Coge los datos que le da el puente, los formatea, crea los temporizadores y le dice a la vista qué tiene que
 dibujar.
 
 */
import AppKit
import Combine
import SwiftUI

enum MusicSource {
    case appleMusic
    case spotify
    case other
    case none
}

class NowPlayingManager: NSObject, ObservableObject, NotchWidget {
    let id = WidgetID.nowPlaying
    let title = "Now Playing"
    let requiresPermission = false
    
    @Published var isEnabled: Bool = true
    @Published var songTitle: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var artwork: NSImage? = nil
    @Published var isPlaying: Bool = false
    @Published var elapsed: Double = 0
    @Published var duration: Double = 0
    
    @Published var source: MusicSource = .none
    @Published var isDraggingSlider: Bool = false
    
    private var progressTimer: Timer?
    private var trackStartDate: Date?
    private var trackElapsedAtStart: Double = 0
    
    override init() {
        super.init()
    }
    
    func activate() {
        setupDistributedNotifications()
        fetchInitialState()
        startProgressTimer()
    }
    
    func deactivate() {
        progressTimer?.invalidate()
        progressTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
        clear()
    }
    
    // MARK: - Notificaciones Distribuidas
    private func setupDistributedNotifications() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(spotifyChanged(_:)), name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"), object: nil)
        center.addObserver(self, selector: #selector(appleMusicChanged(_:)), name: NSNotification.Name("com.apple.Music.playerInfo"), object: nil)
    }
    
    //Pasa la fuente directamente para evitar el bug de milisegundos
    @objc private func appleMusicChanged(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        updateCoreState(info: info, newSource: .appleMusic)
    }
    
    @objc private func spotifyChanged(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        updateCoreState(info: info, newSource: .spotify)
    }
    
    private func updateCoreState(info: [AnyHashable: Any], newSource: MusicSource) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Asignamos la fuente correcta INSTANTÁNEAMENTE para que salga el logo
            self.source = newSource
            
            if self.isDraggingSlider { return }
            
            let newTitle = info["Name"] as? String ?? ""
            let state = info["Player State"] as? String ?? ""
            let isSpotify = (newSource == .spotify)
            
            if newTitle != self.songTitle {
                self.elapsed = 0
                self.trackStartDate = (state == "Playing" || state == "Playing ") ? Date() : nil
                self.trackElapsedAtStart = 0
                
                //Si es Spotify y no manda foto, usamos el fallback de iTunes
                if isSpotify {
                    if let urlStr = info["art_url"] as? String, let url = URL(string: urlStr) {
                        self.fetchArtwork(from: url)
                    } else {
                        let currentArtist = info["Artist"] as? String ?? ""
                        self.fetchArtworkFromiTunes(title: newTitle, artist: currentArtist)
                    }
                } else {
                    self.fetchArtworkFromMusicApp()
                }
            }
            
            self.songTitle = newTitle
            self.artist = info["Artist"] as? String ?? ""
            self.album = info["Album"] as? String ?? ""
            
            if let dur = info["Total Time"] as? Double, !isSpotify {
                self.duration = dur / 1000.0
            } else if let dur = info["Duration"] as? Double, isSpotify {
                self.duration = dur > 10000 ? dur / 1000.0 : dur
            }
            
            if let pos = info["Current Position"] as? Double, !isSpotify {
                self.elapsed = pos
                self.trackElapsedAtStart = pos
                self.trackStartDate = (state == "Playing" || state == "Playing ") ? Date() : nil
            }
            
            let wasPlaying = self.isPlaying
            self.isPlaying = (state == "Playing" || state == "Playing ")
            
            if self.isPlaying && !wasPlaying {
                self.trackStartDate = Date()
                self.trackElapsedAtStart = self.elapsed
            } else if !self.isPlaying {
                self.trackStartDate = nil
            }
            
            if isSpotify { self.fetchSpotifyPosition() }
        }
    }
    
    // MARK: - El Reloj Matemático
    private func startProgressTimer() {
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, let start = self.trackStartDate else { return }
            if self.isDraggingSlider { return }
            
            let realElapsed = self.trackElapsedAtStart + Date().timeIntervalSince(start)
            self.elapsed = self.duration > 0 ? min(realElapsed, self.duration) : realElapsed
        }
    }
    
    // MARK: - Arrastrar Barra (Seeking)
    func seekTo(seconds: Double) {
        self.elapsed = seconds
        self.trackElapsedAtStart = seconds
        if self.isPlaying { self.trackStartDate = Date() }
        
        let appName = (source == .appleMusic) ? "Music" : "Spotify"
        let script = """
        tell application "System Events" to set isRunning to exists (processes where name is "\(appName)")
        if isRunning then
            tell application "\(appName)" to set player position to \(seconds)
        end if
        """
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            if let err = error { print("❌ Error en Seek: \(err)") }
        }
    }
    
    // MARK: - Descarga de Imágenes
    private func fetchArtwork(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async { self?.artwork = image }
        }.resume()
    }
    
    
    private func fetchArtworkFromMusicApp() {
            let script = """
            tell application "Music"
                try
                    set theArtwork to raw data of artwork 1 of current track
                    return theArtwork
                end try
            end tell
            """
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let scriptObject = NSAppleScript(source: script) else { return }
                var error: NSDictionary?
                let descriptor = scriptObject.executeAndReturnError(&error)
                
                let data = descriptor.data
                
                //Comprueba si esos datos pueden formar una imagen válida
                if let image = NSImage(data: data) {
                    DispatchQueue.main.async { self?.artwork = image }
                } else {
                    DispatchQueue.main.async {
                        if let title = self?.songTitle, let artist = self?.artist {
                            self?.fetchArtworkFromiTunes(title: title, artist: artist)
                        }
                    }
                }
            }
        }
    
    private func fetchArtworkFromiTunes(title: String, artist: String) {
        let term = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = "https://itunes.apple.com/search?term=\(term)&limit=1&entity=song"
        guard let url = URL(string: urlStr) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artUrlStr = first["artworkUrl100"] as? String else { return }
            
            let highResUrlStr = artUrlStr.replacingOccurrences(of: "100x100bb", with: "600x600bb")
            if let highResUrl = URL(string: highResUrlStr) { self?.fetchArtwork(from: highResUrl) }
        }.resume()
    }
    
    // MARK: - Posición inicial
    private func fetchInitialState() {
        fetchSpotifyPosition()
    }
    
    private func fetchSpotifyPosition() {
        let script = """
        tell application "System Events" to set isRunning to exists (processes where name is "Spotify")
        if isRunning then
            tell application "Spotify" to return (player position as string) & "|" & ((duration of current track / 1000) as string)
        end if
        return "0|0"
        """
        DispatchQueue.global(qos: .background).async { [weak self] in
            var error: NSDictionary?
            if let result = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue {
                let parts = result.components(separatedBy: "|")
                if parts.count == 2, let pos = Double(parts[0]), let dur = Double(parts[1]), dur > 0 {
                    DispatchQueue.main.async {
                        self?.duration = dur
                        self?.elapsed = pos
                        self?.trackElapsedAtStart = pos
                        if self?.isPlaying == true { self?.trackStartDate = Date() }
                    }
                }
            }
        }
    }
    
    private func clear() {
        songTitle = ""; artist = ""; album = ""; artwork = nil
        isPlaying = false; elapsed = 0; duration = 0
        trackStartDate = nil; trackElapsedAtStart = 0; source = .none
    }
    
    func makeView() -> some View { NowPlayingView().environmentObject(self) }
    func togglePlayPause() { _ = MRMediaRemoteBridge.shared.send(.togglePlayPause) }
    func skipNext() { _ = MRMediaRemoteBridge.shared.send(.nextTrack) }
    func skipPrevious() { _ = MRMediaRemoteBridge.shared.send(.previousTrack) }
}
