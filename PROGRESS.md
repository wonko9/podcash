# Podcash Build Progress

## Current Status
**Milestone 1: Project Skeleton** - VERIFIED
**Milestone 2: Data Models + Add Podcast** - VERIFIED (added search + Apple/PocketCasts URL support)
**Milestone 3: Episode List** - VERIFIED
**Milestone 4: Audio Playback** - VERIFIED
**Milestone 5: Downloads + Offline Handling** - COMPLETE
**Milestone 6: Starring + Queue** - COMPLETE
**Milestone 7: Folders** - COMPLETE
**Milestone 8: Playback Speed + Sleep Timer** - COMPLETE
**Milestone 9: Polish + Sync** - COMPLETE

## Completed Work

### Milestone 1: Project Skeleton
- [x] Created Xcode project with xcodegen
- [x] SwiftUI app entry point (PodcashApp.swift)
- [x] Tab bar with 5 tabs (ContentView.swift)
- [x] Placeholder views: LibraryView, DownloadsView, StarredView, QueueView, SettingsView
- [x] Info.plist with background audio mode
- [x] Assets.xcassets structure

## Remaining Milestones

### Milestone 2: Data Models + Add Podcast
- [x] SwiftData models: Podcast, Episode, Folder, QueueItem, AppSettings
- [x] FeedService for RSS parsing (add FeedKit via SPM)
- [x] AddPodcastView with URL input
- [x] Display podcasts in LibraryView
- **Test:** Paste podcast URL, see it appear with artwork

### Milestone 3: Episode List
- [x] PodcastDetailView showing episodes
- [x] EpisodeRowView with metadata
- [x] Sort by newest/oldest
- [x] Date and duration formatting extensions
- [x] Pull-to-refresh for new episodes
- [x] Star filter toggle
- **Test:** Tap podcast, see episode list

### Milestone 4: Audio Playback
- [x] AudioPlayerManager singleton
- [x] MiniPlayer bar
- [x] NowPlayingView (full screen)
- [x] Lock screen controls (MPNowPlayingInfoCenter, MPRemoteCommandCenter)
- [x] Background audio
- [x] Play/pause/seek/skip controls
- [x] Playback speed control
- [x] Progress saving and resume
- **Test:** Play episode, lock phone, audio continues

### Milestone 5: Downloads + Offline Handling
- [x] DownloadManager with URLSession background configuration
- [x] Download progress tracking
- [x] DownloadsView showing all downloaded episodes
- [x] Offline playback (use local file when available)
- [x] Network connectivity detection (NWPathMonitor)
- [x] Offline mode indicator in UI
- [x] Filter lists by: Starred (toggle), Downloaded (toggle) - can combine both
- [x] Auto-filter to downloaded when offline
- [x] Disable streaming when offline (only allow downloaded episodes)
- [x] Delete downloads (single, per-podcast, all)
- [x] Auto-download when playing or starring (queue auto-download in Milestone 6)
- **Test:** Download episode, enable airplane mode, verify only downloaded episodes playable

**Future consideration:** Add settings to manage excessive downloading (e.g., max storage, auto-delete old downloads, download only on WiFi)

### Milestone 6: Starring + Queue
- [x] Star/unstar episodes (tappable star button on episode rows)
- [x] StarredView with sort/filter controls
- [x] QueueManager service
- [x] QueueView with reordering and "Now Playing" section
- [x] "Play Next" and "Add to Queue" context menu options
- [x] Auto-download when adding to queue
- [x] Auto-advance playback (plays next queued episode when current finishes)
- [x] Simulated offline mode toggle in Settings (for testing)
- **Test:** Star episodes, add to queue, verify auto-advance

### Milestone 7: Folders
- [x] Folder CRUD operations (create, rename, delete)
- [x] Add/remove podcasts from folders (long-press podcast in Library)
- [x] Folders section in Library tab
- [x] FolderDetailView with two view modes:
  - **Podcasts view**: List of podcasts in the folder (tap to open podcast)
  - **Episodes view**: Combined episodes from all podcasts in folder
- [x] Episodes view features:
  - Sort by newest/oldest
  - Filter by starred
  - Filter by downloaded
  - Same episode row with star/download buttons
- [x] Toggle between Podcasts/Episodes view modes (segmented control)
- [x] Color picker for folders
- **Test:** Create folder, add podcasts, switch between views, verify sort/filter work

### Milestone 8: Playback Speed + Sleep Timer
- [x] Speed picker (0.5x - 3.0x) in NowPlayingView
- [x] Per-podcast speed override (via podcast detail menu)
- [x] Sleep timer with preset durations and "End of Episode" option
- [x] Customizable skip forward interval (default 30s, configurable in Settings)
- [x] Customizable skip backward interval (default 15s, configurable in Settings)
- [x] Skip icons update dynamically based on interval setting
- **Test:** Change speed, set timer, customize skip intervals, verify all work

### Milestone 9: Polish + Sync
- [x] iCloud Drive sync (not CloudKit) - SyncService with JSON file in iCloud Drive
  - Syncs: podcast subscriptions, folders, episode states (played/starred/position), settings
  - Auto-syncs on app launch
  - Manual "Sync Now" button in Settings
- [x] Empty states - ContentUnavailableView throughout app
- [x] Error handling - sync errors shown in Settings
- [x] Pull-to-refresh - implemented in PodcastDetailView
- **Test:** Install on second device, verify sync

## Architecture Decisions

1. **No Apple Developer subscription required** - runs via free Xcode signing (7-day refresh)
2. **iCloud sync via iCloud Drive** (JSON file) instead of CloudKit (avoids paid account requirement)
3. **No push notifications** - manual refresh only
4. **Files kept under 300 lines** - extract components early
5. **DRY principles** - shared components for episodes, context menus, formatters

## Test Podcast Feeds
- ATP: `https://atp.fm/episodes?format=rss`
- The Talk Show: `https://daringfireball.net/thetalkshow/rss`
- Syntax: `https://feed.syntax.fm/rss`

## Project Structure
```
Podcash/
├── PodcashApp.swift
├── ContentView.swift
├── Info.plist
├── Assets.xcassets/
├── Models/           (Milestone 2)
├── Services/         (Milestone 2+)
├── Views/
│   ├── Library/
│   ├── Downloads/
│   ├── Starred/
│   ├── Queue/
│   ├── Settings/
│   ├── Podcast/      (Milestone 3)
│   ├── Player/       (Milestone 4)
│   └── Folders/      (Milestone 7)
├── Components/       (Milestone 6+)
└── Extensions/       (Milestone 3)
```
