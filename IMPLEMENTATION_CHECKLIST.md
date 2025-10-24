# BlackboxPlayer - Implementation Checklist

**Last Updated**: 2025-10-25
**Purpose**: Step-by-step implementation guide with actionable checklists
**Target Audience**: Developers implementing TODO items

---

## 📋 Table of Contents

1. [Current Implementation Status](#current-implementation-status)
2. [Environment Setup](#1-environment-setup-checklist)
3. [Before You Start](#2-before-you-start-checklist)
4. [Phase 1: File System & Metadata](#3-phase-1-file-system--metadata)
5. [Phase 2: Video Decoding & Playback](#4-phase-2-video-decoding--playback)
6. [Phase 3: Multi-Channel Synchronization](#5-phase-3-multi-channel-synchronization)
7. [Phase 4: GPS, G-Sensor & Image Processing](#6-phase-4-gps-g-sensor--image-processing)
8. [Phase 5: Metal Rendering & UI](#7-phase-5-metal-rendering--ui)
9. [Testing & Validation](#8-testing--validation-checklist)
10. [Code Quality](#9-code-quality-checklist)

---

## Current Implementation Status

**Last Updated**: 2025-10-25

### ✅ Completed Phases (Phases 1-4)

#### Phase 1: File System and Metadata Extraction ✅
**Commit**: f0981f7, 1fd70da, 60a418f

- [x] **FileScanner** (BlackboxPlayer/Services/FileScanner.swift)
  - Recursive directory scanning
  - Video file filtering (.mp4, .avi, .mov, etc.)
  - Error handling and logging

- [x] **FileSystemService** (BlackboxPlayer/Services/FileSystemService.swift)
  - File metadata extraction (size, dates)
  - Directory operations
  - File type detection

- [x] **VideoFileLoader** (BlackboxPlayer/Services/VideoFileLoader.swift)
  - Video file metadata extraction via VideoDecoder
  - Concurrent loading with DispatchQueue
  - Progress reporting

- [x] **MetadataExtractor** (BlackboxPlayer/Services/MetadataExtractor.swift)
  - GPS data extraction from MP4 atom structure
  - Acceleration data extraction
  - Frame-by-frame metadata parsing

#### Phase 2: Video Decoding and Playback Control ✅
**Commit**: 083ba4d

- [x] **VideoDecoder** (BlackboxPlayer/Services/VideoDecoder.swift, 1584 lines)
  - FFmpeg integration for video decoding
  - Frame-by-frame decoding with timestamp
  - Seek functionality (keyframe-based)
  - BGRA pixel format output
  - Thread-safe operations

- [x] **MultiChannelSynchronizer** (BlackboxPlayer/Services/MultiChannelSynchronizer.swift)
  - Multi-channel timestamp synchronization
  - Frame selection strategies (nearest, before, after, exact)
  - Tolerance-based sync control (default 33ms)

#### Phase 3: Multi-Channel Synchronization ✅
**Commit**: 4712a30

- [x] **VideoBuffer** (BlackboxPlayer/Services/VideoBuffer.swift)
  - Thread-safe FIFO circular buffer
  - Max 30 frames buffering
  - Timestamp-based frame search
  - Automatic old frame cleanup

- [x] **MultiChannelSynchronizer** (enhanced)
  - Drift monitoring with Timer-based checking (100ms interval)
  - Automatic drift correction (50ms threshold)
  - Drift statistics and history tracking
  - Median timestamp strategy for minimal seek

#### Phase 4: GPS Mapping, G-Sensor, Image Processing ✅
**Commit**: 8b9232c

- [x] **GPSService** (BlackboxPlayer/Services/GPSService.swift, 1235 lines)
  - GPS data loading and parsing
  - Timestamp-based location query
  - Haversine distance calculation
  - Speed/direction calculation

- [x] **GSensorService** (BlackboxPlayer/Services/GSensorService.swift, 1744 lines)
  - Acceleration data processing
  - Impact event detection (threshold-based)
  - Timestamp synchronization
  - Filtering and normalization

- [x] **FrameCaptureService** (BlackboxPlayer/Services/FrameCaptureService.swift, 415 lines)
  - Video frame to image file capture (PNG/JPEG)
  - Metadata overlay support (timestamp, GPS info)
  - Multi-channel composite capture (grid/horizontal layout)
  - VideoFrame → CGImage → NSImage conversion

- [x] **VideoTransformations** (BlackboxPlayer/Services/VideoTransformations.swift, 1085 lines)
  - Video transformation parameters management
  - Brightness/contrast, flip, digital zoom
  - UserDefaults persistence
  - SwiftUI integration (@Published)

### ✅ Phase 5: Metal Rendering and UI (COMPLETED)

#### Phase 5: Metal Rendering and UI ✅
**Status**: Completed (2025-10-25)
**Commit**: [To be added]

Components implemented:
- [x] **MultiChannelRenderer** (BlackboxPlayer/Services/MultiChannelRenderer.swift, 1336 lines)
  - Metal-based GPU-accelerated multi-channel video rendering
  - Support for Grid, Focus, Horizontal layout modes
  - Video transformations (brightness, flip, zoom) via Metal shaders
  - Frame capture and screenshot functionality
  - CVMetalTextureCache for optimized texture management

- [x] **Metal Shaders** (BlackboxPlayer/Shaders/MultiChannelShaders.metal, 117 lines)
  - Vertex shader with flip and zoom transformations
  - Fragment shader with brightness adjustment
  - YUV to RGB conversion shader

- [x] **MapOverlayView** (BlackboxPlayer/Views/MapOverlayView.swift, 1296 lines)
  - GPS route visualization with MapKit integration
  - Past/future path rendering (blue solid / gray dashed)
  - Current position marker with speed display
  - Impact event markers at collision points
  - Control buttons (center on location, fit route)

- [x] **GraphOverlayView** (BlackboxPlayer/Views/GraphOverlayView.swift, 1216 lines)
  - Real-time G-sensor (accelerometer) data visualization
  - 3-axis graphs (X: red, Y: green, Z: blue)
  - 10-second sliding time window
  - Impact event highlighting (4G+ threshold)
  - Current time indicator

- [x] **MetadataOverlayView** (BlackboxPlayer/Views/MetadataOverlayView.swift, 1286 lines)
  - Real-time metadata overlay (GPS, speed, G-force)
  - Left panel: Speed gauge, GPS coordinates, altitude, heading
  - Right panel: Timestamp, G-force, event type badge
  - Semi-transparent background with video blending

- [x] **MultiChannelPlayerView** (BlackboxPlayer/Views/MultiChannelPlayerView.swift, 1996 lines)
  - Complete multi-channel player UI with Metal rendering
  - Layout controls and channel indicators
  - Video transformation controls
  - GPS/metadata overlay toggles
  - Fullscreen mode with auto-hiding controls
  - Screenshot capture integration

- [x] **NotificationExtensions** (BlackboxPlayer/Utilities/NotificationExtensions.swift, 232 lines)
  - All menu action notifications defined
  - File management, UI toggles, playback control
  - Help & info notifications

- [x] **Menu Integration** (BlackboxPlayer/App/BlackboxPlayerApp.swift, 860 lines)
  - Complete menu system with keyboard shortcuts
  - File, View, Playback, Help menus
  - All notifications properly connected to ContentView

- [x] **UI Integration** (BlackboxPlayer/Views/ContentView.swift, 1887 lines)
  - All notification receivers implemented
  - Complete UI flow integration
  - File management and playback control

### Git Commit History
```
8b9232c - feat(Phase4): implement FrameCaptureService for screenshot and image processing
4712a30 - feat(Phase3): implement drift monitoring and VideoBuffer for multi-channel synchronization
083ba4d - feat(VideoDecoder, MultiChannelSynchronizer): implement frame navigation and multi-channel synchronization for Phase 2
60a418f - feat(MetadataExtractor): implement GPS and acceleration data extraction
1fd70da - feat(VideoFileLoader): integrate VideoDecoder for real video metadata extraction
f0981f7 - refactor(FileScanner): integrate FileSystemService for file operations
```

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

## 3. Phase 1: File System & Metadata

**Status**: ✅ COMPLETED
**Goal**: Implement file system access and metadata parsing
**Commits**: f0981f7, 1fd70da, 60a418f

### Completed Components

#### ✅ FileScanner (BlackboxPlayer/Services/FileScanner.swift)
- [x] Recursive directory scanning
- [x] Video file filtering (.mp4, .avi, .mov, etc.)
- [x] Error handling and logging
- [x] File type detection

#### ✅ FileSystemService (BlackboxPlayer/Services/FileSystemService.swift)
- [x] File metadata extraction (size, creation date, modification date)
- [x] Directory operations
- [x] File type detection
- [x] Path validation

#### ✅ VideoFileLoader (BlackboxPlayer/Services/VideoFileLoader.swift)
- [x] Video file metadata extraction via VideoDecoder
- [x] Concurrent loading with DispatchQueue
- [x] Progress reporting
- [x] Error handling for corrupted files

#### ✅ MetadataExtractor (BlackboxPlayer/Services/MetadataExtractor.swift)
- [x] GPS data extraction from MP4 atom structure
- [x] Acceleration data extraction
- [x] Frame-by-frame metadata parsing
- [x] Timestamp synchronization

---

## 4. Phase 2: Video Decoding & Playback

**Status**: ✅ COMPLETED
**Goal**: Implement video decoding and frame-by-frame playback control
**Commit**: 083ba4d

### Completed Components

#### ✅ VideoDecoder (BlackboxPlayer/Services/VideoDecoder.swift, 1584 lines)
- [x] FFmpeg integration for video decoding
- [x] H.264/MP3 codec support
- [x] Frame-by-frame decoding with timestamp
- [x] Seek functionality (keyframe-based)
- [x] BGRA pixel format output for Metal rendering
- [x] Thread-safe operations with NSLock
- [x] Memory management and cleanup

#### ✅ MultiChannelSynchronizer (BlackboxPlayer/Services/MultiChannelSynchronizer.swift)
- [x] Multi-channel timestamp synchronization
- [x] Frame selection strategies (nearest, before, after, exact)
- [x] Tolerance-based sync control (default 33ms)
- [x] Frame alignment across multiple channels
- [x] Error handling for missing frames

---

## 5. Phase 3: Multi-Channel Synchronization

**Status**: ✅ COMPLETED
**Goal**: Achieve frame-perfect synchronization across 5 channels
**Commit**: 4712a30

### Completed Components

#### ✅ VideoBuffer (BlackboxPlayer/Services/VideoBuffer.swift, NEW)
- [x] Thread-safe FIFO circular buffer implementation
- [x] Maximum 30 frames buffering capacity
- [x] Timestamp-based frame search
- [x] Automatic old frame cleanup
- [x] Memory-efficient frame management

#### ✅ MultiChannelSynchronizer (Enhanced)
- [x] Drift monitoring with Timer-based checking (100ms interval)
- [x] Automatic drift correction (50ms threshold)
- [x] Drift statistics and history tracking
- [x] Median timestamp strategy for minimal seek operations
- [x] Multi-channel frame alignment with tolerance control

### Validation Results
- [x] 5 channels synchronized with ±50ms accuracy
- [x] Drift monitoring prevents desynchronization
- [x] Automatic correction maintains sync during long playback
- [x] Performance optimized for real-time playback

---

## 6. Phase 4: GPS, G-Sensor & Image Processing

**Status**: ✅ COMPLETED
**Goal**: Implement GPS mapping, G-sensor visualization, and image processing
**Commit**: 8b9232c

### Completed Components

#### ✅ GPSService (BlackboxPlayer/Services/GPSService.swift, 1235 lines)
- [x] GPS data loading and parsing from metadata
- [x] Timestamp-based location query with binary search
- [x] Haversine distance calculation
- [x] Speed and direction calculation
- [x] GPS route interpolation
- [x] Coordinate system conversion

#### ✅ GSensorService (BlackboxPlayer/Services/GSensorService.swift, 1744 lines)
- [x] Acceleration data processing
- [x] Impact event detection (threshold-based)
- [x] Timestamp synchronization with video
- [x] Data filtering and normalization
- [x] X/Y/Z axis acceleration tracking
- [x] Event severity classification

#### ✅ FrameCaptureService (BlackboxPlayer/Services/FrameCaptureService.swift, 415 lines)
- [x] Video frame to image file capture (PNG/JPEG)
- [x] Metadata overlay support (timestamp, GPS info)
- [x] Multi-channel composite capture
- [x] Grid and horizontal layout support
- [x] VideoFrame → CGImage → NSImage conversion
- [x] File path validation and error handling

#### ✅ VideoTransformations (BlackboxPlayer/Services/VideoTransformations.swift, 1085 lines)
- [x] Video transformation parameters management
- [x] Brightness and contrast adjustment
- [x] Horizontal and vertical flip
- [x] Digital zoom with pan support
- [x] UserDefaults persistence
- [x] SwiftUI integration with @Published properties

### Validation Results
- [x] GPS data synchronized with video playback
- [x] G-sensor events detected and highlighted
- [x] Screenshot capture working for all channels
- [x] Video transformations applied in real-time
- [x] All services thread-safe and performant

---

## 7. Phase 5: Metal Rendering & UI

**Status**: ⏳ PENDING
**Goal**: Implement Metal GPU rendering and complete UI layer
**Priority**: HIGH (requires Xcode build environment)

### Pending Components

#### ⏳ MetalRenderer (Not Started)
- [ ] GPU-accelerated video rendering pipeline
- [ ] Multi-texture rendering for 5 channels
- [ ] Shader programs for transformations
- [ ] Real-time brightness/contrast/zoom
- [ ] Performance optimization for 30fps+

#### ⏳ MapViewController (Not Started)
- [ ] MapKit integration for GPS route display
- [ ] Real-time position marker
- [ ] Route polyline rendering
- [ ] User interaction (zoom, pan)
- [ ] Synchronization with video playback

#### ⏳ UI Layer (Not Started)
- [ ] SwiftUI views for all features
- [ ] AppKit integration for complex controls
- [ ] Menu actions implementation
- [ ] Keyboard shortcuts
- [ ] Settings management UI

### Dependencies
- Xcode project configuration
- Metal framework setup
- MapKit permissions
- SwiftUI layout debugging

---

## 8. Testing & Validation Checklist

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

## 9. Code Quality Checklist

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

**Last Updated**: 2025-10-25
**Next Review**: After Phase 5 (Metal Rendering & UI) completion
