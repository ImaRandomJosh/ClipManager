import SwiftUI
import AppKit
import Carbon

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

    func getDefaultRect() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1000, height: 1000)

        let panelWidth: CGFloat = 320
        let panelHeight: CGFloat = 420

        return NSRect(
            x: screenFrame.maxX - panelWidth - 20,
            y: screenFrame.minY + 20,
            width: panelWidth,
            height: panelHeight
        )
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

        setupBulletproofShortcut()
    }

    @objc
    func togglePanelClicked() {
        togglePanel()
    }

    func setupBulletproofShortcut() {
        let modifierFlags = UInt32(cmdKey | controlKey)
        let keyCode = UInt32(8) // C key

        var localHotKeyRef: EventHotKeyRef?
        var hotKeyID = EventHotKeyID(signature: OSType(1), id: UInt32(1))

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

    func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
        }
    }
}
