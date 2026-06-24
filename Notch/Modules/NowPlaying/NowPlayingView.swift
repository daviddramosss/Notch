/*
 Muestra la interfaz de reproducción de música.
 Diseño: Carátula grande a la izquierda. A la derecha, una columna
 con dos filas: arriba (Título/Artista + Controles) y abajo (Slider de tiempo).
 */
import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var manager: NowPlayingManager
    @ObservedObject var settings = AppSettings.shared
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            
            if settings.nowPlayingShowArtwork {
                artworkView
            }
            
            VStack(spacing: 8) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(manager.songTitle.isEmpty ? "Sin reproducción" : manager.songTitle)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8) // Permite que la letra encoja un 20% si no cabe
                        
                        Text(manager.artist.isEmpty ? "NotchPanel" : manager.artist)
                            .foregroundColor(.white.opacity(0.6))
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading) // Empuja los botones a la derecha
                    
                    if settings.nowPlayingShowControls {
                        HStack(spacing: 8) {
                            Button(action: manager.skipPrevious) {
                                Image(systemName: "backward.fill").font(.system(size: 14))
                            }
                            
                            Button(action: manager.togglePlayPause) {
                                Image(systemName: manager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14))
                                    .frame(width: 30, height: 30)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                            }
                            
                            Button(action: manager.skipNext) {
                                Image(systemName: "forward.fill").font(.system(size: 14))
                            }
                        }
                        .foregroundColor(.white)
                        .buttonStyle(.plain)
                        // [FIX-2] Desactiva controles si no hay reproductor nativo
                        .opacity(manager.canControlPlayback ? 1.0 : 0.3)
                        .allowsHitTesting(manager.canControlPlayback)
                    }
                }
                
                if settings.nowPlayingShowProgress {
                    HStack(spacing: 8) {
                        Text(formatTime(manager.elapsed))
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 10, design: .monospaced))
                        
                        Slider(value: Binding(
                            get: { manager.elapsed },
                            set: { newValue in
                                manager.isDraggingSlider = true
                                manager.elapsed = newValue
                            }
                        ), in: 0...max(1, manager.duration), onEditingChanged: { editingStarted in
                            if !editingStarted {
                                manager.seekTo(seconds: manager.elapsed)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    manager.isDraggingSlider = false
                                }
                            }
                        })
                        .controlSize(.mini)
                        .accentColor(.white)
                        
                        Text(formatTime(manager.duration))
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 10, design: .monospaced))
                    }
                }
            }
            .frame(maxWidth: .infinity) // La columna derecha ocupa todo lo que sobra
        }
        .frame(maxWidth: .infinity, alignment: .leading) // La vista entera ocupa el espacio matemático
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private var artworkView: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let artwork = manager.artwork {
                    Image(nsImage: artwork).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color(white: 0.15)
                        Image(systemName: "music.note.list").foregroundColor(Color(white: 0.3)).font(.system(size: 24))
                    }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            sourceAppIcon.offset(x: 6, y: 6)
        }
    }
    
    @ViewBuilder
    private var sourceAppIcon: some View {
        switch manager.source {
        case .appleMusic:
            ZStack {
                Circle().fill(.black).frame(width: 22, height: 22)
                Image(systemName: "applelogo").foregroundColor(.white).font(.system(size: 12))
            }
        case .spotify:
            ZStack {
                Circle().fill(.black).frame(width: 22, height: 22)
                Image("spotifyLogo").resizable().scaledToFit().frame(width: 16, height: 16)
            }
        default: EmptyView()
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 && !seconds.isNaN else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
