/// @file ContentView.swift
/// @brief Main content view for blackbox player
/// @author BlackboxPlayer Development Team
/// @details
/// Main content view for the BlackboxPlayer app, integrating overall UI structure and business logic.
/// Provides NavigationView-based master-detail layout, folder scanning, multi-channel video player,
/// GPS map and G-sensor graph visualization features.

/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                            ContentView                                       ║
 ║                  Blackbox Player Main Content View                           ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝

 📚 Purpose of this File
 ════════════════════════════════════════════════════════════════════════════════
 Main content view for the BlackboxPlayer app, integrating overall UI structure and business logic.

 This is one of the largest view files in the project, responsible for:
 • NavigationView-based master-detail layout
 • Folder scanning and video file loading
 • Multi-channel video player integration
 • GPS map and G-sensor graph visualization
 • Playback controls and timeline slider


 🏗️ Overall Layout Structure
 ════════════════════════════════════════════════════════════════════════════════
 ```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │ 🔧 ⊞ 📂 🖥️                                           [Toolbar]          │
 ├─────────────┬───────────────────────────────────────────────────────────┤
 │             │                                                           │
 │   Sidebar   │                  Main Content                             │
 │             │                                                           │
 │ 📁 Folder   │  ┌─────────────────────────────────────────────────┐     │
 │ ─────────   │  │                                                 │     │
 │ 3 files     │  │         Multi-Channel Player                    │     │
 │             │  │         (4 cameras synchronized)                │     │
 │ ┌─────────┐ │  │                                                 │     │
 │ │📹 File1 │ │  └─────────────────────────────────────────────────┘     │
 │ ├─────────┤ │                                                           │
 │ │📹 File2 │ │  📋 File Information Card                                │
 │ ├─────────┤ │  📹 Camera Channels Card                                 │
 │ │📹 File3 │ │  📊 Metadata Card                                        │
 │ └─────────┘ │  🗺️  GPS Map Card                                        │
 │             │  📈 Acceleration Graph Card                              │
 │             │                                                           │
 └─────────────┴───────────────────────────────────────────────────────────┘
 (FileListView)                    (ScrollView)

 [Debug Log Overlay] (bottom, toggleable)
 [Loading Overlay] (fullscreen, during scan)
 ```


 🎨 Main Components
 ════════════════════════════════════════════════════════════════════════════════

 1. **NavigationView**
 - Master (Sidebar) - Detail (Main Content) layout
 - Sidebar: File list + search/filter
 - Main Content: Detailed info of selected file

 2. **Toolbar**
 - Sidebar toggle button
 - Open folder button (NSOpenPanel)
 - Debug log toggle

 3. **Sidebar** (300-500px)
 - Current folder path display
 - File count display
 - FileListView integration (search/filter/selection)

 4. **Main Content**
 - Empty State: Guide screen when no file selected
 - File Info View: Detailed info of selected file
 - MultiChannelPlayerView (multi-channel player)
 - File Information Card
 - Camera Channels Card
 - Metadata Card
 - GPS Map Card (MapKit)
 - Acceleration Graph Card (Custom Drawing)

 5. **Overlays**
 - Loading Overlay: Displayed during folder scan
 - Debug Log Overlay: Slides up from bottom


 📊 State Management Pattern
 ════════════════════════════════════════════════════════════════════════════════

 This view manages 15 states with @State:

 **File-related State:**
 ```swift
 @State private var selectedVideoFile: VideoFile?    // Selected file
 @State private var videoFiles: [VideoFile]          // All file list
 @State private var currentFolderPath: String?       // Current folder path
 ```

 **UI-related State:**
 ```swift
 @State private var showSidebar = true               // Whether to show sidebar
 @State private var showDebugLog = false             // Whether to show debug log
 @State private var isLoading = false                // Loading state
 @State private var showError = false                // Whether to show error alert
 @State private var errorMessage = ""                // Error message
 ```

 **Playback-related State (simulation):**
 ```swift
 @State private var isPlaying = false                // Whether playing
 @State private var currentPlaybackTime: Double      // Current playback time
 @State private var playbackSpeed: Double = 1.0      // Playback speed
 @State private var volume: Double = 0.8             // Volume
 @State private var showControls = true              // Whether to show controls
 ```

 📌 What is @State?
 A SwiftUI Property Wrapper that automatically re-renders the view when its value changes.
 Declared as private, it is only accessible within the current view.

 📌 Why do we need so many States?
 ContentView is the top-level view of the app and must manage various UI states.
 Each State controls the display/behavior of specific UI elements.


 🔌 Service Integration
 ════════════════════════════════════════════════════════════════════════════════

 **FileScanner**
 - Role: Scan folder to detect blackbox file groups
 - When used: openFolder() → scanAndLoadFolder()
 - Operation: Scan file system in background thread

 **VideoFileLoader**
 - Role: FileGroup → VideoFile conversion
 - When used: scanAndLoadFolder() → file loading
 - Operation: Metadata parsing and VideoFile object creation

 ```
 User Action          Service Flow
 ─────────────────────────────────────────
 [Open Folder]
 ↓
 NSOpenPanel (folder selection)
 ↓
 FileScanner.scanDirectory()
 ↓ (background)
 FileGroup[] creation
 ↓
 VideoFileLoader.loadVideoFiles()
 ↓
 VideoFile[] creation
 ↓ (main thread)
 videoFiles update
 ↓
 Automatic view re-rendering
 ```


 🎯 Core Feature Flows
 ════════════════════════════════════════════════════════════════════════════════

 ### 1. Open Folder Flow
 ```
 1) Toolbar > Click "Open Folder" button
 ↓
 2) Execute openFolder()
 ↓
 3) Display NSOpenPanel (macOS native folder selection dialog)
 ↓
 4) User selects folder → Call scanAndLoadFolder(URL)
 ↓
 5) isLoading = true (display loading overlay)
 ↓
 6) DispatchQueue.global() → Scan in background thread
 ↓
 7) FileScanner.scanDirectory() → FileGroup[] creation
 ↓
 8) VideoFileLoader.loadVideoFiles() → VideoFile[] creation
 ↓
 9) DispatchQueue.main.async → Return to main thread
 ↓
 10) Update videoFiles, isLoading = false
 ↓
 11) Automatically select first file
 ↓
 12) View re-rendering (display file list + detailed info)
 ```

 ### 2. File Selection Flow
 ```
 1) Sidebar > Tap file in FileListView
 ↓
 2) selectedVideoFile = file (passed via binding)
 ↓
 3) mainContent conditional rendering
 ↓ if selectedFile != nil
 4) Call fileInfoView(for: file)
 ↓
 5) Display in order inside ScrollView:
 - MultiChannelPlayerView (video player)
 - File Information Card (filename, timestamp, size, etc.)
 - Camera Channels Card (channel list)
 - Metadata Card (GPS, G-sensor summary)
 - GPS Map Card (MapKit integration)
 - Acceleration Graph Card (Custom Drawing)
 ```

 ### 3. GPS Map Display Flow
 ```
 1) Check videoFile.hasGPSData == true
 ↓
 2) Call gpsMapCard(for: videoFile)
 ↓
 3) Create GPSMapView(gpsPoints: [...])
 ↓ NSViewRepresentable
 4) makeNSView() → Create MKMapView
 ↓
 5) updateNSView() → Process GPS points
 ↓
 6) Draw route with MKPolyline
 ↓
 7) Add MKPointAnnotation to start/end points
 ↓
 8) Set map region (1km radius)
 ```

 ### 4. Acceleration Graph Display Flow
 ```
 1) Check videoFile.hasAccelerationData == true
 ↓
 2) Call accelerationGraphCard(for: videoFile)
 ↓
 3) Create AccelerationGraphView(accelerationData: [...])
 ↓
 4) Measure size with GeometryReader
 ↓
 5) gridLines() → Draw grid
 ↓
 6) accelerationCurves() → Draw 3-axis graph
 ↓ Using KeyPath
 7) Create Path for X-axis (red), Y-axis (green), Z-axis (blue)
 ↓
 8) Normalize and display in ±2G range
 ↓
 9) Display Legend (top right)
 ```


 🧩 SwiftUI Core Concepts
 ════════════════════════════════════════════════════════════════════════════════

 ### 1. NavigationView (Master-Detail)
 ```swift
 NavigationView {
 // Master (Sidebar)
 if showSidebar { sidebar }

 // Detail (Main Content)
 mainContent
 }
 ```
 - Implement sidebar + main content layout on macOS
 - Can toggle sidebar with showSidebar
 - Size constraints with .frame(minWidth:idealWidth:maxWidth:)

 ### 2. Toolbar
 ```swift
 .toolbar {
 ToolbarItemGroup(placement: .navigation) {
 // Buttons...
 }
 }
 ```
 - Customize top toolbar of macOS app
 - .navigation placement: left area
 - .help() modifier: Display tooltip

 ### 3. Overlay
 ```swift
 .overlay {
 if isLoading { ... }
 }
 .overlay(alignment: .bottom) {
 if showDebugLog { DebugLogView() }
 }
 ```
 - Overlay another view on top of existing view
 - Specify position with alignment
 - Show/hide with conditional rendering

 ### 4. Alert
 ```swift
 .alert("Error", isPresented: $showError) {
 Button("OK", role: .cancel) { }
 } message: {
 Text(errorMessage)
 }
 ```
 - Control alert display with @State binding
 - Automatically show alert when showError = true
 - Automatically changes to false on button click

 ### 5. GeometryReader
 ```swift
 GeometryReader { geometry in
 // Access parent size with geometry.size
 let layout = calculateChannelLayout(count: channels.count, in: geometry.size)
 ...
 }
 ```
 - Read parent view size to configure dynamic layout
 - Used for multi-channel layout calculation
 - Implement timeline slider with DragGesture

 ### 6. NSViewRepresentable (GPSMapView)
 ```swift
 struct GPSMapView: NSViewRepresentable {
 func makeNSView(context: Context) -> MKMapView { ... }
 func updateNSView(_ mapView: MKMapView, context: Context) { ... }
 func makeCoordinator() -> Coordinator { ... }
 }
 ```
 - Use AppKit (macOS) NSView in SwiftUI
 - MKMapView (MapKit) integration
 - Handle delegate with Coordinator pattern

 ### 7. Property Wrapper: @State
 ```swift
 @State private var selectedVideoFile: VideoFile?
 ```
 - Manage state inside view
 - Automatic view re-rendering on value change
 - private: Not accessible from outside

 ### 8. Binding ($)
 ```swift
 FileListView(
 videoFiles: $videoFiles,           // Binding<[VideoFile]>
 selectedFile: $selectedVideoFile   // Binding<VideoFile?>
 )
 ```
 - Create two-way binding with $ prefix
 - Child view can directly modify parent's state


 ⚙️ Asynchronous Processing Pattern
 ════════════════════════════════════════════════════════════════════════════════

 **Background processing when scanning folder:**
 ```swift
 DispatchQueue.global(qos: .userInitiated).async {
 // 🔄 Background thread
 do {
 let groups = try fileScanner.scanDirectory(folderURL)
 let loadedFiles = videoFileLoader.loadVideoFiles(from: groups)

 DispatchQueue.main.async {
 // 🎨 Main thread (UI update)
 self.videoFiles = loadedFiles
 self.isLoading = false
 }
 } catch {
 DispatchQueue.main.async {
 self.errorMessage = "Failed: \(error.localizedDescription)"
 self.showError = true
 }
 }
 }
 ```

 📌 Why use background thread?
 File scanning is I/O operation that can take a long time.
 Running on main thread would freeze the UI, so we process in background.

 📌 Why return to main thread?
 In SwiftUI, UI updates must be done on the main thread.
 @State value changes must also be performed on main thread for automatic re-rendering to work.


 🗺️ MapKit Integration Pattern
 ════════════════════════════════════════════════════════════════════════════════

 **GPSMapView (NSViewRepresentable):**

 1. **makeNSView()** - Initial setup
 ```swift
 let mapView = MKMapView()
 mapView.mapType = .standard        // Standard map
 mapView.showsUserLocation = false  // Don't show user location
 mapView.isZoomEnabled = true       // Allow zoom
 mapView.isScrollEnabled = true     // Allow scroll
 ```

 2. **updateNSView()** - Data update
 ```swift
 // Remove existing overlays
 mapView.removeOverlays(mapView.overlays)

 // GPS points → CLLocationCoordinate2D conversion
 let coordinates = gpsPoints.map { CLLocationCoordinate2D(...) }

 // Draw route with MKPolyline
 let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
 mapView.addOverlay(polyline)

 // Add markers for start/end points
 mapView.addAnnotation(startAnnotation)
 mapView.addAnnotation(endAnnotation)
 ```

 3. **Coordinator** - Delegate pattern
 ```swift
 class Coordinator: NSObject, MKMapViewDelegate {
 func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
 let renderer = MKPolylineRenderer(polyline: polyline)
 renderer.strokeColor = NSColor.systemBlue  // Blue line
 renderer.lineWidth = 3                      // 3px thickness
 return renderer
 }
 }
 ```


 📈 Custom Drawing Pattern (Acceleration Graph)
 ════════════════════════════════════════════════════════════════════════════════

 **AccelerationGraphView:**

 1. **Measure size with GeometryReader**
 ```swift
 GeometryReader { geometry in
 ZStack {
 gridLines(in: geometry.size)
 accelerationCurves(in: geometry.size)
 legend
 }
 }
 ```

 2. **Draw graph with Path**
 ```swift
 Path { path in
 let points = accelerationData.enumerated().map { index, data in
 let x = size.width * CGFloat(index) / CGFloat(count - 1)
 let value = data[keyPath: keyPath]                    // Use KeyPath
 let normalizedValue = (value + maxValue) / (2 * maxValue)
 let y = size.height * (1 - CGFloat(normalizedValue)) // Invert (top→0, bottom→1)
 return CGPoint(x: x, y: y)
 }

 path.move(to: points[0])
 for point in points.dropFirst() {
 path.addLine(to: point)
 }
 }
 .stroke(color, lineWidth: 2)
 ```

 3. **Dynamic access using KeyPath**
 ```swift
 accelerationPath(for: \.x, in: size, color: .red)    // X-axis
 accelerationPath(for: \.y, in: size, color: .green)  // Y-axis
 accelerationPath(for: \.z, in: size, color: .blue)   // Z-axis
 ```
 - KeyPath: Type-safe property reference
 - Can read different property values at runtime


 🔧 NSOpenPanel Usage Pattern
 ════════════════════════════════════════════════════════════════════════════════

 **macOS native folder selection dialog:**
 ```swift
 private func openFolder() {
 let panel = NSOpenPanel()                        // Create panel
 panel.canChooseFiles = false                     // Cannot choose files
 panel.canChooseDirectories = true                // Can choose folders
 panel.allowsMultipleSelection = false            // Single selection only
 panel.message = "Select a folder containing..."  // Guide message
 panel.prompt = "Select"                          // Button text

 panel.begin { response in                        // Async display
 if response == .OK, let url = panel.url {
 scanAndLoadFolder(url)
 }
 }
 }
 ```

 📌 .begin vs .runModal:
 • .begin: Async, doesn't block UI (recommended)
 • .runModal: Sync, blocks UI until selection complete


 🎮 Usage Examples
 ════════════════════════════════════════════════════════════════════════════════

 ```swift
 // 1. Load test files on app launch
 @State private var videoFiles: [VideoFile] = VideoFile.allTestFiles
 // → Automatically load 7 sample files

 // 2. Open folder
 User: Toolbar > Click "Open Folder"
 → Display NSOpenPanel
 → Select folder (/Users/me/Blackbox)
 → FileScanner operates
 → VideoFile[] creation
 → Display file list in Sidebar

 // 3. Select file
 User: Sidebar > Tap "2024_03_15_14_23_45_F.mp4"
 → selectedVideoFile = file
 → Display detailed info in Main Content
 → Load MultiChannelPlayerView
 → Display GPS map
 → Display acceleration graph

 // 4. Toggle sidebar
 User: Toolbar > Click Sidebar button
 → showSidebar.toggle()
 → Hide/show Sidebar

 // 5. Refresh
 User: Sidebar > Click Refresh button
 → refreshFileList()
 → Re-scan same folder
 → Update file list
 ```


 ═══════════════════════════════════════════════════════════════════════════════
 */

