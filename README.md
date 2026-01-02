# AutoRecall

AutoRecall is a privacy-focused macOS application that helps you remember everything you've seen on your screen. It continuously captures your screen activity, indexes text content, and allows you to search through your screen history.

## Features

- Screen recording with automatic transcription
- Text input tracking and searching
- Clipboard history management
- AI-powered searching and analysis
- Privacy-focused with all processing happening locally

## Directory Structure

```
AutoRecall/
├── Sources/
│   └── AutoRecall/
│       ├── Application/    # Main application files
│       ├── Extensions/     # Swift extensions
│       ├── Managers/       # Service managers
│       ├── Models/         # Data models
│       ├── Utilities/      # Utility classes
│       └── Views/          # UI components
├── Resources/              # Application resources
├── Tests/                  # Test files
└── Package.swift           # Swift package definition
```

## Building and Running

```bash
# Build the application
make build

# Run the application
make run
```

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later

# AutoRecall

An open-source macOS application that captures and makes searchable everything you see, hear, and copy on your Mac, without any data leaving your machine.

## Features

- Continuous screen recording
- OCR of all screen content
- Audio transcription (meetings)
- Clipboard monitoring (text, images, files)
- Active window title tracking
- Website URL capture
- Semantic search
- Timeline navigation
- Smart Answers using local LLMs

## Getting Started

### Running the App

To run the pre-built app:

```bash
make run
```

This will build the application if needed and launch it.

### Building from Source

To build AutoRecall from source:

```bash
make build
```

To create an application bundle:

```bash
make package
```

### Development and Testing

AutoRecall includes a comprehensive build and test system:

```bash
# Run Swift tests
make test

# Run comprehensive tests
make test-all

# Clean build artifacts
make clean

# Repair and optimize database
make repair

# Verify data integrity
make verify

# Optimize application performance
make optimize
```

Run `make help` to see all available commands.

## Project Structure

- **Sources/AutoRecall**: Main Swift source files
- **Tests/AutoRecallTests**: Test files
- **Tools**: Utility scripts and tools for development and testing
- **docs**: Project documentation
- **images**: Image assets used in the README and documentation

## Dependencies

- [SQLite.swift](https://github.com/stephencelis/SQLite.swift.git): SQLite database wrapper
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin): Utility for launching the app at login

## Privacy

AutoRecall respects your privacy:
- All data stays on your machine
- No analytics or telemetry
- All processing happens locally

## License

See the [LICENSE](LICENSE) file for details.

# Take Control of Your Digital Memory

OpenRecall is a fully open-source, privacy-first alternative to proprietary solutions like Microsoft's Windows Recall or Limitless' Rewind.ai. With OpenRecall, you can easily access your digital history, enhancing your memory and productivity without compromising your privacy.

## What does it do?

OpenRecall captures your digital history through regularly taken snapshots, which are essentially screenshots. The text and images within these screenshots are analyzed and made searchable, allowing you to quickly find specific information by typing relevant keywords into OpenRecall. You can also manually scroll back through your history to revisit past activities.

https://github.com/openrecall/openrecall/assets/16676419/cfc579cb-165b-43e4-9325-9160da6487d2

## Why Choose OpenRecall?

OpenRecall offers several key advantages over closed-source alternatives:

- **Transparency**: OpenRecall is 100% open-source, allowing you to audit the source code for potential backdoors or privacy-invading features.
- **Native macOS Implementation**: Built entirely with Swift and SwiftUI for optimal performance and integration with macOS.
- **Privacy-focused**: Your data is stored locally on your device, no internet connection or cloud is required. In addition, you have the option to encrypt the data on a removable disk for added security, read how in our [guide](docs/encryption.md) here. 
- **Hardware Compatibility**: OpenRecall is designed to work with a [wide range of hardware](docs/hardware.md), unlike proprietary solutions that may require specific certified devices.

<p align="center">
  <a href="https://twitter.com/elonmusk/status/1792690964672450971" target="_blank">
    <img src="images/black_mirror.png" alt="Elon Musk Tweet" width="400">
  </a>
</p>

## Features

- **Time Travel**: Revisit and explore your past digital activities seamlessly on macOS.
- **Local-First AI**: OpenRecall harnesses the power of local AI processing to keep your data private and secure.
- **Semantic Search**: Advanced local OCR interprets your history, providing robust semantic search capabilities.
- **Full Control Over Storage**: Your data is stored locally, giving you complete control over its management and security.

<p align="center">
  <img src="images/lisa_rewind.webp" alt="Lisa Rewind" width="400">
</p>


## Comparison



| Feature          | OpenRecall                    | Windows Recall                                  | Rewind.ai                              |
|------------------|-------------------------------|--------------------------------------------------|----------------------------------------|
| Transparency     | Open-source                   | Closed-source                                    | Closed-source                          |
| Supported Hardware | All macOS devices           | Copilot+ certified Windows hardware              | M1/M2 Apple Silicon                    |
| OS Support       | macOS                         | Windows                                          | macOS                                  |
| Privacy          | On-device, self-hosted        | Microsoft's privacy policy applies               | Connected to ChatGPT                   |
| Cost             | Free                          | Part of Windows 11 (requires specialized hardware) | Monthly subscription                   |

## Quick links
- [Roadmap](https://github.com/orgs/openrecall/projects/2) and you can [vote for your favorite features](https://github.com/openrecall/openrecall/discussions/9#discussion-6775473)
- [FAQ](https://github.com/openrecall/openrecall/wiki/FAQ)

## Get Started

### Prerequisites
- macOS 13.0 or later

### Installation

Download the latest release from our [GitHub releases page](https://github.com/openrecall/openrecall/releases) and install the .dmg file.

Alternatively, you can build from source using Swift:

```
git clone https://github.com/openrecall/openrecall.git
cd openrecall
make build
make package
```

The built application will be available in the project root as `AutoRecall.app`.

## Uninstall instructions

To uninstall OpenRecall and remove all stored data:

1. Delete the OpenRecall.app from your Applications folder

2. Remove stored data:
   ```
   rm -rf ~/Library/Application\ Support/openrecall
   ```

Note: If you specified a custom storage path, make sure to remove that directory too.

## Contribute

As an open-source project, we welcome contributions from the community. If you'd like to help improve OpenRecall, please submit a pull request or open an issue on our GitHub repository.

## Contact the maintainers
mail@datatalk.be

## License

OpenRecall is released under the [AGPLv3](https://opensource.org/licenses/AGPL-3.0), ensuring that it remains open and accessible to everyone.

## Troubleshooting

If you encounter any issues with AutoRecall, you can use our built-in tools to diagnose and fix common problems:

```bash
# Repair database issues
make repair

# Verify data integrity
make verify

# Optimize performance
make optimize
```

You can also run the comprehensive test suite to identify issues:

```bash
make test-all
```

For more help, please create an issue on our GitHub repository.

