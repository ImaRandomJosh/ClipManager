import SwiftUI
import AppKit
import UniformTypeIdentifiers
import AVFoundation

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private enum Keys {
        static let fontName = "fontName"
        static let fontSize = "fontSize"
        static let backgroundOpacity = "backgroundOpacity"
        static let backgroundImagePath = "backgroundImagePath"
        static let backgroundVideoPath = "backgroundVideoPath"
        static let historyLimit = "historyLimit"
        static let copyOnSelection = "copyOnSelection"
        static let hideFromDock = "hideFromDock"
        static let overlayScale = "overlayScale"
    }

    private let defaults = UserDefaults.standard

    private let defaultFontName = "System"
    private let defaultFontSize = 14.0
    private let defaultBackgroundOpacity = 0.18
    private let defaultHistoryLimit = 25
    private let defaultCopyOnSelection = true
    private let maxBackgroundVideoDuration: Double = 60.0
    private let defaultHideFromDock = true
    private let defaultOverlayScale = 1.0

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

    @Published var backgroundVideoPath: String {
        didSet { defaults.set(backgroundVideoPath, forKey: Keys.backgroundVideoPath) }
    }
    
    @Published var overlayScale: Double {
        didSet { defaults.set(overlayScale, forKey: Keys.overlayScale) }
    }
    @Published var backgroundVideoAspectRatio: Double?

    @Published var historyLimit: Int {
        didSet { defaults.set(historyLimit, forKey: Keys.historyLimit) }
    }

    @Published var copyOnSelection: Bool {
        didSet { defaults.set(copyOnSelection, forKey: Keys.copyOnSelection) }
    }
    
    @Published var hideFromDock: Bool {
        didSet { defaults.set(hideFromDock, forKey: Keys.hideFromDock) }
    }

    let fontChoices: [String]

    private init() {
        fontChoices = ["System"] + NSFontManager.shared.availableFontFamilies.sorted()

        fontName = defaults.string(forKey: Keys.fontName) ?? defaultFontName

        if defaults.object(forKey: Keys.fontSize) == nil {
            fontSize = defaultFontSize
        } else {
            fontSize = defaults.double(forKey: Keys.fontSize)
        }
        
        if defaults.object(forKey: Keys.overlayScale) == nil {
            overlayScale = defaultOverlayScale
        } else {
            overlayScale = defaults.double(forKey: Keys.overlayScale)
        }
        
        if defaults.object(forKey: Keys.backgroundOpacity) == nil {
            backgroundOpacity = defaultBackgroundOpacity
        } else {
            backgroundOpacity = defaults.double(forKey: Keys.backgroundOpacity)
        }
        
        if defaults.object(forKey: Keys.hideFromDock) == nil {
            hideFromDock = defaultHideFromDock
        } else {
            hideFromDock = defaults.bool(forKey: Keys.hideFromDock)
        }

        backgroundImagePath = defaults.string(forKey: Keys.backgroundImagePath) ?? ""
        backgroundVideoPath = defaults.string(forKey: Keys.backgroundVideoPath) ?? ""
        backgroundVideoAspectRatio = nil

        let savedLimit = defaults.integer(forKey: Keys.historyLimit)
        historyLimit = savedLimit == 0 ? defaultHistoryLimit : savedLimit

        if defaults.object(forKey: Keys.copyOnSelection) == nil {
            copyOnSelection = defaultCopyOnSelection
        } else {
            copyOnSelection = defaults.bool(forKey: Keys.copyOnSelection)
        }

        if let url = backgroundVideoURL {
            backgroundVideoAspectRatio = videoAspectRatio(for: url)
        }
    }
    
    let basePanelWidth: CGFloat = 320
    let basePanelHeight: CGFloat = 420

    var scaledPanelWidth: CGFloat {
        basePanelWidth * overlayScale
    }

    var scaledPanelHeight: CGFloat {
        basePanelHeight * overlayScale
    }

    var backgroundImage: NSImage? {
        guard backgroundVideoPath.isEmpty, !backgroundImagePath.isEmpty else { return nil }
        return NSImage(contentsOfFile: backgroundImagePath)
    }

    var backgroundVideoURL: URL? {
        guard backgroundImagePath.isEmpty, !backgroundVideoPath.isEmpty else { return nil }
        return URL(fileURLWithPath: backgroundVideoPath)
    }

    var activeBackgroundDescription: String {
        if backgroundVideoURL != nil { return "Video" }
        if backgroundImage != nil { return "Image" }
        return "None"
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
        panel.prompt = "Choose Image"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveBackgroundImage(from: url)
    }

    func chooseBackgroundVideo() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie]
        panel.prompt = "Choose Video"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        saveBackgroundVideo(from: url)
    }

    func clearBackgroundImage() {
        if !backgroundImagePath.isEmpty {
            try? FileManager.default.removeItem(atPath: backgroundImagePath)
        }
        backgroundImagePath = ""
    }

    func clearBackgroundVideo() {
        if !backgroundVideoPath.isEmpty {
            try? FileManager.default.removeItem(atPath: backgroundVideoPath)
        }
        backgroundVideoPath = ""
        backgroundVideoAspectRatio = nil
    }

    func clearBackgroundMedia() {
        clearBackgroundImage()
        clearBackgroundVideo()
    }

    func resetToDefaults() {
        fontName = defaultFontName
        fontSize = defaultFontSize
        backgroundOpacity = defaultBackgroundOpacity
        historyLimit = defaultHistoryLimit
        copyOnSelection = defaultCopyOnSelection
        clearBackgroundMedia()
        overlayScale = defaultOverlayScale
    }

    private func saveBackgroundImage(from sourceURL: URL) {
        do {
            clearBackgroundVideo()

            let folder = try applicationSupportDirectory()
            let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
            let destinationURL = folder.appendingPathComponent("background-image.\(ext)")

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            backgroundImagePath = destinationURL.path
        } catch {
            showAlert(
                title: "Image Import Failed",
                message: "The selected image could not be imported."
            )
            print("Failed to save background image: \(error)")
        }
    }

    private func saveBackgroundVideo(from sourceURL: URL) {
        let asset = AVURLAsset(url: sourceURL)
        let durationSeconds = CMTimeGetSeconds(asset.duration)

        guard durationSeconds.isFinite else {
            showAlert(
                title: "Unsupported Video",
                message: "This video could not be read properly."
            )
            return
        }

        guard durationSeconds <= maxBackgroundVideoDuration else {
            showAlert(
                title: "Video Too Long",
                message: "Please choose a video that is 60 seconds or shorter."
            )
            return
        }

        guard let aspectRatio = videoAspectRatio(for: sourceURL) else {
            showAlert(
                title: "Unsupported Video",
                message: "This video could not be used as a background."
            )
            return
        }

        do {
            clearBackgroundImage()

            let folder = try applicationSupportDirectory()
            let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
            let destinationURL = folder.appendingPathComponent("background-video.\(ext)")

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            backgroundVideoPath = destinationURL.path
            backgroundVideoAspectRatio = aspectRatio
        } catch {
            showAlert(
                title: "Video Import Failed",
                message: "The selected video could not be imported."
            )
            print("Failed to save background video: \(error)")
        }
    }

    private func videoAspectRatio(for url: URL) -> Double? {
        let asset = AVURLAsset(url: url)

        guard let track = asset.tracks(withMediaType: .video).first else { return nil }

        let transformedSize = track.naturalSize.applying(track.preferredTransform)
        let width = abs(transformedSize.width)
        let height = abs(transformedSize.height)

        guard height > 0 else { return nil }
        return Double(width / height)
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

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }
}
