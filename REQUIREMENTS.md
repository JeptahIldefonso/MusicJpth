# MUSIC OASIS — TECH STACK & REQUIREMENTS

## 01 — Technology Stack

### Core

| Layer | Technology | Purpose |
|---|---|---|
| App framework | **Flutter** | Cross-platform mobile/desktop application |
| Language | **Dart** | Application logic |
| State management | **Riverpod** | Reactive state and dependency management |
| Database | **SQLite** | Local music library and metadata |
| Audio engine | **just_audio** | Local audio playback |
| Background audio | **audio_service / platform media APIs** | Background playback and system media controls |
| File access | **Platform file APIs + file picker** | Select and access music folders/files |
| Metadata | **Audio metadata parser/package** | Read title, artist, album, artwork, etc. |
| Image cache | **Local disk/cache** | Efficient album artwork |
| Navigation | **Flutter Router / go_router if needed** | App navigation |
| Testing | **Flutter test + integration tests** | Unit/widget/platform testing |

---

# 02 — Platform Targets

## Primary

### Android

Highest priority. Mobile primary target.

Must support:

- Local music scanning
- Offline playback
- Background playback
- Lock-screen controls
- Media notification
- Bluetooth/headset controls where supported
- Android storage permissions
- Screen-off playback

### Windows

Desktop primary target.

Must support:

- Local music scanning
- Offline playback
- Folder selection
- Large music libraries
- Desktop navigation
- Background playback while the PC is awake

## Secondary

- iOS
- macOS
- Linux

Do not sacrifice Android/Windows stability just to support every platform immediately.

---

# 03 — Why Flutter

Flutter is the primary framework because Music Oasis needs:

```text
One codebase
      ↓
Android
iOS
Windows
macOS
Linux
```

Advantages:

- Fast development
- Native compiled applications
- Strong UI control
- Good performance
- Shared code
- Responsive layouts
- Suitable for offline applications

Do not create separate applications in:

```text
Kotlin
Swift
C#
```

unless a platform-specific feature requires native implementation.

---

# 04 — Dart

Use Dart for:

- UI
- Business logic
- State management
- Database repositories
- Scanner orchestration
- Player controllers
- Application services

Keep Dart code:

- Typed
- Modular
- Testable
- Readable

Avoid unnecessary metaprogramming or overly complex abstractions.

---

# 05 — SQLite

SQLite is the primary persistent database.

Use it for:

```text
Songs
Artists
Albums
Playlists
Playlist songs
Favorites
Playback history
Music folders
Scan metadata
```

Do NOT store audio files inside SQLite.

Correct:

```text
Music/
├── song.mp3
├── song.flac
└── song.m4a

Music Oasis Database
└── music.db
```

SQLite contains references and metadata.

---

# 06 — SQLite Requirements

The database must support:

- Efficient queries
- Indexes
- Transactions
- Migrations
- Upserts
- Large libraries
- Safe interrupted writes

Important indexes should exist for frequently queried fields such as:

```text
title
artist
album
path
date_added
last_played
```

Do not query the entire database unnecessarily.

---

# 07 — State Management

Use **Riverpod**.

Primary application states:

```text
PlayerState
LibraryState
ScannerState
SearchState
PlaylistState
SettingsState
```

Riverpod should manage:

- UI state
- Reactive updates
- Service dependencies
- Player state exposure
- Scanner progress
- Loading/error states

SQLite remains the persistent source of truth.

---

# 08 — Audio Playback

Use **just_audio** or an equivalent mature Flutter audio engine.

Requirements:

- Local file playback
- Play
- Pause
- Resume
- Seek
- Next
- Previous
- Queue
- Shuffle
- Repeat
- Playback position
- Duration
- Playback state

Audio playback must be independent from UI screens.

---

# 09 — Background Audio

Music Oasis must support background audio.

Architecture:

```text
Flutter UI
     ↓
Player Controller
     ↓
Audio Service
     ↓
Platform Media Session
     ↓
Operating System
```

The player must continue when:

- User leaves the player screen
- User navigates to Home
- User opens another application
- Phone screen turns off

Where supported by the operating system.

---

# 10 — Android Media Notification

Android is a primary target.

Music Oasis must provide a normal Android media notification.

Expected:

```text
┌───────────────────────────────┐
│ MUSIC OASIS                   │
│                               │
│ Song Title                    │
│ Artist                        │
│                               │
│    ◀       ▶       ▶          │
└───────────────────────────────┘
```

