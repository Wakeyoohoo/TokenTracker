# Token Usage Menu Bar App - Task Checklist

## Planning
- [x] Research AI platform usage APIs (OpenAI, Anthropic, DeepSeek, Google Gemini, MiniMax)
- [x] Design plugin-based architecture and write implementation plan
- [/] Update plan with config-driven provider registration (JSON file + UI form)
- [ ] Get user approval on updated plan

## Implementation
- [x] Set up Xcode project with SwiftUI MenuBarExtra
- [x] Build data models (UsageData, ProviderConfig with EndpointConfig)
- [x] Implement built-in providers (OpenAI, DeepSeek, MiniMax, Anthropic, Gemini)
- [x] Implement CustomProvider engine (executes config-driven API calls)
- [x] Implement ConfigFileManager (load/save JSON from ~/.config/tokentracker/providers/)
- [x] Build Settings UI with API key configuration
- [x] Build AddProviderView (custom provider form)
- [x] Build main MenuBarView with usage dashboard (total + percentage + progress bar)
- [x] Build ProviderCardView with token counts, cost, quota progress bar
- [x] Implement ViewModel with auto-refresh and background polling
- [x] Add Keychain storage for API keys
- [x] Create Xcode project file (.xcodeproj)

## Verification
- [x] Build and run the app in Xcode
- [x] Test with real API keys
- [x] Test custom provider via JSON config file
- [x] Test custom provider via UI form
- [x] Verify menu bar icon and popup behavior