import SwiftUI
import MapKit
import AppKit
import Combine

/// @struct ContentView
/// @brief Main content view for blackbox player
///
/// @details
/// Top-level view of the BlackboxPlayer app providing the following features:
/// - NavigationView-based master-detail layout
/// - Folder scanning and video file loading
/// - Multi-channel video player integration
/// - GPS map and G-sensor graph visualization
/// - Playback controls and timeline slider
///
/// ## Main Features
/// - **NavigationView layout**: Sidebar (file list) + Main content (detailed info)
/// - **Folder scanning**: NSOpenPanel → FileScanner → VideoFileLoader
/// - **Multi-channel player**: Synchronized playback of up to 5 cameras
/// - **GPS map**: MapKit integration, route visualization
/// - **G-sensor graph**: Custom Path Drawing, 3-axis real-time display
/// - **Async processing**: Background scan with DispatchQueue, UI update on main thread
///
/// ## State Management
/// Manages UI state with 15 @State properties:
/// - File-related: selectedVideoFile, videoFiles, currentFolderPath
/// - UI-related: showSidebar, showDebugLog, isLoading, showError
/// - Playback-related: isPlaying, currentPlaybackTime, playbackSpeed, volume
///
/// ## Service Integration
/// - FileScanner: Folder scanning and file group detection
/// - VideoFileLoader: FileGroup → VideoFile conversion
struct ContentView: View {
    // MARK: - State Properties

