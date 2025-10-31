# Contributing to NotesApp

## Development Setup

1. Open `NotesApp.xcodeproj` in Xcode
2. Select your development team
3. Configure bundle identifiers
4. Build and run

## Architecture

The app follows a modular architecture:

- **App**: Main app entry point and global state
- **Views**: SwiftUI views organized by feature
- **Models**: Data models (Note, NoteAnalysis, etc.)
- **Services**: Business logic organized by domain:
  - LLMEngine: On-device LLM inference
  - GitHubService: GitHub API integration
  - ContentExtractor: URL content extraction
  - StorageService: Local persistence

## Key Components

### LLM Integration
- `LLMService` protocol defines the interface
- `MLCLLMService` implements LLM inference
- Models are downloaded via `ModelDownloader`
- Currently uses placeholder implementation - needs actual MLC-LLM integration

### GitHub Sync
- Offline-first architecture
- `CommitQueue` manages pending commits
- Auto-sync when network is available
- Supports PAT, OAuth, and SSH authentication

### Share Extension
- Receives URLs from other apps
- Extracts content and analyzes with LLM
- Saves to main app via shared UserDefaults

## TODOs

- [ ] Integrate actual MLC-LLM or llama.cpp framework
- [ ] Implement proper HTML parsing (SwiftSoup)
- [ ] Add PDF text extraction
- [ ] Complete GitHub OAuth flow
- [ ] Implement Core Data persistence
- [ ] Add unit tests
- [ ] Add integration tests

