# MUSIC OASIS — Design System

> Authority: This document is the single source of truth for visual design.
> Before making UI changes, read this file first.

---

## 1. Design Direction

Music Oasis is a **premium native music player that happens to have a beautiful library**.

Core feeling:

- Minimal
- Monochrome
- Editorial
- Technical
- Premium
- Confident
- Modern
- Human
- Slightly unconventional

The app must feel designed, not like a generic Material/Cupertino template.

---

## 2. Color Palette

Strictly monochrome. No accent colors anywhere in the UI.

### Light Mode (Default)

| Token              | Hex       | Usage                        |
| ------------------ | --------- | ---------------------------- |
| `background`       | `#F2F1ED` | Scaffold background          |
| `surface`          | `#FFFFFF` | Cards, inputs, elevated areas |
| `textPrimary`      | `#111111` | Headings, body text          |
| `textSecondary`    | `#666666` | Metadata, subtitles, labels  |
| `divider`          | `#D2D1CD` | Hairline borders, rules      |
| `white`            | `#FFFFFF` | Inverted text on dark        |

### Dark Mode (Now Playing Only)

| Token         | Hex       | Usage                     |
| ------------- | --------- | ------------------------- |
| `darkBg`      | `#111111` | Now Playing screen bg     |
| `white`       | `#FFFFFF` | Text on dark background   |
| `darkSurface` | `#1A1A1A` | Elevated elements on dark |

### Rules

- Never use accent colors for interactive states
- Active/selected state = full opacity text; inactive = `#666666`
- Error states use `#A84B3F` (desaturated brick) — the only hue permitted
- Avoid: neon colors, RGB gaming aesthetics, generic blue SaaS styling

---

## 3. Typography

Typography carries the visual weight. No custom font files — use system fonts with fallback chains.

### Font Stacks

```dart
// Display / Headings — serif for editorial weight
fontFamilyFallback: ['Georgia', 'Times New Roman', 'serif']

// Body — clean sans-serif
fontFamilyFallback: ['Inter', 'Helvetica Neue', 'Arial', 'sans-serif']

// Labels / Metadata — monospace for technical feel
fontFamilyFallback: ['Consolas', 'Cascadia Mono', 'SF Mono', 'Roboto Mono', 'monospace']
```

### Scale

| Style          | Size | Weight | Letter Spacing | Usage                        |
| -------------- | ---- | ------ | -------------- | ---------------------------- |
| `displayLarge` | 48   | 700    | -1.5           | MUSIC OASIS header           |
| `displayMed`   | 38   | 700    | -1.2           | Screen titles                |
| `displaySmall` | 30   | 700    | -0.8           | Section headers              |
| `headlineLg`   | 26   | 600    | -0.5           | Song titles, album names     |
| `headlineMd`   | 22   | 600    | -0.3           | Artist names                 |
| `headlineSm`   | 19   | 600    | -0.2           | Sub-headings                 |
| `titleLg`      | 17   | 600    | 0              | List item titles             |
| `titleMd`      | 15   | 600    | 0.1            | Body emphasis                |
| `titleSm`      | 13   | 600    | 0.2            | Compact emphasis             |
| `bodyLg`       | 15   | 400    | 0              | Body text                    |
| `bodyMd`       | 13.5 | 400    | 0              | Secondary body               |
| `bodySm`       | 12   | 400    | 0              | Captions, metadata           |
| `labelLg`      | 13   | 600    | 0.8            | Tab labels, buttons          |
| `labelMd`      | 11   | 600    | 1.0            | Section labels, nav labels   |
| `labelSm`      | 10   | 600    | 1.2            | Technical metadata, track #  |

### Rules

- All-caps for section labels and nav items
- Monospace for: track numbers, durations, file paths, scan counts, timestamps
- Tight letter-spacing for headings, wide for labels
- No decorative fonts — editorial restraint

---

## 4. Spacing

```dart
xs: 4
sm: 8
md: 16
lg: 24
xl: 40
xxl: 64
```

- Hairline border width: `1px`
- Corner radius: `0-8px` max — sharp editorial feel
- Generous vertical whitespace between sections
- Compact horizontal spacing within rows

---

## 5. Navigation

### Mobile (4 Tabs)

Bottom navigation with **translucent/frosted glass** effect:

```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
  child: Container(
    color: backgroundColor.withOpacity(0.85),
    child: Row(
      children: [
        '01 HOME',
        '02 LIBRARY',
        '03 SEARCH',
        '04 PLAYLISTS',
      ],
    ),
  ),
)
```

Rules:
- Numbered labels: `01 HOME`, `02 LIBRARY`, `03 SEARCH`, `04 PLAYLISTS`
- Translucent background with backdrop blur
- No icons — text only
- Active state: `#111111` text; Inactive: `#666666`
- Settings accessed via gear icon in Home header, not a tab

### Desktop (Left Sidebar)