    /// @var selectedVideoFile
    /// @brief Currently selected video file
    @State private var selectedVideoFile: VideoFile?

    /// @var videoFiles
    /// @brief List of all video files
    @State private var videoFiles: [VideoFile] = []

    /// @var showSidebar
    /// @brief Whether to show sidebar
    @State private var showSidebar = AppSettings.shared.showSidebarByDefault

    /// @var isPlaying
    /// @brief Whether playing (simulation)
    @State private var isPlaying = false

    /// @var currentPlaybackTime
    /// @brief Current playback time (in seconds)
    @State private var currentPlaybackTime: Double = 0.0

    /// @var playbackSpeed
    /// @brief Playback speed (1.0 = normal speed)
    @State private var playbackSpeed: Double = AppSettings.shared.defaultPlaybackSpeed

    /// @var volume
    /// @brief Volume (0.0 ~ 1.0)
    @State private var volume: Double = AppSettings.shared.defaultVolume

    /// @var showControls
    /// @brief Whether to show controls
    @State private var showControls = true

    /// @var currentFolderPath
    /// @brief Currently opened folder path
    @State private var currentFolderPath: String?

    /// @var isLoading
    /// @brief Loading state (during folder scan)
    @State private var isLoading = false

    /// @var showError
    /// @brief Whether to show error alert
    @State private var showError = false