Controls:

- Previous
- Play/Pause
- Next

Where supported, also provide:

- Seek
- Playback position
- Queue
- Album artwork

The notification must use Android's media session system rather than being a custom fake notification.

---

# 11 — Lock Screen

When the phone is locked:

```text
Screen OFF
     ↓
Music continues
     ↓
Lock-screen media controls
```

Users should be able to:

- Pause
- Resume
- Previous
- Next

without opening the application.

The lock-screen state must remain synchronized with the application.

---

# 12 — Bluetooth / Headset Controls

Where supported, handle:

- Bluetooth play/pause
- Bluetooth next
- Bluetooth previous
- Headphone controls
- Car media controls

Use the operating system's media session/audio focus mechanisms.

Do not implement custom hardware-control protocols.

---

# 13 — Audio Focus

Handle:

- Phone calls
- Other music applications
- Bluetooth connection/disconnection
- Headphone removal
- System audio interruptions

Music Oasis should follow platform audio-focus behavior.

Possible responses:

```text
Pause
Duck volume
Resume
```

depending on the interruption and platform.

---

# 14 — File Scanner

Music Oasis needs a local music scanner.

Scanner must:

- Select folders
- Recursively discover files
- Detect supported extensions
- Read metadata
- Update SQLite
- Detect new files
- Detect changed files
- Detect missing files
- Avoid duplicates

The scanner must not freeze the UI.

---

# 15 — Supported Music Formats

Initial target:

```text
MP3
FLAC
WAV
M4A
AAC
OGG
OPUS
```

Actual playback support must be verified per platform/audio engine.

Do not promise unsupported formats.

---

# 16 — Metadata

Extract when available:

```text
Title
Artist
Album
Album Artist
Genre
Year
Track Number
Disc Number
Duration
Artwork
```

Metadata can be missing or corrupted.

The application must continue working.

Example:

```text
Unknown Artist
Unknown Album
```

is acceptable fallback behavior.

---

# 17 — Filesystem Storage

Actual music files stay where the user placed them.

Example:

```text
Phone
└── Music
    ├── Artist A
    │   ├── Song 1.mp3
    │   └── Song 2.flac
    └── Artist B
        └── Song 3.m4a
```

Music Oasis stores references to those files.

Never automatically copy thousands of music files into an application folder.

---

# 18 — File Safety

The scanner must be read-only.

Never automatically:

- Delete music
- Rename music
- Move music
- Modify metadata
- Convert files
- Overwrite files

The user's music is considered user-owned data.

---

# 19 — Incremental Scanning

Do not perform a complete metadata scan every time the app launches.

Preferred:

```text
Existing Database
       ↓
Check selected folders
       ↓
Detect changes
       ↓
Process only changes
```

Use:

- File path
- File size
- Modified time
- Stable identifiers where available

Avoid expensive full-file hashing unless necessary.

---

# 20 — Startup Performance

The app must load the existing SQLite library before performing expensive filesystem work.

Preferred:

```text
App Launch
    ↓
Open SQLite
    ↓
Load existing library
    ↓
Show UI
    ↓
Background verification/scan
```

Do not make the user wait for a 10,000-file scan before seeing the application.

---

# 21 — Large Library

Design for:

```text
100 songs
1,000 songs
5,000 songs
10,000+ songs
```

Use:

- SQLite indexes
- Lazy lists
- Pagination when useful
- Incremental scanning
- Artwork caching
- Efficient queries

Do not load every song and every artwork image into memory simultaneously.

---

# 22 — Search

Search must be local.

```text
User types
     ↓
Debounce
     ↓
SQLite query
     ↓
Results
```

Search:

- Songs
- Artists
- Albums
- Playlists
- Genres

Never scan the filesystem for every search.

---

# 23 — Artwork

Artwork should be cached locally.

Use:

```text
Original artwork
      ↓
Cache
      ↓
Thumbnail
      ↓
Library UI
```

Use higher-resolution artwork only where necessary.

Do not decode thousands of full-resolution album covers simultaneously.

---

# 24 — Navigation

## Mobile

Use three primary destinations:

```text
Home
Search
Library
```

Plus:

```text
Persistent Mini Player
```

Navigation should feel familiar to modern music applications but have Music Oasis's own visual identity.

---

# 25 — Mini Player

The mini-player should appear above mobile navigation when music is playing.

