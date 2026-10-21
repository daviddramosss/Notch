// MRMediaRemoteBridge.swift
// Puente dinámico en C para invocar funciones privadas de MediaRemote.framework vía dlopen/dlsym.

import Foundation

enum MRCommand: UInt32 {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
}

typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping (NSDictionary?) -> Void) -> Void
typealias MRMediaRemoteSendCommandFunction = @convention(c) (UInt32, NSDictionary?) -> Bool

class MRMediaRemoteBridge {
    static let shared = MRMediaRemoteBridge()
    
    private var _getNowPlayingInfo: MRMediaRemoteGetNowPlayingInfoFunction?
    private var _sendCommand: MRMediaRemoteSendCommandFunction?
    
    private init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
        
        guard let handle = dlopen(path, RTLD_NOW) else {
            return
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") {
            _getNowPlayingInfo = unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
        
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            _sendCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
        }
    }
    
    func fetchNowPlaying(completion: @escaping ([String: Any]?) -> Void) {
        guard let fn = _getNowPlayingInfo else {
            completion(nil)
            return
        }
        
        fn(DispatchQueue.main) { dict in
            completion(dict as? [String: Any])
        }
    }
    
    func send(_ command: MRCommand) -> Bool {
        guard let fn = _sendCommand else { return false }
        return fn(command.rawValue, nil)
    }
}
