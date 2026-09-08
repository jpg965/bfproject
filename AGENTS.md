# OpenCode Mobile

Native iOS client (SwiftUI) that connects to an opencode server via Tailscale VPN.

## Quick Facts

- **Language:** Swift 5.9, iOS 17.0+
- **Framework:** SwiftUI only — no UIKit, storyboards, or xibs
- **Architecture:** MVVM with `@Observable` macro (not `ObservableObject`/`@Published`)
- **Persistence:** SwiftData (`@Model`, `ModelContainer`, `#Predicate`)
- **Dependencies:** Zero — Apple frameworks only
- **Project generator:** XcodeGen (`project.yml` is source of truth for the Xcode project)

## Build

```bash
# Regenerate Xcode project after editing project.yml
xcodegen generate --project OpenCodeMobile

# Build from CLI
xcodebuild -project OpenCodeMobile/OpenCodeMobile.xcodeproj \
  -scheme OpenCodeMobile \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build
```

## What Doesn't Exist (Don't Look For)

- No test files or test targets
- No lint config (`.swiftlint.yml`, `.swiftformat`)
- No CI/CD pipelines
- No SPM/CocoaPods/Carthage — no third-party deps at all
- No `opencode.json` in the repo

## Architecture

```
OpenCodeMobile/
├── Models/          # Codable structs: Session, Message, ServerConfig, etc.
├── Networking/      # APIClient (REST), SSEClient (Server-Sent Events)
├── Persistence/     # DataStore — SwiftData wrapper
├── Utilities/       # KeychainHelper, AppLifecycleManager
├── ViewModels/      # ConnectionViewModel, SessionListViewModel, ChatViewModel
└── Views/           # ContentView (TabView), SessionListView, ChatView, MessageRowView, SettingsView
```

Entry point: `OpenCodeMobileApp.swift` (`@main`).

## Conventions That Trip You Up

- **`@Observable` not `ObservableObject`:** All ViewModels use the `@Observable` macro. Do not add `@Published` or conform to `ObservableObject`.
- **Async/await only:** No completion handlers, no Combine (except one NotificationCenter publisher in `AppLifecycleManager`). All networking is `async/await`.
- **`NavigationStack`** not `NavigationView`.
- **SwiftData init order matters:** `ModelContext` must be created from the resolved `ModelContainer`, not from a stored reference. See recent commits for the fix pattern.
- **Keychain service ID:** `com.opencode.mobile`. Use `KeychainHelper` — don't write raw Security framework calls.
- **Background behavior:** iOS suspends URLSession in background. The app falls back to HTTP polling when backgrounded. Don't assume SSE stays connected.

## Project Regeneration

If you modify file structure (add/remove Swift files), the `project.yml` sources entry uses `path: OpenCodeMobile` which auto-includes. After changes:

```bash
xcodegen generate --project OpenCodeMobile
```

Then open the generated `.xcodeproj` in Xcode to verify.

## Git Workflow

- Branch: `main`
- Commits: conventional style (`fix:`, `feat:`, etc.)
- Remote: `https://github.com/jpg965/bfproject.git`
