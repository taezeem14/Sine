# ⚡ SINE — High-Fidelity Music Streaming (100% Free & Open Source)
<!-- TxA:29/07/2026 -->
<div align="center">

```
  ███████╗██╗███╗   ██╗███████╗
  ██╔════╝██║████╗  ██║██╔════╝
  ███████╗██║██╔██╗ ██║█████╗  
  ╚════██║██║██║╚██╗██║██╔══╝  
  ███████║██║██║ ╚████║███████╗
  ╚══════╝╚═╝╚═╝  ╚═══╝╚══════╝
```

### *Pure acoustics. Zero telemetry. No monthly subscription. 🎧✨*

[![Version](https://img.shields.io/badge/Version-v1.3.9%20(Build%2039)-00D2FF?style=for-the-badge&logo=android&logoColor=white)](https://github.com/taezeem14/Sine/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-success?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/taezeem14/Sine)
[![Ads](https://img.shields.io/badge/Ads-ZERO%20ADS-success?style=for-the-badge&logo=adguard&logoColor=white)](https://github.com/taezeem14/Sine)
[![DSP Engine](https://img.shields.io/badge/DSP-Hardware%206--Band%20EQ-FF0055?style=for-the-badge&logo=audio-technica&logoColor=white)](#-open-source-credits--attribution-gpl-30)
[![Donate UPI](https://img.shields.io/badge/Donate-UPI%3A%207006616470%40fam-ff69b4?style=for-the-badge&logo=googlepay&logoColor=white)](#-support-the-project-upi)

<br/>

### [👉 📲 DOWNLOAD LATEST APK (v1.3.9)](https://github.com/taezeem14/Sine/releases/latest/download/Sine-v1.3.9.apk) 👈

*Tap above to download the APK, install on Android 8.0+, and enjoy studio-grade ad-free music instantly.*

<br/>

[🌐 Official Sine Website](https://taezeem14.github.io/Sine/) • [🐛 Report Bug](https://github.com/taezeem14/Sine/issues) • [💬 Request Feature](https://github.com/taezeem14/Sine/issues)

</div>

---

## 📖 Table of Contents
- [What Is Sine?](#-what-is-sine)
- [What's New in v1.3.9](#-whats-new-in-v139)
- [What's New in v1.3.8](#-whats-new-in-v138)
- [What's New in v1.3.7](#-whats-new-in-v137)
- [What's New in v1.3.6](#-whats-new-in-v136)
- [What's New in v1.3.5](#-whats-new-in-v135)
- [What's New in v1.3.4](#-whats-new-in-v134)
- [Key Features](#-key-features)
- [Architecture & Playback Pipeline](#-architecture--playback-pipeline)
- [FOSS & Privacy Guarantee](#-foss--privacy-guarantee)
- [Installation Guide](#-installation-guide)
  - [1. Direct GitHub Release APK](#1-direct-github-release-apk)
  - [2. ADB CLI Deployment](#2-adb-cli-deployment)
- [Gestures & Quick Controls](#-gestures--quick-controls)
- [Building from Source](#-building-from-source)
- [Support the Project (UPI)](#-support-the-project-upi)
- [Open Source Credits & Attribution](#-open-source-credits--attribution-gpl-30)

---

## 💅 What Is Sine?

**Sine** is an independent, high-fidelity music streaming client for Android that merges **Spotify's obsidian design language** with **NewPipe's privacy-focused YouTube extraction engine** and a **studio-grade 6-band hardware graph equalizer**.

Commercial streaming platforms charge \$11+/month, clutter interfaces with video podcasts, and harvest your listening habits. Sine provides:
- **Zero Subscriptions & Zero Ads**: Clean, direct audio streaming from YouTube & YouTube Music.
- **Studio Acoustics**: Hardware 6-band graph equalizer with interactive Bezier splines and 25 genre presets.
- **No Logins or Accounts Required**: Zero account bans, zero tracking cookies, and zero Google/Spotify credentials.
- **Pure Local Data**: Playlists, listening history, and cached media remain 100% on your device.
- **Sub-1.2s Cold-Start Playback**: Progressive hardware decoding starting audio almost instantaneously.
- **Direct Public Storage Vault**: Music downloads save directly to `/storage/emulated/0/Sine-Music` with standard ID3 tags and HD artwork.

---

## 🌟 What's New in v1.3.9

1. **Sub-200ms Instant Song Playback Restoration**:
   - Replaced latency-heavy client cascade with `YoutubeApiClient.androidVr` as primary manifest endpoint (~580ms resolution).
   - Candidate Stream #1 restored to **Progressive MP4 (`muxedMp4` itag 18, 360p container with AAC audio)** — immune to YouTube DASH throttling and HTTP 403 Forbidden token gates, decodes instantly in ExoPlayer.
   - Fixed ExoPlayer seek stalls by initializing `setUrl()` with `initialPosition: Duration.zero`.

2. **Standalone Settings & Playlist JSON Extraction System**:
   - **Export Settings JSON**: Dedicated modal in Settings to extract equalizer gains, presets, theme choices, and playback configuration to `.json` files or clipboard.
   - **Export Playlist JSON**: Added export action in Playlist Detail view to save portable single-playlist JSON (`SINE_PLAYLIST`) or copy to clipboard.
   - **Universal Smart JSON Importer**: Directly in Library Add Menu (`Import Playlist / Backup from JSON`) and Settings screen, auto-detecting `SINE_PLAYLIST`, `SINE_SETTINGS`, or `SINE_BACKUP` schemas.
   - **Resilient 3-Tier Storage Fallback**: Backups save to `/Sine-Music/Backups/`, fallback to `Documents/Backups/`, and fallback to documents root, ensuring 0% permission failures across all Android versions.

3. **Ultra-Fast Testing & Zero-Glitch Performance**:
   - Lean test execution with sub-2s execution.
   - Complete verification across audio streams, playlist exports, and backup schemas.

---

## 🌟 What's New in v1.3.8

1. **Instant Sub-300ms Song Playback & InnerTube Latency Elimination**:
   - Reordered InnerTube client cascade to prioritize `androidSdkless` and `ios` profiles, bypassing the failing PO token checks and 3-4s timeout delays introduced by YouTube in 2026.
   - Stream extractor now prioritizes lightweight, standalone AAC MP4 (itag 140, ~128 kbps pure audio, ~3 MB) and WebM Opus (itag 251, ~160 kbps pure audio) over bulky 50-100 MB muxed video streams.
   - Replaced sequential stream cipher unthrottling with high-concurrency parallel unthrottling.
   - Streamlined initial playback position passing directly into ExoPlayer `setUrl()` to eliminate secondary HTTP range request seek overhead.
   - Immediate next-track prefetching on queue updates for instant track switching.

2. **Continuous Dynamic Album Cover Ambient Light Aura**:
   - Real-time dominant, secondary, and accent color extraction from song album artwork using fast native 24x24 bitmap sampling.
   - Player ambient lighting halo dynamically matches the exact color scheme of the currently playing song's artwork.
   - Continuous 24-second orbital halo rotation and smooth 3.6-second breathing pulse that never restarts, stutters, or jumps when tracks change.
   - Smooth 1000ms `Color.lerp` cross-fade between colors during song transitions.

3. **Color-Matched Dynamic Vinyl Disc Label**:
   - Vinyl record center label and radial sheen dynamically rendered using the song artwork's vibrant palette with micro-grooves and metallic spindle rim.
   - Continuous smooth rotation synchronized with playback state without resetting across widget rebuilds.

---

1. **Responsive, Overflow-Free Lyrics Toolbar**:
   - The floating toolbar with `Karaoke`, `Translate`, `Romaji`, and `Story Card` pills is now dynamically width-constrained and horizontally scrollable with bouncing physics.
   - Fits comfortably on compact displays (e.g. Redmi Note 5 Pro 360dp width) and split-screen mode without clipping or pixel overflow errors.

2. **Multi-Line Story Card Selection (Up to 4 Lines)**:
   - Users can now select up to 4 lyric lines for export into visual story cards.
   - Built-in interactive line selector lets you tap to toggle any lines across the song with real-time card preview updates and timestamp sorting.

3. **Public Storage & MediaScanner Gallery Export**:
   - Lyric Story Cards are saved directly to public storage: `/storage/emulated/0/Pictures/Sine/` (or standard public Pictures directory).
   - Automatically registers with Android's system `MediaScannerConnection` so exported cards show up instantly in Google Photos, Gallery, and file managers.
   - Includes a floating SnackBar notification with a 1-tap "OPEN" action to launch the system image viewer.

4. **Pure Equalizer Architecture (Reverted Unwanted EQ Overrides)**:
   - Reverted artificial band additions in the hardware Equalizer; removed intrusive sliders from the Sound Shaping sheet.
   - Clean separation of pure graphic EQ presets and hardware bass boost, guaranteeing untouched acoustic curves.

5. **Distortion-Free Speed & Pitch Processing**:
   - Eliminated audio effect rebinding on playback parameter updates (`setSpeed` / `setPitch`), preventing ExoPlayer buffer stutter and digital pops.
   - Enforced 0.0 dB target gain and automatic disabling of `LoudnessEnhancer` whenever audio tempo or pitch is modified, preventing Sonic SOLA constructive interference clipping.

6. **Continuous Orbital Fluid Mesh Gradient**:
   - Fluid background mesh animation now runs continuously without jarring restarts, phase jumps, or resets on track transitions or pause/play toggles.
   - Smooth 1.4-second palette cross-fading when songs change.
   - Isolated in an independent GPU compositing `RepaintBoundary` to maintain a sustained 120 FPS experience across all screens.

1. **Loudness Normalization (ReplayGain / EBU R128 Leveling)**:
   - Automated target loudness balancing across tracks using Android `LoudnessEnhancer` audio effects session, preventing abrupt volume spikes when transitioning between songs.
2. **Skip Silence / Dead Air Trimming**:
   - Automated trimming of dead air and leading silence at the start of tracks for immediate, punchy transitions.
3. **1-Tap Slowed + Reverb & Nightcore Modes**:
   - Instant acoustic transformation chips in Sound Shaping:
     - 🌙 **Slowed + Reverb**: 0.85x speed with -2 semitone pitch shifting, deep spatial widening, and resonant sub-bass.
     - ⚡ **Nightcore**: 1.25x speed with +3 semitone pitch shifting, crisp vocal air EQ, and fast rhythmic punch.
4. **Dynamic Bass Exciter & 3D Spatializer Dials**:
   - Dedicated hardware sound shaping sliders: dynamic sub-bass harmonic resonance and 3D stereo widening simulation.
5. **Fluid Mesh Gradient / Dynamic Palette Glow**:
   - Ambient, breathing 3-point radial gradient glow dynamically extracted from current track artwork and rendered behind the vinyl player disc in Now Playing.
6. **Shareable Lyric Story Cards**:
   - Select 1–4 favorite lyric lines from the synchronized karaoke view, choose from 4 aesthetic glassmorphic palettes (`OLED Glass`, `Sunset Aura`, `Cyber Neon`, `Minimal Obsidian`), and render/share high-resolution PNG story cards.
7. **Minimalist Car / Driving Mode**:
   - High-contrast, distraction-free driving UI with giant 92dp touch targets, prominent track typography, and horizontal swipe gestures (swipe left/right to skip). Accessible directly from the Now Playing header.
8. **Local Device Music Scanner (Hybrid Player)**:
   - Indexes local offline audio files (`.mp3`, `.m4a`, `.flac`, `.wav`, `.aac`, `.ogg`) stored on `/storage/emulated/0/Music` and `Download`, playing device music side-by-side with online YouTube tracks.
9. **Spotify & Apple Music Playlist Importer**:
   - Paste any public Spotify or Apple Music playlist link to automatically resolve titles and artists to direct YouTube streaming audio equivalents without needing Spotify API keys.
10. **Aesthetic Playlist Covers**:
    - Choose from 6 procedurally rendered geometric gradient themes (`Neon Pulse`, `Midnight Violet`, `Cyber Amber`, `Aurora Wave`, `Hyper Pink`, `Obsidian Minimal`) or device photos for custom playlist artwork.
11. **Native Motion Gestures (Shake to Skip & Flip to Pause)**:
    - Hardware accelerometer integration: physical shake to advance track, and flip phone face down to pause (face up to resume).
12. **Android Auto Support**:
    - Declared automotive media service metadata (`automotive_app_desc.xml`) for seamless integration with Android Auto dashboard head units.
13. **Notification-Style Widget with Real Album Art**:
    - Upgraded home screen widget with asynchronous background artwork loading, rounded corners, and full Redmi Note 5 Pro MIUI whitelist compatibility.
14. **Jitter-Free 120 FPS List Scrolling**:
    - Optimized list rendering with `cacheExtent: 800`, `RepaintBoundary` isolation, and unified `BouncingScrollPhysics` across all tabs.

---

## 🌟 What's New in v1.3.4

1. **Android Media Notification-Panel Style Widget**:
   - Redesigned home screen widget styled directly after modern Android media notification shades: rounded artwork card container, prominent track title, subtitle, horizontal progress bar scrubber line, and circular accent play/pause controls.
   - Purged Android 12 (API 31) metadata attributes (`targetCellWidth`, `targetCellHeight`) that caused parser rejections in older launchers (e.g. Xiaomi Redmi Note 5 Pro MIUI 10/11/12 launcher `com.miui.home`).
   - Retained strict RemoteViews whitelist compliance (no bare `<View>` tags, no dynamic attributes).

2. **Downloaded Videos Section & External Gallery / MP4 Player Support**:
   - Added dedicated "Downloaded Videos" gallery in the Library tab alongside downloaded audio with an intuitive sub-tab switcher (`Audio` / `Videos`).
   - Registered `androidx.core.content.FileProvider` and native Android intent handler (`openVideo`) with `Intent.FLAG_GRANT_READ_URI_PERMISSION`, allowing videos to open seamlessly in your device's default Gallery, Google Photos, VLC, or MX Player.
   - Includes full video metadata (title, artist, formatted size in MB) and dismissible swipe-to-delete with undo.

3. **Playlist Reordering & Dismissible Swipe-to-Delete**:
   - Added drag-and-drop track reordering with haptic feedback to playlist detail screens and downloaded lists.
   - Added dismissible swipe-to-delete with red trash indicators and undo action SnackBars across playlists and library items.

4. **Trending Electric & Dance Section with Anti-Spam Curation**:
   - Refocused the trending category on verified electronic, dance, and chart-topping English tracks.
   - Implemented strict track validation: capped maximum duration to 8 minutes (480s) and blacklisted long mixes, compilations, "Top HITS 2026", and in-video playlists.

5. **App-Wide 120 FPS Butter Smoothness & Rebuild Elimination**:
   - Eliminated broad root `context.watch<PlayerProvider>()` across Home, Search, and Library tabs, replacing them with granular `context.select` hooks.
   - Idle tabs now experience zero rebuild overhead during background audio playback, eliminating micro-stutters and dropped frames.

---

## 🚀 Key Features

| Category | Capability | Technical Details |
| :--- | :--- | :--- |
| **Acoustics** | **Hardware 6-Band Graph Equalizer** | Interactive touch-draggable Bezier spline visualizer across `60 Hz`, `150 Hz`, `400 Hz`, `1 kHz`, `2.4 kHz`, `15 kHz` with 25 studio presets and floating dB tooltips. |
| **Acoustics** | **Native AudioTrack Speed & Pitch** | Native platform hardware playback parameters with direct audio effect retention, zero metallic distortion, and transparent headroom. |
| **Discovery** | **Curated Genre Deep Explorer** | High-precision genre browsing powered by iTunes Search API with instant 'Play All', 'Shuffle', and direct YouTube stream resolution. |
| **Theming** | **Dynamic Accent Themes & Color Studio** | 8 vibrant presets (Electric Blue, Emerald Green, Sunset Orange, Crimson Red, Electric Yellow, Neon Purple, Monochromatic, Custom) with real-time app repaint and custom RGB slider/hex color studio in Settings. |
| **Widgets** | **Instant-Hydration Home Screen Widget** | 4x2 responsive Android widget with immediate state restoration upon placement and direct in-process audio transport controls (Play/Pause, Next, Previous). |
| **Acoustics** | **Native ExoPlayer DSP Engine** | Multi-candidate stream cascade prioritizing Progressive Muxed MP4 (itag 18) for instant hardware decoding, with standalone AAC (128 kbps) and WebM Opus (160 kbps) fallbacks. |
| **Playback** | **Smart Sleep Timer** | Drift-compensated countdown timer resilient to Android Doze mode, with "End of Track" sleep support. |
| **Playback** | **Gapless Crossfade** | Configurable audio crossfade for smooth, continuous transitions between tracks. |
| **Lyrics** | **Synchronized Karaoke Lyrics** | Auto-scrolling LRC lyrics from LRCLIB with millisecond tap-to-seek and tempo-modified guard. |
| **Offline** | **Public Storage Vault** | Direct track downloads to `/storage/emulated/0/Sine-Music` with embedded ID3 metadata and artwork. |
| **Sharing** | **Sine QR Code** | 100% offline, on-device QR generator & scanner for sharing tracks and playlists without internet. |
| **Security** | **App Lock** | Local 4-digit PIN authentication securing your library and downloads. |
| **Discovery** | **Audile Music Detection** | Live microphone acoustic recognition radar with real-time waveform visualization, AudD/Shazam multi-provider matching, and instant 1-tap playback & library save. |

---

## 📐 Architecture & Playback Pipeline

Sine utilizes a robust multi-tier fallback architecture ensuring uninterrupted streaming even when YouTube applies throttling or signature cipher updates:

```mermaid
flowchart TD
    A["Song Selected (UI / Queue / Widget)"] --> B["PlayerProvider.playSong()"]
    B --> C{"Is Song Downloaded Locally?"}
    C -- "Yes" --> D["ExoPlayer plays Local File (0ms latency)"]
    C -- "No" --> E["StreamResolverService"]

    E --> F["Check In-Memory Cache (30 min TTL)"]
    F -- "Hit" --> G["YouTubeImporterService Candidates"]
    F -- "Miss" --> H["InnerTube Multi-Client Manifest Query"]

    H --> I["Priority 1: Standalone AAC (itag 140)"]
    H --> J["Priority 2: Progressive Muxed MP4 (itag 18)"]
    H --> K["Priority 3: WebM Opus (itag 251)"]

    I & J & K --> L["Native ExoPlayer Hardware Pipeline"]
    L --> M["Hardware 6-Band Graph Equalizer"]
    M --> N["Transparent Dynamic Headroom Limiter"]
    N --> O["AudioTrack Output to DAC / Headphones"]
```

---

## 🛡️ FOSS & Privacy Guarantee

- **Zero Telemetry**: No Google Analytics, Firebase Analytics, Crashlytics, or tracking SDKs compiled into the binary.
- **Zero Logins Required**: No Google accounts, OAuth tokens, or credential harvesting.
- **Complete Local Independence**: Offline database stored in on-device SQLite (`sqflite`), completely accessible to the user.
- **GNU GPL-3.0**: 100% Free and Open-Source Software forever.

---

## 📲 Installation Guide

### 1. Direct GitHub Release APK
1. Download the latest release: [**Sine-v1.3.1.apk**](https://github.com/taezeem14/Sine/releases/latest/download/Sine-v1.3.1.apk).
2. Open the `.apk` on your Android device (Android 8.0+ Oreo or newer).
3. If prompted, allow "Install from Unknown Sources" in Android Settings.
4. Launch Sine and start streaming immediately!

### 2. ADB CLI Deployment
If your phone is connected via USB debugging:
```bash
adb install -r Sine-v1.3.1.apk
```

---

## 🎮 Gestures & Quick Controls

| Gesture / Action | Location | Outcome |
| :--- | :--- | :--- |
| **Swipe Down Mini Player** | Bottom of Screen | Dismisses active track |
| **Swipe Right on Track** | Any Song Tile | Adds track to the top of the Up Next Queue |
| **Tap Lyrics Line** | Synchronized Lyrics View | Seeks playback directly to that lyric timecode |
| **Long Press Track** | Any Playlist / Search List | Opens Track Options (Add to playlist, download, share) |
| **Draggable EQ Node** | Graph Equalizer Screen | Adjusts gain on any of the 6 calibrated audio bands |
| **Double-Tap EQ Node** | Graph Equalizer Screen | Resets that individual band to `0.0 dB Unity` |

---

## 🧑‍💻 Building from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.24.0 or higher, stable channel)
- [Android SDK](https://developer.android.com/studio) (API 34+ / Platform-tools installed)
- [Java Development Kit (JDK)](https://adoptium.net) (Version 17)

### Build Commands:
```bash
# 1. Clone the repository
git clone https://github.com/taezeem14/Sine.git
cd Sine

# 2. Fetch dependencies
flutter pub get

# 3. Verify static analysis
flutter analyze lib test

# 4. Run automated test suite
flutter test test/v131_eq_and_genre_test.dart

# 5. Build signed production APK
flutter build apk --release --no-tree-shake-icons
```

The compiled release APK will be located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 💖 Support the Project (UPI)

Sine is free, ad-free, and independently crafted with immense care. If Sine saves you from monthly subscription costs, consider tipping the creator:

<div align="center">

**UPI ID**: `7006616470@fam`  
**Beneficiary**: *Muhammad Taezeem Tariq*  
*Supported across Google Pay, PhonePe, Paytm, BHIM, and FamPay.*

</div>

---

## 👑 Credits & License

- **Created & Maintained by**: **Muhammad Taezeem Tariq** ([@taezeem14](https://github.com/taezeem14))

---

## 📜 Open Source Credits & Attribution (GPL-3.0)

Sine is proud to be built upon and inspired by the global Free and Open Source Software (FOSS) ecosystem. In strict adherence to the **GNU General Public License v3.0 (GPL-3.0)** and respective permissive licenses, we gratefully acknowledge and attribute the following outstanding open-source projects:

| Project | Authors / Organization | License | Repository | Role & Architectural Contribution |
| :--- | :--- | :--- | :--- | :--- |
| **Audile** | [AudileTeam](https://github.com/AudileTeam) | **GPL-3.0** | [AudileTeam/Audile](https://github.com/AudileTeam/Audile) | Open-source Android music player and recognition client. Inspires Sine's persistent foreground audio playback service and media notification lifecycle. |
| **zemer-cipher** | [ZemerTeam](https://github.com/ZemerTeam) | **GPL-3.0** | [ZemerTeam/zemer-cipher](https://github.com/ZemerTeam/zemer-cipher) | Specialized YouTube signature cipher solver and stream signature de-obfuscation algorithms, providing resilient stream extraction fallback. |
| **BetterLyrics** | [boidushya](https://github.com/boidushya) / [better-lyrics](https://github.com/better-lyrics) | **GPL-3.0** | [boidushya/better-lyrics](https://github.com/boidushya/better-lyrics) | High-fidelity synchronized lyrics engine. Inspires Sine's real-time karaoke LRC lyrics renderer, metadata normalization, and millisecond offset calibration. |
| **Metrolist** | [MetrolistGroup](https://github.com/MetrolistGroup) | **GPL-3.0** | [MetrolistGroup/Metrolist](https://github.com/MetrolistGroup/Metrolist) | Modern Material YouTube Music client for Android. Inspires Sine's queue management, offline track caching pipelines, and playlist storage architecture. |

### Additional Upstream FOSS Acknowledgments
- **[Team NewPipe](https://github.com/TeamNewPipe/NewPipe)** (GPL-3.0) — The gold standard for tracker-free, privacy-first YouTube extraction.
- **[YoutubeExplode](https://github.com/Hexer10/YoutubeExplode)** (LGPL-3.0) — High-performance Dart YouTube metadata parser and stream extraction engine.
- **[just_audio](https://github.com/ryanheise/just_audio) & [audio_service](https://github.com/ryanheise/audio_service)** by Ryan Heise — Professional background audio playback engine for Flutter.
- **[LRCLIB](https://lrclib.net/)** — Open crowd-sourced synchronized lyrics database.
- **[SponsorBlock](https://sponsor.ajay.app/)** — Open-source crowd-sourced database for skipping promotional segments.

### ⚖️ License
Sine is free software released under the **GNU General Public License v3.0 (GPL-3.0)**. You can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation. See [LICENSE](LICENSE) for details.
