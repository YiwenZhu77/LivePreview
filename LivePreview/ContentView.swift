//
//  ContentView.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var captureManager = WindowCaptureManager()
    @State private var showingWindowPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "pip.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("LivePreview")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Picture-in-Picture for any window")
                .foregroundColor(.secondary)
            
            Button(action: {
                showingWindowPicker = true
            }) {
                Label("Select Window", systemImage: "macwindow")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            
            if captureManager.isCapturing {
                Button(action: {
                    captureManager.stopCapture()
                }) {
                    Label("Stop Capture", systemImage: "stop.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
        .sheet(isPresented: $showingWindowPicker) {
            WindowPicker(captureManager: captureManager, isPresented: $showingWindowPicker)
        }
    }
}

#Preview {
    ContentView()
}
