# DevToolbox

A native macOS developer utility app with a collection of everyday tools — no subscriptions, no telemetry, no internet required.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

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
- **Content detection** — paste anything and DevToolbox routes it to the right tool automatically
- **Raycast** support via a shell script (no extension required)

## Requirements

- macOS 26 or later
- Xcode 26 or later (to build from source)

## Getting Started

```bash
git clone https://github.com/YOUR_USERNAME/DevToolbox.git
cd DevToolbox
open DevToolbox.xcodeproj
```

Then press **⌘R** in Xcode to build and run.

No external dependencies or package setup required — the project builds out of the box.

## License

MIT — see [LICENSE](LICENSE) for details.
