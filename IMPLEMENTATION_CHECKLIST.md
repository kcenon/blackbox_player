# Implementation Checklist

> 🌐 **Language**: [English](#) | [한국어](IMPLEMENTATION_CHECKLIST_kr.md)

This document provides a detailed checklist for implementing the macOS Blackbox Player project. Check off tasks as you complete them to track your progress.

**Timeline**: 12-16 weeks (3-4 months)
**Last Updated**: 2025-10-10

---

## Progress Overview

```
Phase 0: Preparation           [█████░░░░░] 9/15 tasks   (Week 1) ✓ Environment Ready
Phase 1: File System & Data    [ ] 0/24 tasks   (Weeks 2-4)
Phase 2: Single Channel        [ ] 0/22 tasks   (Weeks 5-7)
Phase 3: Multi-Channel Sync    [ ] 0/21 tasks   (Weeks 8-10)
Phase 4: Additional Features   [ ] 0/18 tasks   (Weeks 11-12)
Phase 5: Export & Settings     [ ] 0/16 tasks   (Weeks 13-14)
Phase 6: Localization & Polish [ ] 0/20 tasks   (Weeks 15-16)
─────────────────────────────────────────────────────
Total Progress                 [█░░░░░░░░░] 9/136 tasks (6.6%)
```

---

## Phase 0: Preparation (Week 1)

**Goal**: Set up development environment and verify technical feasibility

### Environment Setup

- [x] Install Xcode 15+ from Mac App Store (26.0.1 installed)
- [x] Install Homebrew package manager (4.6.11 installed)
  ```bash
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ```
- [x] Install development tools (FFmpeg 8.0, Git LFS 3.7.0, SwiftLint 0.61.0)
  ```bash
  brew install ffmpeg cmake git git-lfs swiftlint
  ```
- [x] Install Xcode Command Line Tools
  ```bash
  xcode-select --install
  ```
- [ ] Create/verify Apple Developer account (user action required)
- [ ] Configure code signing certificates in Xcode (user action required)

### Project Initialization

- [x] Create new Xcode project (using xcodegen)
  - Template: macOS App
  - Interface: SwiftUI
  - Language: Swift
  - Minimum Deployment: macOS 12.0
- [x] Set up project folder structure
  ```
  BlackboxPlayer/
  ├── App/
  ├── Views/
  ├── ViewModels/
  ├── Services/
  ├── Models/
  ├── Utilities/
  ├── Resources/
  └── Tests/
  ```
- [x] Configure .gitignore for Xcode
- [x] Set up Git repository with initial commit
- [x] Configure CI/CD pipeline (GitHub Actions)

### Library Integration

- [ ] Obtain EXT4 C/C++ library from vendor
- [ ] Create Objective-C++ bridging header
- [ ] Test basic EXT4 read operation
- [ ] Verify EXT4 library macOS compatibility
- [ ] Link FFmpeg libraries to project
- [ ] Create basic FFmpeg Swift wrapper
- [ ] Test H.264 video decoding with FFmpeg

### Sample Data Collection

- [ ] Obtain sample SD card from dashcam
- [ ] Document SD card file structure
- [ ] Extract and document metadata format
- [ ] Extract GPS data samples
- [ ] Extract G-Sensor data samples
- [ ] Document video specifications (resolution, codec, bitrate, fps)

### Proof of Concept

- [ ] Create minimal EXT4 file read demo
- [ ] Create minimal FFmpeg H.264 decode demo
- [ ] Display single decoded frame in SwiftUI
- [ ] Validate hardware performance (decode 5 streams simultaneously)
- [ ] Document any technical blockers or limitations

**Success Criteria**:
- ✅ Can read files from EXT4-formatted SD card
- ✅ Can decode H.264 video with FFmpeg
- ✅ Can display video frame in SwiftUI
- ✅ Project builds without errors

---

## Phase 1: File System & Data Layer (Weeks 2-4)

**Goal**: Implement EXT4 file system access and metadata parsing

### Week 1: EXT4 Integration

#### EXT4 Bridge Implementation

- [ ] Create `EXT4Wrapper.h` (Objective-C++ header)
- [ ] Create `EXT4Wrapper.mm` (Objective-C++ implementation)
- [ ] Implement `mount(device:)` method
- [ ] Implement `unmount()` method
- [ ] Implement `listFiles(at:)` method
- [ ] Implement `readFile(at:)` method
- [ ] Implement `writeFile(data:to:)` method
- [ ] Create Swift `EXT4Bridge` class
- [ ] Add comprehensive error handling
- [ ] Write unit tests for EXT4Bridge
- [ ] Test with real SD card hardware

#### Device Detection

- [ ] Implement USB device detection (IOKit)
- [ ] Create device filter for SD cards
- [ ] Implement device selection UI
- [ ] Add device connection/disconnection notifications
- [ ] Handle multiple connected SD cards

### Week 2: Metadata Parsing

#### Metadata Parser Implementation

- [ ] Create `MetadataParser` class
- [ ] Reverse engineer GPS data format
- [ ] Implement GPS data parser
- [ ] Reverse engineer G-Sensor data format
- [ ] Implement G-Sensor data parser
- [ ] Implement timestamp parser
- [ ] Implement channel info parser
- [ ] Add data validation logic
- [ ] Write unit tests for parsers

#### Data Models

- [ ] Define `VideoFile` model (Identifiable, Codable)
- [ ] Define `VideoMetadata` model
- [ ] Define `GPSPoint` model
- [ ] Define `AccelerationData` model
- [ ] Define `EventType` enum
- [ ] Define `ChannelInfo` model
- [ ] Define `CameraPosition` enum
- [ ] Create test fixtures for all models

### Week 3: File Manager Service

#### Service Implementation

- [ ] Create `FileManagerService` protocol
- [ ] Implement file scanning logic
- [ ] Implement event type categorization (Normal/Impact/Parking)
- [ ] Implement file filtering by type
- [ ] Implement search functionality
- [ ] Add file caching mechanism
- [ ] Handle corrupted files gracefully
- [ ] Write integration tests

#### Basic UI

- [ ] Create `FileListView` (SwiftUI)
- [ ] Create `FileRow` component
- [ ] Display file information (name, size, duration, date)
- [ ] Show event type badges with colors
- [ ] Implement file selection (single/multi)
- [ ] Add loading states
- [ ] Add error states

**Success Criteria**:
- ✅ Can mount SD card and list all files
- ✅ Can read video file data
- ✅ Can parse GPS and G-Sensor metadata
- ✅ File list displays correctly with event types
- ✅ No memory leaks in file operations

---

## Phase 2: Single Channel Playback (Weeks 5-7)

**Goal**: Implement smooth single-video playback

### Week 1: Video Decoder

#### FFmpeg Integration

- [ ] Create `VideoDecoder` class
- [ ] Implement `open(url:)` method
- [ ] Implement H.264 decoding
- [ ] Implement MP3 audio decoding
- [ ] Handle different video resolutions
- [ ] Implement frame buffering (circular buffer)
- [ ] Add error recovery logic
- [ ] Optimize decoding performance
- [ ] Write unit tests

#### Audio/Video Synchronization

- [ ] Implement master clock (CMClock)
- [ ] Implement A/V drift detection
- [ ] Implement A/V drift correction
- [ ] Handle variable frame rates
- [ ] Test with different video samples

### Week 2: Metal Renderer

#### Metal Setup

- [ ] Create `MetalVideoRenderer` class
- [ ] Initialize Metal device and command queue
- [ ] Create render pipeline descriptor
- [ ] Implement vertex shader
- [ ] Implement fragment shader
- [ ] Create texture from CVPixelBuffer
- [ ] Implement render loop (60fps target)
- [ ] Handle window resizing
- [ ] Optimize for performance
- [ ] Profile with Metal debugger

#### Video Player View

- [ ] Create `VideoPlayerView` (SwiftUI + MTKView)
- [ ] Display video frames
- [ ] Handle aspect ratio correctly
- [ ] Add loading indicator
- [ ] Add error display

### Week 3: Playback Controls

#### Controls UI Implementation

- [ ] Create `PlayerControlsView`
- [ ] Implement Play/Pause button
- [ ] Implement Stop button
- [ ] Implement Previous/Next file buttons
- [ ] Create timeline scrubber
- [ ] Display current time / duration
- [ ] Implement speed control picker (0.5x, 1x, 2x)
- [ ] Implement volume slider
- [ ] Add full-screen button

#### Keyboard Shortcuts

- [ ] Implement Space: Play/Pause
- [ ] Implement Left/Right: Seek ±5 seconds
- [ ] Implement Up/Down: Volume adjustment
- [ ] Implement F: Toggle full-screen
- [ ] Implement ESC: Exit full-screen

#### Player ViewModel

- [ ] Create `PlayerViewModel` (ObservableObject)
- [ ] Implement `play()` method
- [ ] Implement `pause()` method
- [ ] Implement `stop()` method
- [ ] Implement `seek(to:)` method
- [ ] Implement `setSpeed(_:)` method
- [ ] Implement `setVolume(_:)` method
- [ ] Add Published properties for UI binding
- [ ] Write unit tests with mocks

**Success Criteria**:
- ✅ Video plays at 30fps minimum
- ✅ Audio/video sync within ±50ms
- ✅ Seeking responds within 500ms
- ✅ Memory usage < 500MB for single HD video
- ✅ No frame drops during normal playback

---

## Phase 3: Multi-Channel Synchronization (Weeks 8-10)

**Goal**: Synchronize 5 channels with frame-perfect accuracy

### Week 1: Multi-Channel Architecture

#### Channel Management

- [ ] Create `VideoChannel` class
- [ ] Implement 5 independent decoder instances
- [ ] Create frame buffer for each channel
- [ ] Set up background decoding queues (GCD)
- [ ] Implement channel state management
- [ ] Add channel error handling
- [ ] Write unit tests

#### Synchronization Controller

- [ ] Create `SyncController` class
- [ ] Implement master clock
- [ ] Implement `syncPlay()` method
- [ ] Implement `syncPause()` method
- [ ] Implement `syncSeek(to:)` method
- [ ] Implement drift monitoring (every 100ms)
- [ ] Implement auto-correction (when drift > 50ms)
- [ ] Handle channels with different frame rates
- [ ] Write synchronization tests

### Week 2: Multi-Texture Rendering

#### Metal Multi-Channel Renderer

- [ ] Create `MultiChannelRenderer` class
- [ ] Implement single-pass 5-texture rendering
- [ ] Create grid layout calculator (2x3)
- [ ] Create focus layout (1 large + 4 small)
- [ ] Create horizontal layout (1x5)
- [ ] Handle missing channels gracefully
- [ ] Optimize render performance
- [ ] Profile with Metal debugger

#### Layout Manager

- [ ] Create `ChannelLayout` enum
- [ ] Create `LayoutManager` class
- [ ] Implement `calculateFrames(for:in:)` method
- [ ] Handle window resizing
- [ ] Add layout switching UI
- [ ] Persist layout preference

### Week 3: Performance Optimization

#### Memory Optimization

- [ ] Implement frame buffer limits (30 frames/channel)
- [ ] Release old frames promptly
- [ ] Use autoreleasepool in tight loops
- [ ] Monitor memory usage with MemoryMonitor
- [ ] Add low-memory warnings
- [ ] Test with Instruments (Allocations)

#### Threading Optimization

- [ ] Create dedicated decode queues (5 queues)
- [ ] Ensure rendering on main thread
- [ ] Avoid main thread blocking
- [ ] Optimize thread priorities
- [ ] Profile with Instruments (Time Profiler)
- [ ] Reduce context switching

#### GPU Optimization

- [ ] Use shared Metal resources
- [ ] Minimize texture uploads
- [ ] Batch draw calls
- [ ] Profile with Metal System Trace
- [ ] Optimize shader performance

**Success Criteria**:
- ✅ All 5 channels play at 30fps minimum
- ✅ Synchronization drift < ±50ms
- ✅ Memory usage < 2GB
- ✅ CPU usage < 80% on Apple Silicon
- ✅ GPU usage < 70%
- ✅ No frame drops during normal playback

---

## Phase 4: Additional Features (Weeks 11-12)

**Goal**: Implement GPS mapping, G-Sensor visualization, and image processing

### Week 1: GPS & G-Sensor

#### GPS Integration

- [ ] Create `GPSService` class
- [ ] Implement `loadGPSData(for:)` method
- [ ] Implement `getCurrentLocation(at:)` method
- [ ] Integrate MapKit framework
- [ ] Create `GPSMapView` (NSView + MKMapView)
- [ ] Draw route on map (MKPolyline)
- [ ] Update location marker during playback
- [ ] Add map controls (zoom, pan, center)
- [ ] Display speed and altitude info
- [ ] Write unit tests

#### G-Sensor Visualization

- [ ] Create `GSensorService` class
- [ ] Implement G-Sensor data parsing
- [ ] Create `GSensorChartView` (NSView + Core Graphics)
- [ ] Draw X/Y/Z acceleration axes
- [ ] Highlight impact events (magnitude > threshold)
- [ ] Synchronize chart with video playback
- [ ] Add zoom/pan for chart
- [ ] Display current values
- [ ] Write unit tests

### Week 2: Image Processing

#### Screen Capture

- [ ] Implement `captureCurrentFrame()` method
- [ ] Create save file dialog
- [ ] Support PNG format
- [ ] Support JPEG format
- [ ] Add optional timestamp overlay
- [ ] Save at full resolution
- [ ] Add success/error notifications

#### Video Transformations

- [ ] Create `VideoTransformations` class
- [ ] Implement brightness adjustment (Metal shader)
- [ ] Implement horizontal flip
- [ ] Implement vertical flip
- [ ] Implement digital zoom
- [ ] Update Metal shaders for transformations
- [ ] Add transformation controls UI
- [ ] Persist transformation settings

#### Full-Screen Mode

- [ ] Implement enter/exit full-screen
- [ ] Auto-hide controls in full-screen
- [ ] Show controls on mouse move
- [ ] Support multiple displays
- [ ] Handle display arrangement changes

**Success Criteria**:
- ✅ GPS location updates in real-time
- ✅ G-Sensor chart renders smoothly
- ✅ Image capture saves at full resolution
- ✅ Video transformations don't impact performance
- ✅ Full-screen mode works correctly

---

## Phase 5: Export & Settings (Weeks 13-14)

**Goal**: Implement MP4 export and dashcam configuration

### Week 1: MP4 Export

#### Export Service

- [ ] Create `ExportService` class
- [ ] Implement FFmpeg muxing (H.264 + MP3 → MP4)
- [ ] Support channel selection
- [ ] Embed metadata (GPS, G-Sensor)
- [ ] Implement progress tracking
- [ ] Support cancellation
- [ ] Implement batch export
- [ ] Write integration tests

#### Video Repair

- [ ] Implement `repairVideo(_:)` method
- [ ] Detect corrupted files
- [ ] Recover readable frames
- [ ] Skip damaged sections
- [ ] Generate playable MP4
- [ ] Report recovery statistics

#### Channel Extraction

- [ ] Implement `extractChannel(_:channel:)` method
- [ ] Extract specific channel
- [ ] Preserve audio if available
- [ ] Maintain video quality

### Week 2: Settings Management

#### Settings Service

- [ ] Create `SettingsService` class
- [ ] Reverse engineer settings file format
- [ ] Implement `loadSettings(from:)` method
- [ ] Implement `saveSettings(_:to:)` method
- [ ] Add settings validation
- [ ] Handle different firmware versions
- [ ] Write integration tests

#### Settings UI

- [ ] Create `SettingsView` (SwiftUI Form)
- [ ] Add Video section (resolution, mode)
- [ ] Add Features section (parking mode, sensitivity)
- [ ] Add Audio section
- [ ] Add Display section
- [ ] Implement save/cancel buttons
- [ ] Add unsaved changes warning
- [ ] Add tooltips/help text

**Success Criteria**:
- ✅ Can export 5-channel video to MP4
- ✅ Export preserves quality
- ✅ Repair recovers maximum frames
- ✅ Settings save correctly to SD card
- ✅ Settings UI is intuitive

---

## Phase 6: Localization & Polish (Weeks 15-16)

**Goal**: Production-ready application

### Week 1: Localization

#### String Extraction

- [ ] Extract all UI strings
- [ ] Create `en.lproj/Localizable.strings`
- [ ] Create `ko.lproj/Localizable.strings`
- [ ] Create `ja.lproj/Localizable.strings` (optional)
- [ ] Replace hardcoded strings with NSLocalizedString
- [ ] Test language switching

#### Translations

- [ ] Complete Korean translation
- [ ] Complete English translation
- [ ] Complete Japanese translation (optional)
- [ ] Review translations with native speakers
- [ ] Test UI layout in all languages

#### Localized Assets

- [ ] Localize error messages
- [ ] Localize help text
- [ ] Localize placeholder text
- [ ] Localize alert messages

### Week 2: Polish & Packaging

#### UI Polish

- [ ] Implement dark mode support
- [ ] Design and add app icon (1024x1024)
- [ ] Refine animations and transitions
- [ ] Improve error message clarity
- [ ] Add loading states everywhere
- [ ] Polish transitions between views
- [ ] Review and fix UI inconsistencies

#### Performance Tuning

- [ ] Profile with Instruments (Time Profiler)
- [ ] Fix all memory leaks
- [ ] Optimize app startup time (< 2 seconds)
- [ ] Reduce CPU usage during idle
- [ ] Reduce battery consumption
- [ ] Test on older Mac hardware

#### Accessibility

- [ ] Add VoiceOver labels to all UI elements
- [ ] Ensure keyboard navigation works
- [ ] Verify color contrast (WCAG AA)
- [ ] Support Dynamic Type (text scaling)
- [ ] Test with VoiceOver enabled

#### Documentation

- [ ] Write user manual (English & Korean)
- [ ] Write installation guide
- [ ] Write troubleshooting guide
- [ ] Write developer documentation
- [ ] Generate API documentation (DocC)

#### Code Signing & Notarization

- [ ] Configure code signing in Xcode
- [ ] Sign all frameworks and libraries
- [ ] Sign main app bundle
- [ ] Create DMG installer with create-dmg
- [ ] Submit for notarization
- [ ] Staple notarization ticket
- [ ] Test notarized app on clean system

#### Final Testing

- [ ] Test on macOS 12 (Monterey)
- [ ] Test on macOS 13 (Ventura)
- [ ] Test on macOS 14 (Sonoma)
- [ ] Test on Intel Mac
- [ ] Test on Apple Silicon Mac
- [ ] Test with various SD cards and dashcams
- [ ] Fix all critical bugs
- [ ] Verify all features work end-to-end

**Success Criteria**:
- ✅ All UI text properly localized
- ✅ Dark mode looks professional
- ✅ App passes Apple notarization
- ✅ DMG installs smoothly
- ✅ No critical bugs remain
- ✅ Performance meets all targets

---

## Testing Checklist

### Unit Tests (Target: 80% coverage)

- [ ] EXT4Bridge tests
- [ ] MetadataParser tests
- [ ] FileManagerService tests
- [ ] VideoDecoder tests
- [ ] PlayerViewModel tests
- [ ] ExportService tests
- [ ] GPSService tests
- [ ] GSensorService tests
- [ ] All models have tests

### Integration Tests

- [ ] EXT4 read/write with real SD card
- [ ] Multi-channel playback test
- [ ] Export with various video combinations
- [ ] Settings load/save test

### Performance Tests

- [ ] Playback FPS measurement
- [ ] Memory usage over time
- [ ] Export speed measurement
- [ ] App startup time

### UI Tests

- [ ] File list navigation
- [ ] Playback controls
- [ ] Settings form validation
- [ ] Export workflow

---

## Release Checklist

- [ ] All features implemented and tested
- [ ] All critical bugs fixed
- [ ] Documentation complete
- [ ] App signed and notarized
- [ ] DMG installer created and tested
- [ ] Release notes written
- [ ] App Store screenshots prepared (if applicable)
- [ ] Marketing materials ready
- [ ] Support channels set up
- [ ] Post-launch monitoring plan ready

---

## Notes

**Tips for Success**:
- Commit early and often
- Write tests as you develop
- Profile performance regularly
- Test on real hardware frequently
- Get user feedback during development
- Document challenges and solutions
- Keep this checklist updated

**Common Pitfalls to Avoid**:
- Skipping error handling
- Ignoring memory leaks
- Not testing on older hardware
- Hardcoding strings (breaks localization)
- Blocking main thread
- Not profiling before optimizing
- Skipping unit tests

---

**Last Updated**: 2025-10-10
**Project**: Blackbox Player for macOS
**Total Tasks**: 136
