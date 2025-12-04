//
//  LivePreviewApp.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import SwiftUI
import ScreenCaptureKit

@main
struct LivePreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        
        Settings {
            Text("Settings")
                .padding()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pip", accessibilityDescription: "LivePreview")
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New PiP Window", action: #selector(newPiPWindow), keyEquivalent: "n"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
        
        // 请求屏幕录制权限
        Task {
            await requestScreenCapturePermission()
        }
    }
    
    @objc func newPiPWindow() {
        let controller = PiPWindowController()
        controller.showWindow(nil)
    }
    
    func requestScreenCapturePermission() async {
        do {
            // 这会触发权限请求
            let _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        } catch {
            print("Screen capture permission error: \(error)")
        }
    }
}
