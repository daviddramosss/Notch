//
//  ContentView.swift
//  Notch
//
//  Created by David Ramos on 04/04/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        Rectangle()
                    .fill(Color.black)
                    .frame(width: 200, height: 50)
                    .clipShape(.rect(bottomLeadingRadius: 12, bottomTrailingRadius: 12))
                    .ignoresSafeArea()
            }
}

#Preview {
    ContentView()
}

