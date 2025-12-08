//
//  WindowCaptureManager.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import Foundation
import ScreenCaptureKit
import Combine
import AppKit

@MainActor
class WindowCaptureManager: NSObject, ObservableObject {
    @Published var availableWindows: [SCWindow] = []
    @Published var currentFrame: CGImage?
    @Published var isCapturing = false
    @Published var error: String?
    
    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    
    override init() {
        super.init()
    }
    
    // 获取可用窗口列表
    // 获取可用窗口列表
    func refreshAvailableWindows() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            
            // 过滤掉没有标题的窗口和自己的窗口
            let selfPID = ProcessInfo.processInfo.processIdentifier
            
            let filteredWindows = content.windows.filter { window in
                guard let title = window.title, !title.isEmpty else { return false }
                guard window.owningApplication?.processID != selfPID else { return false }
                guard window.frame.width > 100 && window.frame.height > 100 else { return false }
                return true
            }
            
            // 去重：同一应用的相同标题窗口，只保留分辨率最高的
            var windowsByKey: [String: [SCWindow]] = [:]
            
            for window in filteredWindows {
                let appPID = window.owningApplication?.processID ?? 0
                let appName = window.owningApplication?.applicationName ?? ""
                let title = window.title ?? ""
                // 使用应用名称和标题作为key，因为PID在某些情况下可能不同
                let key = "\(appName)|\(title)"
                
                if windowsByKey[key] == nil {
                    windowsByKey[key] = []
                }
                windowsByKey[key]?.append(window)
            }
            
            // 为每个key保留分辨率最高的窗口
            var uniqueWindows: [SCWindow] = []
            for (key, windows) in windowsByKey {
                if windows.count > 1 {
                    NSLog("[DEDUP] Found \(windows.count) windows for key: \(key)")
                    for w in windows {
                        NSLog("[DEDUP]   - Size: \(Int(w.frame.width))×\(Int(w.frame.height))")
                    }
                }
                
                if let maxResolutionWindow = windows.max(by: { w1, w2 in
                    let area1 = w1.frame.width * w1.frame.height
                    let area2 = w2.frame.width * w2.frame.height
                    return area1 < area2
                }) {
                    uniqueWindows.append(maxResolutionWindow)
                    if windows.count > 1 {
                        NSLog("[DEDUP]   → Keeping: \(Int(maxResolutionWindow.frame.width))×\(Int(maxResolutionWindow.frame.height))")
                    }
                }
            }
            
            availableWindows = uniqueWindows.sorted { ($0.title ?? "") < ($1.title ?? "") }
            
        } catch {
            self.error = "Failed to get windows: \(error.localizedDescription)"
        }
    }
    
    // 开始捕获指定窗口
    func startCapture(window: SCWindow, showWindow: Bool = true) async {
        do {
            // 停止现有捕获
            await stopCapture()
            
            // 创建内容过滤器 - 只捕获指定窗口
            let filter = SCContentFilter(desktopIndependentWindow: window)
            
            // 配置流
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width * 2) // Retina
            config.height = Int(window.frame.height * 2)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
            config.queueDepth = 5
            config.showsCursor = true
            config.capturesAudio = false
            
            // 创建流输出处理器
            streamOutput = CaptureStreamOutput { [weak self] frame in
                Task { @MainActor in
                    self?.currentFrame = frame
                }
            }
            
            // 创建并启动流
            stream = SCStream(filter: filter, configuration: config, delegate: nil)
            
            try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            
            try await stream?.startCapture()
            
            isCapturing = true
            error = nil
            
            // 打开 PiP 窗口（可选，AppDelegate 已创建窗口时传 showWindow=false）
            if showWindow {
                openPiPWindow(for: window)
            }
            
        } catch {
            self.error = "Failed to start capture: \(error.localizedDescription)"
            isCapturing = false
        }
    }
    
    // 停止捕获
    func stopCapture() async {
        guard let stream = stream else { return }
        
        do {
            try await stream.stopCapture()
        } catch {
            print("Error stopping capture: \(error)")
        }
        
        self.stream = nil
        self.streamOutput = nil
        self.isCapturing = false
        self.currentFrame = nil
    }
    
    // 同步版本的停止捕获
    func stopCapture() {
        Task {
            await stopCapture()
        }
    }
    
    private func openPiPWindow(for window: SCWindow) {
        let pipController = PiPWindowController(captureManager: self, sourceWindow: window)
        pipController.showWindow(nil)
    }
}

// 流输出处理器
class CaptureStreamOutput: NSObject, SCStreamOutput {
    private let frameHandler: (CGImage) -> Void
    
    init(frameHandler: @escaping (CGImage) -> Void) {
        self.frameHandler = frameHandler
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        guard let imageBuffer = sampleBuffer.imageBuffer else { return }
        
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        frameHandler(cgImage)
    }
}