```text
┌──────────────┬─────────────────────────┐
│              │                         │
│ 01 HOME      │                         │
│ 02 LIBRARY   │      CONTENT            │
│ 03 SEARCH    │                         │
│ 04 PLAYLISTS │                         │
│              │                         │
│ ···          │                         │
│ 05 SETTINGS  │                         │
│              │                         │
├──────────────┴─────────────────────────┤
│ Mini Player                             │
└─────────────────────────────────────────┘
```

- 220px sidebar width
- Same numbered labels
- Settings pinned at bottom
- Hairline right border

### Mini Player

Persistent bar above navigation:

```text
┌───────────────────────────────────────┐
│ [ART] Song Title               ▶      │
│       Artist Name                     │
└───────────────────────────────────────┘
```

- Artwork thumbnail (40x40, no radius)
- Song title + artist
- Play/pause button
- Above the translucent nav bar on mobile
- Below content on desktop

---

## 6. Screens

### Home

```text
┌───────────────────────────────────────┐
│ MUSIC OASIS                    [gear] │
│───────────────────────────────────────│
│ RECENTLY PLAYED                       │
│───────────────────────────────────────│
│ [art] Song Title              14:32   │
│       Artist Name                     │
│ [art] Song Title              12:15   │
│       Artist Name                     │
│                                       │
│ RECENTLY ADDED                        │
│───────────────────────────────────────│
│ [art] Song Title               3:42   │
│       Artist Name                     │
│                                       │
│ FAVORITES                             │
│───────────────────────────────────────│
│ 01 / Song Title                       │
│ 02 / Song Title                       │
│ 03 / Song Title                       │
│                                       │
│ YOUR PLAYLISTS                        │
│───────────────────────────────────────│
│ 01 / Playlist Name                    │
│ 02 / Playlist Name                    │
└───────────────────────────────────────┘
```

- "MUSIC OASIS" in large serif/editorial type
- Settings gear icon top-right
- Sections with divider lines
- Numbered playlist/favorite rows: `01 / NAME`
- Artwork thumbnails on recently played/added rows

### Library

Category-based navigation, not flat song list:

```text
┌───────────────────────────────────────┐
│ LIBRARY                               │
│───────────────────────────────────────│
│ SONGS                           1,284 │
│───────────────────────────────────────│
│ ALBUMS                               24 │
│───────────────────────────────────────│
│ ARTISTS                              12 │
│───────────────────────────────────────│
│ GENRES                                8 │
│───────────────────────────────────────│
│ FOLDERS                               3 │
│───────────────────────────────────────│
│ PLAYLISTS                             5 │
└───────────────────────────────────────┘
```

- Category name left-aligned, count right-aligned
- Monospace count
- Tapping navigates to category detail (future)
- Hairline dividers between rows

### Search

```text
┌───────────────────────────────────────┐
│ SEARCH MUSIC                          │
│───────────────────────────────────────│
│ ┌───────────────────────────────┐     │
│ │ 🔍 Type to search...         │     │
│ └───────────────────────────────┘     │
│                                       │
│ RESULTS                               │
│───────────────────────────────────────│
│ [art] Song Title                      │
│       Artist · Album                  │
└───────────────────────────────────────┘
```

- "SEARCH MUSIC" header
- Clean search input with border
- Results grouped by type
- Debounced SQLite query

### Playlists

```text
┌───────────────────────────────────────┐
│ PLAYLISTS                             │
│───────────────────────────────────────│
│ 01 / NIGHT DRIVE                      │
│───────────────────────────────────────│
│ 02 / MORNING FOCUS                    │
│───────────────────────────────────────│
│ 03 / WORKOUT MIX                      │
│───────────────────────────────────────│
│                                       │
│ + NEW PLAYLIST                        │
└───────────────────────────────────────┘
```

- Numbered editorial rows: `01 / PLAYLIST NAME`
- Track count subtitle
- "New Playlist" button at bottom

### Full Player (Now Playing)

**Dark background** — the only dark screen in the app:

```text
┌───────────────────────────────────────┐
│ ×                                     │
│                                       │
│                                       │
│         ┌─────────────────┐           │
│         │                 │           │
│         │    ARTWORK      │           │
│         │    (large)      │           │
│         │                 │           │
│         └─────────────────┘           │
│                                       │
│         Song Title                    │
│         Artist Name                   │
│                                       │
│  ───────────●───────────────          │
│  1:23                    3:45         │
│                                       │
│      ⊘    ▶    ⇄                     │
│                                       │
│    ♡    ≡ queue                       │
└───────────────────────────────────────┘
```

Rules:
- Background: `#111111`
- All text: `#FFFFFF`
- Large artwork (280x280), no border radius
- Song title in large serif/editorial type
- Artist name in secondary white
- Seek bar: white track, white thumb
- Transport: previous, play/pause, next (large, centered)
- Below: shuffle, repeat, favorite, queue
- Dismiss via X or swipe down

### Settings

