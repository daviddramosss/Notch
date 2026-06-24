
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
    // Indica a la View si hay un reproductor nativo controlable.
    // Si es false, los botones se desactivan para no enviar comandos al navegador.
    @Published var canControlPlayback: Bool = false
    
    private var progressTimer: Timer?
    private var trackStartDate: Date?
    private var trackElapsedAtStart: Double = 0
    
    // [FIX-1.1] Identidad compuesta de pista.
    // Antes solo comparábamos el título, lo cual fallaba con pistas
    // de nombre idéntico (remixes, "Intro", versiones live).
    // Ahora combinamos título + artista + álbum como clave única.
    private var currentTrackKey: String = ""
    
    // [FIX-1.3] Token de generación para invalidar fetches obsoletos.
    // Cada cambio de pista incrementa este contador. Cada descarga de
    // artwork captura el valor al inicio y lo compara al terminar.
    // Si no coincide, el resultado se descarta silenciosamente.
    // Esto elimina la race condition A→B→C sin necesidad de cancelar tasks.
    private var artworkFetchGeneration: UInt64 = 0
    
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
            
            self.source = newSource
            
            if self.isDraggingSlider { return }
            
            let newTitle  = info["Name"] as? String ?? ""
            let newArtist = info["Artist"] as? String ?? ""
            let newAlbum  = info["Album"] as? String ?? ""
            let state     = info["Player State"] as? String ?? ""
            let isSpotify = (newSource == .spotify)
            
            // [FIX-1.1] Identidad compuesta en vez de solo título
            let incomingTrackKey = "\(newTitle)|\(newArtist)|\(newAlbum)"
            let trackDidChange = (incomingTrackKey != self.currentTrackKey)
            
            if trackDidChange {
                self.currentTrackKey = incomingTrackKey
                
                // [FIX-1.2] Invalida la carátula ANTES de pedir la nueva.
                // La View verá nil y mostrará el placeholder inmediatamente,
                // eliminando el estado visual "carátula vieja con título nuevo".
                self.artwork = nil
                
                // [FIX-1.3] Incrementa la generación para matar fetches en vuelo
                self.artworkFetchGeneration &+= 1
                let fetchGen = self.artworkFetchGeneration
                
                self.elapsed = 0
                self.trackStartDate = (state == "Playing" || state == "Playing ") ? Date() : nil
                self.trackElapsedAtStart = 0
                
                if isSpotify {
                    // Intento 1: URL directa de la notificación (clave variable entre versiones)
                    let artURLString = info["art_url"] as? String
                        ?? info["Album Art URL"] as? String
                        ?? info["artUrl"] as? String
                    
                    if let urlStr = artURLString, let url = URL(string: urlStr) {
                        self.fetchArtwork(from: url, generation: fetchGen)
                    } else {
                        // Intento 2: AppleScript directo a Spotify (100% fiable)
                        self.fetchSpotifyArtwork(generation: fetchGen)
                    }
                } else {
                    self.fetchArtworkFromMusicApp(generation: fetchGen)
                }
            }
            
            self.songTitle = newTitle
            self.artist    = newArtist
            self.album     = newAlbum
            
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
            
            self.refreshCanControlPlayback()
        }
    }
    
    // MARK: - Targeting de comandos por app nativa
        
        private enum PlaybackTarget {
            case spotify
            case appleMusic
            case unavailable
        }
        
        private func resolveActiveTarget() -> PlaybackTarget {
            let spotifyRunning = !NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.spotify.client"
            ).isEmpty
            let musicRunning = !NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.apple.Music"
            ).isEmpty
            
            // Prioriza la fuente que reportan las notificaciones
            switch source {
            case .spotify:
                if spotifyRunning { return .spotify }
                if musicRunning  { return .appleMusic }
            case .appleMusic:
                if musicRunning  { return .appleMusic }
                if spotifyRunning { return .spotify }
            default:
                // Sin fuente conocida — probamos en orden de preferencia
                if spotifyRunning { return .spotify }
                if musicRunning  { return .appleMusic }
            }
            
            return .unavailable
        }
        
        private func executeAppleScript(_ script: String) {
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                NSAppleScript(source: script)?.executeAndReturnError(&error)
                if let err = error { print("Error AppleScript comando: \(err)") }
            }
        }
        
        private func refreshCanControlPlayback() {
            canControlPlayback = resolveActiveTarget() != .unavailable
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
            if let err = error { print(" Error en Seek: \(err)") }
        }
    }
    
    // MARK: - Descarga de Artwork (con protección de generación)
    
    // Todas las funciones de fetch reciben el token de generación.
    // Al completar, comprueban que la generación siga siendo la actual.
    // Si la pista cambió durante la descarga, el resultado se descarta.
    
    private func fetchArtwork(from url: URL, generation: UInt64) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self,
                  let data = data,
                  error == nil,
                  let image = NSImage(data: data) else { return }
            
            DispatchQueue.main.async {
                // [FIX-1.3] ¿Sigue siendo la misma pista que pidió esta descarga?
                guard self.artworkFetchGeneration == generation else { return }
                self.artwork = image
            }
        }.resume()
    }
    
    private func fetchArtworkFromMusicApp(generation: UInt64) {
        let script = """
        tell application "Music"
            try
                set theArtwork to raw data of artwork 1 of current track
                return theArtwork
            end try
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // [FIX-1.3] Comprobación temprana antes de ejecutar AppleScript (caro)
            guard self.artworkFetchGeneration == generation else { return }
            
            guard let scriptObject = NSAppleScript(source: script) else { return }
            var error: NSDictionary?
            let descriptor = scriptObject.executeAndReturnError(&error)
            let data = descriptor.data
            
            DispatchQueue.main.async {
                // [FIX-1.3] Comprobación tardía tras recibir el resultado
                guard self.artworkFetchGeneration == generation else { return }
                
                if let image = NSImage(data: data) {
                    self.artwork = image
                } else {
                    // Fallback a iTunes Search API — pasa la misma generación
                    self.fetchArtworkFromiTunes(
                        title: self.songTitle,
                        artist: self.artist,
                        generation: generation
                    )
                }
            }
        }
    }
    
    // MARK: - Artwork directo de Spotify vía AppleScript
        private func fetchSpotifyArtwork(generation: UInt64) {
            let script = """
            tell application "System Events" to set isRunning to exists (processes where name is "Spotify")
            if isRunning then
                tell application "Spotify" to return artwork url of current track
            end if
            return ""
            """
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                guard self.artworkFetchGeneration == generation else { return }
                
                var error: NSDictionary?
                guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue,
                      !result.isEmpty,
                      let url = URL(string: result) else {
                    // Último recurso: iTunes Search API con álbum incluido
                    DispatchQueue.main.async {
                        guard self.artworkFetchGeneration == generation else { return }
                        self.fetchArtworkFromiTunes(
                            title: self.songTitle,
                            artist: self.artist,
                            album: self.album,
                            generation: generation
                        )
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    guard self.artworkFetchGeneration == generation else { return }
                    self.fetchArtwork(from: url, generation: generation)
                }
            }
        }
    
    private func fetchArtworkFromiTunes(title: String, artist: String, album: String = "", generation: UInt64) {
            // Incluimos el álbum en la query para que iTunes devuelva el match correcto
            var searchParts = [title, artist]
            if !album.isEmpty { searchParts.append(album) }
            
            let term = searchParts.joined(separator: " ")
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlStr = "https://itunes.apple.com/search?term=\(term)&limit=1&entity=song"
            guard let url = URL(string: urlStr) else { return }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self else { return }
                guard self.artworkFetchGeneration == generation else { return }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = json["results"] as? [[String: Any]],
                      let first = results.first,
                      let artUrlStr = first["artworkUrl100"] as? String else { return }
                
                let highResUrlStr = artUrlStr.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                if let highResUrl = URL(string: highResUrlStr) {
                    self.fetchArtwork(from: highResUrl, generation: generation)
                }
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
        currentTrackKey = ""
        artworkFetchGeneration &+= 1  // Invalida cualquier fetch en vuelo al limpiar
        canControlPlayback = false
    }
    
    func makeView() -> some View { NowPlayingView().environmentObject(self) }
    
    // Comandos enrutados vía AppleScript a la app específica.
    // MRMediaRemoteSendCommand se elimina del path de comandos porque
    // envía al "Now Playing client" global del sistema (puede ser Chrome/Safari).
    func togglePlayPause() {
        switch resolveActiveTarget() {
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to playpause")
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to playpause")
        case .unavailable:
            break
        }
    }
    
    func skipNext() {
        switch resolveActiveTarget() {
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to next track")
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to next track")
        case .unavailable:
            break
        }
    }
    
    func skipPrevious() {
        switch resolveActiveTarget() {
        case .spotify:
            executeAppleScript("tell application \"Spotify\" to previous track")
        case .appleMusic:
            executeAppleScript("tell application \"Music\" to previous track")
        case .unavailable:
            break
        }
    }
}
