/*
 El Cerebro de la ventana. Guarda el estado reactivo (isExpanded)
 y define el tamaño de la caja física de macOS en la pantalla.
 */

import SwiftUI
import Combine

class PanelViewModel: ObservableObject {
    
    @Published var isExpanded: Bool = false
    
    var collapsedHeight: CGFloat = 32
    var collapsedWidth: CGFloat = 200
    
    //ANCHO FIJO: Para que la ventana se centre siempre respecto a la cámara del Mac
    var dynamicExpandedWidth: CGFloat {
        return 720
    }
    
    //ALTO DINÁMICO: Lo lee directamente del deslizador en tu ventana de Ajustes
    var dynamicExpandedHeight: CGFloat {
        return CGFloat(AppSettings.shared.expandedHeight)
    }
}