```text
┌───────────────────────────────────────┐
│ SETTINGS                              │
│───────────────────────────────────────│
│ MUSIC FOLDERS                    [+]  │
│───────────────────────────────────────│
│ /storage/emulated/0/Music         [×] │
│ /storage/emulated/0/Download      [×] │
│                                       │
│ LIBRARY SCAN                          │
│───────────────────────────────────────│
│ READY TO SCAN — Music Oasis will      │
│ ask to read your audio files.         │
│                        [SCAN LIBRARY] │
└───────────────────────────────────────┘
```

- Minimal list-style
- Monospace file paths
- No cards, no shadows
- Hairline dividers

### Scanner (Progress)

Technical, monospace progress display:

```text
SCANNING
───────────────────────────────────────
FILES FOUND    1,284
ADDED             24
UPDATED            3
MISSING            0
───────────────────────────────────────
[CANCEL]
```

- Monospace numbers with thousands separators
- Technical/clinical feel
- Progress bar: thin, horizontal, monochrome

---

## 7. Shared Components

### SectionHeader

Reusable label + divider:

```dart
SectionHeader('RECENTLY PLAYED')
// Renders: all-caps label in labelMd style, hairline divider below
```

### EmptyState

Typography-based, no illustrations:

```dart
EmptyState('Nothing played yet.')
// Renders: bodyMd text in #666666, centered vertically
```

---

## 8. States & Microcopy

Reuse existing microcopy for consistency:

- Missing file: `FILE UNAVAILABLE — This song may have been moved or deleted.`
- Permission needed: `MUSIC ACCESS REQUIRED — Choose a music folder to build your library.`
- Empty library: direct, minimal prompt — not a decorative illustration
- Scan complete: `1,284 SCANNED · 24 ADDED · 3 UPDATED · 0 MISSING`
- Empty history: `Nothing played yet.`
- Empty playlists: `No playlists yet.`

---

## 9. Artwork

- Library rows: small cached thumbnail (48x48, no radius)
- Full Player: large artwork (280x280, no radius)
- Never decode full-resolution artwork for every visible list item
- Placeholder: solid `#D2D1CD` rectangle with music note icon

---

## 10. UI Components

- Minimal, reusable, consistent, accessible, responsive
- Hairline borders (`1px`) instead of cards and shadows
- Buttons: square, flat, wide-tracked — purposeful, not decorative
- Outlined buttons with hairline border
- No rounded corners > 8px
- No elevation/shadows anywhere

---

## 11. Animation

Use subtle animation only when it improves experience:

- Mini-player → Full Player expand transition
- Small hover/press states
- Subtle screen transitions (slide up for player)

Avoid:

- Excessive motion
- Animated visualizers/equalizers
- Gaming-style effects

Respect platform reduce-motion accessibility setting.

---

## 12. Multi-Platform Layout

Primary: Android (mobile) and Windows (desktop).

- Mobile: 4-tab translucent bottom navigation
- Desktop: 220px left sidebar
- Never force mobile layout onto desktop or vice versa
- Content area adapts: single column mobile, wider desktop

---

## 13. Design Tokens (Dart)

Centralized in `lib/app/theme.dart`:

```dart
// Colors
MusicOasisPalette.background    // #F2F1ED
MusicOasisPalette.surface       // #FFFFFF
MusicOasisPalette.textPrimary   // #111111
MusicOasisPalette.textSecondary // #666666
MusicOasisPalette.divider       // #D2D1CD
MusicOasisPalette.darkBg        // #111111
MusicOasisPalette.error         // #A84B3F

// Spacing
MusicOasisSpacing.xs   // 4
MusicOasisSpacing.sm   // 8
MusicOasisSpacing.md   // 16
MusicOasisSpacing.lg   // 24
MusicOasisSpacing.xl   // 40

// Component Tokens
MusicOasisTokens.hairline      // divider color
MusicOasisTokens.metadata      // monospace text style
MusicOasisTokens.metadataStrong // monospace bold style

// Navigation
MusicOasisNav.height           // 58
MusicOasisNav.blur             // 20

// Artwork
MusicOasisArtwork.listSize     // 48
MusicOasisArtwork.playerSize   // 280
```

---

## 14. Personality

Music Oasis feels like a considered, personal listening tool — not a corporate product.

Allow personality through:

- Technical metadata labels
- Numbered lists (playlists, favorites)
- Monospace scan counts
- Editorial typography

Keep it subtle. Let the music be the personality.

---

## 15. Avoid

Never make Music Oasis look like:

- A Spotify/Apple Music clone
- A generic RGB "gaming" music app
- A default Material/Cupertino template
- An AI-generated landing page

Avoid: excessive rounded corners, shadows, gradients, visual noise, accent colors.

---

## 16. Design Priority

1. Clarity
2. Typography
3. Whitespace
4. Content hierarchy
5. Usability
6. Consistency
7. Personality
8. Decorative effects

The design should remain strong even with artwork and animation removed.

---

## 17. Final Rule

**MONOCHROME + TECHNICAL + PREMIUM + HUMAN**

Typography and spacing do the visual work — not decoration.