    /// @var errorMessage
    /// @brief Error message content
    @State private var errorMessage = ""

    /// @var showDebugLog
    /// @brief Whether to show debug log
    @State private var showDebugLog = AppSettings.shared.showDebugLogByDefault

    /// @var showAboutWindow
    /// @brief Whether to show About window
    @State private var showAboutWindow = false

    /// @var showHelpWindow
    /// @brief Whether to show Help window
    @State private var showHelpWindow = false

    /// @var showMetadataOverlay
    /// @brief Whether to show metadata overlay
    @State private var showMetadataOverlay = AppSettings.shared.showMetadataOverlayByDefault

    /// @var showMapOverlay
    /// @brief Whether to show map overlay
    @State private var showMapOverlay = AppSettings.shared.showMapOverlayByDefault

    /// @var showGraphOverlay
    /// @brief Whether to show graph overlay
    @State private var showGraphOverlay = AppSettings.shared.showGraphOverlayByDefault

    /// @var showSettings
    /// @brief Whether to show settings window
    @State private var showSettings = false

    // MARK: - Services

    private let fileScanner = FileScanner()
    private let videoFileLoader = VideoFileLoader()

    // MARK: - Body

    var body: some View {
        content
            .notificationHandlers(
                selectedVideoFile: $selectedVideoFile,
                showSidebar: $showSidebar,
                showMetadataOverlay: $showMetadataOverlay,
                showMapOverlay: $showMapOverlay,
                showGraphOverlay: $showGraphOverlay,
                isPlaying: $isPlaying,
                playbackSpeed: $playbackSpeed,
                showAboutWindow: $showAboutWindow,
                showHelpWindow: $showHelpWindow,
                openFolder: openFolder,
                refreshFileList: refreshFileList,
                seekBy: seekBy
            )
    }

