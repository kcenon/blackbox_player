# BlackboxPlayer - Implementation Checklist

**Last Updated**: 2025-10-13
**Purpose**: Step-by-step implementation guide with actionable checklists
**Target Audience**: Developers implementing TODO items

---

## 📋 Table of Contents

1. [Environment Setup](#1-environment-setup-checklist)
2. [Before You Start](#2-before-you-start-checklist)
3. [Phase 1: Critical Path](#3-phase-1-critical-path)
4. [Phase 2: Core Features](#4-phase-2-core-features)
5. [Phase 3: Enhanced UX](#5-phase-3-enhanced-ux)
6. [Phase 4: Polish](#6-phase-4-polish)
7. [Testing & Validation](#7-testing--validation-checklist)
8. [Code Quality](#8-code-quality-checklist)

---

## 1. Environment Setup Checklist

### Prerequisites Verification

- [ ] **Verify Xcode Version**
  ```bash
  xcodebuild -version
  # Required: Xcode 15.4+ or 16.0+ (NOT 26.x beta)
  ```
  **If Xcode 26.x beta**: Download stable Xcode from https://developer.apple.com/download/all/

- [ ] **Verify Homebrew Installation**
  ```bash
  brew --version
  ```
  **If missing**: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

- [ ] **Verify Swift Version**
  ```bash
  swift --version
  # Required: Swift 5.9+
  ```

### Development Tools Installation

- [ ] **Install FFmpeg**
  ```bash
  brew install ffmpeg
  ffmpeg -version | head -1
  ```

- [ ] **Install Build Tools**
  ```bash
  brew install cmake git git-lfs xcodegen swiftlint
  ```

- [ ] **Install Metal Toolchain**
  ```bash
  xcodebuild -downloadComponent MetalToolchain
  # Expected download: ~700MB
  ```
  **Verification**: Build should no longer show "cannot execute tool 'metal'" error

### Project Setup

- [ ] **Open Project in Xcode**
  ```bash
  cd /Users/dongcheolshin/Sources/blackbox_player
  open BlackboxPlayer.xcodeproj
  ```

- [ ] **Configure Code Signing**
  - Select BlackboxPlayer target
  - Go to "Signing & Capabilities"
  - Select your development team
  - Verify bundle identifier: `com.blackboxplayer.app`

- [ ] **Build Project Successfully**
  ```bash
  xcodebuild -project BlackboxPlayer.xcodeproj \
             -scheme BlackboxPlayer \
             -configuration Debug build
  ```
  **Expected**: Build succeeds with 0 errors

---

## 2. Before You Start Checklist

### Understanding the Codebase

- [ ] **Read Core Documentation**
  - [ ] `docs/03_architecture.md` - Understand MVVM architecture
  - [ ] `docs/02_technology_stack.md` - Review FFmpeg/Metal/SwiftUI stack
  - [ ] `docs/04_project_plan.md` - Read Appendix A (TODO summary)

- [ ] **Study Key Files** (Priority order)
  1. [ ] `BlackboxPlayer/App/BlackboxPlayerApp.swift` (433 lines, 14 TODOs)
     - App entry point
     - Menu structure
     - TODO items for menu actions

  2. [ ] `BlackboxPlayer/Models/VideoFile.swift` (1911 lines)
     - Core data model
     - Multi-channel structure
     - Sample data for testing

  3. [ ] `BlackboxPlayer/Services/VideoDecoder.swift` (1006 lines)
     - FFmpeg integration
     - H.264/MP3 decoding

### Running Existing Tests

- [ ] **Run Full Test Suite**
  ```bash
  ./scripts/test.sh
  # OR: xcodebuild test -scheme BlackboxPlayer
  ```
  **Note**: Some tests may fail due to missing implementations - this is expected

- [ ] **Review Test Coverage**
  - [ ] GPSSensorIntegrationTests - GPS/G-sensor pipeline
  - [ ] SyncControllerTests - Multi-channel synchronization
  - [ ] VideoDecoderTests - FFmpeg decoding
  - [ ] DataModelsTests - Core data structures

---

## 3. Phase 1: Critical Path

**Goal**: Basic file loading and playback working

#### TODO #1: Open Folder Picker 🔴 P0
- [ ] **Implement NSOpenPanel**
  ```swift
  // File: BlackboxPlayer/App/BlackboxPlayerApp.swift:463
  func openFolderPicker() {
      let panel = NSOpenPanel()
      panel.canChooseFiles = false
      panel.canChooseDirectories = true
      panel.begin { response in
          if response == .OK, let url = panel.url {
              // Load files from url
          }
      }
  }
  ```

- [ ] **Validation**
  - [ ] Dialog opens and closes correctly
  - [ ] Selected folder triggers file loading
  - [ ] UI updates with file list

#### TODO #7: Play/Pause 🔴 P0
- [ ] **Implement Playback Control**
  ```swift
  // File: BlackboxPlayer/App/BlackboxPlayerApp.swift:681
  func togglePlayPause() {
      // TODO: Call VideoPlayerService.togglePlayPause()
  }
  ```
  - [ ] Connect to existing VideoDecoder
  - [ ] Update UI state
  - [ ] Handle keyboard shortcut (Space)

- [ ] **Validation**
  - [ ] Video plays and pauses correctly
  - [ ] Audio synchronized
  - [ ] Frame rate stable (30fps minimum)

#### TODO #2: Refresh File List 🔴 P0
- [ ] **Implement Refresh**
  ```swift
  // File: BlackboxPlayer/App/BlackboxPlayerApp.swift:507
  func refreshFileList() {
      // TODO: Call FileSystemService.refreshFiles()
  }
  ```

- [ ] **Validation**
  - [ ] Detects new files added to SD card
  - [ ] Updates UI without full restart
  - [ ] Preserves user selection

---

## 4. Phase 2: Core Features

**Goal**: Multi-channel playback with metadata

### Metadata Parsing

#### TODO #27: Load Video Metadata 🟠 P1
- [ ] Parse proprietary metadata format
- [ ] Extract channel information
- [ ] Load associated metadata files (.gps, .gsensor)
- [ ] **Validation**: Metadata aligns with video

#### TODO #25: Parse GPS Metadata 🟠 P1
- [ ] **Implementation** (`MetadataExtractor.swift:359`)
  - [ ] Reverse engineer GPS binary format
  - [ ] Parse latitude, longitude, altitude, speed
  - [ ] Handle timestamp synchronization
- [ ] **Validation**: GPS points render correctly on map

### Synchronization

#### TODO #26: Sync Video Timestamp 🟠 P1
- [ ] **Implementation** (`SyncController.swift:1459`)
  - [ ] Align video PTS with GPS timestamps
  - [ ] Implement drift correction (±50ms)
  - [ ] Handle different frame rates
- [ ] **Validation**: Metadata updates in real-time during playback

#### TODO #8: Step Forward 🟠 P1
- [ ] Seek to currentTime + (1/frameRate)
- [ ] Update all channels synchronously
- [ ] **Validation**: Frame-accurate stepping

#### TODO #9: Step Backward 🟠 P1
- [ ] Seek to currentTime - (1/frameRate)
- [ ] Handle start-of-file boundary
- [ ] **Validation**: Reverse frame stepping works

#### TODO #3: Toggle Sidebar 🟠 P1
- [ ] Implement NavigationSplitViewVisibility toggle
- [ ] Save state to UserDefaults
- [ ] **Validation**: Sidebar shows/hides correctly

---

## 5. Phase 3: Enhanced UX

**Goal**: Overlays and advanced controls

### Overlay Implementation

#### TODO #4: Toggle Metadata Overlay 🟠 P1
- [ ] Create MetadataOverlayView
- [ ] Display: time, GPS, speed, G-sensor
- [ ] Update in real-time during playback
- [ ] **Validation**: Overlay synchronized with video

#### TODO #5: Toggle Map Overlay 🟠 P1
- [ ] Integrate MapKit
- [ ] Draw GPS route on map
- [ ] Highlight current position
- [ ] **Validation**: Map updates during playback

#### TODO #6: Toggle Graph Overlay 🟠 P1
- [ ] Create GSensorChartView with Charts framework
- [ ] Plot X/Y/Z acceleration
- [ ] Highlight impact events
- [ ] **Validation**: Graph synchronized with video

### Playback Controls

#### TODO #10: Increase Speed 🟡 P2
- [ ] Implement speed increments (1x → 1.5x → 2x → 4x)
- [ ] Update UI indicator
- [ ] **Validation**: Audio pitch maintained

#### TODO #11: Decrease Speed 🟡 P2
- [ ] Implement speed decrements (4x → 2x → 1.5x → 1x → 0.5x)
- [ ] Handle slow-motion audio
- [ ] **Validation**: Smooth speed transitions

#### TODO #12: Normal Speed 🟡 P2
- [ ] Reset to 1.0x playback rate
- [ ] **Validation**: Returns to normal immediately

#### TODO #42: Filter File List 🟡 P2
- [ ] Add filter controls (event type, date, channel)
- [ ] Implement predicate logic
- [ ] **Validation**: Filters apply correctly

#### TODO #43: File Row Actions 🟡 P2
- [ ] Add context menu (export, delete, rename)
- [ ] Implement action handlers
- [ ] **Validation**: Actions work on selected files

---

## 6. Phase 4: Polish

**Goal**: Complete application

### Help & Settings

#### TODO #13: Show About Window 🟢 P3
- [ ] Create AboutView with app info
- [ ] Include version, copyright, licenses
- [ ] **Validation**: About window displays correctly

#### TODO #14: Show Help 🟢 P3
- [ ] Create HelpView with user guide
- [ ] Document keyboard shortcuts
- [ ] **Validation**: Help is accessible and accurate

### Testing & Optimization

#### TODO #28-41: Metal Renderer Tests 🟡 P2
- [ ] Test multi-texture rendering
- [ ] Test layout switching
- [ ] Test video transformations
- [ ] Test performance benchmarks
- [ ] Test memory management
- [ ] Test thread safety
- [ ] **Validation**: All tests pass, coverage >80%

---

## 7. Testing & Validation Checklist

### Unit Testing

- [ ] **Run Full Test Suite**
  ```bash
  xcodebuild test -scheme BlackboxPlayer \
    -destination 'platform=macOS'
  ```

- [ ] **Test Coverage Analysis**
  ```bash
  xcodebuild test -scheme BlackboxPlayer \
    -enableCodeCoverage YES
  ```
  **Target**: >80% coverage

- [ ] **Specific Test Suites**
  - [ ] DataModelsTests - Core data structures
  - [ ] VideoDecoderTests - FFmpeg integration
  - [ ] SyncControllerTests - Multi-channel sync
  - [ ] GPSSensorIntegrationTests - End-to-end GPS/G-sensor

### Integration Testing

- [ ] **Multi-Channel Playback**
  - [ ] 5x 1080p videos play simultaneously
  - [ ] All channels synchronized (±50ms)
  - [ ] No frame drops during 10-minute playback

- [ ] **File Operations**
  - [ ] Can load files from local filesystem
  - [ ] Can parse 1000+ video file metadata
  - [ ] Can handle large video files (>2GB)

- [ ] **Performance**
  - [ ] Memory usage <2GB during playback
  - [ ] CPU usage <80% on Apple Silicon
  - [ ] GPU usage <70%

### Manual Testing

- [ ] **Happy Path**
  - [ ] Open folder picker → Select video folder
  - [ ] Browse file list → Select video
  - [ ] Play video → All channels display
  - [ ] Toggle overlays → GPS/metadata visible
  - [ ] Export to MP4 → File created successfully

- [ ] **Error Cases**
  - [ ] Invalid folder path → Error message shown
  - [ ] Corrupted video file → Graceful handling
  - [ ] Missing video files → Clean error handling

- [ ] **Edge Cases**
  - [ ] Very long videos (>2 hours)
  - [ ] High resolution videos (4K)
  - [ ] Folder with mixed file formats

---

## 8. Code Quality Checklist

### Before Committing

- [ ] **Code Formatting**
  ```bash
  swiftlint lint --fix
  swiftlint lint --strict
  ```
  **Expected**: 0 warnings

- [ ] **Code Review Self-Check**
  - [ ] Descriptive function/variable names
  - [ ] Early exit with guard statements
  - [ ] Error handling with do-catch
  - [ ] No magic numbers (use named constants)
  - [ ] Comments explain "why", not "what"

### Documentation

- [ ] **Add DocC Comments**
  ```swift
  /// Loads GPS points from binary metadata file
  ///
  /// - Parameter filePath: Absolute path to .gps metadata file
  /// - Returns: Array of parsed GPS points with timestamps
  /// - Throws: `MetadataError.invalidFormat` if file is corrupted
  func loadGPSPoints(from filePath: String) async throws -> [GPSPoint]
  ```

- [ ] **Update Inline Comments**
  - [ ] Mark completed TODOs with implementation notes
  - [ ] Add performance notes where relevant
  - [ ] Document known limitations

### Commit Message

- [ ] **Use Conventional Commits**
  ```bash
  # Format: type(scope): description

  # Examples:
  git commit -m "feat(decoder): add H.265 video codec support"
  git commit -m "fix(decoder): resolve memory leak in frame cleanup"
  git commit -m "test(gps): add integration tests for route sync"
  ```

- [ ] **Types**
  - `feat`: New feature
  - `fix`: Bug fix
  - `docs`: Documentation only
  - `test`: Adding/updating tests
  - `refactor`: Code restructuring
  - `perf`: Performance improvement
  - `chore`: Build/tooling changes

### Pull Request

- [ ] **PR Description Template**
  ```markdown
  ## Summary
  Implements TODO #X: [Brief description]

  ## Changes
  - [List of key changes]

  ## Testing
  - [How to test]
  - [Test cases covered]

  ## Screenshots (if UI change)
  [Attach before/after screenshots]

  ## Performance (if applicable)
  - Memory: [impact]
  - CPU: [impact]
  - FPS: [impact]

  Closes #X
  ```

- [ ] **Before Requesting Review**
  - [ ] All tests passing
  - [ ] SwiftLint 0 warnings
  - [ ] Documentation updated
  - [ ] Performance benchmarks run (if applicable)

---

## 📊 Progress Tracking

### Milestones

#### Milestone 1: MVP
- [ ] File list loading from local filesystem
- [ ] Single channel video playback
- [ ] Basic playback controls (play, pause, seek)

**Definition of Done**: Can play a single channel video from local folder

#### Milestone 2: Multi-Channel
- [ ] Multiple channels synchronized
- [ ] GPS overlay working
- [ ] Metadata overlay working
- [ ] G-sensor graph working

**Definition of Done**: Can play 5 channels with overlays

#### Milestone 3: Feature Complete
- [ ] All menu actions implemented
- [ ] Export functionality working
- [ ] Settings management working
- [ ] Test coverage >80%

**Definition of Done**: All 59 TODOs completed, ready for beta testing

---

## 🆘 Troubleshooting Guide

### Common Build Issues

#### "Cannot find module 'FFmpeg'"
```bash
# Solution: Add FFmpeg to header search paths
# In project.yml:
HEADER_SEARCH_PATHS: /opt/homebrew/Cellar/ffmpeg/8.0_1/include
```

#### "Metal pipeline state creation failed"
```bash
# Solution: Check shader syntax
# View shader compilation output in Xcode build log
# Look for syntax errors in MultiChannelShaders.metal
```

#### "The Xcode build system has crashed"
```bash
# Solution: Downgrade to stable Xcode
# Xcode 26.x beta has known issues with experimental features
# Download Xcode 15.4 or 16.0 from developer.apple.com
```

### Runtime Issues

#### Memory Usage Growing Over Time
Check for:
- Unreleased video frames
- Unclosed file handles
- Retained strong references in closures

Profile with Instruments → Leaks tool.

---

## 📚 Reference

### Key Files by Feature

| Feature | Primary File | Test File |
|---------|-------------|-----------|
| Video Decoding | VideoDecoder.swift | VideoDecoderTests.swift |
| Multi-Channel Sync | SyncController.swift | SyncControllerTests.swift |
| GPS Service | GPSService.swift | GPSSensorIntegrationTests.swift |
| Metal Rendering | MultiChannelRenderer.swift | MultiChannelRendererTests.swift |
| Menu Actions | BlackboxPlayerApp.swift | (UI Tests) |

### External Resources

- **FFmpeg**: https://ffmpeg.org/documentation.html
- **Metal**: https://developer.apple.com/documentation/metal
- **SwiftUI**: https://developer.apple.com/documentation/swiftui

---

**Last Updated**: 2025-10-13
**Next Review**: After each milestone completion
