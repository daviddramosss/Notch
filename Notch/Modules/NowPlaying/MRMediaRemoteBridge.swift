import Foundation

// Los comandos numéricos secretos
enum MRCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

// Las llaves del diccionario para extraer los datos de la canción
enum MRKey {
    static let title = "kMRMediaRemoteNowPlayingInfoTitle"
    static let artist = "kMRMediaRemoteNowPlayingInfoArtist"
    static let album = "kMRMediaRemoteNowPlayingInfoAlbum"
    static let artworkData = "kMRMediaRemoteNowPlayingInfoArtworkData"
    static let playbackRate = "kMRMediaRemoteNowPlayingInfoPlaybackRate"
    static let duration = "kMRMediaRemoteNowPlayingInfoDuration"
    static let elapsedTime = "kMRMediaRemoteNowPlayingInfoElapsedTime"
}

// Firmas corregidas de C puro (Usando NSDictionary en lugar de diccionarios de Swift)
typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, NSDictionary?) -> Bool

class MRMediaRemoteBridge {
    static let shared = MRMediaRemoteBridge()
    
    private var _getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var _sendCommand: MRMediaRemoteSendCommandFunction?
    
    private init() {
        // Cargar la librería "a la fuerza bruta" con C puro
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        
        // dlopen salta restricciones que CFBundle no puede
        guard let handle = dlopen(path, RTLD_NOW) else {
            print("❌ Error: No se pudo cargar MediaRemote vía dlopen")
            return
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            _getNowPlayingInfo = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            _sendCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
        }
        
        print(_getNowPlayingInfo != nil ? "✅ MediaRemote Bridge inyectado con éxito" : "❌ Fallo en el Bridge")
    }
    
    // Función pública protegida para pedir los datos
    func fetchNowPlaying(completion: @escaping ([String: Any]?) -> Void) {
        guard let fn = _getNowPlayingInfo else {
            completion(nil)
            return
        }
        
        // Pedimos a Apple el NSDictionary, y lo traducimos a [String: Any] para nuestro Manager
        fn(DispatchQueue.main) { dict in
            completion(dict as? [String: Any])
        }
    }
    
    // Función pública para enviar comandos
    func send(_ command: MRCommand) -> Bool {
        guard let fn = _sendCommand else { return false }
        return fn(command.rawValue, nil)
    }
}