    private var content: some View {
        Group {
            if showSidebar {
                NavigationView {
                    // Sidebar: File list
                    sidebar
                        .frame(minWidth: 300, idealWidth: 350, maxWidth: 500)

                    // Main content
                    mainContent
                        .frame(minWidth: 600, minHeight: 400)
                }
            } else {
                // Main content only (full width)
                mainContent
                    .frame(minWidth: 600, minHeight: 400)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle sidebar")

                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open blackbox video folder")
                .disabled(isLoading)

                Button(action: { showDebugLog.toggle() }) {
                    Image(systemName: showDebugLog ? "terminal.fill" : "terminal")
                }
                .help("Toggle debug log")

                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.5)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(.circular)
                        Text("Scanning folder...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
                .ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottom) {
            if showDebugLog {
                DebugLogView()
                    .padding()
                    .transition(.move(edge: .bottom))
            }
        }
        .sheet(isPresented: $showAboutWindow) {
            AboutWindow()
        }
        .sheet(isPresented: $showHelpWindow) {
            HelpWindow()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Text("Video Files")
                        .font(.headline)

                    Spacer()

                    Button(action: refreshFileList) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Refresh file list")
                    .disabled(isLoading || currentFolderPath == nil)
                }
                .padding(.horizontal)
                .padding(.top)

                if let folderPath = currentFolderPath {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                            .font(.caption)
                        Text((folderPath as NSString).lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(videoFiles.count) files")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                } else {
                    Text("No folder selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            }

            Divider()

            // File list
            FileListView(
                videoFiles: $videoFiles,
                selectedFile: $selectedVideoFile
            )
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            if let selectedFile = selectedVideoFile {
                // Selected file info
                fileInfoView(for: selectedFile)
            } else {
                // Empty state
                emptyState
            }
        }
        .background(Color.black)
    }

    // MARK: - File Info View

    private func fileInfoView(for videoFile: VideoFile) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Video thumbnail placeholder
                videoThumbnail(for: videoFile)

                // File information
                fileInformationCard(for: videoFile)

                // Channel information
                channelsCard(for: videoFile)

                // Metadata information
                if showMetadataOverlay && (videoFile.hasGPSData || videoFile.hasAccelerationData) {
                    metadataCard(for: videoFile)
                }

                // GPS Map
                if showMapOverlay && videoFile.hasGPSData {
                    gpsMapCard(for: videoFile)
                }

                // Acceleration Graph
                if showGraphOverlay && videoFile.hasAccelerationData {
                    accelerationGraphCard(for: videoFile)
                }
            }
            .padding()
        }
    }

    private func videoThumbnail(for videoFile: VideoFile) -> some View {
        // Multi-channel video player
        MultiChannelPlayerView(videoFile: videoFile)
            .id("player-\(videoFile.id)")  // Stable ID to prevent recreation on layout changes
            .aspectRatio(16 / 9, contentMode: .fit)
            .cornerRadius(12)
            .shadow(radius: 4)
    }

