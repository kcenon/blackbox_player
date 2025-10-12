# Implementation Checklist

> 🌐 **Language**: [English](#) | [한국어](IMPLEMENTATION_CHECKLIST_kr.md)

This document provides a detailed checklist for implementing the macOS Blackbox Player project. Check off tasks as you complete them to track your progress.

**Timeline**: 12-16 weeks (3-4 months)
**Last Updated**: 2025-10-12

---

## Progress Overview

```
Phase 0: Preparation           [█████████░] 11/15 tasks  (Week 1) ✓ EXT4 Interface Ready
Phase 1: File System & Data    [█░░░░░░░░] 3/24 tasks   (Weeks 2-4) ✓ Protocol Layer Complete
Phase 2: Single Channel        [████████░] 18/22 tasks  (Weeks 5-7) ✓ Video Playback Complete
Phase 3: Multi-Channel Sync    [████████░] 17/21 tasks  (Weeks 8-10) ✓ Multi-Channel Rendering Complete
Phase 4: Additional Features   [█████░░░░░] 20/38 tasks  (Weeks 11-12) ✓ Phase 4 Week 2 Complete
Phase 5: Export & Settings     [ ] 0/16 tasks   (Weeks 13-14)
Phase 6: Localization & Polish [ ] 0/20 tasks   (Weeks 15-16)
─────────────────────────────────────────────────────
Total Progress                 [████░░░░░░] 69/156 tasks (44.2%)

📚 Documentation Phase (In Progress)   [███░░░░░░░] 10/29 files  ⏳ A-3 Views 3/11 Complete
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

## Phase 1: File System & Data Layer (Weeks 2-4)

**Goal**: Implement EXT4 file system access and metadata parsing

### Week 1: EXT4 Integration

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

- [x] Create `VideoDecoder` class ✅ 2025-10-11
- [x] Implement `initialize()` method ✅ 2025-10-11
- [x] Implement H.264 decoding ✅ 2025-10-11
- [x] Implement MP3 audio decoding ✅ 2025-10-11
- [x] Handle different video resolutions ✅ 2025-10-11
- [x] Implement frame buffering (VideoChannel) ✅ 2025-10-11
- [x] Add error recovery logic (EAGAIN, EOF handling) ✅ 2025-10-11
- [x] Fix Swift/C interoperability (String.withCString) ✅ 2025-10-11
- [ ] Write unit tests

#### Audio/Video Synchronization

- [x] Implement master clock (CACurrentMediaTime) ✅ 2025-10-11
- [x] Implement A/V drift detection ✅ 2025-10-11
- [x] Implement A/V drift correction ✅ 2025-10-11
- [x] Handle variable frame rates ✅ 2025-10-11
- [ ] Test with different video samples

### Week 2: Metal Renderer

#### Metal Setup

- [x] Create `MultiChannelRenderer` class ✅ 2025-10-11
- [x] Initialize Metal device and command queue ✅ 2025-10-11
- [x] Create render pipeline descriptor ✅ 2025-10-11
- [x] Implement vertex shader (Shaders.metal) ✅ 2025-10-11
- [x] Implement fragment shader (Shaders.metal) ✅ 2025-10-11
- [x] Create texture from CVPixelBuffer (IOSurface backing) ✅ 2025-10-11
- [x] Implement render loop (30fps target) ✅ 2025-10-11
- [x] Handle window resizing ✅ 2025-10-11
- [ ] Optimize for performance
- [ ] Profile with Metal debugger

#### Video Player View

- [x] Create `MultiChannelPlayerView` (SwiftUI + MTKView) ✅ 2025-10-11
- [x] Display video frames ✅ 2025-10-11
- [x] Handle aspect ratio (viewport calculation) ✅ 2025-10-11
- [x] Add loading indicator (BufferingView) ✅ 2025-10-11
- [x] Add error display (DebugLogView) ✅ 2025-10-11

### Week 3: Playback Controls

#### Controls UI Implementation

- [x] Create `PlayerControlsView` (inside MultiChannelPlayerView) ✅ 2025-10-11
- [x] Implement Play/Pause button ✅ 2025-10-11
- [x] Implement Stop button (replaced with Pause) ✅ 2025-10-11
- [ ] Implement Previous/Next file buttons
- [x] Create timeline scrubber ✅ 2025-10-11
- [x] Display current time / duration ✅ 2025-10-11
- [x] Implement speed control picker (0.25x ~ 2.0x) ✅ 2025-10-11
- [ ] Implement volume slider
- [ ] Add full-screen button

#### Keyboard Shortcuts

- [ ] Implement Space: Play/Pause
- [x] Implement Left/Right: Seek ±10 seconds (seekBySeconds) ✅ 2025-10-11
- [ ] Implement Up/Down: Volume adjustment
- [ ] Implement F: Toggle full-screen
- [ ] Implement ESC: Exit full-screen

#### Player ViewModel

- [x] Create `SyncController` (ObservableObject) ✅ 2025-10-11
- [x] Implement `play()` method ✅ 2025-10-11
- [x] Implement `pause()` method ✅ 2025-10-11
- [x] Implement `stop()` method ✅ 2025-10-11
- [x] Implement `seekToTime(_:)` method ✅ 2025-10-11
- [x] Implement `playbackSpeed` property ✅ 2025-10-11
- [ ] Implement `setVolume(_:)` method
- [x] Add @Published properties for UI binding ✅ 2025-10-11
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

- [x] Create `VideoChannel` class ✅ 2025-10-11
- [x] Implement independent decoder instances ✅ 2025-10-11
- [x] Create frame buffer for each channel (circular buffer, 30 frames) ✅ 2025-10-11
- [x] Set up background decoding queues (DispatchQueue) ✅ 2025-10-11
- [x] Implement channel state management (ChannelState enum) ✅ 2025-10-11
- [x] Add channel error handling (ChannelError) ✅ 2025-10-11
- [ ] Write unit tests

#### Synchronization Controller

- [x] Create `SyncController` class ✅ 2025-10-11
- [x] Implement master clock (CACurrentMediaTime) ✅ 2025-10-11
- [x] Implement `play()` method (all channels synchronized) ✅ 2025-10-11
- [x] Implement `pause()` method ✅ 2025-10-11
- [x] Implement `seekToTime(_:)` method ✅ 2025-10-11
- [x] Implement drift monitoring (updateSync, 30fps) ✅ 2025-10-11
- [x] Set drift threshold (50ms) ✅ 2025-10-11
- [x] Handle channels with different frame rates ✅ 2025-10-11
- [ ] Write synchronization tests

### Week 2: Multi-Texture Rendering

#### Metal Multi-Channel Renderer

- [x] Create `MultiChannelRenderer` class ✅ 2025-10-11
- [x] Implement single-pass multi-texture rendering ✅ 2025-10-11
- [x] Create grid layout calculator (auto row/column calculation) ✅ 2025-10-11
- [x] Create focus layout (75% + 25% thumbnails) ✅ 2025-10-11
- [x] Create horizontal layout (equal division) ✅ 2025-10-11
- [x] Handle missing channels gracefully (guard statements) ✅ 2025-10-11
- [x] Configure MTLSamplerState (linear filtering) ✅ 2025-10-11
- [ ] Profile with Metal debugger

#### Layout Manager

- [x] Create `LayoutMode` enum ✅ 2025-10-11
- [x] Implement `calculateViewports` method ✅ 2025-10-11
- [x] Implement `calculateGridViewports` ✅ 2025-10-11
- [x] Implement `calculateFocusViewports` ✅ 2025-10-11
- [x] Implement `calculateHorizontalViewports` ✅ 2025-10-11
- [x] Handle window resizing (drawableSize passed) ✅ 2025-10-11
- [x] Add layout switching UI (layoutControls) ✅ 2025-10-11
- [ ] Persist layout preference

### Week 3: Performance Optimization

#### Memory Optimization

- [x] Implement frame buffer limits (30 frames/channel) ✅ 2025-10-11
- [x] Auto-release old frames (delete frames older than 1 second) ✅ 2025-10-11
- [x] Use autoreleasepool in tight loops ✅ 2025-10-11
- [ ] Monitor memory usage with MemoryMonitor
- [x] Track buffer status (getBufferStatus) ✅ 2025-10-11
- [ ] Test with Instruments (Allocations)

#### Threading Optimization

- [x] Create dedicated decode queues (per-channel DispatchQueue) ✅ 2025-10-11
- [x] Ensure rendering on main thread (MTKView delegate) ✅ 2025-10-11
- [x] Thread safety with NSLock ✅ 2025-10-11
- [x] Set thread priorities (.userInitiated QoS) ✅ 2025-10-11
- [ ] Profile with Instruments (Time Profiler)
- [ ] Reduce context switching

#### GPU Optimization

- [x] Use shared Metal resources (single device, commandQueue) ✅ 2025-10-11
- [x] Leverage CVMetalTextureCache ✅ 2025-10-11
- [x] Multiple draw calls in single render pass ✅ 2025-10-11
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

- [x] Create `GPSService` class ✅ 2025-10-12
- [x] Implement `loadGPSData(from:startTime:)` method ✅ 2025-10-12
- [x] Implement `getCurrentLocation(at:)` method ✅ 2025-10-12
- [x] Integrate MapKit framework ✅ 2025-10-12
- [x] Create `MapOverlayView` (SwiftUI + MKMapView) ✅ 2025-10-12
- [x] Draw route on map (MKPolyline) ✅ 2025-10-12
- [x] Update location marker during playback ✅ 2025-10-12
- [x] Add map controls (zoom, pan, center) ✅ 2025-10-12
- [x] Display speed and altitude info ✅ 2025-10-12
- [ ] Write unit tests

#### G-Sensor Visualization

- [x] Create `GSensorService` class ✅ 2025-10-12
- [x] Implement G-Sensor data parsing ✅ 2025-10-12
- [x] Create `GraphOverlayView` (SwiftUI + Charts) ✅ 2025-10-12
- [x] Draw X/Y/Z acceleration axes ✅ 2025-10-12
- [x] Highlight impact events (magnitude > threshold) ✅ 2025-10-12
- [x] Synchronize chart with video playback ✅ 2025-10-12
- [x] Add zoom/pan for chart ✅ 2025-10-12
- [x] Display current values ✅ 2025-10-12
- [x] Write integration tests (GPSSensorIntegrationTests) ✅ 2025-10-12

### Week 2: Image Processing

#### Screen Capture

- [x] Implement `captureCurrentFrame()` method ✅ 2025-10-12
- [x] Create save file dialog ✅ 2025-10-12
- [x] Support PNG format ✅ 2025-10-12
- [x] Support JPEG format ✅ 2025-10-12
- [x] Add optional timestamp overlay ✅ 2025-10-12
- [x] Save at full resolution ✅ 2025-10-12
- [x] Add success/error notifications ✅ 2025-10-12

#### Video Transformations

- [x] Create `VideoTransformations` class ✅ 2025-10-12
- [x] Implement brightness adjustment (Metal shader) ✅ 2025-10-12
- [x] Implement horizontal flip ✅ 2025-10-12
- [x] Implement vertical flip ✅ 2025-10-12
- [x] Implement digital zoom ✅ 2025-10-12
- [x] Update Metal shaders for transformations ✅ 2025-10-12
- [x] Add transformation controls UI ✅ 2025-10-12
- [x] Persist transformation settings ✅ 2025-10-12

#### Full-Screen Mode

- [x] Implement enter/exit full-screen ✅ 2025-10-12
- [x] Auto-hide controls in full-screen ✅ 2025-10-12
- [x] Show controls on mouse move ✅ 2025-10-12
- [x] Support multiple displays ✅ 2025-10-12
- [x] Handle display arrangement changes ✅ 2025-10-12

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

**Last Updated**: 2025-10-12
**Project**: Blackbox Player for macOS
**Total Tasks**: 156

---

## Recent Implementation History (2025-10-12)

### Phase 4 Week 2: Screen Capture and Video Transformations Complete

#### Core Features Implemented
1. **ScreenCaptureService**: Metal texture capture and image saving
   - Metal texture → CGImage → NSImage conversion pipeline
   - PNG/JPEG format support (adjustable JPEG quality)
   - Timestamp overlay (date/time + video timestamp)
   - File save dialog via NSSavePanel
   - Success/error notification display

2. **VideoTransformations**: Real-time video transformation system
   - Brightness adjustment (-1.0 ~ 1.0, Metal fragment shader)
   - Horizontal/vertical flip (Metal vertex shader)
   - Digital zoom (1.0x ~ 5.0x, Metal vertex shader)
   - Settings persistence via UserDefaults
   - Real-time UI updates with ObservableObject pattern

3. **Metal Shader Transformation Pipeline**
   - TransformUniforms struct definition (6 float parameters)
   - Vertex shader: Texture coordinate transformation (flip, zoom)
   - Fragment shader: Pixel color adjustment (brightness)
   - Uniform buffer for CPU→GPU data transfer

4. **Full-Screen Mode**
   - Full-screen toggle via NSWindow.toggleFullScreen
   - Full-screen state tracking via NotificationCenter
   - Full-screen toggle button added

5. **Auto-Hide/Show Controls**
   - 3-second auto-hide using Timer
   - Mouse movement detection (DragGesture + onHover)
   - Auto-hide enabled only in full-screen mode
   - Animation effects (.opacity transition)

6. **Multiple Display Support**
   - Display detection via NSScreen.screens
   - didChangeScreenParametersNotification handling
   - Automatic update on display arrangement changes

#### Technical Issues Resolved
1. **Metal Shader Duplicate Symbol Error**
   - Cause: Shaders.metal and MultiChannelShaders.metal defining same function names
   - Solution: Removed legacy Shaders.metal

2. **ObservableObject Compliance Error**
   - Cause: Protocol not implemented when using @Published in VideoTransformationService
   - Solution: Conform to ObservableObject protocol, import Combine framework

3. **Buffer Index Conflict**
   - Cause: Vertex attributes and uniform buffer sharing buffer(0)
   - Solution: Changed vertex shader uniform buffer to buffer(1)

#### Transformation Controls UI
- Toggleable transformation panel added
- Brightness/zoom sliders (real-time value display)
- Horizontal/vertical flip toggle buttons
- Reset button (initialize all transformations)
- Clean design integrated into top bar

---

## Recent Implementation History (2025-10-11)

### Phase 2 & 3: Video Playback and Multi-Channel Synchronization Complete

#### Core Features Implemented
1. **VideoDecoder**: FFmpeg-based H.264/MP3 decoding
   - Swift/C interoperability fix (String.withCString)
   - macOS EAGAIN error code handling (-35 vs -11)
   - EOF detection and error recovery logic

2. **VideoChannel**: Independent decoding and buffer management per channel
   - Background decoding queue (DispatchQueue)
   - Circular buffer (30 frames)
   - Auto-delete old frames (older than 1 second)
   - Channel state management (ChannelState enum)

3. **SyncController**: Multi-channel synchronization controller
   - Master clock (CACurrentMediaTime)
   - Drift monitoring and correction (±50ms)
   - NSLock-based thread safety
   - Playback speed control (0.25x ~ 2.0x)

4. **MultiChannelRenderer**: Metal-based GPU rendering
   - CVPixelBuffer with IOSurface backing for Metal compatibility
   - 3 layout modes (Grid/Focus/Horizontal)
   - CVMetalTextureCache optimization
   - MTLSamplerState configuration

5. **MultiChannelPlayerView**: SwiftUI + Metal integration
   - MTKView delegate pattern
   - Playback control UI (Play/Pause/Seek/Speed)
   - Timeline scrubber
   - Layout switching UI

6. **Debug System**: Integrated log management
   - LogManager (thread-safe)
   - DebugLogView (real-time log display)
   - Log copy functionality
   - Log level color coding

#### Technical Issues Resolved
1. **Metal Texture Creation Failure (-6660 error)**
   - Cause: CVPixelBuffer missing IOSurface backing
   - Solution: Added kCVPixelBufferMetalCompatibilityKey and kCVPixelBufferIOSurfacePropertiesKey

2. **Playback Stall Due to Full Buffer**
   - Cause: getFrame() not removing frames, causing buffer congestion
   - Solution: Added auto-delete logic for frames older than 1 second

3. **Dictionary.Keys Thread Race Condition**
   - Cause: Concurrent access between Metal render thread and UI thread
   - Solution: Use NSLock and sorted array copy

4. **VideoDecoder Crash**
   - Cause: filePath.cString(using:) memory premature deallocation
   - Solution: Use filePath.withCString

#### Current Status
- ✅ Video loading and decoding complete
- ✅ Metal rendering working
- ✅ Multi-channel synchronization implemented
- ✅ Playback control UI complete
- ⏳ Buffer management optimization in progress
- ⏳ Awaiting final performance verification

#### Next Steps
1. Final validation of video playback stability
2. Multi-channel synchronization precision testing
3. Metal performance profiling (Instruments)
4. File system integration (EXT4)
5. GPS/G-sensor data visualization
