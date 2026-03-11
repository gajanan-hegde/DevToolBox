# DevToolbox

A native macOS developer utility app with a collection of everyday tools - no subscriptions, no telemetry, no internet required.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Disclaimer:** This project is fully vibecoded. Every line was written by Claude. Use at your own risk, inspect before you trust, and PRs are welcome.

<!-- TODO: Add a screenshot or demo GIF here once the app is published -->
<!-- Example: ![DevToolbox Screenshot](docs/screenshot.png) -->

## Features

| Tool | Description |
|---|---|
| **JWT Decoder** | Decode and inspect JWT headers, payloads, and signatures |
| **JSON Editor** | Format, validate, and explore JSON with a collapsible tree view |
| **YAML Editor** | Format and validate YAML documents |
| **JSON ↔ YAML Converter** | Convert between JSON and YAML instantly |
| **JSON Diff** | Side-by-side diff of two JSON documents |
| **Base64 Encoder/Decoder** | Encode or decode Base64 strings |
| **URL Encoder/Decoder** | Percent-encode or decode URL strings |
| **Epoch Converter** | Convert between Unix timestamps and human-readable dates |

### Spotlight & Raycast Integration

- Launch any tool directly from **Spotlight** or **Siri** via App Intents
- Deep-link with clipboard content: `devtoolbox://open?input=<encoded>`
- **Content detection** - paste anything and DevToolbox routes it to the right tool automatically
- **Raycast** support via a shell script (no extension required)

## Requirements

- macOS 26 or later
- Xcode 26 or later (to build from source)

## Installation

### Homebrew (recommended)

```bash
brew tap gajanan-hegde/devtoolbox
brew install --cask devtoolbox
```

### Manual download

Download the latest `DevToolbox-<version>.zip` from [GitHub Releases](https://github.com/gajanan-hegde/DevToolbox/releases), unzip, and drag `DevToolbox.app` to your `/Applications` folder.

### Allowing the app through Gatekeeper

DevToolbox is not notarized by Apple, so macOS will block it on first launch. To allow it:

1. Try to open DevToolbox — macOS will show a "cannot be opened" alert. Click **Done** (or **OK**).
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the **Security** section. You should see a message like *"DevToolbox was blocked from use because it is not from an identified developer."*
4. Click **Open Anyway**, then confirm in the dialog that appears.

> **Note:** DevToolbox is open-source and unsigned. Gatekeeper warns about apps that haven't been notarized by Apple, but the app itself does not require any special permissions, access the network, or collect any data.

## Building from Source

```bash
git clone https://github.com/gajanan-hegde/DevToolbox.git
cd DevToolbox
open DevToolbox.xcodeproj
```

Then press **⌘R** in Xcode to build and run.

No external dependencies or package setup required - the project builds out of the box.

## Release workflow

To publish a new release:

1. Run the build script:
   ```bash
   bash Scripts/build-release.sh
   ```
2. Upload the generated `dist/DevToolbox-<version>.zip` to a new GitHub Release tagged `v<version>`.
3. Copy the printed SHA256 into `Casks/devtoolbox.rb` (replace the `REPLACE_WITH_SHA256_FROM_BUILD_SCRIPT` placeholder).
4. Copy the updated `Casks/devtoolbox.rb` into the `homebrew-devtoolbox` tap repo under `Casks/`.
5. Commit and push the tap repo.

### Tap repo structure

The `github.com/gajanan-hegde/homebrew-devtoolbox` repo must have this layout:

```
homebrew-devtoolbox/
  Casks/
    devtoolbox.rb
```

## License

MIT - see [LICENSE](LICENSE) for details.
