import Foundation
import AppKit

// A new data structure that can hold EITHER text or an image
struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String?
    let image: NSImage?
    
    // This tells the app how to avoid duplicate entries
    static func == (lhs: ClipboardItem, rhs: ClipboardItem) -> Bool {
        if let lt = lhs.text, let rt = rhs.text { return lt == rt }
        // Compares image data to prevent copying the exact same image twice
        if let li = lhs.image, let ri = rhs.image { return li.tiffRepresentation == ri.tiffRepresentation }
        return false
    }
}

class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = 0
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.checkForChanges()
        }
    }
    
    private func checkForChanges() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        
        // 1. Check for an Image FIRST
        if let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            let newItem = ClipboardItem(text: nil, image: image)
            addItem(newItem)
        }
        // 2. If no image, check for Text
        else if let text = pasteboard.string(forType: .string) {
            let newItem = ClipboardItem(text: text, image: nil)
            addItem(newItem)
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        history.removeAll { $0 == item }
        history.insert(item, at: 0)
        if history.count > 10 {
            history.removeLast()
        }
    }
    
    func copyToClipboard(item: ClipboardItem) {
        pasteboard.clearContents()
        if let text = item.text {
            pasteboard.setString(text, forType: .string)
        } else if let image = item.image {
            pasteboard.writeObjects([image]) // Native Apple way to write an image
        }
    }
    
    // NEW: Function to wipe the history completely
    func clearHistory() {
        history.removeAll()
        pasteboard.clearContents() // Also wipes the actual Mac clipboard so you can't paste it anywhere else
    }
}
