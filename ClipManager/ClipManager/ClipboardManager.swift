import SwiftUI
import AppKit
import ServiceManagement

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String?
    let image: NSImage?

    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if let lt = lhs.text, let rt = rhs.text {
            return lt == rt
        }

        if let li = lhs.image, let ri = rhs.image {
            return li.tiffRepresentation == ri.tiffRepresentation
        }

        return false
    }
}

@MainActor
final class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    @Published var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled

    private let settings = AppSettings.shared
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
        startMonitoring()
    }

    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForChanges()
            }
        }
    }

    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            let newItem = ClipboardItem(text: nil, image: image)
            addItem(newItem)
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            let newItem = ClipboardItem(text: text, image: nil)
            addItem(newItem)
        }
    }

    private func addItem(_ item: ClipboardItem) {
        history.removeAll { $0 == item }
        history.insert(item, at: 0)

        if history.count > settings.historyLimit {
            history.removeLast()
        }
    }

    func copyToClipboard(item: ClipboardItem) {
        pasteboard.clearContents()

        if let text = item.text {
            pasteboard.setString(text, forType: .string)
        } else if let image = item.image {
            pasteboard.writeObjects([image])
        }
    }

    func clearHistory() {
        history.removeAll()
        pasteboard.clearContents()
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }

            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } catch {
            print("Startup error: \(error)")
        }
    }
}
