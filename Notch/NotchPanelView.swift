import SwiftUI

struct NotchPanelView: View {
    @EnvironmentObject var viewModel: PanelViewModel

    var body: some View {
        ZStack(alignment: .top) {
            // Fondo negro que se adapta al estado
            Color.black
                .clipShape(RoundedRectangle(cornerRadius: viewModel.isExpanded ? 16 : 12))
            
            if viewModel.isExpanded {
                expandedContent
                    // Transición combinada: aparece y baja ligeramente
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // ESTAS DOS LÍNEAS SOLUCIONAN LA PELEA:
        // Le obligamos a medir 300px si está expandido, y 32px si está cerrado.
        .frame(height: viewModel.isExpanded ? viewModel.expandedHeight : viewModel.collapsedHeight)
        .ignoresSafeArea()
        // Esta animación asegura que el cambio de color/forma sea fluido
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: viewModel.isExpanded)
    }

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Este espacio "ciego" es vital: reserva el lugar donde está el notch físico
            Color.clear.frame(height: viewModel.collapsedHeight)
            
            VStack {
                Text("¡El Notch funciona!")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Fase 1 completada")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.top, 10)
            
            Spacer()
        }
    }
}

