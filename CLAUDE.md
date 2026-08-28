# MUSIC OASIS — CLAUDE CODE INSTRUCTIONS

> This file is the primary instruction file for Claude Code.
> Keep implementation focused on a **fast, offline-first, native-feeling music player**.
>
> Before making architectural or large implementation changes, read:
>
> - `PROJECT.md` — architecture and engineering requirements
> - `REQUIREMENTS.md` — functional requirements
> - `DESIGN.md` — visual design system
>
> Do not duplicate those documents unnecessarily.

---

# 01 — PRODUCT

## Name

**Music Oasis**

## Product Type

Offline-first local music player and music file scanner.

## Primary Platforms

1. Android
2. Windows

## Secondary Platforms

- iOS
- macOS
- Linux

## Core Concept

Music Oasis scans music files stored locally on the user's device, indexes their metadata into SQLite, and provides a fast local music library and player.

The application should feel like:

> **A premium native music player that happens to have a beautiful library.**

It is NOT:

- A music streaming service
- A social network
- A cloud music service
- An online recommendation platform
- A Spotify clone

---

# 02 — PRIMARY ENGINEERING GOALS

Every implementation decision should prioritize:

```text
1. Correctness
2. Responsiveness
3. Offline functionality
4. Smooth playback
5. Low memory usage
6. Battery efficiency
7. Fast scanning
8. Maintainability
9. Visual quality
```

The application must feel fast even with a large music library.

---

# 03 — ABSOLUTE RULES

## Offline First

Core functionality must never require internet access.

The following must work in airplane mode:

- App launch
- Library
- Search
- Music scanning
- Metadata
- Playback
- Playlists
- Favorites
- Playback history
- Settings

Do not introduce a backend unless explicitly requested.

Do not add:

- Firebase
- Supabase
- REST APIs
- GraphQL
- WebSockets
- Cloud databases
- Authentication

for MVP functionality.

---

# 04 — TECHNOLOGY

Use:

```text
Flutter
Dart
SQLite
Riverpod
just_audio
Platform-native audio/background services
```

Use additional dependencies only when they solve a real requirement.

Before adding a package:

1. Check whether the existing stack already solves the problem.
2. Check whether the package is actively maintained.
3. Check Android/iOS/desktop compatibility.
4. Consider package size and performance.
5. Avoid duplicate packages solving the same problem.

Do not add dependencies just for convenience.

---

# 05 — ARCHITECTURE

Use layered architecture:

```text
UI
 ↓
State Management
 ↓
Repository
 ↓
Services
 ↓
SQLite / Filesystem / Audio Engine
```

The UI must not directly perform:

- SQLite queries
- Recursive filesystem scanning
- Metadata parsing
- Audio engine initialization
- Platform permission logic
- Background service management

---

# 06 — DIRECTORY STRUCTURE

Use feature-based organization.

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
│   ├── utils/
│   └── platform/
│
├── data/
│   ├── database/
│   │   ├── database.dart
│   │   ├── tables/
│   │   └── migrations/
│   │
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

Keep related files together.

Do not create arbitrary global folders.

---

# 07 — UI ARCHITECTURE

Separate:

```text
Presentation
Business logic
Data
Platform services
```

A screen should primarily compose widgets and consume state.

Example:

```text
LibraryScreen
    ↓
LibraryProvider
    ↓
LibraryRepository
    ↓
SQLite
```

Do not put database logic inside `LibraryScreen`.

---

# 08 — STATE MANAGEMENT

Use Riverpod.

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
├── idle
├── scanning
├── completed
├── cancelled
└── error
```

The database remains the source of persistent data.

Riverpod is not a replacement for SQLite.

Do not load the entire music database into one provider unnecessarily.

---

# 09 — DATABASE

Use SQLite for persistent local music metadata.

Store:

```text
songs
artists
albums
playlists
playlist_songs
favorites
playback_history
music_folders
```

A song may contain:

```text
id
path
title
artist_id
album_id
duration
track_number
disc_number
genre
year
format
file_size
modified_time
artwork_path
date_added
last_played
```

Do not store actual MP3/FLAC/WAV files inside SQLite.

SQLite stores metadata and references.

---

# 10 — FILESYSTEM

Actual music remains on the filesystem.

Example:

```text
Device
├── Music/
│   ├── Song.mp3
│   ├── Album/
│   │   └── Track.flac
│   └── ...
│
└── Music Oasis data
    ├── music.db
    └── artwork cache
```

Music Oasis should never modify the original files automatically.

Never automatically:

- Delete
- Move
- Rename
- Convert
- Overwrite
- Modify metadata

user music.

---

# 11 — FILE SCANNER

The scanner is a background-capable service.

Flow:

```text
Select Folder
      ↓
Permission
      ↓
Discover Files
      ↓
Filter Audio Extensions
      ↓
Compare Existing Database
      ↓
Read Metadata
      ↓
Upsert Database
      ↓
Update UI
```

Supported initial formats:

```text
.mp3
.flac
.wav
.m4a
.aac
.ogg
.opus
```

Playback support depends on the platform/audio engine.

---

# 12 — SCANNING PERFORMANCE

Never perform a large recursive scan directly on the UI thread.

Bad:

```text
button.onPressed:
    scanEverythingSynchronously()
```

Good:

```text
UI
 ↓
Scanner Service
 ↓
Background/isolate work where appropriate
 ↓
Progress updates
 ↓
SQLite transaction/batched writes
```

The UI must remain responsive during scanning.

---

# 13 — INCREMENTAL SCANNING

Do not rebuild the entire library every scan.

Example:

```text
Existing:
1,000 songs

New scan:
20 new songs
3 changed songs
2 removed songs

Process only relevant changes.
```

Use:

- File path
- File size
- Modification time
- Stable identifiers where possible

Avoid expensive full-file hashing on every scan unless there is a specific reason.

---

# 14 — APP STARTUP

Startup speed is critical.

Preferred:

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
Perform lightweight background verification
```

Never wait for a full filesystem scan before showing the library.

The user should see existing library data immediately.

---

# 15 — LARGE LIBRARY

Design for:

```text
100 songs
1,000 songs
5,000 songs
10,000+ songs
```

Use:

- Lazy lists
- Pagination where appropriate
- Database indexes
- Efficient queries
- Cached artwork
- Incremental scanning

Never build a giant widget tree containing every song at once.

Use Flutter's efficient list/grid builders.

---

# 16 — SEARCH

Search must query SQLite.

Never scan the filesystem for every search query.

Bad:

```text
User types:
"Eminem"

Scan entire filesystem
```

Good:

```text
User types:
"Eminem"
 ↓
Debounced query
 ↓
SQLite
 ↓
Results
```

Search:

- Song title
- Artist