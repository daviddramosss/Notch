import SwiftUI
import Combine

class PanelViewModel: ObservableObject {
    
    @Published var isExpanded: Bool = false
    @Published var isMenuOrPopoverOpen: Bool = false
    
    var collapsedHeight: CGFloat = 32
    var collapsedWidth: CGFloat = 200
    
    var dynamicExpandedWidth: CGFloat {
        return 720
    }
    
    var dynamicExpandedHeight: CGFloat {
        return CGFloat(AppSettings.shared.expandedHeight)
    }
}
