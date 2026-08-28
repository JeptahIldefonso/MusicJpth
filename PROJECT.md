# MUSIC OASIS — PROJECT

## 01 — Project Overview

**Music Oasis** is a fast, offline-first music player and local music file scanner.

The application scans music stored on the user's device, indexes the files locally, reads metadata, and provides a fast music-library and playback experience.

### Primary goals

- Offline-first
- Fast startup
- Fast library browsing
- Fast local search
- Smooth audio playback
- Low memory usage
- Low battery usage
- Reliable background playback
- Large-library support
- Mobile-first design
- Desktop support

Music Oasis must not depend on a server or internet connection for core functionality.

---

# 02 — Critical Architecture Principle

There are two separate concerns:

```text
MUSIC FILES
     ↓
Filesystem
     ↓
Scanner
     ↓
SQLite Library
     ↓
Music Player
```

The actual music files remain on the user's device.

SQLite stores metadata and references to those files.

Never store complete audio files inside SQLite.

---

# 03 — Target Platforms

Primary:

- Android
- Windows

Secondary:

- iOS
- macOS
- Linux

The application should use a shared Flutter/Dart codebase where possible.

Platform-specific functionality must be isolated behind services.

---

# 04 — Technology Stack

## Application

**Flutter + Dart**

Reason:

- One codebase
- Android support
- iOS support
- Windows support
- macOS support
- Linux support
- Good performance
- Native compilation
- Suitable for offline applications

## Database

**SQLite**

Used for:

- Songs
- Artists
- Albums
- Playlists
- Favorites
- Playback history
- Music folders
- Scan information

## State Management

**Riverpod**

Used for:

- Player state
- Library state
- Scan state
- Search state
- UI state
- Dependency management

## Audio

Use a mature Flutter audio playback solution such as:

**just_audio**

Background playback must be handled through the appropriate platform audio/background services.

## Filesystem

Use platform-appropriate file APIs and folder/file pickers.

Do not assume Android, iOS, Windows, and macOS have identical filesystem behavior.

---

# 05 — Offline-First Requirement

Music Oasis must work without internet.

The following must work offline:

```text
App Launch
Library
Search
Music Scan
Metadata
Playback
Playlists
Favorites
History
Settings
```

No API request should be required for these functions.

Do not introduce:

- Firebase
- Cloud database
- Authentication
- REST API
- WebSocket
- Cloud storage

unless explicitly required later.

---

# 06 — Performance Requirements

Performance is a core product requirement.

The application should remain responsive when the library contains:

```text
100 songs
1,000 songs
5,000 songs
10,000+ songs
```

The exact practical limit depends on the device.

## Never

Do not:

- Load the entire music library into memory unnecessarily
- Scan the entire filesystem on every app launch
- Parse every file's metadata every time the library opens
- Decode all album artwork simultaneously
- Perform large database operations on the UI thread
- Rebuild the entire library UI after one song changes
- Keep unnecessary background processes running

## Prefer

Use:

- SQLite queries
- Database indexes
- Pagination/lazy loading
- Cached metadata
- Cached artwork
- Incremental scanning
- Background/isolate processing where appropriate
- Reactive state updates
- Debounced search
- Efficient list/grid builders

---

# 07 — Music Scanner

The scanner is one of the most important systems.

## Scan flow

```text
User selects folder
        ↓
Check permission
        ↓
Discover files
        ↓
Filter audio formats
        ↓
Check existing database records
        ↓
Read metadata only when needed
        ↓
Insert/update SQLite
        ↓
Update library
```

## Supported formats

Initial target:

```text
.mp3
.flac
.wav
.m4a
.aac
.ogg
.opus
```

Actual playback support depends on the platform/audio engine.

---

# 08 — Incremental Scanning

Do not completely rebuild the database every time.

Example:

```text
Previous scan
1,000 songs

User adds
20 songs

Next scan
↓
Check existing records
↓
Process only new/changed files
```

The scanner should identify:

- New files
- Removed files
- Changed files
- Existing files

Use stable identifiers where possible.

Possible identification data:

```text
Path
File size
Modified timestamp
Optional file fingerprint
```

Do not calculate expensive full-file hashes for every scan unless necessary.

---

# 09 — Background Scanning

Scanning must not freeze the UI.

Bad:

```text
Scan 10,000 files
        ↓
UI freezes
```

Good:

```text
UI
│
├── Scanner
│     ↓
│  Background work
│
└── Progress updates
```

Display progress:

```text
Scanning Music

1,284 / 5,000

MP3 files detected
```

The user should still be able to navigate the application where practical.

---

# 10 — Music Database

Conceptual structure:

```text
MusicFolder
    │
    └── Song
          │
          ├── Artist
          ├── Album
          ├── Favorite
          ├── PlaybackHistory
          └── PlaylistSong
                    │
                    └── Playlist
```

## Song

Possible fields:

```text
id
path
title
artistId
albumId
duration
trackNumber
discNumber
genre
year
format
fileSize
modifiedTime
artworkPath
dateAdded
lastPlayed
```

Do not assume every field exists.

Music files can have incomplete metadata.

---

# 11 — Filesystem Safety

Music Oasis must treat user files as user-owned data.

The scanner must be read-only by default.

Never automatically:

- Delete music
- Rename music
- Move music
- Overwrite music
- Modify metadata
- Convert music
- Upload music

If file management is added later, destructive actions must require explicit user confirmation.

---

# 12 — Handling Missing Files

A music file may be moved or deleted outside the application.

Example:

```text
SQLite
    ↓
song.mp3
    ↓
File no longer exists
```

The application must not crash.

Instead:

```text
FILE UNAVAILABLE

This song may have been moved or deleted.

[ RESCAN ]
```

The database can mark the file as unavailable until the next scan.

---

# 13 — Audio Playback

Playback must remain independent from the UI.

Architecture:

```text
UI
 ↓
Player Controller
 ↓
Audio Service
 ↓
Audio Engine
 ↓
Local File
```

The UI must not directly control the underlying audio engine everywhere.

## Required controls

- Play
- Pause
- Resume
- Seek
- Previous
- Next
- Queue
- Shuffle
- Repeat
- Volume where supported
- Favorite

---

# 14 — Background Playback

This is critical for mobile.

The player should continue playing when:

- Screen is locked
- User switches apps
- App UI is not visible
- Phone display turns off

Use platform-supported background audio mechanisms.

The app must not rely on keeping the Flutter UI active indefinitely.

---

# 15 — Important Clarification: Phone Sleep vs Computer Sleep

### Mobile phone

When the screen is locked, Music Oasis should continue audio playback using the operating system's background audio facilities.

```text
Screen OFF
    ↓
OS background audio
    ↓
Music continues
```

### Computer

A sleeping computer generally suspends application execution.

Therefore:

> Music Oasis cannot reliably continue scanning or playing audio while the computer itself is actually asleep.

It can continue when:

- The display is off
- The application is minimized
- The computer remains awake

It cannot depend on normal application execution while the operating system is suspended.

Do not attempt to bypass OS sleep behavior.

---

# 16 — Battery Efficiency

Offline does not automatically mean battery-efficient.

Avoid unnecessary background work.

After scanning completes:

```text
Scanner
   ↓
STOP
```

Do not continuously monitor the entire filesystem unless the user explicitly enables such functionality.

Prefer:

- Manual scan
- Startup lightweight verification
- User-selected folder monitoring where platform APIs support it
- Event-based changes instead of constant polling

Avoid:

```text
Every 1 second:
scan entire Music folder
```

---

# 17 — Library Loading

The library should open quickly.

Do not scan the filesystem before displaying the existing database.

Preferred startup:

```text
App starts
   ↓
Load SQLite library
   ↓
Show music immediately
   ↓
Perform lightweight background verification
```

This makes the application feel instant even when the device contains thousands of files.

