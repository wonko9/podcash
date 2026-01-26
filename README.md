# Podcash

A personal iOS podcast player built with SwiftUI and SwiftData.

## Features

- **Podcast Management**: Subscribe to podcasts via RSS feed URL or search
- **Offline Playback**: Download episodes for offline listening
- **Folders**: Organize podcasts into color-coded folders
- **Queue**: Build a queue with "Play Next" and "Add to Queue"
- **Starring**: Star episodes to save them for later
- **Sleep Timer**: Set a timer or stop at end of episode
- **Playback Speed**: Global speed (0.5x-3x) with per-podcast overrides
- **Customizable Skip**: Configure skip forward/backward intervals
- **iCloud Sync**: Sync subscriptions, folders, and listening progress across devices (requires paid Apple Developer account)
- **Listening Stats**: Track your listening habits

## Requirements

- iOS 18.0+
- Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

1. Install XcodeGen if you haven't:
   ```bash
   brew install xcodegen
   ```

2. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/podcash.git
   cd podcash
   ```

3. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

4. Open the project in Xcode:
   ```bash
   open Podcash.xcodeproj
   ```

5. Select your Development Team in Xcode:
   - Select the Podcash target
   - Go to Signing & Capabilities
   - Select your team from the dropdown

6. Build and run on your device or simulator

### iCloud Sync (Optional)

iCloud sync requires a paid Apple Developer account. To enable it:

1. Add the iCloud capability in Xcode (Signing & Capabilities)
2. Enable "iCloud Documents" with container `iCloud.com.personal.podcash`
3. Create `Podcash/Podcash.entitlements` with the iCloud container identifiers

Without iCloud, the app works fully but sync is disabled.

## Architecture

- **SwiftUI** for the UI layer
- **SwiftData** for persistence
- **AVFoundation** for audio playback
- **iCloud Drive** for cross-device sync (no CloudKit required)

## Project Structure

```
Podcash/
├── Models/          # SwiftData models
├── Services/        # Business logic (AudioPlayer, Download, Sync, etc.)
├── Views/           # SwiftUI views organized by feature
│   ├── Library/
│   ├── Player/
│   ├── Podcast/
│   ├── Folders/
│   ├── Downloads/
│   ├── Starred/
│   ├── Queue/
│   └── Settings/
└── Extensions/      # Swift extensions
```

## License

MIT License - feel free to use this for your own podcast app!
