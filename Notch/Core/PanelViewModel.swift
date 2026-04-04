//
//  PanelViewModel.swift
//  Notch
//
//  Created by David Ramos on 04/04/2026.
//

/*
 
 Haremos un archivo nuevo que guardará una simple variable: isExpanded (Verdadero o Falso).
 Por qué: SwiftUI es reactivo.Necesitamos un "interruptor" central.
 Si el interruptor está en Verdadero, la vista dibuja el panel grande. Si está en Falso, dibuja el panel pequeño.
 
 */

import SwiftUI
import Combine

// ObservableObject permite que SwiftUI "escuche" los cambios de esta clase
class PanelViewModel: ObservableObject {
    
    // @Published avisa automáticamente a la interfaz cuando cambia el valor
    // Inicia en "false" (el panel empieza cerrado)
    @Published var isExpanded: Bool = false
    
    // Altura del panel cuando pasemos el ratón
    @Published var expandedHeight: CGFloat = 300
    
    // Guardaremos aquí la altura del notch físico para no perderla
    var collapsedHeight: CGFloat = 32
}
