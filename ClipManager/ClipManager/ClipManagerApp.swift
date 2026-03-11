import SwiftUI
import AppKit
import Carbon // NEW: Apple's deep system framework for global hotkeys!

@main
struct ClipManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NSPanel!
    var statusItem: NSStatusItem!
    
    func getDefaultRect() -> NSRect {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1000, height: 1000)
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
        panel.contentView = NSHostingView(rootView: ContentView())
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipboard Manager")
            button.action = #selector(togglePanelClicked)
        }
        
        // Listens for the Reset Button
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ResetPosition"), object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.panel.setFrame(self.getDefaultRect(), display: true, animate: true)
        }
        
        // NEW: Listens for our new Carbon Hotkey
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TogglePanel"), object: nil, queue: .main) { [weak self] _ in
            self?.togglePanel()
        }
        
        setupBulletproofShortcut()
    }
    
    @objc func togglePanelClicked() {
        togglePanel()
    }
    
    // THE UPGRADE: A true, professional Carbon Global Hotkey
    func setupBulletproofShortcut() {
        // 1. Define Control + Command + C
        let modifierFlags = UInt32(cmdKey | controlKey)
        let keyCode = UInt32(8) // 8 is the keycode for 'C'
        
        // 2. Register the hotkey directly with the macOS kernel
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(1), id: UInt32(1))
        RegisterEventHotKey(keyCode, modifierFlags, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        
        // 3. Tell macOS to shout out to our app when it hears the shortcut
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(GetApplicationEventTarget(), { (_, _, _) -> OSStatus in
            // This safely triggers the TogglePanel notification we set up above!
            NotificationCenter.default.post(name: NSNotification.Name("TogglePanel"), object: nil)
            return noErr
        }, 1, &eventType, nil, nil)
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
