/*
 Dibuja el botón circular "Mirror".
 Usa un NSView personalizado con "layout()" para obligar al vídeo
 a rellenar el círculo y evitar la pantalla negra.
*/

import SwiftUI
import AVFoundation

struct CameraView: View {
    @EnvironmentObject var manager: CameraManager
    @State private var isMirrorActive = false
    
    var body: some View {
        Button {
            withAnimation(.spring()) {
                isMirrorActive.toggle()
                if isMirrorActive {
                    manager.startSession()
                } else {
                    manager.stopSession()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(white: 0.12))
                
                // La pantalla NUNCA se destruye para que no haya crash.
                // Le pasamos "isRunning" para que sepa cuándo aplicar el efecto espejo.
                CameraPreviewView(session: manager.session, isRunning: manager.isRunning)
                    .clipShape(Circle())
                    // Si apagamos el botón, la hacemos invisible
                    .opacity((isMirrorActive && manager.isRunning) ? 1 : 0)
                
                // Textos e icono por encima cuando está apagado
                if !isMirrorActive || !manager.isRunning {
                    VStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 26)) //hago la camara un poco mas grande
                        Text("Mirror")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 92, height: 92)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - El Puente Nativo
class VideoPreviewNSView: NSView {
    var previewLayer: AVCaptureVideoPreviewLayer
    
    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        self.wantsLayer = true
        self.previewLayer.videoGravity = .resizeAspectFill
        self.layer?.addSublayer(self.previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func layout() {
        super.layout()
        self.previewLayer.frame = self.bounds
    }
    
    // Función manual que llamamos solo cuando sabemos que es seguro
    func applyMirrorEffect() {
        if let connection = self.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let isRunning: Bool // SwiftUI vigilará esta variable
    
    func makeNSView(context: Context) -> VideoPreviewNSView {
        return VideoPreviewNSView(session: session)
    }
    
    func updateNSView(_ nsView: VideoPreviewNSView, context: Context) {
        // Cuando el motor confirme que está encendido, aplicamos el espejo
        if isRunning {
            nsView.applyMirrorEffect()
        }
    }
}
