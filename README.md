# ZipShare

A menu-bar-only macOS app: press **⌘⇧U** anywhere, whatever's on your
clipboard gets uploaded and the resulting share link is copied back to your
clipboard, with a toast notification.

**Routing:** images (a copied image file, or raw pasted/screenshotted image
data) go to **Immich** and come back as a public, unauthenticated share
link. Other copied files go to **Zipline**. A URL on the clipboard gets
shortened via **Zipline's URL shortener**. Any other plain text goes to
**FlashPaper** as a self-destructing note.

No Dock icon, no Xcode project — just a Swift package and a Makefile.

## Build

Requires Xcode Command Line Tools (`xcode-select --install` if you don't
have them — this gives you `swift`/`swiftc` without opening Xcode itself).

```
cd ZipShare
make install
```

This builds a release binary, wraps it in `ZipShare.app`, ad-hoc code-signs
it for a stable identity, and copies it to `/Applications`. Use `make app`
instead if you just want the `.app` bundle in the project directory without
installing it.

First launch: since this isn't signed with a real Developer ID, Gatekeeper
will likely balk. Right-click the app in Finder and choose **Open** (or
System Settings → Privacy & Security → "Open Anyway") the first time.

## Configure

Click the paperclip icon in the menu bar → **Preferences…** and enter:

- **Zipline** — Base URL (e.g. `https://share.jessedyer.org`, no trailing
  path) and your existing API token. Optionally a "short-link display
  domain" (e.g. `https://links.jessedyer.org`) — if set, short links come
  back rewritten to `{that domain}/{id}` instead of Zipline's own
  `/go/{id}` host, same id either way.
- **Immich** — Base URL (e.g. `https://photos.jessedyer.org`) and an API
  key from your account settings → API Keys page.
- **FlashPaper** — Base URL (e.g. `https://flashpaper.jessedyer.org`). No
  token — it's an open POST endpoint that encrypts server-side.

Both tokens go to Keychain, not a plaintext prefs file.

## Use

- **⌘⇧U** from anywhere: uploads clipboard contents, copies the resulting
  link to your clipboard.
- Menu bar → **Upload Clipboard** does the same thing without the hotkey.
- Feedback is a small HUD-style toast near the top of the screen (not a
  system notification — those are unreliable for unsigned local builds),
  plus a Glass/Funk sound on success/failure.

## Notes / things you may want to tweak

- **Hotkey combo** is hardcoded to Cmd+Shift+U in `HotKeyManager.swift`
  (`keyCode`/`modifiers` constants near the top). Change it there if it
  collides with something else you use.
- **Image detection** for file-based clipboard content checks the file
  extension via `UTType` in `UploadCoordinator.swift` (`isImageFile`).
  Covers standard image extensions (jpg, png, heic, gif, etc.) — if you
  copy something with an unusual/missing extension it'll fall through to
  Zipline.
- **URL detection** for text routing (`isURL` in `UploadCoordinator.swift`)
  requires an http/https scheme and a host. Anything that doesn't parse as
  one of those goes to FlashPaper as plain text instead.
- **Immich shared links** are created with `showMetadata: false` (strips
  EXIF/GPS from what recipients can see) and `allowDownload: true`. Change
  the `payload` dict in `ImmichUploader.swift` if you want different
  defaults.
- **Zipline response parsing** in `ZiplineUploader.swift` recursively hunts
  for a `"url"` key in the JSON response rather than assuming an exact
  schema, since that's shifted across Zipline versions.
- **Login at boot**: add `ZipShare.app` via System Settings → General →
  Login Items after `make install`.

## Uninstall

```
rm -rf /Applications/ZipShare.app
```

