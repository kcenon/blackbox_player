# Implementation Checklist

> 🌐 **Language**: [English](#) | [한국어](IMPLEMENTATION_CHECKLIST_kr.md)

This document provides a detailed checklist for implementing the macOS Blackbox Player project. Check off tasks as you complete them to track your progress.

---

## Progress Overview

```
Phase 0: Preparation           [█████████░] 11/15 tasks  ✓ EXT4 Interface Ready
Phase 1: File System & Data    [█░░░░░░░░] 3/24 tasks   ✓ Protocol Layer Complete
Phase 2: Single Channel        [████████░] 18/22 tasks  ✓ Video Playback Complete
Phase 3: Multi-Channel Sync    [████████░] 17/21 tasks  ✓ Multi-Channel Rendering Complete
Phase 4: Additional Features   [█████░░░░░] 20/38 tasks  ✓ Phase 4 Complete
Phase 5: Export & Settings     [ ] 0/16 tasks
Phase 6: Localization & Polish [ ] 0/20 tasks
─────────────────────────────────────────────────────
Total Progress                 [████░░░░░░] 69/156 tasks (44.2%)

📚 Documentation Phase (In Progress)   [███░░░░░░░] 10/29 files  ⏳ A-3 Views 3/11 Complete
```

---

## Phase 0: Preparation

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

- [ ] Obtain EXT4 C/C++ library from vendor (external dependency)
- [x] Create Objective-C++ bridging header (BridgingHeader.h)
- [x] Design EXT4 filesystem protocol interface (EXT4FileSystemProtocol)
- [x] Implement mock EXT4 filesystem for development (MockEXT4FileSystem)
- [x] Create EXT4Bridge stub for future C library integration
- [x] Write comprehensive unit tests for EXT4 interface (22 tests passing)
- [x] Document C library integration guide (EXT4_INTEGRATION_GUIDE.md)
- [ ] Test basic EXT4 read operation with real C library (library required)
- [ ] Verify EXT4 library macOS compatibility (library required)
- [x] Link FFmpeg libraries to project (configured in project.yml)
- [ ] Create basic FFmpeg Swift wrapper (planned for Phase 1-2)
- [ ] Test H.264 video decoding with FFmpeg (planned for Phase 1-2)

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

## Phase 1: File System & Data Layer

**Goal**: Implement EXT4 file system access and metadata parsing

### EXT4 Integration

#### EXT4 Protocol Layer (Preparatory Work - Completed ✓)

- [x] Design `EXT4FileSystemProtocol` interface
- [x] Create comprehensive error types (EXT4Error)
- [x] Define data models (EXT4FileInfo, EXT4DeviceInfo)
- [x] Create `MockEXT4FileSystem` for testing
- [x] Create `EXT4Bridge` stub with integration examples
- [x] Write unit tests (mount, unmount, file ops, performance)
- [x] Document C library integration process

#### EXT4 Bridge Implementation (Awaiting C Library)

- [ ] Obtain C/C++ library from vendor
- [ ] Create `EXT4Wrapper.h` (Objective-C++ header)
- [ ] Create `EXT4Wrapper.mm` (Objective-C++ implementation)
- [ ] Implement `mount(device:)` method with C library
- [ ] Implement `unmount()` method with C library
- [ ] Implement `listFiles(at:)` method with C library
- [ ] Implement `readFile(at:)` method with C library
- [ ] Implement `writeFile(data:to:)` method with C library
- [ ] Update `EXT4Bridge` to use C library wrapper
- [ ] Update unit tests for real hardware
- [ ] Test with real SD card hardware

#### Device Detection

- [ ] Implement USB device detection (IOKit)
- [ ] Create device filter for SD cards
- [ ] Implement device selection UI
- [ ] Add device connection/disconnection notifications
- [ ] Handle multiple connected SD cards

### Metadata Parsing

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

### File Manager Service

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

## Phase 2: Single Channel Playback

**Goal**: Implement smooth single-video playback

### Video Decoder

#### FFmpeg Integration

- [x] Create `VideoDecoder` class
- [x] Implement `initialize()` method
- [x] Implement H.264 decoding
- [x] Implement MP3 audio decoding
- [x] Handle different video resolutions
- [x] Implement frame buffering (VideoChannel)
- [x] Add error recovery logic (EAGAIN, EOF handling)
- [x] Fix Swift/C interoperability (String.withCString)
- [ ] Write unit tests

#### Audio/Video Synchronization

- [x] Implement master clock (CACurrentMediaTime)
- [x] Implement A/V drift detection
- [x] Implement A/V drift correction
- [x] Handle variable frame rates
- [ ] Test with different video samples

### Metal Renderer

#### Metal Setup

- [x] Create `MultiChannelRenderer` class
- [x] Initialize Metal device and command queue
- [x] Create render pipeline descriptor
- [x] Implement vertex shader (Shaders.metal)
- [x] Implement fragment shader (Shaders.metal)
- [x] Create texture from CVPixelBuffer (IOSurface backing)
- [x] Implement render loop (30fps target)
- [x] Handle window resizing
- [ ] Optimize for performance
- [ ] Profile with Metal debugger

#### Video Player View

- [x] Create `MultiChannelPlayerView` (SwiftUI + MTKView)
- [x] Display video frames
- [x] Handle aspect ratio (viewport calculation)
- [x] Add loading indicator (BufferingView)
- [x] Add error display (DebugLogView)

### Playback Controls

#### Controls UI Implementation

- [x] Create `PlayerControlsView` (inside MultiChannelPlayerView)
- [x] Implement Play/Pause button
- [x] Implement Stop button (replaced with Pause)
- [ ] Implement Previous/Next file buttons
- [x] Create timeline scrubber
- [x] Display current time / duration
- [x] Implement speed control picker (0.25x ~ 2.0x)
- [ ] Implement volume slider
- [ ] Add full-screen button

#### Keyboard Shortcuts

- [ ] Implement Space: Play/Pause
- [x] Implement Left/Right: Seek ±10 seconds (seekBySeconds)
- [ ] Implement Up/Down: Volume adjustment
- [ ] Implement F: Toggle full-screen
- [ ] Implement ESC: Exit full-screen

#### Player ViewModel

- [x] Create `SyncController` (ObservableObject)
- [x] Implement `play()` method
- [x] Implement `pause()` method
- [x] Implement `stop()` method
- [x] Implement `seekToTime(_:)` method
- [x] Implement `playbackSpeed` property
- [ ] Implement `setVolume(_:)` method
- [x] Add @Published properties for UI binding
- [ ] Write unit tests with mocks

**Success Criteria**:
- ✅ Video plays at 30fps minimum
- ✅ Audio/video sync within ±50ms
- ✅ Seeking responds within 500ms
- ✅ Memory usage < 500MB for single HD video
- ✅ No frame drops during normal playback

---

## Phase 3: Multi-Channel Synchronization

**Goal**: Synchronize 5 channels with frame-perfect accuracy

### Multi-Channel Architecture

#### Channel Management

- [x] Create `VideoChannel` class
- [x] Implement independent decoder instances
- [x] Create frame buffer for each channel (circular buffer, 30 frames)
- [x] Set up background decoding queues (DispatchQueue)
- [x] Implement channel state management (ChannelState enum)
- [x] Add channel error handling (ChannelError)
- [ ] Write unit tests

#### Synchronization Controller

- [x] Create `SyncController` class
- [x] Implement master clock (CACurrentMediaTime)
- [x] Implement `play()` method (all channels synchronized)
- [x] Implement `pause()` method
- [x] Implement `seekToTime(_:)` method
- [x] Implement drift monitoring (updateSync, 30fps)
- [x] Set drift threshold (50ms)
- [x] Handle channels with different frame rates
- [ ] Write synchronization tests

### Multi-Texture Rendering

#### Metal Multi-Channel Renderer

- [x] Create `MultiChannelRenderer` class
- [x] Implement single-pass multi-texture rendering
- [x] Create grid layout calculator (auto row/column calculation)
- [x] Create focus layout (75% + 25% thumbnails)
- [x] Create horizontal layout (equal division)
- [x] Handle missing channels gracefully (guard statements)
- [x] Configure MTLSamplerState (linear filtering)
- [ ] Profile with Metal debugger

#### Layout Manager

- [x] Create `LayoutMode` enum
- [x] Implement `calculateViewports` method
- [x] Implement `calculateGridViewports`
- [x] Implement `calculateFocusViewports`
- [x] Implement `calculateHorizontalViewports`
- [x] Handle window resizing (drawableSize passed)
- [x] Add layout switching UI (layoutControls)
- [ ] Persist layout preference

### Performance Optimization

#### Memory Optimization

- [x] Implement frame buffer limits (30 frames/channel)
- [x] Auto-release old frames (delete frames older than 1 second)
- [x] Use autoreleasepool in tight loops
- [ ] Monitor memory usage with MemoryMonitor
- [x] Track buffer status (getBufferStatus)
- [ ] Test with Instruments (Allocations)

#### Threading Optimization

- [x] Create dedicated decode queues (per-channel DispatchQueue)
- [x] Ensure rendering on main thread (MTKView delegate)
- [x] Thread safety with NSLock
- [x] Set thread priorities (.userInitiated QoS)
- [ ] Profile with Instruments (Time Profiler)
- [ ] Reduce context switching

#### GPU Optimization

- [x] Use shared Metal resources (single device, commandQueue)
- [x] Leverage CVMetalTextureCache
- [x] Multiple draw calls in single render pass
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

## Phase 4: Additional Features

**Goal**: Implement GPS mapping, G-Sensor visualization, and image processing

### GPS & G-Sensor

#### GPS Integration

- [x] Create `GPSService` class
- [x] Implement `loadGPSData(from:startTime:)` method
- [x] Implement `getCurrentLocation(at:)` method
- [x] Integrate MapKit framework
- [x] Create `MapOverlayView` (SwiftUI + MKMapView)
- [x] Draw route on map (MKPolyline)
- [x] Update location marker during playback
- [x] Add map controls (zoom, pan, center)
- [x] Display speed and altitude info
- [ ] Write unit tests

#### G-Sensor Visualization

- [x] Create `GSensorService` class
- [x] Implement G-Sensor data parsing
- [x] Create `GraphOverlayView` (SwiftUI + Charts)
- [x] Draw X/Y/Z acceleration axes
- [x] Highlight impact events (magnitude > threshold)
- [x] Synchronize chart with video playback
- [x] Add zoom/pan for chart
- [x] Display current values
- [x] Write integration tests (GPSSensorIntegrationTests)

### Image Processing

#### Screen Capture

- [x] Implement `captureCurrentFrame()` method
- [x] Create save file dialog
- [x] Support PNG format
- [x] Support JPEG format
- [x] Add optional timestamp overlay
- [x] Save at full resolution
- [x] Add success/error notifications

#### Video Transformations

- [x] Create `VideoTransformations` class
- [x] Implement brightness adjustment (Metal shader)
- [x] Implement horizontal flip
- [x] Implement vertical flip
- [x] Implement digital zoom
- [x] Update Metal shaders for transformations
- [x] Add transformation controls UI
- [x] Persist transformation settings

#### Full-Screen Mode

- [x] Implement enter/exit full-screen
- [x] Auto-hide controls in full-screen
- [x] Show controls on mouse move
- [x] Support multiple displays
- [x] Handle display arrangement changes

**Success Criteria**:
- ✅ GPS location updates in real-time
- ✅ G-Sensor chart renders smoothly
- ✅ Image capture saves at full resolution
- ✅ Video transformations don't impact performance
- ✅ Full-screen mode works correctly

---

## Phase 5: Export & Settings

**Goal**: Implement MP4 export and dashcam configuration

### MP4 Export

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

### Settings Management

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

## Phase 6: Localization & Polish

**Goal**: Production-ready application

### Localization

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

### Polish & Packaging

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

**Project**: Blackbox Player for macOS
**Total Tasks**: 156

---