```text
┌──────────────────────────────┐
│ [ART] Song Title       ▶      │
├──────────────────────────────┤
│ HOME   SEARCH   LIBRARY       │
└──────────────────────────────┘
```

Tap:

```text
Mini Player
     ↓
Full Player
```

---

# 26 — Full Player

Full player:

```text
Artwork
Title
Artist
Album
Progress
Play/Pause
Previous
Next
Shuffle
Repeat
Favorite
Queue
```

It must remain synchronized with:

- Mini-player
- Notification
- Lock screen
- Bluetooth controls

---

# 27 — Desktop Navigation

Windows/macOS/Linux should use a desktop layout.

```text
Sidebar
├── Home
├── Search
├── Library
├── Playlists
└── Settings

Main Content

Bottom Player
```

Do not force mobile bottom navigation onto desktop.

---

# 28 — Offline Requirement

Core functionality must work with:

```text
Wi-Fi OFF
Mobile Data OFF
Airplane Mode ON
```

No server is required.

Do not introduce network dependencies for MVP.

---

# 29 — Backend

### MVP backend:

**None.**

Music Oasis is a local application.

Do not create:

```text
Node.js backend
Python backend
REST API
PostgreSQL server
MongoDB server
Firebase
```

unless a future requirement specifically needs online functionality.

---

# 30 — Cloud

Cloud functionality is NOT part of MVP.

Future possibilities:

- Cloud backup
- Cross-device synchronization
- Online metadata
- Account system

These must remain optional future features.

---

# 31 — Performance Requirements

The application should avoid:

- UI blocking
- Large synchronous scans
- Excessive rebuilds
- Repeated metadata parsing
- Repeated artwork decoding
- Unnecessary background processes
- Full database reloads
- Full filesystem scans on every launch

Prioritize:

```text
Fast startup
Fast navigation
Fast search
Smooth playback
Low memory
Low battery
```

---

# 32 — Background Scanning

Scanning should happen asynchronously.

Example:

```text
UI
│
├── User continues browsing
│
└── Scanner
      ↓
   Background work
      ↓
   SQLite
```

Show progress:

```text
Scanning Music

1,284 / 5,000

Current:
Song.mp3
```

The user should not lose control of the app during scanning.

---

# 33 — Battery Requirements

Do not continuously scan the filesystem.

Avoid:

```text
Scan every second
Scan every minute
```

Prefer:

- Manual scan
- Incremental scan
- Platform file-system events where available
- Lightweight startup verification

Stop scanner work when scanning finishes.

---

# 34 — Phone Sleep

The application must support:

### Screen locked

Music continues through the operating system's background audio system.

### Actual device sleep/suspension

The OS controls application execution.

Do not attempt to bypass system power management.

---

# 35 — Computer Sleep

Windows/macOS/Linux applications can continue working when:

- Application is minimized
- Screen/display is off
- Computer remains awake

Actual system sleep suspends normal application execution.

Do not claim the app can scan or play normally while the entire computer is asleep.

---

# 36 — Permissions

Request permissions only when needed.

Preferred:

```text
Add Music Folder
      ↓
Explain access
      ↓
Request permission
      ↓
Scan
```

Do not request every possible permission on first launch.

---

# 37 — Architecture

Use:

```text
Presentation
     ↓
State
     ↓
Repository
     ↓
Service
     ↓
Database / Filesystem / Audio
```

Recommended directories:

```text
lib/
├── app/
├── core/
├── data/
├── services/
└── features/
```

---

# 38 — Testing

Test:

### Scanner

- Empty folder
- Single file
- 1,000 files
- 10,000 files
- Duplicate files
- Missing files
- Moved files
- Corrupt files
- Missing metadata
- Permission denied
- Interrupted scan

### Player

- Play
- Pause
- Resume
- Seek
- Previous
- Next
- Shuffle
- Repeat
- Queue
- Screen lock
- Bluetooth
- Headphones
- Audio interruptions
- App switching

### Database

- First launch
- App restart
- Database migration
- Interrupted scan
- Large library

---

# 39 — Code Quality

Code must be:

- Strongly typed
- Modular
- Readable
- Testable
- Maintainable

Avoid:

- Giant widgets
- Giant services
- Global mutable state
- Duplicate player logic
- Duplicate database logic
- Unnecessary abstractions

---

# 40 — Dependency Policy

Every dependency must have a clear purpose.

Before adding one:

