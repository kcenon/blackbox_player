//
//  ContentView.swift
//  BlackboxPlayer
//
//  Main application view
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "video.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
                .font(.system(size: 72))

            Text("BlackboxPlayer")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)

            Text("macOS Dashcam Video Player")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Text("Phase 0: Preparation Complete")
                .font(.subheadline)
                .foregroundColor(.green)
                .padding(.top, 20)
        }
        .padding()
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}
