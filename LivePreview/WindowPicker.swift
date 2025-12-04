//
//  WindowPicker.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import SwiftUI
import ScreenCaptureKit

struct WindowPicker: View {
    @ObservedObject var captureManager: WindowCaptureManager
    @Binding var isPresented: Bool
    @State private var selectedWindow: SCWindow?
    @State private var isLoading = true
    @State private var searchText = ""
    
    var filteredWindows: [SCWindow] {
        if searchText.isEmpty {
            return captureManager.availableWindows
        }
        return captureManager.availableWindows.filter { window in
            let title = window.title?.lowercased() ?? ""
            let appName = window.owningApplication?.applicationName.lowercased() ?? ""
            let search = searchText.lowercased()
            return title.contains(search) || appName.contains(search)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("Select a Window")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search windows...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // 窗口列表
            if isLoading {
                Spacer()
                ProgressView("Loading windows...")
                Spacer()
            } else if filteredWindows.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "macwindow.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No windows found")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredWindows, id: \.windowID) { window in
                            WindowRow(
                                window: window,
                                isSelected: selectedWindow?.windowID == window.windowID
                            )
                            .onTapGesture {
                                selectedWindow = window
                            }
                            .onTapGesture(count: 2) {
                                startCapture(window: window)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
            
            // 底部按钮
            HStack {
                Button("Refresh") {
                    Task {
                        isLoading = true
                        await captureManager.refreshAvailableWindows()
                        isLoading = false
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Button("Start PiP") {
                    if let window = selectedWindow {
                        startCapture(window: window)
                    }
                }
                .keyboardShortcut(.return)
                .disabled(selectedWindow == nil)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .task {
            await captureManager.refreshAvailableWindows()
            isLoading = false
        }
    }
    
    private func startCapture(window: SCWindow) {
        Task {
            await captureManager.startCapture(window: window)
            isPresented = false
        }
    }
}

struct WindowRow: View {
    let window: SCWindow
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 应用图标
            if let app = window.owningApplication,
               let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 24))
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }
            
            // 窗口信息
            VStack(alignment: .leading, spacing: 2) {
                Text(window.title ?? "Untitled")
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                
                Text(window.owningApplication?.applicationName ?? "Unknown App")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 窗口尺寸
            Text("\(Int(window.frame.width))×\(Int(window.frame.height))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
    }
}

#Preview {
    WindowPicker(captureManager: WindowCaptureManager(), isPresented: .constant(true))
}
