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

[![Version](https://img.shields.io/badge/Version-v1.3.2%20(Build%2032)-00D2FF?style=for-the-badge&logo=android&logoColor=white)](https://github.com/taezeem14/Sine/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg?style=for-the-badge)](LICENSE)
[![Privacy](https://img.shields.io/badge/Privacy-Zero%20Telemetry-success?style=for-the-badge&logo=shield&logoColor=white)](https://github.com/taezeem14/Sine)
[![Ads](https://img.shields.io/badge/Ads-ZERO%20ADS-success?style=for-the-badge&logo=adguard&logoColor=white)](https://github.com/taezeem14/Sine)
[![DSP Engine](https://img.shields.io/badge/DSP-AutoEq%20%2B%20JamesDSP-FF0055?style=for-the-badge&logo=audio-technica&logoColor=white)](#-open-source-credits--attribution-gpl-30)
[![Donate UPI](https://img.shields.io/badge/Donate-UPI%3A%207006616470%40fam-ff69b4?style=for-the-badge&logo=googlepay&logoColor=white)](#-support-the-project-upi)

<br/>

### [👉 📲 DOWNLOAD LATEST APK (v1.3.2)](https://github.com/taezeem14/Sine/releases/latest/download/Sine-v1.3.2.apk) 👈

*Tap above to download the APK, install on Android 8.0+, and enjoy studio-grade ad-free music instantly.*

<br/>

[🌐 Official Sine Website](https://taezeem14.github.io/Sine/) • [🐛 Report Bug](https://github.com/taezeem14/Sine/issues) • [💬 Request Feature](https://github.com/taezeem14/Sine/issues)

</div>

---

## 📖 Table of Contents
- [What Is Sine?](#-what-is-sine)
- [What's New in v1.3.1](#-whats-new-in-v131)
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

**Sine** is an independent, high-fidelity music streaming client for Android that merges **Spotify's obsidian design language** with **NewPipe's privacy-focused YouTube extraction engine** and **studio-grade open-source DSP acoustic models** (AutoEq, JamesDSP, Equalizer APO).

Commercial streaming platforms charge \$11+/month, clutter interfaces with video podcasts, and harvest your listening habits. Sine provides:
- **Zero Subscriptions & Zero Ads**: Clean, direct audio streaming from YouTube & YouTube Music.
- **Studio Acoustics**: AutoEq acoustic targets, JamesDSP audio algorithms, and hardware parametric EQ.
- **No Logins or Accounts Required**: Zero account bans, zero tracking cookies, and zero Google/Spotify credentials.
- **Pure Local Data**: Playlists, listening history, and cached media remain 100% on your device.
- **Sub-1.2s Cold-Start Playback**: Progressive hardware decoding starting audio almost instantaneously.
- **Direct Public Storage Vault**: Music downloads save directly to `/storage/emulated/0/Sine-Music` with standard ID3 tags and HD artwork.

---

## 🌟 What's New in v1.3.1

1. **Studio Open-Source Equalizer (AutoEq & JamesDSP)**:
   - Integrated acoustic target curves from **AutoEq** (Jaakko Pasanen, MIT): *AutoEq: Harman Target*, *AutoEq: Audiophile Neutral*, *AutoEq: Harman Bass Boost*, *AutoEq: Vocal Forward*.
   - Integrated acoustic models from **JamesDSP** (James34602, GPL-3.0): *JamesDSP: Pure Clarity*, *JamesDSP: Bass Resonance*, *JamesDSP: Tube Amp Warmth*, *JamesDSP: Studio Master*.
   - Integrated ISO 226 equal-loudness contours from **Equalizer APO** (jthedering, GPL).
   - Horizontal category filter chips (`All`, `AutoEq Studio`, `JamesDSP Acoustic`, `APO / Loudness`, `Genre Classics`).
   - Interactive touch-draggable Bezier spline curve with real-time floating dB readout bubble (`+5.2 dB (AutoEq Harman)`).
   - Double-tap any frequency node to reset that individual band to `0.0 dB Unity`, plus a "Reset to Flat" button.
   - In-app open-source DSP attribution and credits dialog.

2. **Curated Genre Deep Explorer (Real High-Precision Tracks)**:
   - Upgraded search genres to query the **iTunes Search API** with resilient failover to YouTube search.
   - Delivers real, genre-accurate tracks across *Classical & Piano*, *Rock & Alt*, *Pop Global*, *Bollywood Hits*, *Electric & Dance*, *Hip-Hop & Rap*, *Indie Vibes*, *Chill & Lo-Fi*, and *Workout & Hype*.
   - Fixed category fallback bug where unmatched keys reverted to "Today's Top Hits".

3. **Lossless Pitch & Speed Anti-Distortion Headroom Guard**:
   - Dynamic `-3.7 dB` (0.65) pre-amp limiter absorbing Sonic SOLA constructive interference spikes during tempo or pitch shifts, eliminating digital clipping and audio crackle.
   - Automatic re-anchoring of Android's hardware `AndroidEqualizer` after Sonic pipeline shifts, ensuring the EQ never detaches or goes flat when pitch or speed is adjusted.

4. **Real Device App Showcase**:
   - Replaced legacy NewPipe placeholders with genuine Sine screenshots across the README, Fastlane store assets, and official website.

---

## 🚀 Key Features

| Category | Capability | Technical Details |
| :--- | :--- | :--- |
| **Acoustics** | **Studio Open-Source Equalizer** | Calibrated AutoEq Harman targets, JamesDSP clarity models, and Equalizer APO contours with touch-draggable Bezier spline visualizer across `60 Hz`, `150 Hz`, `400 Hz`, `1 kHz`, `2.4 kHz`, `15 kHz`. |
| **Acoustics** | **Lossless Pitch & Speed Guard** | Dynamic -3.7 dB pre-amp limiter absorbing Sonic SOLA constructive interference spikes, preventing clipping and keeping hardware DSP effects permanently anchored. |
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
    L --> M["AutoEq / JamesDSP Graph Equalizer"]
    M --> N["Lossless Headroom Limiter (-3.7 dB)"]
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
| **AutoEq** | [Jaakko Pasanen](https://github.com/jaakkopasanen) | **MIT** | [jaakkopasanen/AutoEq](https://github.com/jaakkopasanen/AutoEq) | Acoustic equalization target curves (Harman In-Ear, Audiophile Neutral reference, Harman Bass Boost, Vocal Forward) providing calibrated studio baseline presets. |
| **JamesDSP** | [James34602](https://github.com/james34602) | **GPL-3.0** | [james34602/JamesDSPAudioManager](https://github.com/james34602/JamesDSPAudioManager) | Advanced audio processing algorithms, pure clarity spatial enhancement, resonant bass curves, and tube amplifier warmth simulation. |
| **Equalizer APO** | [jthedering](https://sourceforge.net/projects/equalizerapo/) | **GPL** | [Equalizer APO](https://sourceforge.net/projects/equalizerapo/) | Parametric filtering architectures and ISO 226 equal-loudness contour curves for natural human auditory compensation. |
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
