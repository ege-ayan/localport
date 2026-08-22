# LocalPort

An open-source AirDrop alternative. LocalPort discovers devices on your LAN, sends files over a direct TCP link, and keeps clipboards in sync — all end-to-end encrypted.

One Flutter codebase targets iOS, Android, macOS, Windows, Linux, and Web. File transfer and discovery need a native build (`dart:io`); the web build is UI-only.

```bash
flutter run -d macos
flutter run -d chrome   # UI preview only
```

## Features

| Feature                  | Description                                                         |
| ------------------------ | ------------------------------------------------------------------- |
| **mDNS discovery**       | Devices advertise `_localport._tcp` and appear without typing an IP |
| **Chunked TCP transfer** | Large files are read on a worker isolate and sent in 64 KiB frames  |
| **Clipboard sync**       | Local clipboard changes are pushed to connected peers               |
| **E2EE**                 | X25519 handshake, HKDF, then AES-256-GCM on every payload           |
| **Isar**                 | Transfer history, trusted devices, and logs stay on-device          |
| **Adaptive UI**          | Navigation rail on tablet/desktop, bottom bar on phones             |
| **Riverpod**             | Device list, transfer progress, and clipboard state stay reactive   |

## Requirements

**Pre-built release:** download from [GitHub Releases](https://github.com/ege-ayan/localport/releases/latest).

**Build from source:** [Flutter](https://docs.flutter.dev/get-started/install) 3.44+ (Dart 3.12)

Devices must share a local network. File send needs the OS local-network permission (already declared for Android, iOS, and macOS).

`isar_community_flutter_libs` does not ship a Swift Package Manager manifest yet. Flutter still falls back to CocoaPods; ignore that tool warning until the plugin adopts SPM.

## Installation

### Pre-built binary

1. Open [GitHub Releases](https://github.com/ege-ayan/localport/releases/latest)
2. Download the archive for your platform
3. Launch `LocalPort`

| Platform            | Download                           |
| ------------------- | ---------------------------------- |
| macOS Apple Silicon | `localport-*-macos-aarch64.tar.gz` |
| Linux x86_64        | `localport-*-linux-x86_64.tar.gz`  |
| Android             | `localport-*-android-arm64.tar.gz` |

### Build from source

```bash
git clone https://github.com/ege-ayan/localport.git
cd localport
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

### Package a local release

```bash
make build                 # macOS release (on a Mac)
./scripts/release.sh
```

## Usage

1. Open LocalPort on two devices on the same Wi‑Fi.
2. Peers appear under **Devices**.
3. **Send file** or drop a file onto a peer (desktop).
4. Copy text — it is pushed to connected devices from the **Clipboard** tab, or automatically every few seconds.
5. Finished transfers land in `Downloads/LocalPort` and show up under **History**.

Inbound files are accepted automatically and written to that downloads folder.

## How it works

1. Each device advertises itself with Bonjour/mDNS and listens on TCP `47831`.
2. The first message on a socket is an unencrypted hello (device id + X25519 public key).
3. Both sides derive an AES-256-GCM session key (HKDF-SHA-256, info `localport/v1`).
4. Control messages and file chunks are length-prefixed, then sealed.
5. File bytes are read on a background isolate so the UI does not stall.
6. Isar stores history and marks the peer as trusted after a successful session.

This is a local-network tool, not a production replacement for AirDrop. There is no relay, no account, and no cloud.

## Development

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
make test          # format + analyze + tests
make fmt
flutter run -d macos
```

### Test coverage

| Area        | Tests                                              |
| ----------- | -------------------------------------------------- |
| Framing     | Length prefix, split packets, hello/clipboard JSON |
| Chunks      | Offset and payload round-trip                      |
| Isolate I/O | File is read on a worker isolate in 64-byte slices |
| Crypto      | X25519 + AES-256-GCM seal/open, auth failure       |
| UI          | Theme smoke test                                   |

## GitHub Actions

`.github/workflows/ci.yml` runs format, Isar codegen, `flutter analyze`, and `flutter test` on Ubuntu and macOS.

Push a `v*` tag to publish macOS, Linux, and Android archives plus `SHA256SUMS.txt`.

## License

GPL-3.0 — see [LICENSE](LICENSE).