---

# 18 — Search

Search must use SQLite/database queries.

Do not scan the filesystem for every search.

Bad:

```text
User types "Eminem"
        ↓
Scan filesystem
```

Good:

```text
User types "Eminem"
        ↓
SQLite query
        ↓
Results
```

Use indexes for frequently searched fields.

Search:

- Title
- Artist
- Album
- Playlist
- Genre

Use debouncing to avoid unnecessary queries on every keystroke.

---

# 19 — Artwork

Artwork can consume significant memory.

Use:

- Disk caching
- Thumbnail generation
- Lazy loading
- Image cache limits
- Appropriate resolution

Do not load full-resolution artwork for every visible list item.

Example:

```text
Library List
   ↓
Small thumbnail

Full Player
   ↓
Higher-resolution artwork
```

---

# 20 — Navigation

Mobile navigation should resemble familiar modern music-player behavior.

Primary navigation:

```text
HOME
SEARCH
LIBRARY
```

Persistent mini-player:

```text
┌───────────────────────────────┐
│ [ART] Song Title       ▶      │
├───────────────────────────────┤
│ HOME   SEARCH   LIBRARY       │
└───────────────────────────────┘
```

Full player:

```text
Mini Player
     ↓
Full Player
```

The player should remain globally accessible.

---

# 21 — Desktop Navigation

Desktop should use a sidebar.

```text
┌──────────────┬─────────────────────┐
│ MUSIC OASIS  │                     │
│              │     CONTENT         │
│ Home         │                     │
│ Search       │                     │
│ Library      │                     │
│ Playlists    │                     │
│              │                     │
│ Settings     │                     │
├──────────────┴─────────────────────┤
│ Mini Player                         │
└────────────────────────────────────┘
```

Do not force mobile bottom navigation onto desktop.

---

# 22 — Application Architecture

Recommended:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   └── utils/
│
├── data/
│   ├── database/
│   ├── models/
│   └── repositories/
│
├── services/
│   ├── audio/
│   ├── scanner/
│   ├── metadata/
│   ├── artwork/
│   └── permissions/
│
└── features/
    ├── home/
    ├── search/
    ├── library/
    ├── playlists/
    ├── player/
    ├── scanner/
    └── settings/
```

---

# 23 — Architecture Rule

Use:

```text
UI
 ↓
State
 ↓
Repository
 ↓
Service
 ↓
Database / Filesystem / Audio
```

Do not put:

- SQLite queries
- Filesystem scanning
- Audio engine logic
- Permission handling

directly inside UI widgets.

---

# 24 — State Management

Use Riverpod for application state.

Important state:

```text
PlayerState
LibraryState
ScannerState
SearchState
PlaylistState
SettingsState
```

Example:

```text
ScannerState

idle
scanning
completed
cancelled
error
```

Do not store the entire music database inside Riverpod state.

SQLite remains the source of persistent library data.

---

# 25 — Offline Data Ownership

```text
USER DEVICE
│
├── Music files
│
└── Music Oasis data
    ├── SQLite database
    ├── Artwork cache
    └── App preferences
```

No server is required.

The application should remain useful even if:

```text
Wi-Fi OFF
Mobile Data OFF
Airplane Mode ON
```

---

# 26 — Permissions

Request permissions only when required.

Do not request every permission during first launch.

Preferred:

```text
First launch
    ↓
Explain feature
    ↓
User chooses music folder
    ↓
Request required permission
    ↓
Scan
```

If permission is denied:

```text
MUSIC ACCESS REQUIRED

Choose a music folder to build your library.
```

Do not repeatedly spam permission dialogs.

---

# 27 — Startup Requirements

Target startup flow:

```text
Launch
 ↓
Initialize essential services
 ↓
Open SQLite
 ↓
Load cached library
 ↓
Render UI
 ↓
Initialize player
 ↓
