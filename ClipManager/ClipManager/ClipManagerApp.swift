import SwiftUI
import AppKit
import Carbon
import Combine

@main
struct ClipManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.clipboardManager)
                .environmentObject(appDelegate.settings)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardManager = ClipboardManager()
    let settings = AppSettings.shared

    var panel: NSPanel!
    var statusItem: NSStatusItem!
    var hotKeyRef: EventHotKeyRef?
    var cancellables = Set<AnyCancellable>()

    func getDefaultRect() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1000, height: 1000)

        let panelWidth = settings.scaledPanelWidth
        let panelHeight = settings.scaledPanelHeight
        let margin: CGFloat = 20

        return NSRect(
            x: screenFrame.maxX - panelWidth - margin,
            y: screenFrame.minY + margin,
            width: panelWidth,
            height: panelHeight
        )
    }
    
    func updatePanelScale(animated: Bool = true) {
        guard panel != nil else { return }

        let screenFrame = panel.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1000, height: 1000)

        let newWidth = settings.scaledPanelWidth
        let newHeight = settings.scaledPanelHeight
        let margin: CGFloat = 20

        let newFrame = NSRect(
            x: screenFrame.maxX - newWidth - margin,
            y: screenFrame.minY + margin,
            width: newWidth,
            height: newHeight
        )

        panel.setFrame(newFrame, display: true, animate: animated)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NSPanel(
            contentRect: getDefaultRect(),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.setFrameAutosaveName("ClipboardPanelPosition")
        panel.contentView = NSHostingView(
            rootView: ContentView()
                .environmentObject(clipboardManager)
                .environmentObject(settings)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Clipboard Manager"
            )
            button.target = self
            button.action = #selector(togglePanelClicked)
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ResetPosition"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.panel.setFrame(self.getDefaultRect(), display: true, animate: true)
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("TogglePanel"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.togglePanel()
        }
        
        settings.$overlayScale
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updatePanelScale()
            }
            .store(in: &cancellables)

        applyDockVisibility()

        settings.$hideFromDock
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyDockVisibility()
            }
            .store(in: &cancellables)

        setupBulletproofShortcut()
    }

    @objc
    func togglePanelClicked() {
        togglePanel()
    }

    func setupBulletproofShortcut() {
        let modifierFlags = UInt32(cmdKey | controlKey)
        let keyCode = UInt32(8)

        var localHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(1), id: UInt32(1))

        RegisterEventHotKey(
            keyCode,
            modifierFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &localHotKeyRef
        )

        hotKeyRef = localHotKeyRef

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in
                NotificationCenter.default.post(
                    name: NSNotification.Name("TogglePanel"),
                    object: nil
                )
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }

    func applyDockVisibility() {
        if settings.hideFromDock {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }
}
