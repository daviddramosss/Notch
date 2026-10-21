// DropzoneManager.swift
// Gestión de elementos arrastrados (drag and drop) y compartición mediante AirDrop.

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Combine

struct DroppedItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let icon: NSImage
}

class DropzoneManager: ObservableObject {
    static let shared = DropzoneManager()
    
    @Published var items: [DroppedItem] = []
    
    func handleDrop(providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSURL.self) {
                _ = provider.loadObject(ofClass: NSURL.self) { nsurl, error in
                    guard let url = nsurl as? URL else { return }
                    
                    let title = url.lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    
                    DispatchQueue.main.async {
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
    
    func handleAirDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        if provider.canLoadObject(ofClass: NSURL.self) {
            _ = provider.loadObject(ofClass: NSURL.self) { nsurl, error in
                guard let url = nsurl as? URL else { return }
                
                DispatchQueue.main.async {
                    if let sharingService = NSSharingService(named: .sendViaAirDrop) {
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
