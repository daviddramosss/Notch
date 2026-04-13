/*
 Cerebro de la Bandeja (Versión Real).
 Extrae la ruta, el nombre y el icono nativo del archivo arrastrado.
 Provee la función para compartir nativamente vía AirDrop.
*/

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

// Estructura para el bolsillo (Files Tray)
struct DroppedItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let icon: NSImage
}

class DropzoneManager: ObservableObject {
    static let shared = DropzoneManager()
    
    // Lista para el bolsillo (Files Tray)
    @Published var items: [DroppedItem] = []
    
    //Maneja el soltar en el "Bolsillo" (Files Tray)
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { nsurl, error in
                    guard let url = nsurl as? URL else { return }
                    
                    // Extraemos los datos reales del archivo
                    let title = url.lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    
                    DispatchQueue.main.async {
                        // Evitamos duplicados
                        if !self.items.contains(where: { $0.url == url }) {
                            self.items.append(DroppedItem(url: url, title: title, icon: icon))
                        }
                    }
                }
                handled = true
            }
        }
        return handled
    }
    
    //Maneja el soltar en "AirDrop"
    func handleAirDrop(providers: [NSItemProvider]) -> Bool {
        // En esta versión, procesamos el primer archivo compatible
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: NSURL.self) {
            _ = provider.loadObject(ofClass: NSURL.self) { nsurl, error in
                guard let url = nsurl as? URL else { return }
                
                //Invocamos el panel de AirDrop 
                DispatchQueue.main.async {
                    // Creamos un servicio de compartir específico para AirDrop
                    if let sharingService = NSSharingService(named: .sendViaAirDrop) {
                        // Pasamos la URL del archivo como ítem a compartir
                        sharingService.perform(withItems: [url])
                    }
                }
            }
            return true
        }
        return false
    }
    
    func clearAll() {
        items.removeAll()
    }
}
