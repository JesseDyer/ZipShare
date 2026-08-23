import SwiftUI
import Cocoa

struct SettingsView: View {
    @State private var baseURLString: String = ConfigStore.shared.baseURL?.absoluteString ?? ""
    @State private var token: String = ConfigStore.shared.token ?? ""
    @State private var shortLinkDomainString: String = ConfigStore.shared.shortLinkDomain?.absoluteString ?? ""
    @State private var immichBaseURLString: String = ConfigStore.shared.immichBaseURL?.absoluteString ?? ""
    @State private var immichAPIKey: String = ConfigStore.shared.immichAPIKey ?? ""
    @State private var flashPaperBaseURLString: String = ConfigStore.shared.flashPaperBaseURL?.absoluteString ?? ""
    @State private var savedRecently = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ZipShare Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("Zipline — non-image files")
                    .font(.subheadline).bold()
                TextField("Base URL — e.g. https://share.jessedyer.org", text: $baseURLString)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Token", text: $token)
                    .textFieldStyle(.roundedBorder)
                TextField("Short-link display domain (optional) — e.g. https://links.jessedyer.org", text: $shortLinkDomainString)
                    .textFieldStyle(.roundedBorder)
                Text("If set, short links come back as {this domain}/{id} instead of Zipline's own /go/{id} host.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Immich — images")
                    .font(.subheadline).bold()
                TextField("Base URL — e.g. https://photos.jessedyer.org", text: $immichBaseURLString)
                    .textFieldStyle(.roundedBorder)
                SecureField("API Key", text: $immichAPIKey)
                    .textFieldStyle(.roundedBorder)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("FlashPaper — text")
                    .font(.subheadline).bold()
                TextField("Base URL — e.g. https://flashpaper.jessedyer.org", text: $flashPaperBaseURLString)
                    .textFieldStyle(.roundedBorder)
                Text("No token needed — FlashPaper takes a plain POST and encrypts server-side.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text("⌘⇧U uploads whatever's on the clipboard. Images go to Immich and come back as a public share link; other files go to Zipline; a URL gets shortened via Zipline; any other text goes to FlashPaper as a self-destructing note. Either way the link lands on your clipboard.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if savedRecently {
                    Text("Saved.")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button("Save") {
                    ConfigStore.shared.baseURL = URL(string: baseURLString)
                    ConfigStore.shared.token = token
                    ConfigStore.shared.shortLinkDomain = shortLinkDomainString.isEmpty ? nil : URL(string: shortLinkDomainString)
                    ConfigStore.shared.immichBaseURL = URL(string: immichBaseURLString)
                    ConfigStore.shared.immichAPIKey = immichAPIKey
                    ConfigStore.shared.flashPaperBaseURL = URL(string: flashPaperBaseURLString)
                    savedRecently = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }
}

final class SettingsWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "ZipShare Preferences"
        window.styleMask = [.titled, .closable]
        window.center()
        self.init(window: window)
    }
}