1. Check existing dependencies.
2. Check platform compatibility.
3. Check maintenance status.
4. Consider application size.
5. Consider performance.
6. Prefer established packages.

Do not install multiple packages that solve the same problem.

---

# 41 — UI Performance

Use:

- `const` widgets where possible
- Lazy lists
- Lazy grids
- Stable keys
- Fine-grained state providers
- Cached images
- Efficient SQLite queries

Avoid rebuilding the whole application for:

```text
Playback position update
```

A progress update should affect only the necessary UI.

---

# 42 — Error Handling

Never crash because one audio file is bad.

Example:

```text
1,000 files scanned
999 indexed
1 failed
```

Continue scanning.

Show users understandable messages.

Keep technical errors in logs.

---

# 43 — Database Integrity

Use transactions for grouped writes.

Support database migrations.

Never destroy existing user library data during an application update.

An interrupted scan must not corrupt the database.

---

# 44 — Security & Privacy

Default behavior:

```text
No account
No server
No upload
No tracking required
Music remains local
Metadata remains local
```

Do not collect unnecessary user data.

---

# 45 — Recommended Package Categories

Use packages for:

```text
SQLite
State management
Audio playback
Background audio
File/folder selection
Metadata parsing
Image caching
Navigation
```

Do not blindly copy package names from documentation if a newer maintained alternative is required.

Verify package compatibility before implementation.

---

# 46 — Development Order

Implement in this order:

```text
1. Flutter project
2. Theme
3. Navigation
4. SQLite
5. Folder selection
6. Music scanner
7. Metadata extraction
8. Library
9. Audio engine
10. Background audio
11. Android media notification
12. Lock-screen controls
13. Mini player
14. Full player
15. Search
16. Playlists
17. Favorites
18. Playback history
19. Artwork cache
20. Performance testing
21. Error handling
22. Android release testing
23. Windows testing
```

Do not build all features simultaneously.

---

# 47 — MVP Acceptance Criteria

The MVP must satisfy:

```text
[ ] App launches offline
[ ] User can select music folder
[ ] Scanner finds music
[ ] Metadata is extracted
[ ] SQLite library works
[ ] Library loads quickly
[ ] Search works offline
[ ] Local audio playback works
[ ] Play/pause works
[ ] Previous/next works
[ ] Queue works
[ ] Mini-player works
[ ] Full player works
[ ] Background playback works on supported platforms
[ ] Android media notification works
[ ] Lock-screen controls work
[ ] Bluetooth/headset controls work where supported
[ ] Playlists work
[ ] Favorites work
[ ] Playback history works
[ ] Large libraries remain responsive
[ ] Scanner does not freeze UI
[ ] Bad files do not crash scanner
[ ] User music is never automatically modified
```

---

# 48 — NON-GOALS

Do not implement these during MVP:

```text
[ ] Streaming
[ ] User accounts
[ ] Cloud sync
[ ] Social features
[ ] Online recommendations
[ ] AI recommendations
[ ] Online lyrics
[ ] Online artwork
[ ] Cloud backup
[ ] Subscription system
```

---

# 49 — Final Stack

The intended MVP stack is:

```text
┌─────────────────────────────────────┐
│              MUSIC OASIS            │
├─────────────────────────────────────┤
│ UI                                  │
│ Flutter                             │
├─────────────────────────────────────┤
│ Language                            │
│ Dart                                │
├─────────────────────────────────────┤
│ State                               │
│ Riverpod                            │
├─────────────────────────────────────┤
│ Navigation                          │
│ Flutter Router / go_router           │
├─────────────────────────────────────┤
│ Local Database                      │
│ SQLite                              │
├─────────────────────────────────────┤
│ Audio                               │
│ just_audio                          │
├─────────────────────────────────────┤
│ Background Audio                    │
│ audio service + native media APIs  │
├─────────────────────────────────────┤
│ Files                               │
│ Native filesystem + file picker     │
├─────────────────────────────────────┤
│ Metadata                            │
│ Audio metadata parser               │
├─────────────────────────────────────┤
│ Artwork                             │
│ Local cache                         │
├─────────────────────────────────────┤
│ Backend                             │
│ NONE                                │
└─────────────────────────────────────┘
```

## Final principle

> **Keep the core stack small.**

Music Oasis is primarily:

**Flutter + Dart + SQLite + Audio Engine + Native Background Media**

Everything else should exist only when a real requirement justifies it.