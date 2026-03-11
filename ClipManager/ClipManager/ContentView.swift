import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var clipboardManager = ClipboardManager()
    @State private var hoveredIndex: Int? = nil
    @State private var showDeleteAlert = false // Tracks if the warning popup should be visible
    
    var body: some View {
        VStack(spacing: 0) {
            // The Header
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentColor)
                
                Text("Clipboard History")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // NEW: The Trash Button
                Button(action: {
                    showDeleteAlert = true // Trigger the warning popup
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        // A slightly faded red so it isn't glaringly bright
                        .foregroundColor(Color.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Clear Clipboard History")
                // NEW: The Native Warning Popup
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("Clear Clipboard?"),
                        message: Text("This will permanently delete your clipboard history. You cannot undo this."),
                        primaryButton: .destructive(Text("Delete All")) {
                            clipboardManager.clearHistory()
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                // Drag Handle
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(DragHandle())
                    .help("Drag to move window")
                
                // Reset Position Button
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("ResetPosition"), object: nil)
                }) {
                    Image(systemName: "arrow.uturn.left.circle")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to bottom corner")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)
            
            Divider()
            
            // The List
            ScrollView {
                VStack(spacing: 0) {
                    // Notice we use \.element.id now because we are using our custom ClipboardItem
                    ForEach(Array(clipboardManager.history.enumerated()), id: \.element.id) { index, item in
                        
                        let keyChar = Character(index < 9 ? "\(index + 1)" : "0")
                        
                        Button(action: {
                            clipboardManager.copyToClipboard(item: item)
                            NSApp.windows.first?.orderOut(nil)
                        }) {
                            HStack(alignment: .center, spacing: 12) {
                                Text("\(index < 9 ? index + 1 : 0)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(hoveredIndex == index ? .accentColor : .secondary.opacity(0.5))
                                
                                // NEW: Dynamic View for Text vs Image
                                if let text = item.text {
                                    Text(text)
                                        .font(.system(size: 13))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .foregroundColor(.primary)
                                } else if let image = item.image {
                                    Image(nsImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 40) // Keeps the image thumbnail small and clean
                                        .cornerRadius(4)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(hoveredIndex == index ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(KeyEquivalent(keyChar), modifiers: .command)
                        .onHover { isHovered in
                            hoveredIndex = isHovered ? index : nil
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        
                        if index < clipboardManager.history.count - 1 {
                            Divider()
                                .opacity(0.5)
                                .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .frame(width: 320, height: 420)
        .background(VisualEffectView().ignoresSafeArea())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// Helpers
struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        return CustomDragView()
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

class CustomDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
