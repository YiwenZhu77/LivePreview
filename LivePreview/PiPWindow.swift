//
//  PiPWindow.swift
//  LivePreview
//
//  Created by Yiwen on 2024/12/04.
//

import AppKit
import SwiftUI
import ScreenCaptureKit

// PiP 窗口控制器
class PiPWindowController: NSWindowController {
    private var captureManager: WindowCaptureManager?
    private var sourceWindow: SCWindow?
    
    convenience init() {
        let window = PiPPanel(
            contentRect: NSRect(x: 100, y: 100, width: 400, height: 300),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        setupWindow()
    }
    
    convenience init(captureManager: WindowCaptureManager, sourceWindow: SCWindow) {
        let aspectRatio = sourceWindow.frame.width / sourceWindow.frame.height
        let width: CGFloat = 400
        let height = width / aspectRatio
        
        let window = PiPPanel(
            contentRect: NSRect(x: 100, y: 100, width: width, height: height),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
        self.captureManager = captureManager
        self.sourceWindow = sourceWindow
        setupWindow()
        setupContentView()
    }
    
    private func setupWindow() {
        guard let window = window as? PiPPanel else { return }
        
        // 窗口配置
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.acceptsMouseMovedEvents = true
        
        // 保持宽高比
        if let sourceWindow = sourceWindow {
            window.aspectRatio = NSSize(width: sourceWindow.frame.width, height: sourceWindow.frame.height)
        }
        
        // 设置最小尺寸
        window.minSize = NSSize(width: 200, height: 150)
        
        // 初始位置 - 右下角
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let windowRect = window.frame
            let x = screenRect.maxX - windowRect.width - 20
            let y = screenRect.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    private func setupContentView() {
        guard let captureManager = captureManager else { return }
        
        let contentView = PiPContentView(captureManager: captureManager) { [weak self] in
            self?.close()
        }
        
        window?.contentView = NSHostingView(rootView: contentView)
    }
    
    override func close() {
        captureManager?.stopCapture()
        super.close()
    }
}

// 自定义 Panel - 支持始终置顶
class PiPPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    private var isPinned = true
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        
        // 让窗口成为浮动面板
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
    }
    
    func togglePin() {
        isPinned.toggle()
        level = isPinned ? .floating : .normal
    }
}

// PiP 内容视图
struct PiPContentView: View {
    @ObservedObject var captureManager: WindowCaptureManager
    let onClose: () -> Void
    
    @State private var isHovering = false
    @State private var opacity: Double = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 捕获的画面
                if let frame = captureManager.currentFrame {
                    Image(decorative: frame, scale: 2.0)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.5)
                        )
                }
                
                // 控制按钮 - 悬停时显示
                if isHovering {
                    VStack {
                        HStack {
                            Spacer()
                            
                            // 关闭按钮
                            Button(action: onClose) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .buttonStyle(.plain)
                            .padding(8)
                        }
                        
                        Spacer()
                        
                        // 底部控制栏
                        HStack {
                            // 透明度滑块
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundColor(.white)
                            Slider(value: $opacity, in: 0.3...1.0)
                                .frame(width: 80)
                            
                            Spacer()
                            
                            // Pin 按钮
                            Button(action: {
                                if let window = NSApp.windows.first(where: { $0 is PiPPanel }) as? PiPPanel {
                                    window.togglePin()
                                }
                            }) {
                                Image(systemName: "pin.fill")
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                    }
                    .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .opacity(opacity)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}
