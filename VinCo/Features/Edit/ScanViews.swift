import SwiftUI
import VisionKit
import Vision
import UIKit
import PhotosUI

// MARK: – Barcode scanner sheet
// Full-screen live barcode scanner using DataScannerViewController (iOS 17+).
// Fires onDetected exactly once with the raw barcode payload string.
struct BarcodeScannerSheet: View {
    let onDetected: (String) -> Void
    let onCancel:   () -> Void
    @Environment(Settings.self) private var settings

    var body: some View {
        ZStack(alignment: .top) {
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                _BarcodeScannerVC(onDetected: onDetected)
                    .ignoresSafeArea()

                // Instruction pill
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 15))
                        Text("Point at the barcode on the sleeve")
                            .font(Theme.courier(13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(.bottom, 48)
                }
            } else {
                // Fallback: device doesn't support DataScannerViewController
                ZStack {
                    settings.bg0.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.textT)
                        Text("Barcode scanning is not\navailable on this device")
                            .font(Theme.courier(15))
                            .foregroundStyle(Theme.textS)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            // Top bar: Cancel + title
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
                Text("SCAN BARCODE")
                    .font(Theme.courier(12, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                Spacer()
                // Balance the cancel button
                Circle().fill(.clear).frame(width: 36, height: 36)
            }
            .padding(.top, 60)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: – DataScannerViewController wrapper
private struct _BarcodeScannerVC: UIViewControllerRepresentable {
    let onDetected: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [.ean13, .ean8, .upce, .code128, .code39, .qr])
            ],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDetected: onDetected) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onDetected: (String) -> Void
        private var fired = false

        init(onDetected: @escaping (String) -> Void) { self.onDetected = onDetected }

        func dataScanner(_ scanner: DataScannerViewController,
                         didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            guard !fired else { return }
            for item in addedItems {
                if case .barcode(let b) = item, let val = b.payloadStringValue {
                    fired = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onDetected(val)
                    return
                }
            }
        }
    }
}

// MARK: – Camera capture view for album cover
// Presents UIImagePickerController in camera mode and returns JPEG data.
struct CoverCameraView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onCancel:  () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType     = .camera
        picker.allowsEditing  = false
        picker.delegate       = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        let onCancel:  () -> Void

        init(onCapture: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture; self.onCancel = onCancel
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage,
               let data = img.jpegData(compressionQuality: 0.85) {
                onCapture(data)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}

// MARK: – Photo library picker (PHPickerViewController)
// Uses NSItemProvider.loadObject(ofClass: UIImage.self) which reliably handles
// JPEG, PNG, HEIC, WebP, and iCloud-stored photos — unlike loadTransferable which
// silently fails for many image types.
struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onImageSelected: (Data) -> Void
    let onCancel:        () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter         = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageSelected: onImageSelected, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImageSelected: (Data) -> Void
        let onCancel:        () -> Void

        init(onImageSelected: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onImageSelected = onImageSelected; self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else { onCancel(); return }
            let provider = result.itemProvider
            guard provider.canLoadObject(ofClass: UIImage.self) else { onCancel(); return }

            // loadObject is called on an arbitrary queue — bridge back to MainActor
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let image = object as? UIImage,
                       let data  = image.jpegData(compressionQuality: 0.88) {
                        self.onImageSelected(data)
                    } else {
                        self.onCancel()
                    }
                }
            }
        }
    }
}

// MARK: – Vision text recognition
// Scores text observations by visual prominence (bounding-box area × OCR confidence)
// so artist/album names (large text) beat navigation chrome and footnotes.
// Returns (query, rawLines) so the caller can show what was recognised.
nonisolated func recognizeAlbumText(from data: Data) async -> (query: String, lines: [String]) {
    guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
        return ("", [])
    }
    return await withCheckedContinuation { continuation in
        let request = VNRecognizeTextRequest { req, _ in
            let observations = (req.results as? [VNRecognizedTextObservation]) ?? []

            // Score: larger bounding box + higher confidence = more prominent text
            let scored: [(text: String, score: Double)] = observations.compactMap { obs in
                guard let top = obs.topCandidates(1).first else { return nil }
                let text = top.string
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: .init(charactersIn: ".,;:!?-–—\"'"))
                guard text.count >= 2 else { return nil }
                let box   = obs.boundingBox
                let score = Double(top.confidence) * box.width * box.height * 1_000
                return (text, score)
            }
            .sorted { $0.score > $1.score }

            let rawLines = scored.prefix(12).map(\.text)

            // Filter common screenshot / app chrome noise
            let meaningful = scored
                .map(\.text)
                .filter { !isScreenshotNoise($0) }

            // Build query from top meaningful strings, fall back to top raw if all filtered
            let queryParts = meaningful.count >= 2
                ? Array(meaningful.prefix(4))
                : Array(scored.prefix(3).map(\.text))

            let query = queryParts.joined(separator: " ")
            continuation.resume(returning: (query, Array(rawLines)))
        }
        // Only process text whose height is ≥ 3% of the image — skips status-bar
        // text, footnotes, tiny UI labels while keeping titles and artist names.
        request.minimumTextHeight     = 0.03
        request.recognitionLevel      = .accurate
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
}

/// Returns true for strings that are almost certainly app UI chrome rather than music metadata.
private nonisolated func isScreenshotNoise(_ text: String) -> Bool {
    // Pure digit strings (track numbers, ratings, counts)
    if text.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }) { return true }

    // Prices / currency
    let firstChar = text.unicodeScalars.first
    let currencySymbols: Set<Unicode.Scalar> = ["$", "€", "£", "¥", "₩", "₪", "₹"]
    if let c = firstChar, currencySymbols.contains(c) { return true }

    // Track duration pattern "3:45" or "1:04:12"
    let durationPattern = #"^\d{1,2}(:\d{2}){1,2}$"#
    if text.range(of: durationPattern, options: .regularExpression) != nil { return true }

    // Very common app UI words (exact or leading match)
    let lower = text.lowercased()
    let uiExact: Set<String> = [
        "want", "have", "add", "buy", "sell", "shop", "cart",
        "follow", "following", "followers", "like", "unlike", "save",
        "share", "report", "flag", "block", "edit", "delete", "remove",
        "more", "less", "ok", "cancel", "done", "back",
        "home", "search", "browse", "radio", "podcasts", "charts",
        "library", "settings", "profile", "account", "sign in", "log in",
        "discogs", "marketplace", "community", "collection", "wishlist",
        "spotify", "apple music", "tidal", "deezer", "soundcloud",
        "now playing", "up next", "queue", "lyrics", "connect",
        "previous", "next", "pause", "play", "shuffle", "repeat",
        "explicit", "clean", "e", "clean version",
        "reviews", "rating", "stars", "tracklist", "credits",
    ]
    if uiExact.contains(lower) { return true }

    return false
}
