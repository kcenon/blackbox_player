# Software Requirements Specification (SRS)
## Blackbox Player for macOS

> 🌐 **Language**: [English](#) | [한국어](01_requirements_kr.md)

---

## Document Control

| Property | Value |
|----------|-------|
| **Document ID** | SRS-BBOX-MACOS-001 |
| **Version** | 1.0 |
| **Status** | Draft |
| **Date** | 2024-01-15 |
| **Author(s)** | Development Team |
| **Reviewer(s)** | Technical Lead, Product Manager |
| **Approver** | Project Manager |
| **Classification** | Internal |

### Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.1 | 2024-01-10 | Development Team | Initial draft |
| 1.0 | 2024-01-15 | Development Team | First complete version |

### Related Documents

| Document ID | Title | Relationship |
|-------------|-------|--------------|
| ARCH-BBOX-MACOS-001 | Architecture Design Document | Implements requirements |
| TEST-BBOX-MACOS-001 | Test Plan | Verifies requirements |
| PROJ-BBOX-MACOS-001 | Project Plan | Schedules implementation |

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Overall Description](#2-overall-description)
3. [Specific Requirements](#3-specific-requirements)
4. [System Features](#4-system-features)
5. [External Interface Requirements](#5-external-interface-requirements)
6. [Non-Functional Requirements](#6-non-functional-requirements)
7. [Other Requirements](#7-other-requirements)
8. [Appendices](#8-appendices)

---

## 1. Introduction

### 1.1 Purpose

This Software Requirements Specification (SRS) describes the functional and non-functional requirements for the Blackbox Player for macOS application. This document is intended for:

- Development team members
- Project managers
- Quality assurance team
- Stakeholders and clients

This SRS conforms to **ISO/IEC/IEEE 29148:2018** standard for requirements engineering.

### 1.2 Scope

**Product Name:** Blackbox Player for macOS

**Product Description:** A native macOS application for dashcam SD card video playback, providing comprehensive multi-channel video management, GPS visualization, and video processing capabilities.

**Benefits:**
- Enable macOS users to access dashcam footage without Windows
- Professional-grade video playback with frame-perfect synchronization
- Comprehensive video analysis tools (GPS, G-Sensor)
- Easy video export and sharing

**Goals:**
- Achieve feature parity with existing Windows viewer
- Provide superior performance through native macOS integration
- Ensure seamless user experience following macOS Human Interface Guidelines

### 1.3 Definitions, Acronyms, and Abbreviations

| Term | Definition |
|------|------------|
| **Dashcam** | Dashboard camera; a video recording device mounted in vehicles |
| **SD Card** | Secure Digital memory card used for data storage |
| **Channel** | Individual video stream from a specific camera position |
| **G-Sensor** | Gravitational sensor; measures acceleration forces |
| **GPS** | Global Positioning System |
| **MP4** | MPEG-4 Part 14; a digital multimedia container format |
| **H.264** | Advanced Video Coding; a video compression standard |
| **MP3** | MPEG-1 Audio Layer 3; an audio coding format |
| **DMG** | Disk Image; macOS installation package format |
| **fps** | Frames per second |
| **API** | Application Programming Interface |
| **UI** | User Interface |
| **SRS** | Software Requirements Specification |
| **NFR** | Non-Functional Requirement |

### 1.4 References

1. ISO/IEC/IEEE 29148:2018 - Systems and software engineering — Life cycle processes — Requirements engineering
2. ISO/IEC 25010:2011 - Systems and software Quality Requirements and Evaluation (SQuaRE)
3. ISO/IEC/IEEE 42010:2011 - Systems and software engineering — Architecture description
4. Apple Human Interface Guidelines for macOS
5. FFmpeg Documentation - https://ffmpeg.org/documentation.html
6. H.264/AVC Standard - ITU-T Recommendation H.264

### 1.5 Overview

This document is organized according to ISO/IEC/IEEE 29148:2018 structure:
- Section 2 provides overall description and context
- Section 3 specifies detailed requirements with unique identifiers
- Section 4 describes system features organized by capability
- Sections 5-7 cover interface, non-functional, and other requirements
- Section 8 contains appendices including traceability matrix

---

## 2. Overall Description

### 2.1 Product Perspective

The Blackbox Player for macOS is a new product that replaces the need for Windows-based dashcam viewers on macOS platform. It is a standalone application that:

- Reads data directly from SD cards
- Operates independently without cloud services
- Integrates with macOS system services (Maps, storage)
- Does not require external dependencies beyond system libraries

**System Context Diagram:**

```
┌─────────────────────────────────────────────────┐
│              macOS System                        │
│  ┌──────────────────────────────────────────┐  │
│  │   Blackbox Player Application            │  │
│  │                                          │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐ │  │
│  │  │  Video  │  │   GPS   │  │ G-Sensor│ │  │
│  │  │ Player  │  │ Mapping │  │  Chart  │ │  │
│  │  └─────────┘  └─────────┘  └─────────┘ │  │
│  │                                          │  │
│  │  ┌────────────────────────────────────┐ │  │
│  │  │     File System Access             │ │  │
│  │  └────────────────────────────────────┘ │  │
│  └──────────────────────────────────────────┘  │
│                     ↕                           │
│  ┌──────────────────────────────────────────┐  │
│  │     macOS System Services                │  │
│  │  • MapKit                                │  │
│  │  • Metal Graphics                        │  │
│  │  • IOKit (USB)                           │  │
│  └──────────────────────────────────────────┘  │
└─────────────────────────────────────────────────┘
                      ↕
    ┌────────────────────────────────┐
    │   SD Card                      │
    │  • Video files (H.264)         │
    │  • Audio files (MP3)           │
    │  • Metadata (GPS, G-Sensor)    │
    └────────────────────────────────┘
```

### 2.2 Product Functions

The major functions of the Blackbox Player include:

1. **Multi-channel video playback** - Play up to 5 video streams simultaneously
2. **Video file management** - Browse, search, and organize dashcam recordings
3. **GPS visualization** - Display driving routes on interactive maps
4. **G-Sensor analysis** - Visualize acceleration data and detect impacts
5. **Video export** - Convert proprietary formats to standard MP4
6. **Dashcam configuration** - Modify device settings through the application
7. **Image processing** - Apply transformations and capture screenshots

### 2.3 User Characteristics

**Primary Users:**
- **Dashcam owners** - Vehicle owners with dashcams who use macOS
  - Technical skill: Beginner to intermediate
  - Domain knowledge: Basic understanding of video files
  - Frequency of use: Weekly to monthly

**Secondary Users:**
- **Fleet managers** - Managing multiple vehicle recordings
  - Technical skill: Intermediate
  - Domain knowledge: Video analysis, incident investigation
  - Frequency of use: Daily

**Tertiary Users:**
- **Law enforcement** - Analyzing traffic incident footage
  - Technical skill: Intermediate
  - Domain knowledge: Video forensics
  - Frequency of use: As needed

### 2.4 Constraints

**CON-001: Platform Constraint**
- The application must run exclusively on macOS 12.0 (Monterey) or later
- Justification: Modern macOS frameworks required

**CON-002: Hardware Constraint**
- Minimum 8GB RAM for basic operation, 16GB recommended for 5-channel playback
- Justification: Video decoding and rendering memory requirements

**CON-003: Video Format Constraint**
- Input: H.264 video, MP3 audio
- Output: MP4 container format
- Justification: Dashcam hardware specifications

**CON-004: Regulatory Constraint**
- Must comply with Apple App Store guidelines if distributed through store
- Must pass Apple notarization process
- Justification: macOS security requirements

**CON-005: Development Constraint**
- Must use Swift as primary language
- Must use SwiftUI for UI components
- Justification: Client requirement for modern, maintainable codebase

### 2.5 Assumptions and Dependencies

**Assumptions:**
1. Users have administrative access to mount USB devices
2. SD cards are properly formatted and not corrupted
3. Dashcam firmware is compatible with current metadata format
4. Users have stable internet connection for map services
5. macOS security settings allow USB device access

**Dependencies:**
1. **DEP-001**: FFmpeg library for video decoding (LGPL licensed)
2. **DEP-002**: MapKit or Google Maps SDK for GPS visualization
3. **DEP-003**: Apple Developer Program membership for code signing
4. **DEP-004**: Xcode 15+ for building the application

### 2.6 Apportioning of Requirements

Future versions may include:
- iOS companion app for mobile viewing
- Cloud storage integration
- AI-powered event detection
- Live streaming from Wi-Fi enabled dashcams
- Advanced video editing features
- Real-time translation of UI to additional languages

---

## 3. Specific Requirements

### 3.1 Functional Requirements

Requirements are identified with the following format: **REQ-[TYPE]-[NUMBER]**
- TYPE: FUNC (Functional), PERF (Performance), SEC (Security), USAB (Usability)
- NUMBER: Sequential identifier

Each requirement includes:
- **ID**: Unique identifier
- **Title**: Brief description
- **Description**: Detailed specification
- **Priority**: Critical (1), High (2), Medium (3), Low (4)
- **Verification**: Method to verify (Test, Demo, Inspection, Analysis)
- **Source**: Origin of requirement (Client, Regulation, Technical)

---

## 4. System Features

### 4.1 Multi-Channel Video Playback

**Priority:** Critical (1)
**Stimulus/Response:** User selects video file(s) → System plays video(s) synchronously

#### REQ-FUNC-001: Simultaneous Channel Playback
**Description:** The system shall support simultaneous playback of up to 5 video channels on a single screen.

**Rationale:** Dashcams record from multiple cameras (front, rear, left, right, interior) simultaneously.

**Verification:** Test - Load 5 video files and verify all play simultaneously

**Acceptance Criteria:**
- All 5 channels display video frames
- Frame rate ≥ 30fps per channel
- No channel freezes or stutters

**Source:** Client requirement

**Dependencies:** REQ-FUNC-002, REQ-PERF-001

---

#### REQ-FUNC-002: Channel Synchronization
**Description:** The system shall maintain synchronization between all playing channels with accuracy of ±50 milliseconds.

**Rationale:** Accurate time correlation between different camera views is essential for incident analysis.

**Verification:** Test - Use timing reference and measure drift between channels over 10 minutes

**Acceptance Criteria:**
- Maximum drift ≤ 50ms at any time
- Automatic drift correction when threshold exceeded
- Synchronization maintained during speed changes

**Source:** Technical requirement

**Dependencies:** REQ-FUNC-001

---

#### REQ-FUNC-003: Play Control
**Description:** The system shall provide play control with the following functions:
- Play/Resume playback
- Pause current playback
- Stop playback and return to beginning
- Previous file navigation
- Next file navigation

**Rationale:** Standard video player controls expected by users.

**Verification:** Test - Verify each control function operates correctly

**Acceptance Criteria:**
- Play button starts playback within 500ms
- Pause button freezes video within 100ms
- Stop button releases resources and resets position
- Previous/Next navigate to adjacent files in list

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-004: Seek Control
**Description:** The system shall allow users to seek to any position in the video timeline with accuracy of ±1 second.

**Rationale:** Users need to navigate to specific moments in recordings.

**Verification:** Test - Seek to various positions and verify accuracy

**Acceptance Criteria:**
- Timeline slider allows seeking to any position
- Seek completes within 1 second
- All channels seek to same relative position
- Playback resumes from new position

**Source:** Client requirement

**Dependencies:** REQ-FUNC-002

---

#### REQ-FUNC-005: Playback Speed Control
**Description:** The system shall support playback at the following speeds: 0.5x, 1.0x, 2.0x.

**Rationale:** Different speeds useful for detailed analysis or quick review.

**Verification:** Test - Change speed and verify playback rate matches selection

**Acceptance Criteria:**
- Speed changes apply to all channels simultaneously
- Audio pitch corrected or muted at non-1.0x speeds
- Synchronization maintained across speed changes
- Frame timing accurate to ±10ms

**Source:** Client requirement

**Dependencies:** REQ-FUNC-002

---

#### REQ-FUNC-006: Volume Control
**Description:** The system shall provide volume control from 0% (mute) to 100% (maximum) with at least 20 distinct levels.

**Rationale:** Users need to adjust audio level for different listening environments.

**Verification:** Test - Adjust volume and measure audio output level

**Acceptance Criteria:**
- Volume slider with minimum 20 steps
- Mute button instantly silences audio
- Volume persists between sessions
- Each channel can have independent volume control

**Source:** Client requirement

**Dependencies:** None

---

### 4.2 Video Export and Processing

**Priority:** Critical (1)

#### REQ-FUNC-007: MP4 Export
**Description:** The system shall export selected video files to standard MP4 format containing H.264 video and AAC or MP3 audio.

**Rationale:** Users need to share videos in universally playable format.

**Verification:** Test - Export file and verify playback in standard media players

**Acceptance Criteria:**
- Export completes at ≥1x real-time speed
- Output file playable in QuickTime Player, VLC
- Video quality maintained (lossless or high-quality re-encoding)
- Audio synchronized with video (±50ms)
- Metadata preserved (creation time, GPS, etc.)

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-008: Multi-Channel Export
**Description:** The system shall allow exporting multiple channels into a single MP4 file with grid layout or separate MP4 files.

**Rationale:** Users may want combined view or individual channel exports.

**Verification:** Test - Export in both modes and verify output

**Acceptance Criteria:**
- Option to export as single combined video
- Option to export as separate files
- Combined export maintains channel layout
- File naming follows pattern: [original_name]_[channel].mp4

**Source:** Client requirement

**Dependencies:** REQ-FUNC-007

---

#### REQ-FUNC-009: Video Repair
**Description:** The system shall attempt to repair corrupted video files by recovering readable frames and creating playable output.

**Rationale:** SD card errors may corrupt files; users want to recover maximum data.

**Verification:** Test - Process intentionally corrupted files and measure recovery rate

**Acceptance Criteria:**
- Detects corrupted file structure
- Recovers contiguous valid frames
- Skips unreadable sections with notification
- Creates playable MP4 from recovered data
- Reports percentage of file recovered

**Source:** Client requirement

**Dependencies:** REQ-FUNC-007

---

#### REQ-FUNC-010: Channel Extraction
**Description:** The system shall allow extracting a specific channel from multi-channel recording as separate MP4 file.

**Rationale:** Users may only need footage from specific camera.

**Verification:** Test - Extract each channel and verify content

**Acceptance Criteria:**
- User selects desired channel(s)
- Extracted file contains only selected channel
- Audio preserved if available for that channel
- Original quality maintained

**Source:** Client requirement

**Dependencies:** REQ-FUNC-007

---

### 4.3 GPS Data Integration

**Priority:** High (2)

#### REQ-FUNC-011: GPS Data Parsing
**Description:** The system shall parse GPS metadata from video files including latitude, longitude, speed, altitude, and heading.

**Rationale:** GPS data provides context for video footage.

**Verification:** Test - Compare parsed data with known reference values

**Acceptance Criteria:**
- Extracts GPS points with timestamp
- Accuracy: ±10 meters (limited by GPS receiver)
- Handles missing or invalid GPS data gracefully
- Parses minimum 1 GPS point per second

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-012: Route Visualization
**Description:** The system shall display GPS route on an interactive map (MapKit or Google Maps).

**Rationale:** Visual route representation aids in understanding video context.

**Verification:** Demo - Display known route and verify map accuracy

**Acceptance Criteria:**
- Route rendered as polyline on map
- Map centered and zoomed to show full route
- User can pan and zoom map
- Current position indicator updates during playback
- Speed and altitude displayed as overlay

**Source:** Client requirement

**Dependencies:** REQ-FUNC-011

---

#### REQ-FUNC-013: GPS-Video Synchronization
**Description:** The system shall synchronize map position indicator with current video playback position.

**Rationale:** Users need to see exact location corresponding to video frame.

**Verification:** Test - Verify position indicator matches video timestamp

**Acceptance Criteria:**
- Position updates at least 10 times per second
- Position accuracy ±1 second of video time
- Synchronization maintained during seek operations
- Works correctly at all playback speeds

**Source:** Technical requirement

**Dependencies:** REQ-FUNC-011, REQ-FUNC-012

---

### 4.4 G-Sensor Data Visualization

**Priority:** High (2)

#### REQ-FUNC-014: G-Sensor Data Parsing
**Description:** The system shall parse G-Sensor (accelerometer) data from video metadata including X, Y, Z axis values.

**Rationale:** Acceleration data helps identify impact events.

**Verification:** Test - Parse G-Sensor data and compare with reference values

**Acceptance Criteria:**
- Extracts acceleration data with timestamp
- Sampling rate ≥ 10Hz
- Handles missing data points
- Calculates magnitude: √(x² + y² + z²)

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-015: Acceleration Graph Display
**Description:** The system shall display G-Sensor data as a line graph showing X, Y, Z axes over time.

**Rationale:** Visual representation enables impact event identification.

**Verification:** Demo - Display graph and verify axes are distinguishable

**Acceptance Criteria:**
- Three distinct lines for X, Y, Z (different colors)
- Time axis aligned with video timeline
- Magnitude line showing combined acceleration
- Grid lines for reference values
- Y-axis range automatically scales to data

**Source:** Client requirement

**Dependencies:** REQ-FUNC-014

---

#### REQ-FUNC-016: Impact Event Detection
**Description:** The system shall detect and highlight impact events when G-Sensor magnitude exceeds configurable threshold (default: 2.0g).

**Rationale:** Automated detection helps users find significant events.

**Verification:** Test - Verify detection at various threshold values

**Acceptance Criteria:**
- Detects events exceeding threshold
- Highlights events on graph and timeline
- Lists detected events with timestamp
- Clicking event seeks video to that time
- Threshold adjustable from 1.0g to 5.0g

**Source:** Client requirement

**Dependencies:** REQ-FUNC-014, REQ-FUNC-015

---

### 4.5 File Management

**Priority:** High (2)

#### REQ-FUNC-017: File System Access
**Description:** The system shall access files on SD cards connected via USB card readers.

**Rationale:** Users need to access dashcam recordings stored on SD cards.

**Verification:** Test - Mount SD card and list files

**Acceptance Criteria:**
- Detects connected USB SD card readers
- Accesses mounted volumes successfully
- Lists all files and directories
- Reads file metadata (size, date, permissions)
- Handles access failures gracefully with error message

**Source:** Technical requirement

**Dependencies:** None (foundational requirement)

---

#### REQ-FUNC-018: File List Display
**Description:** The system shall display a list of video files with the following information: thumbnail, filename, duration, size, date, event type.

**Rationale:** Users need to browse and identify recordings.

**Verification:** Inspection - Verify all information displayed correctly

**Acceptance Criteria:**
- List view shows all video files
- Thumbnail generated from first frame
- Metadata loaded asynchronously (non-blocking)
- Sorting by date, name, size, duration
- Filtering by date range

**Source:** Client requirement

**Dependencies:** REQ-FUNC-017

---

#### REQ-FUNC-019: Event Type Organization
**Description:** The system shall categorize recordings into event types: Normal, Impact, Parking.

**Rationale:** Dashcams record different types of events that users want to view separately.

**Verification:** Test - Verify files appear in correct category

**Acceptance Criteria:**
- Tab or filter for each event type
- Files categorized based on metadata or file location
- Visual distinction (color coding or icon)
- Event type displayed in file list
- "All" view showing all types with indicators

**Source:** Client requirement

**Dependencies:** REQ-FUNC-018

---

#### REQ-FUNC-020: Multi-File Selection
**Description:** The system shall allow selecting multiple files using standard macOS selection methods (Shift-click, Cmd-click).

**Rationale:** Users need to perform batch operations.

**Verification:** Test - Select multiple files and verify selection state

**Acceptance Criteria:**
- Shift-click selects range
- Cmd-click toggles individual selection
- Cmd-A selects all visible files
- Selection count displayed
- Visual indication of selected files

**Source:** Client requirement

**Dependencies:** REQ-FUNC-018

---

#### REQ-FUNC-021: Batch Export
**Description:** The system shall export multiple selected files in a single operation with progress indication.

**Rationale:** Efficiency for processing many files.

**Verification:** Test - Export multiple files and monitor progress

**Acceptance Criteria:**
- Export button enabled when multiple files selected
- Progress bar shows overall completion
- Individual file status (pending, processing, complete, failed)
- Option to cancel operation
- Completion notification

**Source:** Client requirement

**Dependencies:** REQ-FUNC-007, REQ-FUNC-020

---

#### REQ-FUNC-022: File Search
**Description:** The system shall provide search functionality by filename, date range, and event type.

**Rationale:** Users need to find specific recordings quickly.

**Verification:** Test - Search with various criteria and verify results

**Acceptance Criteria:**
- Search field in UI
- Results update as user types (live search)
- Date range picker for temporal filtering
- Event type filter checkboxes
- Clear search button
- Search results count displayed

**Source:** Client requirement

**Dependencies:** REQ-FUNC-018

---

### 4.6 Dashcam Configuration

**Priority:** Medium (3)

#### REQ-FUNC-023: Settings File Access
**Description:** The system shall read dashcam configuration files from SD card root directory.

**Rationale:** Settings stored on SD card control dashcam behavior.

**Verification:** Test - Read settings file and parse correctly

**Acceptance Criteria:**
- Locates configuration file (e.g., config.ini, settings.dat)
- Parses file format correctly
- Handles missing or corrupted file
- Displays error if file format unrecognized

**Source:** Client requirement

**Dependencies:** REQ-FUNC-017

---

#### REQ-FUNC-024: Settings Display
**Description:** The system shall display current dashcam settings in a form organized by category: Video, Audio, Recording, Safety.

**Rationale:** Users need to view and modify settings.

**Verification:** Inspection - Verify all settings displayed with correct values

**Acceptance Criteria:**
- All supported settings displayed
- Settings grouped logically
- Current values loaded from SD card
- Tooltips or help text for each setting
- Default values indicated

**Source:** Client requirement

**Dependencies:** REQ-FUNC-023

---

#### REQ-FUNC-025: Settings Modification
**Description:** The system shall allow users to modify dashcam settings and save changes back to SD card.

**Rationale:** Users want to configure dashcam without removing from vehicle.

**Verification:** Test - Modify settings, save, and verify change persisted

**Acceptance Criteria:**
- All editable settings have appropriate controls (dropdowns, checkboxes, sliders)
- Input validation prevents invalid values
- Save button writes to SD card
- Success/failure notification
- Option to reset to defaults
- Warning before saving changes

**Source:** Client requirement

**Dependencies:** REQ-FUNC-024

---

### 4.7 Image Processing

**Priority:** Medium (3)

#### REQ-FUNC-026: Screen Capture
**Description:** The system shall capture the current video frame and save as PNG or JPEG image file.

**Rationale:** Users want to extract still images from video.

**Verification:** Test - Capture frame and verify image quality

**Acceptance Criteria:**
- Capture button in player UI
- Captures at original video resolution
- Supports PNG and JPEG formats
- User selects save location
- Filename includes timestamp
- Optional: Include overlay information (time, GPS)

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-027: Digital Zoom
**Description:** The system shall provide digital zoom from 1x to 4x with pan capability.

**Rationale:** Users need to examine video details closely.

**Verification:** Test - Zoom and verify image quality and pan function

**Acceptance Criteria:**
- Zoom slider or buttons (1x, 2x, 3x, 4x)
- Mouse drag to pan when zoomed
- Smooth interpolation for quality
- Zoom applies to individual channel when selected
- Reset zoom button

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-028: Video Flip
**Description:** The system shall flip video horizontally or vertically.

**Rationale:** Some camera installations may be inverted or mirrored.

**Verification:** Test - Apply flip and verify correct orientation

**Acceptance Criteria:**
- Horizontal flip button
- Vertical flip button
- Flip persists during playback
- Applies to selected channel only
- Flip state saved with project

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-029: Brightness Adjustment
**Description:** The system shall adjust video brightness from -50% to +50% with real-time preview.

**Rationale:** Improve visibility of over/under-exposed footage.

**Verification:** Test - Adjust brightness and verify image changes

**Acceptance Criteria:**
- Brightness slider with 0 as default
- Changes apply in real-time
- GPU-accelerated for performance
- Applies to selected channel
- Reset button

**Source:** Client requirement

**Dependencies:** None

---

### 4.8 User Interface

**Priority:** High (2)

#### REQ-FUNC-030: Multi-Channel Layout
**Description:** The system shall support at least 3 layout modes: Grid (2x3), Focus+Small (1 large + 4 small), Horizontal (1x5).

**Rationale:** Different layouts suit different viewing needs.

**Verification:** Demo - Switch between layouts and verify arrangement

**Acceptance Criteria:**
- Layout selector in UI
- Layouts switch without stopping playback
- Each layout optimizes screen space
- Selected channel highlighted in multi-channel view
- Layout preference saved

**Source:** Technical requirement

**Dependencies:** REQ-FUNC-001

---

#### REQ-FUNC-031: Full-Screen Mode
**Description:** The system shall provide full-screen viewing mode with auto-hiding controls.

**Rationale:** Immersive viewing experience.

**Verification:** Test - Enter/exit full-screen and verify behavior

**Acceptance Criteria:**
- Full-screen button or keyboard shortcut (Cmd+F)
- Controls hide after 3 seconds of inactivity
- Mouse movement reveals controls
- Exit full-screen with ESC or button
- Support for multiple displays

**Source:** Client requirement

**Dependencies:** None

---

#### REQ-FUNC-032: Keyboard Shortcuts
**Description:** The system shall provide keyboard shortcuts for common actions per the following table:

| Action | Shortcut |
|--------|----------|
| Play/Pause | Space |
| Stop | Cmd+. |
| Seek Forward 5s | Right Arrow |
| Seek Backward 5s | Left Arrow |
| Volume Up | Up Arrow |
| Volume Down | Down Arrow |
| Mute | Cmd+Shift+M |
| Full Screen | Cmd+F |
| Exit Full Screen | ESC |
| Next File | Cmd+Right |
| Previous File | Cmd+Left |

**Rationale:** Power users expect keyboard control.

**Verification:** Test - Verify each shortcut performs expected action

**Acceptance Criteria:**
- All shortcuts function as specified
- Shortcuts work in all application states
- Conflicts with system shortcuts avoided
- Shortcuts displayed in menu items
- Keyboard shortcuts configurable (nice-to-have)

**Source:** macOS HIG, Client requirement

**Dependencies:** Various UI functions

---

### 4.9 Localization

**Priority:** Low (4)

#### REQ-FUNC-033: Multi-Language Support
**Description:** The system shall support the following languages: Korean, English, with infrastructure for adding Japanese.

**Rationale:** Support international users; Korean market priority.

**Verification:** Inspection - Verify all text translated correctly

**Acceptance Criteria:**
- All UI text externalized to resource files
- Language selection in preferences
- Korean and English translations complete
- Date/time/number formatting locale-aware
- Language change without restart (nice-to-have)
- Japanese strings marked as TODO

**Source:** Client requirement

**Dependencies:** None (pervasive requirement)

---

## 5. External Interface Requirements

### 5.1 User Interfaces

**REQ-UI-001: macOS Native Interface**
**Description:** The application shall follow Apple Human Interface Guidelines for macOS.

**Verification:** Inspection - Review UI against HIG checklist

**Acceptance Criteria:**
- Native macOS window chrome
- Standard menu bar with expected items
- Toolbar with common actions
- SF Symbols for icons
- Support for light and dark modes

---

**REQ-UI-002: Responsive Layout**
**Description:** The application UI shall adapt to window sizes from 1024x768 minimum to full screen.

**Verification:** Test - Resize window and verify layout adapts

**Acceptance Criteria:**
- Minimum window size enforced
- Layout adjusts to available space
- No overlapping elements
- Controls remain accessible
- Text remains readable

---

### 5.2 Hardware Interfaces

**REQ-HW-001: SD Card Reader**
**Description:** The system shall interface with USB SD card readers through macOS IOKit framework.

**Verification:** Test - Connect various SD card readers and verify detection

**Acceptance Criteria:**
- Detects USB card readers
- Supports USB 2.0 and 3.0
- Handles hot-plug events
- Notifies user of reader connection/disconnection

---

**REQ-HW-002: Display Support**
**Description:** The system shall support displays with resolution from 1920x1080 to 5K (5120x2880).

**Verification:** Test - Run on various display configurations

**Acceptance Criteria:**
- Correct rendering on all supported resolutions
- Support for Retina displays (2x scaling)
- Support for multiple displays
- Correct DPI handling

---

### 5.3 Software Interfaces

**REQ-SW-001: FFmpeg Library Interface**
**Description:** The system shall use FFmpeg library for video/audio decoding and encoding.

**Verification:** Test - Decode and encode various formats

**Acceptance Criteria:**
- Decode H.264 video
- Decode MP3 audio
- Encode to H.264/AAC
- Mux to MP4 container
- Handle codec errors gracefully

---

**REQ-SW-002: Map Service Interface**
**Description:** The system shall interface with either MapKit or Google Maps SDK for map display.

**Verification:** Test - Display map and route

**Acceptance Criteria:**
- Initialize map view
- Set map region
- Draw polyline route
- Add annotations
- Handle API errors

---

### 5.4 Communication Interfaces

**REQ-COM-001: Network Communication**
**Description:** The system shall use HTTPS for all network communication (map tiles, geocoding).

**Verification:** Inspection - Verify network traffic uses TLS

**Acceptance Criteria:**
- All HTTP requests use TLS 1.2 or later
- Certificate validation enabled
- Handles network unavailability gracefully
- Offline mode for non-map features

---

## 6. Non-Functional Requirements

### 6.1 Performance Requirements (ISO/IEC 25010: Performance Efficiency)

**REQ-PERF-001: Video Playback Frame Rate**
**Description:** The system shall maintain playback rate of at least 30 frames per second for each channel during normal operation.

**Verification:** Test - Measure frame rate with profiling tools

**Acceptance Criteria:**
- Average FPS ≥ 30 per channel
- Frame drops < 1% over 10-minute period
- Stable performance for 2+ hours continuous playback

**Priority:** Critical (1)

---

**REQ-PERF-002: Startup Time**
**Description:** The application shall launch and display the main window within 2 seconds on typical hardware (Apple Silicon M1 or equivalent).

**Verification:** Test - Measure time from launch to window display

**Acceptance Criteria:**
- Cold start ≤ 2 seconds
- Warm start ≤ 1 second
- Progress indicator if loading takes >500ms

**Priority:** High (2)

---

**REQ-PERF-003: Seek Response Time**
**Description:** The system shall complete seek operations within 1 second.

**Verification:** Test - Measure time from seek initiation to frame display

**Acceptance Criteria:**
- Average seek time ≤ 1 second
- Maximum seek time ≤ 2 seconds
- Visual feedback during seek

**Priority:** High (2)

---

**REQ-PERF-004: Export Speed**
**Description:** The system shall export video at minimum 1x real-time speed (10-minute video exports in ≤10 minutes).

**Verification:** Test - Export various length videos and measure time

**Acceptance Criteria:**
- Export rate ≥ 1x real-time on Apple Silicon
- Export rate ≥ 0.75x real-time on Intel Mac
- Progress estimation accurate to ±20%

**Priority:** High (2)

---

**REQ-PERF-005: Memory Usage**
**Description:** The system shall operate within 2GB total memory usage during 5-channel playback of 1080p video.

**Verification:** Test - Monitor memory usage with Instruments

**Acceptance Criteria:**
- Average memory ≤ 2GB
- Peak memory ≤ 2.5GB
- No memory leaks (stable over time)
- Graceful degradation if memory constrained

**Priority:** Critical (1)

---

**REQ-PERF-006: CPU Usage**
**Description:** The system shall maintain CPU usage below 80% during 5-channel playback on Apple Silicon Mac.

**Verification:** Test - Monitor CPU usage with Activity Monitor

**Acceptance Criteria:**
- Average CPU ≤ 80%
- Efficient use of multiple cores
- Background tasks deprioritized when in background

**Priority:** High (2)

---

### 6.2 Safety Requirements (ISO/IEC 25010: Reliability)

**REQ-SAFE-001: Data Integrity**
**Description:** The system shall not corrupt or modify original video files during read operations.

**Verification:** Test - Compare file checksums before and after opening

**Acceptance Criteria:**
- Read operations do not modify source files
- File timestamps unchanged
- Application crash does not corrupt SD card

**Priority:** Critical (1)

---

**REQ-SAFE-002: Graceful Degradation**
**Description:** The system shall continue operating with reduced functionality when encountering non-critical errors.

**Verification:** Test - Simulate various error conditions

**Acceptance Criteria:**
- Missing GPS data: Video still plays, map unavailable
- Missing G-Sensor data: Video still plays, graph unavailable
- Corrupted channel: Other channels continue playing
- Network unavailable: Offline features work

**Priority:** High (2)

---

**REQ-SAFE-003: Auto-Recovery**
**Description:** The system shall automatically recover from transient errors (e.g., USB disconnection) when possible.

**Verification:** Test - Disconnect and reconnect SD card during operation

**Acceptance Criteria:**
- Detects SD card disconnection
- Prompts user to reconnect
- Resumes operation when reconnected
- Saves application state

**Priority:** Medium (3)

---

### 6.3 Security Requirements (ISO/IEC 25010: Security)

**REQ-SEC-001: Secure Storage**
**Description:** The system shall not store sensitive data (videos, GPS coordinates) persistently except user preferences.

**Verification:** Inspection - Verify no sensitive data in application support folder

**Acceptance Criteria:**
- No video data cached permanently
- GPS data cleared on quit
- Only UI preferences stored
- User data in standard macOS locations

**Priority:** High (2)

---

**REQ-SEC-002: Sandbox Compliance**
**Description:** The system shall operate within macOS App Sandbox restrictions if distributed through App Store.

**Verification:** Test - Enable sandbox and verify functionality

**Acceptance Criteria:**
- Requests user permission for USB access
- Uses security-scoped bookmarks for file access
- No privileged operations without entitlements
- Passes App Store review

**Priority:** Medium (3) if App Store, Low (4) otherwise

---

**REQ-SEC-003: Input Validation**
**Description:** The system shall validate all external input (file contents, metadata) to prevent crashes or exploitation.

**Verification:** Test - Provide malformed input and verify safe handling

**Acceptance Criteria:**
- Validates file headers before parsing
- Bounds checking on array access
- Safe string handling (no buffer overflows)
- Graceful handling of malformed data

**Priority:** High (2)

---

**REQ-SEC-004: Code Signing**
**Description:** The application shall be signed with a valid Developer ID certificate.

**Verification:** Inspection - Verify signature with codesign tool

**Acceptance Criteria:**
- All binaries signed
- Hardened runtime enabled
- No ad-hoc signatures in release build
- Passes Gatekeeper

**Priority:** Critical (1) for distribution

---

**REQ-SEC-005: Notarization**
**Description:** The application shall be notarized by Apple for macOS 10.15+.

**Verification:** Test - Verify notarization ticket

**Acceptance Criteria:**
- Submitted to Apple notary service
- No warnings or errors from notarization
- Ticket stapled to application
- Launches without Gatekeeper prompt

**Priority:** Critical (1) for distribution

---

### 6.4 Software Quality Attributes (ISO/IEC 25010)

#### 6.4.1 Usability

**REQ-USAB-001: Learnability**
**Description:** A new user shall be able to play a video within 2 minutes without documentation.

**Verification:** Test - User study with 5+ participants

**Acceptance Criteria:**
- 80% of users succeed within 2 minutes
- Average time ≤ 1 minute
- No user requires help for basic playback

**Priority:** High (2)

---

**REQ-USAB-002: Accessibility**
**Description:** The system shall support VoiceOver screen reader for visually impaired users.

**Verification:** Test - Navigate application with VoiceOver

**Acceptance Criteria:**
- All controls have accessibility labels
- Logical tab order
- Image descriptions provided
- Keyboard navigation functional

**Priority:** Medium (3)

---

**REQ-USAB-003: Error Messages**
**Description:** The system shall provide clear, actionable error messages in user's language.

**Verification:** Inspection - Review all error messages

**Acceptance Criteria:**
- Error messages explain what happened
- Messages suggest corrective action
- Technical details in collapsible section
- No generic "Error occurred" messages

**Priority:** High (2)

---

#### 6.4.2 Reliability

**REQ-REL-001: Crash-Free Operation**
**Description:** The system shall operate without crashing for at least 24 hours of continuous use.

**Verification:** Test - Stability test with extended operation

**Acceptance Criteria:**
- No crashes during 24-hour test
- Memory stable (no leaks)
- Performance stable (no degradation)
- Passes stress tests

**Priority:** Critical (1)

---

**REQ-REL-002: Data Loss Prevention**
**Description:** The system shall not lose user data (export jobs, settings) due to application crash.

**Verification:** Test - Force crash and verify recovery

**Acceptance Criteria:**
- Export jobs resumable after crash
- Settings auto-saved
- Temporary files cleaned on next launch
- Crash reports generated

**Priority:** High (2)

---

#### 6.4.3 Maintainability

**REQ-MAINT-001: Code Quality**
**Description:** The codebase shall maintain high quality standards with linting and static analysis.

**Verification:** Analysis - Run SwiftLint and review warnings

**Acceptance Criteria:**
- Zero SwiftLint errors in release build
- SwiftLint warnings < 10 per 1000 lines of code
- Cyclomatic complexity ≤ 10 per function
- No force-unwraps in production code

**Priority:** High (2)

---

**REQ-MAINT-002: Test Coverage**
**Description:** The codebase shall maintain at least 80% unit test coverage.

**Verification:** Analysis - Generate coverage report

**Acceptance Criteria:**
- Line coverage ≥ 80%
- Branch coverage ≥ 70%
- All public APIs tested
- Critical paths tested

**Priority:** High (2)

---

**REQ-MAINT-003: Documentation**
**Description:** All public APIs shall have documentation comments following Swift documentation standards.

**Verification:** Inspection - Generate API documentation

**Acceptance Criteria:**
- All public classes documented
- All public methods documented
- Parameters and return values described
- Code examples for complex APIs

**Priority:** Medium (3)

---

#### 6.4.4 Portability

**REQ-PORT-001: Architecture Support**
**Description:** The application shall support both Apple Silicon and Intel architectures as Universal Binary.

**Verification:** Test - Build and run on both architectures

**Acceptance Criteria:**
- Single binary supports both architectures
- Performance optimized for each architecture
- No architecture-specific code paths visible to user

**Priority:** High (2)

---

**REQ-PORT-002: OS Version Support**
**Description:** The application shall support macOS 12.0 (Monterey) through latest macOS version.

**Verification:** Test - Run on minimum and latest OS versions

**Acceptance Criteria:**
- Launches on macOS 12.0
- All features work on macOS 12.0
- Takes advantage of newer APIs when available
- Graceful fallback for unsupported APIs

**Priority:** Critical (1)

---

#### 6.4.5 Compatibility

**REQ-COMPAT-001: Video Format Support**
**Description:** The system shall support H.264 profiles: Baseline, Main, High.

**Verification:** Test - Play videos encoded with each profile

**Acceptance Criteria:**
- Baseline profile supported
- Main profile supported
- High profile supported
- Graceful handling of unsupported profiles

**Priority:** Critical (1)

---


## 7. Other Requirements

### 7.1 Legal Requirements

**REQ-LEGAL-001: Open Source Compliance**
**Description:** The application shall comply with all open source licenses (LGPL, MIT, Apache).

**Verification:** Inspection - Review license compliance

**Acceptance Criteria:**
- License texts included in application
- Dynamic linking for LGPL libraries
- Attribution notices displayed
- Source code availability for GPL components (if any)

**Priority:** Critical (1)

---

**REQ-LEGAL-002: Third-Party Licenses**
**Description:** The application shall display third-party licenses in About panel.

**Verification:** Inspection - Verify licenses displayed

**Acceptance Criteria:**
- FFmpeg license displayed
- Map service license displayed (if applicable)
- All dependencies listed
- License viewer accessible from menu

**Priority:** Medium (3)

---

### 7.2 Database Requirements

Not applicable - application does not use persistent database.

### 7.3 Internationalization

Covered under REQ-FUNC-033.

---

## 8. Appendices

### Appendix A: Requirements Traceability Matrix

| Requirement ID | Priority | Phase | Test ID | Architecture Component |
|----------------|----------|-------|---------|----------------------|
| REQ-FUNC-001 | Critical (1) | 3 | TEST-FUNC-001 | MultiChannelPlayer |
| REQ-FUNC-002 | Critical (1) | 3 | TEST-FUNC-002 | SyncController |
| REQ-FUNC-003 | Critical (1) | 2 | TEST-FUNC-003 | PlayerViewModel |
| REQ-FUNC-004 | Critical (1) | 2 | TEST-FUNC-004 | PlayerViewModel |
| REQ-FUNC-005 | Critical (1) | 2 | TEST-FUNC-005 | PlayerViewModel |
| REQ-FUNC-006 | Critical (1) | 2 | TEST-FUNC-006 | PlayerViewModel |
| REQ-FUNC-007 | Critical (1) | 5 | TEST-FUNC-007 | ExportService |
| REQ-FUNC-008 | Critical (1) | 5 | TEST-FUNC-008 | ExportService |
| REQ-FUNC-009 | High (2) | 5 | TEST-FUNC-009 | ExportService |
| REQ-FUNC-010 | High (2) | 5 | TEST-FUNC-010 | ExportService |
| REQ-FUNC-011 | High (2) | 4 | TEST-FUNC-011 | GPSService |
| REQ-FUNC-012 | High (2) | 4 | TEST-FUNC-012 | GPSMapView |
| REQ-FUNC-013 | High (2) | 4 | TEST-FUNC-013 | GPSService |
| REQ-FUNC-014 | High (2) | 4 | TEST-FUNC-014 | GSensorService |
| REQ-FUNC-015 | High (2) | 4 | TEST-FUNC-015 | GSensorChartView |
| REQ-FUNC-016 | High (2) | 4 | TEST-FUNC-016 | GSensorService |
| REQ-FUNC-017 | Critical (1) | 1 | TEST-FUNC-017 | FileManagerService |
| REQ-FUNC-018 | High (2) | 1 | TEST-FUNC-018 | FileListViewModel |
| REQ-FUNC-019 | High (2) | 1 | TEST-FUNC-019 | FileManagerService |
| REQ-FUNC-020 | High (2) | 1 | TEST-FUNC-020 | FileListViewModel |
| REQ-FUNC-021 | High (2) | 5 | TEST-FUNC-021 | ExportService |
| REQ-FUNC-022 | Medium (3) | 1 | TEST-FUNC-022 | FileManagerService |
| REQ-FUNC-023 | Medium (3) | 5 | TEST-FUNC-023 | SettingsService |
| REQ-FUNC-024 | Medium (3) | 5 | TEST-FUNC-024 | SettingsViewModel |
| REQ-FUNC-025 | Medium (3) | 5 | TEST-FUNC-025 | SettingsService |
| REQ-FUNC-026 | Medium (3) | 4 | TEST-FUNC-026 | PlayerViewModel |
| REQ-FUNC-027 | Medium (3) | 4 | TEST-FUNC-027 | MetalRenderer |
| REQ-FUNC-028 | Medium (3) | 4 | TEST-FUNC-028 | MetalRenderer |
| REQ-FUNC-029 | Medium (3) | 4 | TEST-FUNC-029 | MetalRenderer |
| REQ-FUNC-030 | High (2) | 3 | TEST-FUNC-030 | LayoutManager |
| REQ-FUNC-031 | Medium (3) | 4 | TEST-FUNC-031 | PlayerView |
| REQ-FUNC-032 | High (2) | 6 | TEST-FUNC-032 | Various ViewModels |
| REQ-FUNC-033 | Low (4) | 6 | TEST-FUNC-033 | Localization |
| REQ-PERF-001 | Critical (1) | 3 | TEST-PERF-001 | MultiChannelPlayer |
| REQ-PERF-002 | High (2) | 6 | TEST-PERF-002 | Application |
| REQ-PERF-003 | High (2) | 2 | TEST-PERF-003 | PlayerViewModel |
| REQ-PERF-004 | High (2) | 5 | TEST-PERF-004 | ExportService |
| REQ-PERF-005 | Critical (1) | 3 | TEST-PERF-005 | Memory Management |
| REQ-PERF-006 | High (2) | 3 | TEST-PERF-006 | Thread Management |
| REQ-SEC-001 | High (2) | All | TEST-SEC-001 | Data Layer |
| REQ-SEC-002 | Medium (3) | 6 | TEST-SEC-002 | Application |
| REQ-SEC-003 | High (2) | All | TEST-SEC-003 | Data Layer |
| REQ-SEC-004 | Critical (1) | 6 | TEST-SEC-004 | Build System |
| REQ-SEC-005 | Critical (1) | 6 | TEST-SEC-005 | Build System |

### Appendix B: ISO/IEC 25010 Quality Model Mapping

| Quality Characteristic | Sub-characteristic | Requirements |
|----------------------|-------------------|--------------|
| **Functional Suitability** | Functional completeness | REQ-FUNC-001 through REQ-FUNC-033 |
| | Functional correctness | All functional requirements |
| | Functional appropriateness | Priority analysis, user needs |
| **Performance Efficiency** | Time behavior | REQ-PERF-001, REQ-PERF-002, REQ-PERF-003 |
| | Resource utilization | REQ-PERF-005, REQ-PERF-006 |
| | Capacity | REQ-FUNC-001 (5 channels) |
| **Compatibility** | Co-existence | REQ-COMPAT-001 |
| | Interoperability | REQ-SW-001, REQ-SW-002 |
| **Usability** | Appropriateness recognizability | REQ-USAB-001 |
| | Learnability | REQ-USAB-001 |
| | Operability | REQ-FUNC-032, REQ-USAB-002 |
| | User error protection | REQ-USAB-003, REQ-SEC-003 |
| | User interface aesthetics | REQ-UI-001 |
| | Accessibility | REQ-USAB-002 |
| **Reliability** | Maturity | REQ-REL-001 |
| | Availability | REQ-SAFE-002 |
| | Fault tolerance | REQ-SAFE-002, REQ-SAFE-003 |
| | Recoverability | REQ-SAFE-003, REQ-REL-002 |
| **Security** | Confidentiality | REQ-SEC-001 |
| | Integrity | REQ-SAFE-001, REQ-SEC-003 |
| | Non-repudiation | N/A |
| | Accountability | N/A |
| | Authenticity | REQ-SEC-004, REQ-SEC-005 |
| **Maintainability** | Modularity | REQ-MAINT-001 (architecture) |
| | Reusability | REQ-MAINT-001 |
| | Analyzability | REQ-MAINT-002 (test coverage) |
| | Modifiability | REQ-MAINT-001 |
| | Testability | REQ-MAINT-002 |
| **Portability** | Adaptability | REQ-PORT-002 |
| | Installability | REQ-SEC-004, REQ-SEC-005 |
| | Replaceability | N/A |

### Appendix C: Glossary

See Section 1.3 for definitions.

### Appendix D: Assumptions and Dependencies

See Section 2.5 for complete list.

### Appendix E: Verification Cross-Reference

| Verification Method | Requirements Count | Examples |
|-------------------|-------------------|----------|
| **Test** | 35 | REQ-FUNC-001, REQ-PERF-001 |
| **Demo** | 5 | REQ-FUNC-012, REQ-USAB-001 |
| **Inspection** | 12 | REQ-UI-001, REQ-MAINT-003 |
| **Analysis** | 4 | REQ-MAINT-001, REQ-MAINT-002 |

---

## Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Project Manager** | | | |
| **Technical Lead** | | | |
| **QA Lead** | | | |
| **Product Owner** | | | |

---

**End of Software Requirements Specification**

*This document conforms to ISO/IEC/IEEE 29148:2018 standard for requirements engineering.*
