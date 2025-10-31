# NotesApp - On-Device LLM Content Classifier

A modern iOS and macOS application for classifying and managing web content using on-device LLM models with GitHub sync.

## Features

- Share links from Safari or other apps
- Automatic content analysis using on-device LLMs (Liquid AI LFM2 models)
- Review and edit classifications before saving
- Sync notes to GitHub repository
- Offline-first architecture with automatic sync
- Full-text search and browsing
- Modern SwiftUI design with smooth animations

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

## Setup

1. Open `NotesApp.xcodeproj` in Xcode
2. Configure your development team and bundle identifier
3. Add required entitlements:
   - App Groups (for Share Extension)
   - Keychain Sharing
   - Network Access

## LLM Integration

The app is designed to work with Liquid AI's LFM2 models:
- LFM2-350M
- LFM2-700M
- LFM2-1.2B

Model integration requires:
1. MLC-LLM Swift framework or llama.cpp Swift bindings
2. GGUF format model files
3. Model download and loading implementation

## GitHub Setup

1. Create a GitHub Personal Access Token with `repo` scope
2. Configure repository settings in the app
3. The app will create a `notes/` directory in your repository

## Project Structure

See the plan document for detailed architecture and implementation details.

## Development Status

This is an initial implementation. Key areas needing completion:
- Actual MLC-LLM integration (currently placeholder)
- HTML content parsing (SwiftSoup integration)
- PDF text extraction
- Complete GitHub OAuth flow
- Core Data persistence layer

## License

MIT

