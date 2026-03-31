# TokenTracker — macOS Menu Bar Token Usage Dashboard

TokenTracker is a native macOS menu bar application designed to aggregate and display token usage and balance information across various AI platforms (OpenAI, DeepSeek, MiniMax, etc.). It features a plugin-based architecture and is configuration-driven, allowing for easy extension via the UI or JSON config files.

## Project Overview

- **Main Technologies:** Swift 5.9, SwiftUI (MenuBarExtra), macOS 14.0+ (Sonoma).
- **Architecture:** Plugin-based `Provider` system. Each provider implements the `UsageProvider` protocol.
- **Configuration:** 
  - **API Keys:** Stored securely in the macOS Keychain.
  - **Custom Providers:** Defined via JSON files in `~/.config/tokentracker/providers/`.
- **Core Features:** 
  - Real-time usage tracking in the menu bar.
  - Built-in support for OpenAI, DeepSeek, and MiniMax.
  - Support for custom API endpoints via configuration.
  - Automatic polling and launch-at-login support.

## Project Structure

- `TokenTracker/`: Main source code directory.
  - `Models/`: Data models for usage and provider configuration (`UsageData.swift`, `ProviderConfig.swift`).
  - `Providers/`: Implementation of various API providers.
    - `UsageProvider.swift`: The core protocol for all providers.
    - `ProviderRegistry.swift`: Registry for built-in and custom providers.
    - `CustomProvider.swift`: Generic engine for user-defined API endpoints.
  - `ViewModels/`: `TokenTrackerViewModel.swift` manages the app state and data fetching.
  - `Views/`: SwiftUI views for the menu bar, settings, and provider management.
  - `Storage/`: Helpers for Keychain and JSON file management.
- `scripts/`: Automation scripts for icons and DMG packaging.
- `docs/`: Implementation plans, tasks, and walkthroughs.

## Building and Running

### Development (Xcode)
1. Open `TokenTracker.xcodeproj` in Xcode 15+.
2. Ensure you have a valid development team selected for code signing.
3. Press `Cmd + R` to build and run the application.

### Command Line Build
To build the project from the terminal:
```bash
xcodebuild -project TokenTracker.xcodeproj -scheme TokenTracker -configuration Release -sdk macosx -derivedDataPath build build
```

### Packaging
To generate a `.dmg` for distribution:
```bash
./scripts/package_dmg.sh
```
The output will be located in `./dist/TokenTracker.dmg`.

## Development Conventions

- **Providers:** To add a new built-in provider, implement the `UsageProvider` protocol and register it in `ProviderRegistry.swift`.
- **Concurrency:** Uses Swift's `async/await` for network requests.
- **UI:** Strictly follows macOS design guidelines using native SwiftUI components.
- **Configuration:** Custom providers can be added without code changes by placing a JSON file in `~/.config/tokentracker/providers/`.

## Key Files

- `TokenTracker/TokenTrackerApp.swift`: App entry point using `MenuBarExtra`.
- `TokenTracker/Providers/UsageProvider.swift`: Interface definition for data fetching logic.
- `TokenTracker/Storage/ConfigFileManager.swift`: Handles persistent storage of custom provider configurations.
- `TokenTracker/ViewModels/TokenTrackerViewModel.swift`: Centralized logic for refreshing data across all active providers.