    private var singleChannelPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.8))

            Text("Video Player")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)

            Text("Implementation pending")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func multiChannelLayout(for videoFile: VideoFile) -> some View {
        GeometryReader { geometry in
            let channels = videoFile.channels.filter(\.isEnabled)
            let layout = calculateChannelLayout(count: channels.count, in: geometry.size)

            ZStack {
                ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                    if index < layout.count {
                        channelPlaceholder(for: channel)
                            .frame(width: layout[index].width, height: layout[index].height)
                            .position(x: layout[index].x, y: layout[index].y)
                    }
                }

                // Play overlay
                VStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.9))

                    Text("\(channels.count) Channels")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                }
            }
        }
    }

    private func channelPlaceholder(for channel: ChannelInfo) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.6))

                Text(channel.position.shortName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }

    private func calculateChannelLayout(count: Int, in size: CGSize) -> [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] {
        var layout: [(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)] = []

        switch count {
        case 1:
            layout.append((x: size.width / 2, y: size.height / 2, width: size.width, height: size.height))

        case 2:
            // Side by side
            let w = size.width / 2
            layout.append((x: w / 2, y: size.height / 2, width: w, height: size.height))
            layout.append((x: w + w / 2, y: size.height / 2, width: w, height: size.height))

        case 3:
            // One large on left, two stacked on right
            let w = size.width * 2 / 3
            let h = size.height / 2
            layout.append((x: w / 2, y: size.height / 2, width: w, height: size.height))
            layout.append((x: w + (size.width - w) / 2, y: h / 2, width: size.width - w, height: h))
            layout.append((x: w + (size.width - w) / 2, y: h + h / 2, width: size.width - w, height: h))

        case 4:
            // 2x2 grid
            let w = size.width / 2
            let h = size.height / 2
            layout.append((x: w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w / 2, y: h + h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h + h / 2, width: w, height: h))

        case 5:
            // 3 on top, 2 on bottom
            let w = size.width / 3
            let h = size.height / 2
            // Top row
            layout.append((x: w / 2, y: h / 2, width: w, height: h))
            layout.append((x: w + w / 2, y: h / 2, width: w, height: h))
            layout.append((x: 2 * w + w / 2, y: h / 2, width: w, height: h))
            // Bottom row
            let bottomW = size.width / 2
            layout.append((x: bottomW / 2, y: h + h / 2, width: bottomW, height: h))
            layout.append((x: bottomW + bottomW / 2, y: h + h / 2, width: bottomW, height: h))

        default:
            // Fallback: single channel
            layout.append((x: size.width / 2, y: size.height / 2, width: size.width, height: size.height))
        }

        return layout
    }

    private func fileInformationCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("File Information")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            InfoRow(label: "Filename", value: videoFile.baseFilename)
            InfoRow(label: "Event Type", value: videoFile.eventType.displayName)
            InfoRow(label: "Timestamp", value: videoFile.timestampString)
            InfoRow(label: "Duration", value: videoFile.durationString)
            InfoRow(label: "File Size", value: videoFile.totalFileSizeString)
            InfoRow(label: "Favorite", value: videoFile.isFavorite ? "Yes" : "No")

            if let notes = videoFile.notes {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes:")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text(notes)
                        .foregroundColor(.white)
                        .font(.body)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func channelsCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Camera Channels (\(videoFile.channelCount))")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            ForEach(videoFile.channels, id: \.id) { channel in
                HStack {
                    Image(systemName: "video.fill")
                        .foregroundColor(channel.isEnabled ? .green : .gray)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(channel.position.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)

                        Text("\(channel.width)x\(channel.height) @ \(Int(channel.frameRate))fps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(channel.codec ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    private func metadataCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
                .foregroundColor(.white)

            Divider()

            if videoFile.hasGPSData {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.green)
                    Text("GPS Data")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.metadata.gpsPoints.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if videoFile.hasAccelerationData {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.blue)
                    Text("G-Sensor Data")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.metadata.accelerationData.count) points")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            if videoFile.hasImpactEvents {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Impact Events")
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(videoFile.impactEventCount)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "video.slash")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Video Selected")
                    .font(.title2)
                    .fontWeight(.medium)

                Text("Select a video from the sidebar to view details")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            Button(action: { showSidebar = true }) {
                Label("Show Sidebar", systemImage: "sidebar.left")
            }
            .buttonStyle(.borderedProminent)
        }
        .foregroundColor(.white)
    }

    // MARK: - GPS Map Card

    private func gpsMapCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(.green)
                Text("GPS Route")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(videoFile.metadata.gpsPoints.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Map view
            GPSMapView(gpsPoints: videoFile.metadata.gpsPoints)
                .frame(height: 300)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Acceleration Graph Card

    private func accelerationGraphCard(for videoFile: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(.blue)
                Text("G-Sensor Data")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Text("\(videoFile.metadata.accelerationData.count) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Graph view
            AccelerationGraphView(accelerationData: videoFile.metadata.accelerationData)
                .frame(height: 200)
                .cornerRadius(8)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Playback Controls

    private func playbackControls(for videoFile: VideoFile) -> some View {
        VStack(spacing: 0) {
            // Timeline
            timelineSlider(for: videoFile)
                .padding(.horizontal)
                .padding(.top, 8)

            // Control buttons
            HStack(spacing: 20) {
                // Play/Pause button
                Button(action: { isPlaying.toggle() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)

                // Seek backward 10s
                Button(action: { seekBy(-10, in: videoFile) }) {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Seek forward 10s
                Button(action: { seekBy(10, in: videoFile) }) {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                // Current time / Duration
                Text(formatTime(currentPlaybackTime) + " / " + videoFile.durationString)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white)

                Spacer()

                // Speed control
                speedControl

                // Volume control
                volumeControl
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func timelineSlider(for videoFile: VideoFile) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 4)

                // Progress
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * (currentPlaybackTime / max(1, videoFile.duration)), height: 4)

                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: geometry.size.width * (currentPlaybackTime / max(1, videoFile.duration)) - 6)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newTime = Double(value.location.x / geometry.size.width) * videoFile.duration
                        currentPlaybackTime = max(0, min(videoFile.duration, newTime))
                    }
            )
        }
        .frame(height: 12)
    }

    private var speedControl: some View {
        Menu {
            ForEach([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                Button(action: { playbackSpeed = speed }) {
                    HStack {
                        Text(formatSpeed(speed))
                        if playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "gauge")
                    .font(.system(size: 14))
                Text(formatSpeed(playbackSpeed))
                    .font(.system(size: 13))
            }
            .foregroundColor(.white)
            .frame(width: 70, height: 28)
            .background(Color.white.opacity(0.2))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
    }

    private var volumeControl: some View {
        HStack(spacing: 8) {
            Button(action: { volume = volume > 0 ? 0 : 0.8 }) {
                Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Slider(value: $volume, in: 0...1)
                .frame(width: 80)
                .accentColor(.white)
        }
    }

    private func seekBy(_ seconds: Double, in videoFile: VideoFile) {
        currentPlaybackTime = max(0, min(videoFile.duration, currentPlaybackTime + seconds))
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatSpeed(_ speed: Double) -> String {
        return String(format: "%.2gx", speed)
    }

    // MARK: - Actions

    /// @brief Open folder selection dialog
    ///
    /// @details
    /// Use NSOpenPanel to select a folder containing blackbox video files.
    /// After folder selection, calls scanAndLoadFolder() method to load files.
    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing blackbox video files"
        panel.prompt = "Select"

        panel.begin { response in
            if response == .OK, let url = panel.url {
                scanAndLoadFolder(url)
            }
        }
    }

    /// @brief Scan folder and load video files
    ///
    /// @param folderURL URL of folder to scan
    ///
    /// @details
    /// Scan folder with FileScanner on background thread,
    /// load files with VideoFileLoader, then update UI on main thread.
    private func scanAndLoadFolder(_ folderURL: URL) {
        isLoading = true
        selectedVideoFile = nil

        // Perform scanning on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Scan directory
                let groups = try fileScanner.scanDirectory(folderURL)

                // Load video files
                let loadedFiles = videoFileLoader.loadVideoFiles(from: groups)

                // Update UI on main thread
                DispatchQueue.main.async {
                    self.currentFolderPath = folderURL.path
                    self.videoFiles = loadedFiles
                    self.isLoading = false

                    // Select first file if available
                    if let firstFile = loadedFiles.first {
                        self.selectedVideoFile = firstFile
                    }
                }
            } catch {
                // Handle error on main thread
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to scan folder: \(error.localizedDescription)"
                    self.showError = true
                }
            }
        }
    }

    /// @brief Refresh file list from current folder
    ///
    /// @details
    /// If currentFolderPath is set, re-scan that folder.
    private func refreshFileList() {
        guard let folderPath = currentFolderPath else {
            // No folder selected, do nothing
            return
        }

        let folderURL = URL(fileURLWithPath: folderPath)
        scanAndLoadFolder(folderURL)
    }
}

// MARK: - Helper Views

/// @struct InfoRow
/// @brief Information row display component
///
/// @details
/// Simple information row displaying label and value side by side.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.body)
        }
    }
}

