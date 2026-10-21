// CameraView.swift
// Vista del módulo de cámara: botón circular de previsualización en vivo (Mirror).

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
                
                CameraPreviewView(session: manager.session, isRunning: manager.isRunning)
                    .clipShape(Circle())
                    .opacity((isMirrorActive && manager.isRunning) ? 1 : 0)
                
                if !isMirrorActive || !manager.isRunning {
                    VStack(spacing: 4) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 26))
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

// MARK: - Previsualización Nativa AVFoundation
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
    
    func applyMirrorEffect() {
        if let connection = self.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    let isRunning: Bool
    
    func makeNSView(context: Context) -> VideoPreviewNSView {
        return VideoPreviewNSView(session: session)
    }
    
    func updateNSView(_ nsView: VideoPreviewNSView, context: Context) {
        if isRunning {
            nsView.applyMirrorEffect()
        }
    }
}
