# ⚡ SINE — High-Fidelity Music Streaming (100% Free & Open Source)

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

[![Version](https://img.shields.io/badge/Version-v1.2.9%20(Build%2027)-00D2FF?style=for-the-badge&logo=android&logoColor=white)](https://github.com/taezeem14/Sine/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-success?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/taezeem14/Sine)
[![Ads](https://img.shields.io/badge/Ads-ZERO%20ADS-success?style=for-the-badge&logo=adguard&logoColor=white)](https://github.com/taezeem14/Sine)
[![Engine](https://img.shields.io/badge/Engine-ExoPlayer%20Hardware%20DSP-FF0000?style=for-the-badge&logo=youtube&logoColor=white)](https://github.com/TeamNewPipe/NewPipe)
[![Donate UPI](https://img.shields.io/badge/Donate-UPI%3A%207006616470%40fam-ff69b4?style=for-the-badge&logo=googlepay&logoColor=white)](#-support-the-project-upi)

<br/>

### [👉 📲 DOWNLOAD LATEST APK (v1.2.9)](https://github.com/taezeem14/Sine/releases/latest/download/Sine-v1.2.9.apk) 👈

*Tap above to download the APK, install on Android 8.0+, and enjoy ad-free music instantly.*

<br/>

[🌐 Official Sine Website](https://taezeem14.github.io/Sine/) • [🐛 Report Bug](https://github.com/taezeem14/Sine/issues) • [💬 Request Feature](https://github.com/taezeem14/Sine/issues)

</div>

---

## 📖 Table of Contents
- [What Is Sine?](#-what-is-sine)
- [Key Features](#-key-features)
- [Architecture & Playback Pipeline](#-architecture--playback-pipeline)
- [FOSS & Privacy Guarantee](#-foss--privacy-guarantee)
- [Installation Guide](#-installation-guide)
  - [1. Direct GitHub Release APK](#1-direct-github-release-apk)
  - [2. ADB CLI Deployment](#2-adb-cli-deployment)
- [Gestures & Quick Controls](#-gestures--quick-controls)
- [Building from Source](#-building-from-source)
- [Support the Project (UPI)](#-support-the-project-upi)
- [Credits & License](#-credits--license)

---

## 💅 What Is Sine?

**Sine** is an independent, high-fidelity music streaming client for Android that merges **Spotify's obsidian design language** with **NewPipe's privacy-focused YouTube extraction engine**.

Commercial streaming platforms charge \$11+/month, clutter interfaces with video podcasts, and collect extensive user listening telemetries. Sine provides:
- **Zero Subscriptions & Zero Ads**: Clean, direct audio streaming from YouTube & YouTube Music.
- **No Logins or Accounts Required**: Zero account bans, zero tracking cookies, and zero Google/Spotify credentials.
- **Pure Local Data**: Playlists, listening history, and cached media remain 100% on your device.
- **Instant Playback**: Progressive hardware decoding starting audio in ~0.5s – 1.0s.
- **Studio-Grade Audio Control**: 6-Band Graph Equalizer, Dynamic Headroom Peak Limiter, Sleep Timer, and Crossfade.

---

## 🚀 Key Features

| Category | Capability | Technical Details |
| :--- | :--- | :--- |
| **Acoustics** | **Native ExoPlayer DSP Engine** | Multi-candidate stream cascade prioritizing Progressive Muxed MP4 (itag 18) for instant hardware decoding, with standalone AAC (128 kbps) and WebM Opus (160 kbps) fallbacks. |
| **Acoustics** | **6-Band Graph Equalizer** | Bezier spline visualizer across `60 Hz`, `150 Hz`, `400 Hz`, `1 kHz`, `2.4 kHz`, `15 kHz` with 20 calibrated Spotify presets. |
| **Acoustics** | **Dynamic Headroom Limiter** | Pre-amp attenuation preventing digital clipping (0 dBFS overshoot) during heavy bass/treble boost. |
| **Playback** | **Smart Sleep Timer** | Drift-compensated countdown timer resilient to Android Doze mode, with "End of Track" sleep support. |
| **Playback** | **Gapless Crossfade** | Configurable audio crossfade for smooth, continuous transitions between tracks. |
| **Lyrics** | **Synchronized Karaoke Lyrics** | Auto-scrolling LRC lyrics from LRCLIB with millisecond tap-to-seek and tempo-modified guard. |
| **Offline** | **Local Storage Vault** | Direct track downloads to `/storage/emulated/0/Sine-Music` with embedded ID3 metadata and artwork. |
| **Sharing** | **Sine QR Code** | 100% offline, on-device QR generator & scanner for sharing tracks and playlists without internet. |
| **Security** | **App Lock** | Local 4-digit PIN authentication securing your library and downloads. |
| **Widgets** | **Home Screen Widget** | 4x2 responsive Android widget with real-time metadata, album art, and transport playback controls. |
| **Discovery** | **Audile Music Detection** | Live microphone acoustic recognition radar with real-time waveform visualization, AudD/Shazam multi-provider matching, and instant 1-tap playback & library save. |
| **Discovery** | **Category & Genre Deep Explorer** | Dedicated modal sheet browsing with instant 'Play All', 'Shuffle', and glitch-free smooth scrolling across Spotify genres. |
| **Streaming** | **Audio Streaming Quality Engine** | User-selected bitrate presets: High (160+ kbps WebM Opus / 128 kbps AAC), Medium (balanced hardware MP4), and Data Saver (~50-70 kbps Opus) with immediate stream cache invalidation. |

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

    H --> I["androidSdkless Client Profile"]
    I --> J["Candidate #1: Progressive Muxed MP4 (itag 18, 0.5s start)"]
    I --> K["Candidate #2: Standalone MP4 AAC (itag 140, 128 kbps)"]
    I --> L["Candidate #3: Standalone WebM Opus (itag 251, 160 kbps)"]

    J & K & L --> M["AudioHandler.playSong() with Native Android Headers"]
    M --> N{"ExoPlayer Connection OK?"}
    N -- "Success" --> O["Audio Streams via Native Hardware Decoders 🎵"]
    N -- "Failure / 403" --> P["Clean Headers Retry"]
    P -- "Failure" --> Q["Piped Public API Cluster Failover"]
    Q -- "Failure" --> R["Dynamic YouTube Search & Next Candidate"]
```

---

## 🛡️ FOSS & Privacy Guarantee

Sine is built on strict Free & Open Source Software principles:
1. **Zero Tracking SDKs**: No Google Firebase Analytics, Crashlytics, Sentry, Mixpanel, or Facebook Graph API.
2. **100% Offline QR Rendering**: All QR code generation is performed locally on-device using vector canvas rendering (`qr_flutter`). No data is sent to external QR APIs.
3. **No Account Association**: Audio streams are resolved anonymously via InnerTube and public proxy endpoints without logging into Google or Spotify accounts.
4. **Local Data Persistence**: Playlists, favorites, and settings are saved to private app storage via SQLite / SharedPreferences.

---

## 📲 Installation Guide

### 1. Direct GitHub Release APK
1. Download the latest release: [Sine-v1.2.9.apk](https://github.com/taezeem14/Sine/releases/latest/download/Sine-v1.2.9.apk).
2. On Android, tap the downloaded APK file.
3. If prompted, allow *"Install unknown apps"* for your browser or file manager.
4. Tap **Install** and open Sine.

### 2. ADB CLI Deployment
For developers and power users:
```bash
adb install -r Sine-v1.2.9.apk
```

---

## 🎮 Gestures & Quick Controls

| Gesture / Action | Screen / Area | Action Triggered |
| :--- | :--- | :--- |
| **Tap Mini-Player** | Bottom Navigation Bar | Expands full-screen Now Playing view |
| **Swipe Down** | Now Playing Header | Dismisses Now Playing view back to browsing |
| **Tap Album Artwork** | Now Playing View | Toggles between Vinyl / Cover Art and Synchronized Lyrics |
| **Horizontal Swipe** | Now Playing Album Art | Skips to Next / Previous track |
| **Tap Lyrics Line** | Synchronized Lyrics View | Seeks playback directly to that lyric timecode |
| **Long Press Track** | Any Playlist / Search List | Opens Track Options (Add to playlist, download, share) |
| **Draggable EQ Node** | Graph Equalizer Screen | Adjusts gain on any of the 6 calibrated audio bands |

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

# 3. Verify static analysis (0 warnings)
flutter analyze lib test

# 4. Run automated test suite
flutter test test/widget_test.dart

# 5. Build signed production APK
flutter build apk --release --no-tree-shake-icons
```

The compiled release APK will be located at:
```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 💖 Support the Project (UPI)

Sine is free, ad-free, and independently crafted with immense care. If Sine saves you from subscription costs, consider tipping the creator:

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

Sine is proud to be built upon and inspired by the global Free and Open Source Software (FOSS) ecosystem. In strict adherence to the **GNU General Public License v3.0 (GPL-3.0)**, we gratefully acknowledge and attribute the following outstanding open-source projects whose code, algorithms, and architectural concepts have directly contributed to or inspired Sine:

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
