//
//  ContentView.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import SwiftUI

struct ContentView: View {
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
            
            Divider()
                .padding(.vertical, 10)
            
            Text("Press to capture the current window:")
                .font(.headline)
            
            HStack(spacing: 8) {
                Text("⌃")
                    .font(.title)
                    .fontWeight(.bold)
                Text("⌘")
                    .font(.title)
                    .fontWeight(.bold)
                Text("P")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.2))
            .cornerRadius(8)
            
            Text("Control + Command + P")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Will capture the highest resolution window\nfrom the current active app")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
    }
}

#Preview {
    ContentView()
}