Perform lightweight background tasks
```

Do not wait for a full filesystem scan before showing the UI.

---

# 28 — Large Library Requirements

The application should be designed for large libraries from the beginning.

Avoid assuming:

```text
50 songs
```

Design for:

```text
1,000+
5,000+
10,000+
```

Use:

- Pagination
- Lazy lists
- Database indexes
- Efficient queries
- Cached artwork
- Incremental scanning

---

# 29 — Crash Safety

The application must gracefully handle:

- Corrupt audio files
- Unsupported formats
- Permission failures
- Missing files
- Invalid metadata
- Database errors
- Interrupted scans
- Storage failures
- Audio playback errors

A single bad music file must not crash the entire scan.

Example:

```text
1,000 files scanned
999 successful
1 unreadable

Continue scanning.
```

---

# 30 — Scan Recovery

If the app closes during scanning:

```text
Previous scan interrupted
        ↓
Restart app
        ↓
Continue/redo incremental scan
        ↓
Existing database remains valid
```

Database writes should be safe and transactional where appropriate.

Never leave the library in a corrupt state because scanning was interrupted.

---

# 31 — Performance Philosophy

Performance should come from architecture rather than hacks.

### Priority

```text
1. Correctness
2. Responsiveness
3. Efficient storage
4. Efficient scanning
5. Smooth playback
6. Battery efficiency
7. Visual polish
```

Do not sacrifice correctness for micro-optimizations.

---

# 32 — Development Order

Build the application incrementally.

```text
1. Flutter project
2. App theme
3. Navigation
4. SQLite
5. Music folder selection
6. Scanner
7. Metadata extraction
8. Library
9. Audio playback
10. Background playback
11. Mini player
12. Full player
13. Search
14. Playlists
15. Favorites
16. Playback history
17. Artwork caching
18. Large-library optimization
19. Permissions
20. Error handling
21. Android testing
22. Windows testing
23. iOS/macOS/Linux adaptation
```

Do not implement everything simultaneously.

---

# 33 — Testing Requirements

Test with:

### Small library

```text
10 songs
```

### Medium library

```text
1,000 songs
```

### Large library

```text
5,000–10,000+ songs
```

Test:

- First scan
- Second scan
- Duplicate scan
- New files
- Removed files
- Moved files
- Corrupt files
- Missing metadata
- Large artwork
- Search
- Playlist creation
- Playback
- Screen lock
- App switching
- Phone restart
- Offline mode
- Permission denial
- Interrupted scan
- Low-storage conditions

---

# 34 — Definition of Done

The MVP is complete when:

- App works without internet.
- User can select music folders.
- Music can be scanned.
- Metadata is indexed.
- Library loads quickly.
- Search is local and fast.
- Music plays from local files.
- Playback continues when the phone screen is locked.
- Mini-player works across navigation.
- Full player works.
- Playlists work.
- Favorites work.
- History works.
- Scanner does not freeze the UI.
- Large libraries remain usable.
- Missing/corrupt files do not crash the app.
- Original music files are never modified automatically.

---

# 35 — Non-Goals

Do not implement during MVP:

- Music streaming
- Online music discovery
- User accounts
- Cloud synchronization
- Social features
- Online recommendations
- Cloud storage
- Subscription system
- AI recommendations
- Automatic music downloading
- Online lyrics
- Automatic online artwork retrieval

These may be considered later.

---

# 36 — Final Product Principle

Music Oasis should feel:

**FAST + LOCAL + PRIVATE + RELIABLE + SIMPLE**

The application should behave as if the music library is part of the device itself.

The user should be able to:

```text
Open app
    ↓
See library immediately
    ↓
Search instantly
    ↓
Tap song
    ↓
Music plays
```

without waiting for:

```text
Internet
Server
Cloud
Account
Network request
Full filesystem rescan
```

### Most important engineering rule

> **Never make the user wait for work that can happen in the background.**

Display the existing local library immediately, perform scanning incrementally, keep audio playback independent from the UI, minimize background work, and let the operating system handle background execution and sleep behavior safely.