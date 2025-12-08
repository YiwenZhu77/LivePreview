//
//  LivePreviewApp.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import SwiftUI
import ScreenCaptureKit
import AppKit

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

struct HotkeyConfig {
    let keyCode: UInt16
    let modifierFlags: NSEvent.ModifierFlags
    
    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
    
    static let `default` = HotkeyConfig(keyCode: 35, modifierFlags: [.control, .command]) // Control+Command+P
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var globalMonitor: Any?
    var hotkeyCaptureMonitor: Any?
    var hotkeyLocalCaptureMonitor: Any?
    private var setShortcutMenuItem: NSMenuItem?
    var activePiPControllers: [PiPWindowController] = []
    private var activePiPByWindowID: [UInt32: PiPWindowController] = [:]
    private let hotkeyDefaultsKey = "livepreview.customHotkey"
    private var hotkeyConfig: HotkeyConfig = .default
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "pip", accessibilityDescription: "LivePreview")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Current Window", action: #selector(triggerCapture), keyEquivalent: ""))
        let shortcutItem = NSMenuItem(title: "Set Shortcut…", action: #selector(promptHotkeyCapture), keyEquivalent: "")
        setShortcutMenuItem = shortcutItem
        menu.addItem(shortcutItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        Task { await requestScreenCapturePermission() }
        loadHotkeyConfig()
        updateShortcutMenuTitle()
        setupGlobalHotkey()
    }
    
    func setupGlobalHotkey() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        guard trusted else { return }
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            if event.isARepeat { return } // 避免长按触发二次事件
            if self.matchesHotkey(event: event, config: self.hotkeyConfig) {
                self.triggerCapture()
            }
        }
    }
    
    @objc func triggerCapture() {
        Task {
            guard let frontWindow = await frontmostWindow() else { return }
            let windowID = frontWindow.windowID
            if let controller = activePiPByWindowID[windowID] {
                await MainActor.run { controller.close() } // 主线程关闭，避免仅停流导致空白窗
                return
            }
            await createPiP(for: frontWindow)
        }
    }
    
    func createPiP(for window: SCWindow) async {
        await MainActor.run {
            let captureManager = WindowCaptureManager()
            let controller = PiPWindowController(captureManager: captureManager, sourceWindow: window)

            controller.onClose = { [weak self, weak controller] in
                guard let self, let controller else { return }
                self.activePiPControllers.removeAll { $0 === controller }
                self.activePiPByWindowID.removeValue(forKey: window.windowID)
            }
            activePiPControllers.append(controller)
            activePiPByWindowID[window.windowID] = controller
            controller.showWindow(nil)
            Task { await captureManager.startCapture(window: window, showWindow: false) }
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

    /// 获取当前前台应用的最合适窗口（同标题去重取最大），用于热键触发。
    private func frontmostWindow() async -> SCWindow? {
        do {
            let workspace = NSWorkspace.shared
            guard let frontmostApp = workspace.frontmostApplication else { return nil }
            let appPID = frontmostApp.processIdentifier
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            let appWindows = content.windows.filter {
                guard let title = $0.title, !title.isEmpty else { return false }
                return $0.owningApplication?.processID == appPID
            }
            let grouped = Dictionary(grouping: appWindows, by: { $0.title ?? "" })
            let unique = grouped.compactMap { (_, windows) -> SCWindow? in
                windows.max(by: { w1, w2 in
                    w1.frame.width * w1.frame.height < w2.frame.width * w2.frame.height
                })
            }
            return unique.max(by: { w1, w2 in
                w1.frame.width * w1.frame.height < w2.frame.width * w2.frame.height
            })
        } catch {
            return nil
        }
    }

    // MARK: - Hotkey helpers

    private func loadHotkeyConfig() {
        if let data = UserDefaults.standard.data(forKey: hotkeyDefaultsKey),
           let decoded = try? JSONDecoder().decode(HotkeyConfigDTO.self, from: data) {
            hotkeyConfig = decoded.toConfig()
        }
    }

    private func saveHotkeyConfig(_ config: HotkeyConfig) {
        hotkeyConfig = config
        if let data = try? JSONEncoder().encode(HotkeyConfigDTO(from: config)) {
            UserDefaults.standard.set(data, forKey: hotkeyDefaultsKey)
        }
        updateShortcutMenuTitle()
        setupGlobalHotkey()
    }

    private func matchesHotkey(event: NSEvent, config: HotkeyConfig) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        return event.keyCode == config.keyCode && flags == config.modifierFlags
    }

    @objc private func promptHotkeyCapture() {
        // 进入捕获模式：下一次按键将设为新的快捷键
        if hotkeyCaptureMonitor != nil { return }
        hotkeyCaptureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            // 至少需要一个修饰键
            guard !flags.isEmpty else { self.stopHotkeyCapture(); return }
            let newConfig = HotkeyConfig(keyCode: event.keyCode, modifierFlags: flags)
            self.saveHotkeyConfig(newConfig)
            self.stopHotkeyCapture()
        }
        // 同时添加本地监控防止事件遗漏
        hotkeyLocalCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            guard !flags.isEmpty else { self.stopHotkeyCapture(); return event }
            let newConfig = HotkeyConfig(keyCode: event.keyCode, modifierFlags: flags)
            self.saveHotkeyConfig(newConfig)
            self.stopHotkeyCapture()
            return nil // swallows the event to avoid side effects
        }
    }

    private func stopHotkeyCapture() {
        if let monitor = hotkeyCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyCaptureMonitor = nil
        }
        if let monitor = hotkeyLocalCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyLocalCaptureMonitor = nil
        }
    }

    private func closeAllPiP() {
        // 先关闭已跟踪的控制器
        activePiPControllers.forEach { $0.close() }
        // 再兜底关闭当前存在的 PiPPanel 窗口，防止数组未跟踪导致留存空窗
        NSApp.windows
            .compactMap { $0 as? PiPPanel }
            .forEach { $0.close() }
        activePiPControllers.removeAll()
        activePiPByWindowID.removeAll()
    }

    private func hasAnyPiPWindow() -> Bool {
        if !activePiPControllers.isEmpty { return true }
        return NSApp.windows.contains { $0 is PiPPanel }
    }

    // DTO 用于持久化 NSEvent.ModifierFlags
    private struct HotkeyConfigDTO: Codable {
        let keyCode: UInt16
        let modifierRawValue: UInt

        init(from config: HotkeyConfig) {
            self.keyCode = config.keyCode
            self.modifierRawValue = config.modifierFlags.rawValue
        }

        func toConfig() -> HotkeyConfig {
            HotkeyConfig(keyCode: keyCode, modifierFlags: NSEvent.ModifierFlags(rawValue: modifierRawValue))
        }
    }

    private func updateShortcutMenuTitle() {
        let display = hotkeyDisplayString(hotkeyConfig)
        setShortcutMenuItem?.title = "Set Shortcut… (\(display))"
    }

    private func hotkeyDisplayString(_ config: HotkeyConfig) -> String {
        var parts: [String] = []
        if config.modifierFlags.contains(.control) { parts.append("⌃") }
        if config.modifierFlags.contains(.option) { parts.append("⌥") }
        if config.modifierFlags.contains(.shift) { parts.append("⇧") }
        if config.modifierFlags.contains(.command) { parts.append("⌘") }
        parts.append(keyName(from: config.keyCode))
        return parts.joined(separator: "")
    }

    private func keyName(from keyCode: UInt16) -> String {
        let mapping: [UInt16: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J",
            40: "K", 37: "L", 46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S",
            17: "T", 32: "U", 9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0"
        ]
        return mapping[keyCode] ?? "#\(keyCode)"
    }
}