// MARK: - GPS Map View

/// @struct GPSMapView
/// @brief GPS route map display view
///
/// @details
/// Integrates MapKit's MKMapView into SwiftUI using NSViewRepresentable.
/// Displays GPS points as polyline and adds markers to start/end points.
struct GPSMapView: NSViewRepresentable {
    let gpsPoints: [GPSPoint]

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.mapType = .standard
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Remove existing overlays
        mapView.removeOverlays(mapView.overlays)

        guard !gpsPoints.isEmpty else { return }

        // Create coordinates array
        let coordinates = gpsPoints.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        // Add polyline
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        mapView.addOverlay(polyline)
        mapView.delegate = context.coordinator

        // Set region to show all points
        if let firstPoint = coordinates.first {
            let region = MKCoordinateRegion(
                center: firstPoint,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: false)
        }

        // Add pins for start and end
        if let start = coordinates.first {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = start
            startAnnotation.title = "Start"
            mapView.addAnnotation(startAnnotation)
        }

        if let end = coordinates.last, coordinates.count > 1 {
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = end
            endAnnotation.title = "End"
            mapView.addAnnotation(endAnnotation)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = NSColor.systemBlue
                renderer.lineWidth = 3
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Acceleration Graph View

/// @struct AccelerationGraphView
/// @brief Acceleration sensor data graph view
///
/// @details
/// Displays 3-axis (X, Y, Z) acceleration data in real-time as a graph.
/// Implemented with custom drawing using Path.
struct AccelerationGraphView: View {
    let accelerationData: [AccelerationData]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.black.opacity(0.3)

                // Grid lines
                gridLines(in: geometry.size)

                // Acceleration curves
                accelerationCurves(in: geometry.size)

                // Legend
                legend
                    .position(x: geometry.size.width - 60, y: 30)
            }
        }
    }

    private func gridLines(in size: CGSize) -> some View {
        Path { path in
            // Horizontal lines
            for i in 0...4 {
                let y = size.height * CGFloat(i) / 4
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }

            // Vertical lines
            for i in 0...4 {
                let x = size.width * CGFloat(i) / 4
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
        }
        .stroke(Color.white.opacity(0.1), lineWidth: 1)
    }

    private func accelerationCurves(in size: CGSize) -> some View {
        ZStack {
            // X axis (red)
            accelerationPath(for: \.x, in: size, color: .red)

            // Y axis (green)
            accelerationPath(for: \.y, in: size, color: .green)

            // Z axis (blue)
            accelerationPath(for: \.z, in: size, color: .blue)
        }
    }

    private func accelerationPath(for keyPath: KeyPath<AccelerationData, Double>, in size: CGSize, color: Color) -> some View {
        Path { path in
            guard !accelerationData.isEmpty else { return }

            let maxValue: Double = 2.0 // ±2G range
            let points = accelerationData.enumerated().map { index, data in
                let x = size.width * CGFloat(index) / CGFloat(max(1, accelerationData.count - 1))
                let value = data[keyPath: keyPath]
                let normalizedValue = (value + maxValue) / (2 * maxValue) // Normalize to 0-1
                let y = size.height * (1 - CGFloat(normalizedValue))
                return CGPoint(x: x, y: y)
            }

            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
        }
        .stroke(color, lineWidth: 2)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                Text("X")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Y")
                    .font(.caption2)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("Z")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
}

// MARK: - About Window

/// @struct AboutWindow
/// @brief About window view
///
/// @details
/// About window displaying app information, version, and copyright.
struct AboutWindow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            // App Name
            Text("Blackbox Player")
                .font(.title)
                .fontWeight(.bold)

            // Version
            Text("Version 1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 40)

            // Description
            VStack(spacing: 8) {
                Text("Multi-channel blackbox video player")
                    .font(.body)
                Text("with GPS and G-sensor visualization")
                    .font(.body)
            }
            .foregroundColor(.secondary)

            // Copyright
            Text("© 2024 BlackboxPlayer Development Team")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)

            // Close Button
            Button("OK") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(40)
        .frame(width: 400)
    }
}

