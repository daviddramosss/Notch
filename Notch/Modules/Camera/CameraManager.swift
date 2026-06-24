import AVFoundation
import SwiftUI
import Combine

class CameraManager: ObservableObject, NotchWidget {
    
    var id: WidgetID { .camera }
    var title: String { "Espejo (Cámara)" }
    var requiresPermission: Bool { true }
    
    @Published var isEnabled: Bool = true
    @Published var permissionGranted: Bool = false
    @Published var isRunning: Bool = false
    
    let session = AVCaptureSession()
    private let cameraQueue = DispatchQueue(label: "com.notchpanel.cameraQueue")
    
    //Para no intentar enchufar la cámara dos veces
    private var isConfigured = false
    
    func activate() {}
    func deactivate() { stopSession() }
    
    func makeView() -> some View {
        CameraView().environmentObject(self)
    }
    
    func startSession() {
        let status = PermissionsManager.shared.camera
        
        switch status {
        case .granted:
            self.permissionGranted = true
            self.setupAndStart()
        case .denied:
            self.permissionGranted = false
        case .notDetermined:
            // No debería llegar aquí si runStartupSequence() ya corrió,
            // pero por defensividad pedimos
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.permissionGranted = granted
                    if granted { self.setupAndStart() }
                }
            }
        }
    }

    private func setupAndStart() {
        cameraQueue.async {
            // 1. Enchu cables SOLO si no se ha hecho antes
            if !self.isConfigured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .low
                
                if let videoDevice = AVCaptureDevice.default(for: .video),
                   let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                   self.session.canAddInput(videoInput) {
                    self.session.addInput(videoInput)
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            
            // 2. Enciende el motor
            if !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.isRunning = true }
            }
        }
    }
    
    func stopSession() {
        cameraQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isRunning = false }
            }
        }
    }
}
