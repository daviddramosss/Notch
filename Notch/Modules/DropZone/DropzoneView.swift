import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct DropzoneView: View {
    @StateObject private var manager = DropzoneManager.shared
    
    @State private var isTargetedFiles = false
    @State private var isTargetedAirDrop = false
    
    var body: some View {
        HStack(spacing: 20) {
            
            //IZQUIERDA: Files Tray
            DropTargetView(
                isTargeted: $isTargetedFiles,
                isEmpty: manager.items.isEmpty,
                icon: "tray",
                title: "Files Tray",
                subtitle: "(Arrastra Archivos aqui)"
            ) {
                // Solo dibujamos los archivos si hay algo
                if !manager.items.isEmpty {
                    VStack {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(manager.items) { item in
                                    VStack {
                                        Image(nsImage: item.icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                        Text(item.title)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.7))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(width: 60)
                                    }
                                    .foregroundColor(.white)
                                    .onDrag { return NSItemProvider(object: item.url as NSURL) }
                                }
                            }
                        }
                        .frame(height: 60)
                        
                        Button(action: { manager.clearAll() }) {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red.opacity(0.8))
                                .padding(6)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                } else {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            .onDrop(of: [.fileURL], isTargeted: $isTargetedFiles) { providers in
                return manager.handleDrop(providers: providers)
            }
            
            //DERECHA: AirDrop
            DropTargetView(
                isTargeted: $isTargetedAirDrop,
                isEmpty: true, // AirDrop siempre muestra el texto por defecto
                icon: "airplayaudio",
                title: "AirDrop",  
                subtitle: nil
            ) {
                EmptyView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [.fileURL], isTargeted: $isTargetedAirDrop) { providers in
                return manager.handleAirDrop(providers: providers)
            }
            
        }
        .frame(height: 115)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        
    }
}

// MARK: - Componente Reutilizable
struct DropTargetView<Content: View>: View {
    @Binding var isTargeted: Bool
    let isEmpty: Bool
    let icon: String
    let title: String
    let subtitle: String?
    let content: Content
    
    init(isTargeted: Binding<Bool>, isEmpty: Bool, icon: String, title: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self._isTargeted = isTargeted
        self.isEmpty = isEmpty
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).clipShape(RoundedRectangle(cornerRadius: 16))
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isTargeted ? Color.blue : Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1.5, dash: [8, 5])
                )
                .background(isTargeted ? Color.blue.opacity(0.06) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .animation(.easeInOut, value: isTargeted)
            
            // Textos base
            VStack(spacing: 8) {
                if !isTargeted {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(isTargeted ? 0.8 : 0.25))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(isTargeted ? 0.9 : 0.6))
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(isTargeted ? 0.8 : 0.4))
                    }
                } else {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("¡Suelta el archivo aquí!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            .opacity(isTargeted ? 1 : (isEmpty ? 1 : 0))
            
            // Archivos guardados
            content
                .padding()
                .opacity(isTargeted ? 0 : 1)
        }
    }
}
