# E2E Test Infra: Sine Music Player v1.3.3 Modernization & Resilience

## Test Philosophy
- **Paradigm**: Opaque-box, requirement-driven E2E verification of Flutter application and native Android integration.
- **Independence**: Derived strictly from `ORIGINAL_REQUEST.md` and `PROJECT.md § Feature Inventory`, without internal white-box mock dependencies.
- **Methodology**: 4-Tier Test Matrix (Category-Partition, Boundary Value Analysis, Pairwise Combinatorial Testing, Real-World Workloads).
- **Execution**: Canonical runner is `flutter test` via Flutter Test framework with `WidgetTester` and headless runtime bindings.
- **Constraints**: No local heavy APK compilation (`flutter build apk`).

## Feature Inventory & Tier Breakdown
| # | Feature | Requirement Source | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---------|-------------------|:------:|:------:|:------:|:------:|
| 1 | Widget RemoteViews XML Fix | PROJECT.md F1 (No `<View>`, uses `<FrameLayout>`) | 5 | 5 | ✓ | ✓ |
| 2 | Widget Kotlin Reflection Fix | PROJECT.md F2 (AudioService MediaSession reflection) | 5 | 5 | ✓ | ✓ |
| 3 | Widget MIUI Context & Intents | PROJECT.md F3 (FLAG_IMMUTABLE, safe app context) | 5 | 5 | ✓ | ✓ |
| 4 | Widget Grid & Dimension Fix | PROJECT.md F4 (minResizeWidth/Height, previewImage) | 5 | 5 | ✓ | ✓ |
| 5 | Root Rebuild Elimination | PROJECT.md F5 (Selector<PlayerProvider, ThemeData>) | 5 | 5 | ✓ | ✓ |
| 6 | RepaintBoundary Encapsulation | PROJECT.md F6 (VinylDisc, AmbientGlow, SpectrumBars) | 5 | 5 | ✓ | ✓ |
| 7 | Smooth Cubic Curve Transitions | PROJECT.md F7 (Curves.easeOutQuint & easeInOutCubic) | 5 | 5 | ✓ | ✓ |
| 8 | Fluid Hero Transitions | PROJECT.md F8 (MiniPlayer to NowPlaying album art hero) | 5 | 5 | ✓ | ✓ |
| 9 | Modern M3 Grouped Settings | PROJECT.md F9 (Grouped cards, crossfade slider, search) | 5 | 5 | ✓ | ✓ |
| 10 | Interactive Live Theme Preview | PROJECT.md F10 (Live player card, AnimatedTheme, OLED) | 5 | 5 | ✓ | ✓ |
| 11 | Smooth Queue Reordering & UX | PROJECT.md F11 (Drag handle, proxyDecorator, undo) | 5 | 5 | ✓ | ✓ |
| 12 | Version Bump to 1.3.3+33 | PROJECT.md F12 (AppConstants, pubspec, metadata) | 5 | 5 | ✓ | ✓ |
| 13 | Documentation & Web Updates | PROJECT.md F13 (README, index.html links/badges) | 5 | 5 | ✓ | ✓ |
| 14 | Test Suite v1.3.3 Update | PROJECT.md F14 (Existing test update, v133 test suite) | 5 | 5 | ✓ | ✓ |
| 15 | Git Tag & Cloud CI/CD Release | PROJECT.md F15 (release.yml, keystore, fetch script) | 5 | 5 | ✓ | ✓ |

## Test Architecture
- **Runner**: `flutter test`
- **Location**: `test/v133_features_and_widget_test.dart`
- **Pass/Fail Semantics**: All tests must complete with exit code 0 and 0 failures.
- **Headless Invariants**:
  - `TestWidgetsFlutterBinding.ensureInitialized();`
  - `GoogleFonts.config.allowRuntimeFetching = false;`
  - `SharedPreferences.setMockInitialValues({});`
  - `SineWidgetService.resetCache();`
  - Mock MethodChannel for `'com.taezeem.spotify_newpipe/widget'`
- **Animation Safety**:
  - No `tester.pumpAndSettle()` during continuous repeating animations (`VinylDisc`, `AmbientGlow`, `SpectrumBars`). Use explicit frame advances `tester.pump(Duration(milliseconds: 100))`.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Onboarding, Live Theme Preview & True OLED Black Mode | F5, F7, F9, F10 | Medium |
| 2 | High-Energy Workout Queue Reordering & Undo Dismissal | F8, F11, F14 | High |
| 3 | Commute Experience & Xiaomi Redmi Note 5 Pro Widget Interaction | F1, F2, F3, F4, F11 | High |
| 4 | Low-End Device Smooth Playback & Rebuild Isolation | F5, F6, F7, F8 | High |
| 5 | Version Upgrade, Backup Migration & Cloud Release Verification | F12, F13, F14, F15 | Medium |

## Coverage Thresholds
- **Tier 1 (Feature Coverage)**: ≥5 test cases per feature = 75 test cases.
- **Tier 2 (Boundary & Corner Cases)**: ≥5 test cases per feature = 75 test cases.
- **Tier 3 (Cross-Feature Combinations)**: 15 pairwise interaction tests.
- **Tier 4 (Real-World Scenarios)**: 5 comprehensive application scenarios.
- **Total Test Suite Target**: ≥170 test cases in `test/v133_features_and_widget_test.dart`.
