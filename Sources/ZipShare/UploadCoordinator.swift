import Cocoa
import UniformTypeIdentifiers

final class UploadCoordinator {
    static let shared = UploadCoordinator()

    func uploadClipboard() {
        print("[ZipShare] uploadClipboard() triggered")
        let pb = NSPasteboard.general
        print("[ZipShare] pasteboard types present: \(pb.types ?? [])")

        // 1. A copied file (e.g. Cmd-C on a file in Finder) — route by type.
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first, first.isFileURL {
            print("[ZipShare] found file URL on pasteboard: \(first.path)")
            if isImageFile(first) {
                routeToImmich(fileURL: first)
            } else {
                routeToZipline(fileURL: first)
            }
            return
        }

        // 2. Raw image data (screenshot, copied image with no file backing) — always Immich.
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let pngData = rep.representation(using: .png, properties: [:]) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".png")
            do {
                try pngData.write(to: tmp)
                print("[ZipShare] wrote clipboard image to \(tmp.path)")
                routeToImmich(fileURL: tmp)
            } catch {
                print("[ZipShare] failed writing temp image: \(error)")
                notify(title: "ZipShare", body: "Couldn't write temp image file.")
            }
            return
        }

        // 3. Plain text — FlashPaper.
        if let text = pb.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[ZipShare] found text on pasteboard (\(text.count) chars)")
            routeToFlashPaper(text: text)
            return
        }

        print("[ZipShare] nothing uploadable found on pasteboard")
        notify(title: "ZipShare", body: "Nothing uploadable on the clipboard.")
    }

    private func isImageFile(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    private func routeToZipline(fileURL: URL) {
        guard ConfigStore.shared.isConfigured else {
            print("[ZipShare] Zipline not configured")
            notify(title: "ZipShare", body: "Set your Zipline URL and token in Preferences first.")
            return
        }
        print("[ZipShare] uploading to Zipline: \(ConfigStore.shared.baseURL!.absoluteString)")
        ZiplineUploader.upload(fileURL: fileURL) { [weak self] result in
            DispatchQueue.main.async { self?.handle(result, source: "Zipline") }
        }
    }

    private func routeToImmich(fileURL: URL) {
        guard ConfigStore.shared.isImmichConfigured else {
            print("[ZipShare] Immich not configured")
            notify(title: "ZipShare", body: "Set your Immich URL and API key in Preferences first.")
            return
        }
        print("[ZipShare] uploading to Immich: \(ConfigStore.shared.immichBaseURL!.absoluteString)")
        ImmichUploader.upload(fileURL: fileURL) { [weak self] result in
            DispatchQueue.main.async { self?.handle(result, source: "Immich") }
        }
    }

    private func routeToFlashPaper(text: String) {
        guard ConfigStore.shared.flashPaperBaseURL != nil else {
            print("[ZipShare] FlashPaper not configured")
            notify(title: "ZipShare", body: "Set your FlashPaper URL in Preferences first.")
            return
        }
        print("[ZipShare] uploading to FlashPaper: \(ConfigStore.shared.flashPaperBaseURL!.absoluteString)")
        FlashPaperUploader.upload(text: text) { [weak self] result in
            DispatchQueue.main.async { self?.handle(result, source: "FlashPaper") }
        }
    }

    private func handle(_ result: Result<String, Error>, source: String) {
        switch result {
        case .success(let urlString):
            print("[ZipShare] \(source) upload succeeded: \(urlString)")
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(urlString, forType: .string)
            SoundPlayer.playSuccess()
            notify(title: "Uploaded to \(source) — link copied", body: urlString)
        case .failure(let error):
            print("[ZipShare] \(source) upload failed: \(error)")
            SoundPlayer.playFailure()
            notify(title: "\(source) upload failed", body: error.localizedDescription)
        }
    }

    private func notify(title: String, body: String) {
        ToastController.shared.show("\(title)\n\(body)")
    }
}