// MARK: - Help Window

/// @struct HelpWindow
/// @brief Help window view
///
/// @details
/// Help window displaying app usage and keyboard shortcuts.
struct HelpWindow: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text("Help")
                    .font(.title)
                    .fontWeight(.bold)
            }

            Divider()

            // Usage
            VStack(alignment: .leading, spacing: 12) {
                Text("Usage")
                    .font(.headline)

                helpItem(title: "Opening Files", description: "Use File > Open Folder to select a folder containing blackbox video files")
                helpItem(title: "Playing Videos", description: "Select a file from the sidebar to view and play")
                helpItem(title: "Navigation", description: "Use playback controls or keyboard shortcuts")
            }

            Divider()

            // Keyboard Shortcuts
            VStack(alignment: .leading, spacing: 12) {
                Text("Keyboard Shortcuts")
                    .font(.headline)

                shortcutItem(key: "Space", action: "Play/Pause")
                shortcutItem(key: "→", action: "Step Forward (5s)")
                shortcutItem(key: "←", action: "Step Backward (5s)")
                shortcutItem(key: "⌘+O", action: "Open Folder")
                shortcutItem(key: "⌘+R", action: "Refresh File List")
                shortcutItem(key: "⌘+B", action: "Toggle Sidebar")
            }

            Spacer()

            // Close Button
            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 500, height: 600)
    }

    private func helpItem(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func shortcutItem(key: String, action: String) -> some View {
        HStack {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
            Text(action)
                .font(.body)
            Spacer()
        }
    }
}

// MARK: - View Extensions

extension View {
    /// @brief Notification handlers view modifier
    ///
    /// @details
    /// Attaches all NotificationCenter handlers to the view.
    /// This extension helps reduce type-checking complexity in ContentView.body.
    func notificationHandlers(
        selectedVideoFile: Binding<VideoFile?>,
        showSidebar: Binding<Bool>,
        showMetadataOverlay: Binding<Bool>,
        showMapOverlay: Binding<Bool>,
        showGraphOverlay: Binding<Bool>,
        isPlaying: Binding<Bool>,
        playbackSpeed: Binding<Double>,
        showAboutWindow: Binding<Bool>,
        showHelpWindow: Binding<Bool>,
        openFolder: @escaping () -> Void,
        refreshFileList: @escaping () -> Void,
        seekBy: @escaping (Double, VideoFile) -> Void
    ) -> some View {
        self
            .onReceive(NotificationCenter.default.publisher(for: .openFolderRequested)) { _ in
                openFolder()
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshFileListRequested)) { _ in
                refreshFileList()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarRequested)) { _ in
                showSidebar.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleMetadataOverlayRequested)) { _ in
                showMetadataOverlay.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleMapOverlayRequested)) { _ in
                showMapOverlay.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleGraphOverlayRequested)) { _ in
                showGraphOverlay.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .playPauseRequested)) { _ in
                isPlaying.wrappedValue.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .stepForwardRequested)) { _ in
                guard let videoFile = selectedVideoFile.wrappedValue else { return }
                seekBy(5, videoFile)
            }
            .onReceive(NotificationCenter.default.publisher(for: .stepBackwardRequested)) { _ in
                guard let videoFile = selectedVideoFile.wrappedValue else { return }
                seekBy(-5, videoFile)
            }
            .onReceive(NotificationCenter.default.publisher(for: .increaseSpeedRequested)) { _ in
                let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0]
                if let currentIndex = speeds.firstIndex(of: playbackSpeed.wrappedValue),
                   currentIndex < speeds.count - 1 {
                    playbackSpeed.wrappedValue = speeds[currentIndex + 1]
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .decreaseSpeedRequested)) { _ in
                let speeds: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 4.0]
                if let currentIndex = speeds.firstIndex(of: playbackSpeed.wrappedValue),
                   currentIndex > 0 {
                    playbackSpeed.wrappedValue = speeds[currentIndex - 1]
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .normalSpeedRequested)) { _ in
                playbackSpeed.wrappedValue = 1.0
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAboutRequested)) { _ in
                showAboutWindow.wrappedValue = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showHelpRequested)) { _ in
                showHelpWindow.wrappedValue = true
            }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}
