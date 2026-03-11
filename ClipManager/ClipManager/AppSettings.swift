import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    private let defaultFontName = "System"
    private let defaultFontSize = 14.0
    private let defaultBackgroundOpacity = 0.18
    private let defaultHistoryLimit = 25
    private let defaultCopyOnSelection = true

    private enum Keys {
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let backgroundOpacity = "backgroundOpacity"
        static let backgroundImagePath = "backgroundImagePath"
        static let historyLimit = "historyLimit"
        static let copyOnSelection = "copyOnSelection"
    }

    private let defaults = UserDefaults.standard

    @Published var fontName: String {
        didSet { defaults.set(fontName, forKey: Keys.fontName) }
    }

    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Keys.fontSize) }
    }

    @Published var backgroundOpacity: Double {
        didSet { defaults.set(backgroundOpacity, forKey: Keys.backgroundOpacity) }
    }

    @Published var backgroundImagePath: String {
        didSet { defaults.set(backgroundImagePath, forKey: Keys.backgroundImagePath) }
    }

    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    @Published var copyOnSelection: Bool {
        didSet { defaults.set(copyOnSelection, forKey: Keys.copyOnSelection) }
    }

    let fontChoices: [String]

    private init() {
        fontChoices = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()

        fontName = defaults.string(forKey: Keys.fontName) ?? "System"

        if defaults.object(forKey: Keys.fontSize) == nil {
            fontSize = 14
        } else {
            fontSize = defaults.double(forKey: Keys.fontSize)
        }

        if defaults.object(forKey: Keys.backgroundOpacity) == nil {
            backgroundOpacity = 0.18
        } else {
            backgroundOpacity = defaults.double(forKey: Keys.backgroundOpacity)
        }

        backgroundImagePath = defaults.string(forKey: Keys.backgroundImagePath) ?? ""

        let savedLimit = defaults.integer(forKey: Keys.historyLimit)
        historyLimit = savedLimit == 0 ? 25 : savedLimit

        if defaults.object(forKey: Keys.copyOnSelection) == nil {
            copyOnSelection = true
        } else {
            copyOnSelection = defaults.bool(forKey: Keys.copyOnSelection)
        }
    }

    var backgroundImage: NSImage? {
        guard !backgroundImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: backgroundImagePath)
    }

    var appFont: Font {
        fontName == "System"
            ? .system(size: fontSize)
            : .custom(fontName, size: fontSize)
    }

    func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        panel.prompt = "Choose Background"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveBackgroundImage(from: url)
    }

    func clearBackgroundImage() {
        if !backgroundImagePath.isEmpty {
            try? FileManager.default.removeItem(atPath: backgroundImagePath)
        }
        backgroundImagePath = ""
    }
    
    func resetToDefaults() {
        fontName = defaultFontName
        fontSize = defaultFontSize
        backgroundOpacity = defaultBackgroundOpacity
        historyLimit = defaultHistoryLimit
        copyOnSelection = defaultCopyOnSelection
        clearBackgroundImage()
    }

    private func saveBackgroundImage(from sourceURL: URL) {
        do {
            let folder = try applicationSupportDirectory()
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let destinationURL = folder.appendingPathComponent("background.\(ext)")

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            backgroundImagePath = destinationURL.path
        } catch {
            print("Failed to save background image: \(error)")
        }
    }

    private func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let folder = base.appendingPathComponent("ClipManager", isDirectory: true)

        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )
        }

        return folder
    }
}
