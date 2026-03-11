import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @EnvironmentObject private var settings: AppSettings

    @State private var hoveredIndex: Int? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            WindowBackgroundView()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.accentColor)

                    Text("Clipboard History")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    SettingsLink {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")

                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Clear Clipboard History")
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

                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(DragHandle())
                        .help("Drag to move window")

                    Button {
                        NotificationCenter.default.post(name: NSNotification.Name("ResetPosition"), object: nil)
                    } label: {
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

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(clipboardManager.history.enumerated()), id: \.element.id) { index, item in
                            let keyChar = Character(index < 9 ? "\(index + 1)" : "0")

                            Button {
                                if settings.copyOnSelection {
                                    clipboardManager.copyToClipboard(item: item)
                                    NSApp.windows.first?.orderOut(nil)
                                }
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    Text("\(index < 9 ? index + 1 : 0)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(
                                            hoveredIndex == index
                                            ? .accentColor
                                            : .secondary.opacity(0.5)
                                        )

                                    if let text = item.text {
                                        Text(text)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .foregroundColor(.primary)
                                    } else if let image = item.image {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxHeight: 40)
                                            .cornerRadius(4)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    hoveredIndex == index
                                    ? Color.accentColor.opacity(0.15)
                                    : Color.clear
                                )
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
            .padding(0)
        }
        .frame(width: 320, height: 420)
        .background(VisualEffectView().ignoresSafeArea())
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .font(settings.appFont)
    }
}

struct WindowBackgroundView: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.06),
                        Color.clear,
                        Color.black.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let image = settings.backgroundImage {
                    let imageSize = image.size
                    let imageAspect = imageSize.width / max(imageSize.height, 1)
                    let viewAspect = geo.size.width / max(geo.size.height, 1)

                    if imageAspect < viewAspect {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .opacity(settings.backgroundOpacity)
                    } else {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .opacity(settings.backgroundOpacity)
                    }

                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.clear,
                            Color.black.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}

struct DragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        CustomDragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}

final class CustomDragView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
