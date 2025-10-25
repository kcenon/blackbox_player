/// @file FileListView.swift
/// @brief Dashcam video file list display and management View
/// @author BlackboxPlayer Development Team
/// @details
/// Main list View that displays dashcam video file list and provides search/filtering/selection functionality.
///
/// ## Key Features
/// - **Search**: Real-time search by filename and timestamp (case-insensitive)
/// - **Event Filter**: Filtering by event type such as Normal, Parking, Event
/// - **Sorting**: Automatic sorting by newest first (timestamp descending)
/// - **Selection**: Two-way binding to parent View when file is selected
/// - **Status Display**: Filter results summary with "X of Y videos" counter
///
/// ## Layout Structure
/// ```
/// ┌──────────────────────────────────┐
/// │  🔍 [Search videos...]      [X]  │ ← Search bar (searchText)
/// ├──────────────────────────────────┤
/// │  [All] [Normal] [Parking] [Event]│ ← Filter buttons (horizontal scroll)
/// ├──────────────────────────────────┤
/// │  ┌────────────────────────────┐  │
/// │  │ 📹 File1  2024-01-15 14:30 │  │ ← FileRow (selectable)
/// │  ├────────────────────────────┤  │
/// │  │ 📹 File2  2024-01-15 13:15 │  │
/// │  ├────────────────────────────┤  │
/// │  │ 📹 File3  2024-01-15 12:00 │  │
/// │  └────────────────────────────┘  │
/// ├──────────────────────────────────┤
/// │  3 of 100 videos                 │ ← Status bar
/// └──────────────────────────────────┘
/// ```
///
/// ## SwiftUI Core Concepts
/// ### 1. Data Synchronization with Parent View using @Binding
/// @Binding references the parent View's @State to synchronize data bidirectionally.
///
/// **How it works:**
/// ```
/// Parent View (ContentView)        Child View (FileListView)
/// ┌──────────────────────┐         ┌──────────────────────┐
/// │ @State var files = []│────────>│ @Binding var files   │
/// │ @State var selected  │<────────│ @Binding var selected│
/// └──────────────────────┘         └──────────────────────┘
///         ↓                                    ↓
///   Owns original data                  Only holds reference
///   (Source of Truth)                   (Read/Write enabled)
/// ```
///
/// **Usage Example:**
/// ```swift
/// // Parent View
/// struct ParentView: View {
///     @State private var files: [VideoFile] = []
///     @State private var selected: VideoFile?
///
///     var body: some View {
///         FileListView(videoFiles: $files,     // Pass Binding with $
///                      selectedFile: $selected)
///     }
/// }
///
/// // Child View
/// struct FileListView: View {
///     @Binding var videoFiles: [VideoFile]    // References parent's files
///     @Binding var selectedFile: VideoFile?   // References parent's selected
///
///     var body: some View {
///         // Changing selectedFile automatically updates parent's selected
///         List(videoFiles, selection: $selectedFile) { ... }
///     }
/// }
/// ```
///
/// ### 2. Real-time Filtering with Computed Property
/// Computed Property is automatically recalculated whenever its dependent @State values change.
///
/// **When filteredFiles is recalculated:**
/// ```
/// searchText changes ──┐
///                      ├──> filteredFiles recalculated ──> body re-rendered
/// selectedEventType ───┘
/// ```
///
/// **Calculation Flow:**
/// ```swift
/// // 1. searchText = "2024"
/// videoFiles: [File1, File2, File3, File4] (100 files)
///      ↓ filter { baseFilename.contains("2024") }
/// files: [File1, File3, File4] (50 files)
///
/// // 2. selectedEventType = .event
/// files: [File1, File3, File4] (50 files)
///      ↓ filter { eventType == .event }
/// files: [File3] (5 files)
///
/// // 3. sorted { timestamp > ... }
/// files: [File3] (sorted by newest)
///      ↓
/// return [File3] ──> Displayed in List
/// ```
///
/// ### 3. List Selection Binding
/// Passing @Binding to List's selection parameter automatically synchronizes the selected item.
///
/// **How it works:**
/// ```swift
/// List(filteredFiles, selection: $selectedFile) { file in
///     FileRow(videoFile: file)
///         .tag(file)  // Specify value to return when selected via tag()
/// }
/// ```
///
/// **Selection Flow:**
/// ```
/// 1. User clicks FileRow
///      ↓
/// 2. Get VideoFile object specified in .tag(file)
///      ↓
/// 3. Assign to $selectedFile (Binding updated)
///      ↓
/// 4. Parent View's @State selected also automatically updated
///      ↓
/// 5. Parent View starts playing video with selected file
/// ```
///
/// ### 4. Conditional View Rendering
/// Use if-else to render different Views and switch UI based on state.
///
/// **Example:**
/// ```swift
/// if filteredFiles.isEmpty {
///     EmptyStateView()        // When no search results
/// } else {
///     List(filteredFiles) { ... }  // When search results exist
/// }
/// ```
///
/// **Transition Flow:**
/// ```
/// searchText = "nonexistentword"
///      ↓
/// filteredFiles.isEmpty == true
///      ↓
/// List disappears ──> EmptyStateView displayed
///      ↓
/// searchText = "" (reset)
///      ↓
/// filteredFiles.isEmpty == false
///      ↓
/// EmptyStateView disappears ──> List displayed
/// ```
///
/// ## Usage Examples
/// ```swift
/// // 1. Using FileListView in ContentView
/// struct ContentView: View {
///     @State private var files: [VideoFile] = []
///     @State private var selectedFile: VideoFile?
///
///     var body: some View {
///         HSplitView {
///             // Left: File list
///             FileListView(videoFiles: $files,
///                          selectedFile: $selectedFile)
///                 .frame(minWidth: 300)
///
///             // Right: Play selected file
///             if let file = selectedFile {
///                 VideoPlayerView(videoFile: file)
///             }
///         }
///     }
/// }
///
/// // 2. Using search feature
/// // Enter searchText = "2024-01-15"
/// //   → Display only files with "2024-01-15" in baseFilename
///
/// // 3. Using filter feature
/// // Click [Event] button
/// //   → selectedEventType = .event
/// //   → Display only files where eventType == .event
///
/// // 4. Selecting a file
/// // Click FileRow
/// //   → selectedFile = clicked VideoFile object
/// //   → ContentView's selectedFile also automatically updated
/// //   → VideoPlayerView starts playing the selected file
/// ```
///
/// ## Real-World Usage Scenarios
/// **Scenario 1: Search for videos on specific date**
/// ```
/// 1. Enter "2024-01-15" in search bar
///      ↓
/// 2. filteredFiles automatically recalculated
///      ↓ baseFilename.contains("2024-01-15")
/// 3. Display only 10 files from that date in list
///      ↓
/// 4. Status bar shows "10 of 100 videos"
/// ```
///
/// **Scenario 2: Filter only event videos**
/// ```
/// 1. Click [Event] filter button
///      ↓
/// 2. Set selectedEventType = .event
///      ↓
/// 3. filteredFiles automatically recalculated
///      ↓ eventType == .event
/// 4. Display only 5 event videos in list
///      ↓
/// 5. Status bar shows "5 of 100 videos"
/// ```
///
/// **Scenario 3: Combine search + filter**
/// ```
/// 1. Enter "2024-01" in search bar
///      ↓ baseFilename.contains("2024-01")
/// 2. Filtered to 30 January videos
///      ↓
/// 3. Click [Parking] filter button
///      ↓ eventType == .parking
/// 4. Display only 3 January + Parking videos
///      ↓
/// 5. Status bar shows "3 of 100 videos"
/// ```
//
//  FileListView.swift
//  BlackboxPlayer
//
//  Main view for displaying list of dashcam video files
//

import SwiftUI

/// @struct FileListView
/// @brief Dashcam video file list display and management View
///
/// @details
/// Main View that displays dashcam video file list and provides search/filtering functionality.
/// Supports search, event type filtering, sorting, and connects with parent View via two-way binding.
struct FileListView: View {
    /// @var videoFiles
    /// @brief Video file array received from parent View (two-way binding)
    ///
    /// ## Why @Binding is needed
    /// - Parent View (ContentView) owns the original file list data
    /// - FileListView only reads and displays this data
    /// - However, @Binding is used to notify parent when sorting or updating
    ///
    /// **Example:**
    /// ```swift
    /// // ContentView (parent)
    /// @State private var files: [VideoFile] = loadFiles()
    ///
    /// // FileListView (child)
    /// FileListView(videoFiles: $files, ...)  // Pass Binding with $
    /// ```
    @Binding var videoFiles: [VideoFile]

    /// @var selectedFile
    /// @brief Currently selected video file (two-way binding)
    ///
    /// ## Selection Synchronization Behavior
    /// 1. User clicks file in List
    ///      ↓
    /// 2. Assign corresponding VideoFile to selectedFile
    ///      ↓
    /// 3. Parent View's @State also automatically updated via @Binding
    ///      ↓
    /// 4. Parent View updates VideoPlayerView with selected file
    ///
    /// **Example:**
    /// ```swift
    /// // Before file selection
    /// selectedFile = nil
    ///
    /// // Click File1 in List
    /// selectedFile = File1
    ///
    /// // Parent View also automatically updated
    /// ContentView.selectedFile = File1  // Reflected in VideoPlayerView
    /// ```
    @Binding var selectedFile: VideoFile?

    /// @var searchText
    /// @brief Search field input text (local state)
    ///
    /// ## @State vs @Binding Selection Criteria
    /// - searchText is only used inside FileListView → use @State
    /// - Parent View doesn't need to know the search term
    /// - Two-way binding with TextField enables real-time search
    ///
    /// **How it works:**
    /// ```swift
    /// // User enters "2024"
    /// searchText = "2024"
    ///      ↓ Two-way binding via TextField($searchText)
    /// TextField displays "2024"
    ///      ↓ searchText changes → filteredFiles recalculated
    /// List automatically updates with filtered files
    /// ```
    @State private var searchText = ""

    /// @var selectedEventType
    /// @brief Selected event type filter (local state)
    ///
    /// ## Why Optional Type
    /// - nil: "All" filter (display all event types)
    /// - .normal: Display only Normal events
    /// - .parking: Display only Parking events
    /// - .event: Display only Event events
    ///
    /// **Example:**
    /// ```swift
    /// // Initial state: display all types
    /// selectedEventType = nil
    ///
    /// // Click [Event] button
    /// selectedEventType = .event
    ///      ↓
    /// filteredFiles filters only files where eventType == .event
    /// ```
    @State private var selectedEventType: EventType?

    /// File array filtered by search term and event type (Computed Property)
    ///
    /// ## What is Computed Property?
    /// - Property calculated each time without storing (no storage space)
    /// - Automatically recalculated when dependent values (searchText, selectedEventType, videoFiles) change
    /// - SwiftUI automatically detects changes and re-renders body
    ///
    /// ## Filtering Algorithm Steps
    /// ```
    /// 1. Copy videoFiles
    ///      ↓
    /// 2. Filter by searchText (filename + timestamp)
    ///      ↓
    /// 3. Filter by selectedEventType (event type)
    ///      ↓
    /// 4. Sort by timestamp descending (newest first)
    ///      ↓
    /// 5. return sorted array
    /// ```
    ///
    /// ## Filtering Examples
    /// **Initial State:**
    /// ```swift
    /// videoFiles = [File1(normal), File2(event), File3(parking), File4(event)]
    /// searchText = ""
    /// selectedEventType = nil
    ///      ↓
    /// filteredFiles = [File4, File3, File2, File1] (sorted by newest)
    /// ```
    ///
    /// **After Search:**
    /// ```swift
    /// searchText = "2024-01-15"
    ///      ↓ filter { baseFilename.contains("2024-01-15") }
    /// filteredFiles = [File2, File1] (only files containing 2024-01-15)
    /// ```
    ///
    /// **After Filter:**
    /// ```swift
    /// selectedEventType = .event
    ///      ↓ filter { eventType == .event }
    /// filteredFiles = [File2] (only event type)
    /// ```
    ///
    /// ## Performance Optimization
    /// - Computed Property is calculated each time it's accessed
    /// - Multiple accesses in body result in multiple calculations
    /// - However, SwiftUI's View updates are efficiently optimized
    /// - Can cache with @State if needed:
    ///   ```swift
    ///   @State private var cachedFilteredFiles: [VideoFile] = []
    ///   .onChange(of: searchText) { cachedFilteredFiles = calculateFiltered() }
    ///   ```
    private var filteredFiles: [VideoFile] {
        /// Step 1: Start by copying videoFiles array
        var files = videoFiles

        /// Step 2: Filter by search term
        ///
        /// ## What is localizedCaseInsensitiveContains?
        /// - Check if string contains substring without case sensitivity
        /// - Considers locale (language) settings for comparison (supports Korean, Japanese, etc.)
        ///
        /// **Comparison Examples:**
        /// ```swift
        /// "ABC".contains("abc")                           // false (case-sensitive)
        /// "ABC".localizedCaseInsensitiveContains("abc")  // true  (case-insensitive)
        ///
        /// "Hello".contains("lo")                          // true
        /// "Hello".localizedCaseInsensitiveContains("LO") // true
        /// ```
        ///
        /// ## Filtering Conditions
        /// - baseFilename contains search term OR
        /// - timestampString contains search term
        ///
        /// **Example:**
        /// ```swift
        /// searchText = "2024"
        ///
        /// File1: baseFilename = "2024-01-15_14-30.mp4"  → included ✅
        /// File2: baseFilename = "video.mp4", timestampString = "2024-01-15" → included ✅
        /// File3: baseFilename = "old_video.mp4", timestampString = "2023-12-01" → excluded ❌
        /// ```
        if !searchText.isEmpty {
            files = files.filter { file in
                file.baseFilename.localizedCaseInsensitiveContains(searchText) ||
                    file.timestampString.localizedCaseInsensitiveContains(searchText)
            }
        }

        /// Step 3: Filter by event type
        ///
        /// ## Safe Handling with Optional Binding
        /// ```swift
        /// if let eventType = selectedEventType {
        ///     // Only executes when selectedEventType is not nil
        ///     // Unwrapped value assigned to eventType variable
        /// }
        /// ```
        ///
        /// **Example:**
        /// ```swift
        /// selectedEventType = nil          → This block not executed (all files kept)
        /// selectedEventType = .event       → Only files where eventType == .event kept
        ///
        /// Before filtering: [File1(normal), File2(event), File3(parking)]
        ///      ↓
        /// After filtering: [File2(event)]
        /// ```
        if let eventType = selectedEventType {
            files = files.filter { $0.eventType == eventType }
        }

        /// Step 4: Sort by timestamp descending (newest first)
        ///
        /// ## sorted Method
        /// - Specify sorting criteria with closure
        /// - { $0.timestamp > $1.timestamp }: Larger timestamp goes first
        /// - Original array unchanged, returns new array
        ///
        /// **Sorting Example:**
        /// ```swift
        /// // Before sorting
        /// files = [
        ///     VideoFile(timestamp: Date("2024-01-15 14:30")),
        ///     VideoFile(timestamp: Date("2024-01-15 12:00")),
        ///     VideoFile(timestamp: Date("2024-01-15 16:45"))
        /// ]
        ///
        /// // sorted { $0.timestamp > $1.timestamp }
        /// //     ↓
        /// // 16:45 > 14:30? → 16:45 goes first
        /// // 14:30 > 12:00? → 14:30 goes first
        ///
        /// // After sorting (newest first)
        /// files = [
        ///     VideoFile(timestamp: Date("2024-01-15 16:45")),  // 1st
        ///     VideoFile(timestamp: Date("2024-01-15 14:30")),  // 2nd
        ///     VideoFile(timestamp: Date("2024-01-15 12:00"))   // 3rd
        /// ]
        /// ```
        ///
        /// ## Other Sorting Examples
        /// ```swift
        /// // Oldest first (ascending)
        /// files.sorted { $0.timestamp < $1.timestamp }
        ///
        /// // Alphabetical by filename
        /// files.sorted { $0.baseFilename < $1.baseFilename }
        ///
        /// // Largest file size first
        /// files.sorted { $0.totalFileSize > $1.totalFileSize }
        /// ```
        return files.sorted { $0.timestamp > $1.timestamp }
    }

    /// FileListView's Main Layout
    ///
    /// ## VStack(spacing: 0) Structure
    /// Set spacing: 0 to remove default spacing between components.
    /// Each component manages its own padding for more precise layout control.
    ///
    /// **Layout Components:**
    /// ```
    /// ┌────────────────────────┐
    /// │  Search bar            │ ← HStack (TextField + button)
    /// ├────────────────────────┤
    /// │  Filter buttons (horiz)│ ← ScrollView(.horizontal)
    /// ├────────────────────────┤ ← Divider()
    /// │                        │
    /// │   File list            │ ← List or EmptyStateView
    /// │                        │
    /// ├────────────────────────┤ ← Divider()
    /// │  Status bar            │ ← StatusBar
    /// └────────────────────────┘
    /// ```
    var body: some View {
        VStack(spacing: 0) {
            /// Search bar
            ///
            /// ## HStack Layout
            /// [🔍] [        Search videos...        ] [(X)]
            ///  ↑              ↑                        ↑
            /// Icon         TextField                Clear button
            ///
            /// ## Conditional Button Rendering
            /// - Display Clear button only when searchText.isEmpty == false
            /// - Reset searchText = "" when button clicked
            ///
            /// **Action Flow:**
            /// ```
            /// 1. User enters "2024"
            ///      ↓
            /// 2. searchText = "2024"
            ///      ↓ Two-way binding via TextField($searchText)
            /// 3. TextField displays "2024"
            ///      ↓ searchText change detected
            /// 4. filteredFiles automatically recalculated
            ///      ↓
            /// 5. List updated (display only filtered files)
            ///      ↓
            /// 6. [X] button appears (!searchText.isEmpty)
            ///      ↓ Button clicked
            /// 7. searchText = "" reset
            ///      ↓
            /// 8. filteredFiles recalculated (display all files)
            ///      ↓
            /// 9. [X] button disappears
            /// ```
            HStack {
                /// Search icon
                ///
                /// ## SF Symbols
                /// - "magnifyingglass": Default icon provided by macOS/iOS
                /// - .foregroundColor(.secondary): Gray color (follows system theme)
                ///
                /// **Color Examples:**
                /// ```swift
                /// .foregroundColor(.primary)    // Default text color (black/white)
                /// .foregroundColor(.secondary)  // Secondary text color (gray)
                /// .foregroundColor(.blue)       // Blue
                /// ```
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                /// Search input field
                ///
                /// ## TextField Parameters
                /// - "Search videos...": placeholder text (displayed before input)
                /// - text: $searchText: Two-way binding ($ converts to Binding)
                ///
                /// ## .textFieldStyle(.plain)
                /// - Remove macOS default TextField style (remove border, background)
                /// - Use with custom background (.background) for consistent design
                ///
                /// **TextField Binding Behavior:**
                /// ```swift
                /// // User enters "A"
                /// TextField internal: displays "A"
                ///      ↓
                /// searchText = "A" updated
                ///      ↓
                /// SwiftUI detects change
                ///      ↓
                /// body re-executed → filteredFiles recalculated
                ///      ↓
                /// List updated
                /// ```
                TextField("Search videos...", text: $searchText)
                    .textFieldStyle(.plain)

                /// Clear button (conditional rendering)
                ///
                /// ## if Conditional View
                /// - Display button only when searchText is not empty
                /// - Reset searchText when button clicked
                ///
                /// **Conditional Rendering Behavior:**
                /// ```swift
                /// searchText = ""     → if false → no button
                /// searchText = "abc"  → if true  → button displayed
                /// Button clicked      → searchText = "" → button disappears
                /// ```
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)  // Remove default button style
                }
            }
            .padding(8)  // HStack internal padding
            .background(Color(nsColor: .controlBackgroundColor))  // macOS system background color
            .cornerRadius(6)  // Round corners
            .padding()  // HStack external padding

            /// Event type filter buttons
            ///
            /// ## ScrollView(.horizontal)
            /// - Enables horizontal scrolling
            /// - showsIndicators: false hides scrollbar
            /// - All filter buttons accessible via horizontal scroll even if many
            ///
            /// ## HStack Layout
            /// ```
            /// [All] [Normal] [Parking] [Event] ...
            ///   ↑      ↑        ↑        ↑
            /// Selected Unsel   Unsel    Unsel
            /// ```
            ///
            /// **Scroll Behavior:**
            /// ```
            /// Screen width: 400px
            /// 4 buttons width: 500px
            ///      ↓
            /// Horizontal scroll automatically enabled
            ///
            /// [All] [Normal] [Parking] [Ev...] →
            ///                            Scroll →
            /// ```
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    /// "All" filter button
                    ///
                    /// ## isSelected Condition
                    /// - selectedEventType == nil: Display all event types
                    /// - Reset selectedEventType = nil when button clicked
                    ///
                    /// **Selection State Change:**
                    /// ```swift
                    /// // Initial state
                    /// selectedEventType = nil
                    /// isSelected = true (All button selected)
                    ///
                    /// // [Event] button clicked
                    /// selectedEventType = .event
                    /// isSelected = false (All button deselected)
                    ///
                    /// // [All] button clicked
                    /// selectedEventType = nil
                    /// isSelected = true (All button selected again)
                    /// ```
                    FilterButton(
                        title: "All",
                        isSelected: selectedEventType == nil,
                        action: { selectedEventType = nil }
                    )

                    /// Filter button for each event type
                    ///
                    /// ## Dynamic Button Generation with ForEach
                    /// - EventType.allCases: [.normal, .parking, .event, ...]
                    /// - id: \.self: Use each EventType as unique identifier
                    ///
                    /// ## Button Properties
                    /// - title: eventType.displayName (e.g., "Normal", "Parking")
                    /// - color: Color for each event type (converted from hex code)
                    /// - isSelected: Check if currently selected type
                    /// - action: Update selectedEventType when button clicked
                    ///
                    /// **ForEach Generation Example:**
                    /// ```swift
                    /// EventType.allCases = [.normal, .parking, .event]
                    ///
                    /// // Views created by ForEach
                    /// FilterButton(title: "Normal", color: .green, isSelected: false, ...)
                    /// FilterButton(title: "Parking", color: .blue, isSelected: false, ...)
                    /// FilterButton(title: "Event", color: .red, isSelected: false, ...)
                    /// ```
                    ///
                    /// **Button Click Flow:**
                    /// ```
                    /// 1. [Event] button clicked
                    ///      ↓
                    /// 2. action: { selectedEventType = .event } executed
                    ///      ↓
                    /// 3. selectedEventType = .event assigned
                    ///      ↓
                    /// 4. SwiftUI detects change
                    ///      ↓
                    /// 5. body re-executed → filteredFiles recalculated
                    ///      ↓
                    /// 6. [Event] button style changed to isSelected = true
                    ///      ↓
                    /// 7. Display only event type files in List
                    /// ```
                    ForEach(EventType.allCases, id: \.self) { eventType in
                        FilterButton(
                            title: eventType.displayName,
                            color: Color(hex: eventType.colorHex),
                            isSelected: selectedEventType == eventType,
                            action: { selectedEventType = eventType }
                        )
                    }
                }
                .padding(.horizontal)  // HStack left/right padding
            }
            .padding(.bottom, 8)  // ScrollView bottom padding

            /// Divider
            ///
            /// ## Divider()
            /// - Separate UI areas with horizontal line
            /// - Color automatically adjusted according to system theme
            Divider()

            /// File list or empty state View
            ///
            /// ## Conditional View Rendering
            /// - filteredFiles.isEmpty: Display EmptyStateView when no filtering results
            /// - Otherwise: Display file list with List
            ///
            /// **Rendering Flow:**
            /// ```
            /// // Initial state (100 files)
            /// filteredFiles = [File1, File2, ..., File100]
            /// isEmpty = false → List rendered
            ///
            /// // Search input: "nonexistentfile"
            /// filteredFiles = []
            /// isEmpty = true → EmptyStateView rendered
            ///
            /// // Reset search
            /// filteredFiles = [File1, File2, ..., File100]
            /// isEmpty = false → List rendered
            /// ```
            if filteredFiles.isEmpty {
                /// Empty state View
                ///
                /// ## When EmptyStateView is Displayed
                /// - No search results
                /// - No filtering results
                /// - Original videoFiles array is empty
                ///
                /// **Display Content:**
                /// - 🎥 Icon (video.slash)
                /// - "No Videos Found" message
                /// - "Try adjusting your search or filters" guidance
                EmptyStateView()
            } else {
                /// File list
                ///
                /// ## List(_, selection:)
                /// - filteredFiles: Data array to display
                /// - selection: $selectedFile: Two-way binding of selected item
                ///
                /// ## selection Binding Behavior
                /// ```
                /// 1. User clicks FileRow
                ///      ↓
                /// 2. Get VideoFile specified in .tag(file)
                ///      ↓
                /// 3. Assign to $selectedFile
                ///      ↓
                /// 4. Parent View's @State also updated via @Binding
                ///      ↓
                /// 5. Parent View detects selectedFile → VideoPlayerView updated
                /// ```
                ///
                /// ## .tag() modifier
                /// - Specify unique value for each List item
                /// - This value is used when binding to selection
                ///
                /// **tag Behavior Example:**
                /// ```swift
                /// List([File1, File2, File3], selection: $selectedFile) { file in
                ///     Text(file.name).tag(file)
                ///     //              ↑ Assign file object to selectedFile when clicked
                /// }
                ///
                /// // Click File2
                /// selectedFile = File2  // Value from .tag(File2) is assigned
                /// ```
                ///
                /// ## .listRowInsets
                /// - Customize internal padding of each List row
                /// - EdgeInsets(top:, leading:, bottom:, trailing:)
                ///
                /// **Padding Example:**
                /// ```
                /// Default padding:
                /// ┌────────────────────────┐
                /// │  [     FileRow      ]  │ ← top: 8, leading: 16
                /// └────────────────────────┘
                ///
                /// Custom padding (top: 4, leading: 8, bottom: 4, trailing: 8):
                /// ┌────────────────────────┐
                /// │ [      FileRow      ]  │ ← Reduced padding
                /// └────────────────────────┘
                /// ```
                ///
                /// ## .listStyle(.plain)
                /// - Remove List default style (background, dividers, etc.)
                /// - FileRow can fully control its own style
                List(filteredFiles, selection: $selectedFile) { file in
                    FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
                        .tag(file)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                }
                .listStyle(.plain)
            }

            /// Divider
            Divider()

            /// Status bar
            ///
            /// ## StatusBar Display Content
            /// - fileCount: filteredFiles.count (file count after filtering)
            /// - totalCount: videoFiles.count (total file count)
            ///
            /// **Display Examples:**
            /// ```
            /// // Initial state
            /// "100 of 100 videos"
            ///
            /// // After search
            /// "10 of 100 videos"
            ///
            /// // After filter
            /// "5 of 100 videos"
            /// ```
            StatusBar(fileCount: filteredFiles.count, totalCount: videoFiles.count)
        }
    }
}

// MARK: - Filter Button

/// @struct FilterButton
/// @brief Event type filter toggle button component
///
/// @details
/// Toggle button for event type filtering.
/// Background color and font weight change according to selection state.
///
/// ## Key Features
/// - **Selection State Visualization**: Changes background color and font weight based on isSelected
/// - **Custom Color**: Can specify different colors for each event type
/// - **Action Handling**: Executes callback function when button clicked
///
/// ## Selected/Unselected Style Difference
/// ```
/// Selected:                   Unselected:
/// ┌───────────────┐          ┌───────────────┐
/// │ Event (Bold)  │          │ Event         │
/// │ Background: Red│          │ Background: Gray│
/// │ Text: White   │          │ Text: Red      │
/// └───────────────┘          └───────────────┘
/// ```
///
/// ## Usage Examples
/// ```swift
/// // "All" button (no color)
/// FilterButton(title: "All",
///              isSelected: true,
///              action: { print("All clicked") })
///
/// // "Event" button (red)
/// FilterButton(title: "Event",
///              color: .red,
///              isSelected: false,
///              action: { selectedEventType = .event })
/// ```
struct FilterButton: View {
    /// Button title (e.g., "All", "Normal", "Parking", "Event")
    let title: String

    /// Button color (Optional)
    ///
    /// ## When nil
    /// - Selected: .accentColor (system accent color, usually blue)
    /// - Unselected: .primary (default text color)
    ///
    /// ## When has value (e.g., .red)
    /// - Selected: .red background + white text
    /// - Unselected: .red text + gray background
    var color: Color?

    /// Selection state
    ///
    /// ## Determining Selection State
    /// ```swift
    /// // "All" button
    /// isSelected = (selectedEventType == nil)
    ///
    /// // "Event" button
    /// isSelected = (selectedEventType == .event)
    /// ```
    let isSelected: Bool

    /// Action to execute when button clicked
    ///
    /// ## Closure Type
    /// () -> Void: Function with no parameters and no return value
    ///
    /// **Action Examples:**
    /// ```swift
    /// action: { selectedEventType = nil }        // "All" button
    /// action: { selectedEventType = .event }     // "Event" button
    /// action: { print("Button clicked") }        // Log output
    /// ```
    let action: () -> Void

    /// FilterButton's Main Layout
    ///
    /// ## Button Style Decision Logic
    /// ```
    /// isSelected == true:
    ///   - Background: color ?? .accentColor (color priority, system accent if none)
    ///   - Text: .white (always white when selected)
    ///   - Font: .bold (bold when selected)
    ///
    /// isSelected == false:
    ///   - Background: .controlBackgroundColor (gray)
    ///   - Text: color ?? .primary (color priority, default text color if none)
    ///   - Font: .regular (regular weight)
    /// ```
    var body: some View {
        Button(action: action) {
            Text(title)
                /// ## .font(.caption)
                /// - caption: Small font size (usually 12pt)
                /// - Use small font as many buttons are arranged
                .font(.caption)

                /// ## Font weight based on selection state
                /// ```swift
                /// isSelected ? .bold : .regular
                /// //   true  → .bold    (bold)
                /// //   false → .regular (normal)
                /// ```
                .fontWeight(isSelected ? .bold : .regular)

                /// ## Text color based on selection state
                /// ```swift
                /// isSelected ? .white : (color ?? .primary)
                /// //   true  → .white (always white when selected)
                /// //   false → color if exists, .primary otherwise
                /// ```
                ///
                /// **Color Examples:**
                /// ```swift
                /// // "All" button (color = nil)
                /// isSelected = true  → .white
                /// isSelected = false → .primary (black/white)
                ///
                /// // "Event" button (color = .red)
                /// isSelected = true  → .white
                /// isSelected = false → .red
                /// ```
                .foregroundColor(isSelected ? .white : (color ?? .primary))
                .padding(.horizontal, 12)  // Left/right padding
                .padding(.vertical, 6)     // Top/bottom padding

                /// ## Background color based on selection state
                /// - RoundedRectangle: Rounded corner rectangle (cornerRadius: 12)
                /// - .fill(): Fill with background color
                ///
                /// **Background Color Decision:**
                /// ```swift
                /// isSelected ? (color ?? .accentColor) : .controlBackgroundColor
                /// //   true  → color if exists, .accentColor otherwise
                /// //   false → .controlBackgroundColor (gray)
                /// ```
                ///
                /// **Background Examples:**
                /// ```
                /// // "All" button (color = nil)
                /// isSelected = true:  ┌──────────┐
                ///                     │   All    │ Background: Blue (.accentColor)
                ///                     └──────────┘
                ///
                /// isSelected = false: ┌──────────┐
                ///                     │   All    │ Background: Gray
                ///                     └──────────┘
                ///
                /// // "Event" button (color = .red)
                /// isSelected = true:  ┌──────────┐
                ///                     │  Event   │ Background: Red
                ///                     └──────────┘
                ///
                /// isSelected = false: ┌──────────┐
                ///                     │  Event   │ Background: Gray, Text: Red
                ///                     └──────────┘
                /// ```
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? (color ?? Color.accentColor) : Color(nsColor: .controlBackgroundColor))
                )
        }
        /// ## .buttonStyle(.plain)
        /// - Remove Button default style (default background, hover effect, etc.)
        /// - Ensures custom background (.background) is applied accurately
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

/// @struct EmptyStateView
/// @brief Display View for no search/filtering results
///
/// @details
/// Empty state View displayed when search or filtering results are empty.
///
/// ## When Displayed
/// - filteredFiles.isEmpty == true
/// - No files found with search term
/// - No files matching filter criteria
/// - Original videoFiles array is empty
///
/// ## UI Structure
/// ```
/// ┌────────────────────────────┐
/// │                            │
/// │         🎥 (48pt)          │ ← SF Symbol: video.slash
/// │                            │
/// │    No Videos Found         │ ← Title (.title2, bold)
/// │                            │
/// │  Try adjusting your search │ ← Guidance message (.caption)
/// │     or filters             │
/// │                            │
/// └────────────────────────────┘
/// ```
///
/// ## User Experience Improvement
/// - Provide clear guidance instead of blank screen
/// - Suggest problem solution ("try adjusting")
/// - Clarify state with visual icon
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            /// No videos icon
            ///
            /// ## SF Symbol: video.slash
            /// - Video icon with slash through it
            /// - Intuitively expresses "no videos" state
            ///
            /// **Icon Examples:**
            /// ```
            /// video.slash:  📹/  (video with slash)
            /// video.fill:   📹   (normal video)
            /// photo.slash:  🖼️/  (photo with slash)
            /// ```
            Image(systemName: "video.slash")
                .font(.system(size: 48))        // Large icon (48pt)
                .foregroundColor(.secondary)    // Gray

            /// Title text
            ///
            /// ## .title2
            /// - Large title font (usually 22pt)
            /// - Used as main message
            Text("No Videos Found")
                .font(.title2)
                .fontWeight(.medium)  // Medium weight

            /// Guidance message
            ///
            /// ## .caption
            /// - Small font (usually 12pt)
            /// - Used as supplementary description
            ///
            /// **Message Intent:**
            /// - "Try changing the search term"
            /// - "Try adjusting the filters"
            /// - Suggest problem solution
            Text("Try adjusting your search or filters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        /// ## .frame(maxWidth:, maxHeight:)
        /// - .infinity: Take up entire parent View space
        /// - VStack positioned at screen center
        ///
        /// **Layout Example:**
        /// ```
        /// Parent View (List area):
        /// ┌────────────────────────────┐
        /// │                            │ ← Take up entire space with .infinity
        /// │                            │
        /// │      VStack centered       │ ← VStack automatically centered
        /// │                            │
        /// │                            │
        /// └────────────────────────────┘
        /// ```
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Status Bar

/// @struct StatusBar
/// @brief File list bottom status bar
///
/// @details
/// Status bar displayed at the bottom of file list, summarizes filtering results.
///
/// ## Display Content
/// - "X of Y videos": Filtered file count / Total file count
///
/// ## UI Structure
/// ```
/// ┌────────────────────────────────┐
/// │ 10 of 100 videos        [TODO] │ ← Left: Counter, Right: Additional info (not implemented)
/// └────────────────────────────────┘
/// ```
///
/// ## Usage Examples
/// ```swift
/// // Initial state (no filter)
/// StatusBar(fileCount: 100, totalCount: 100)
/// // Display: "100 of 100 videos"
///
/// // After search
/// StatusBar(fileCount: 10, totalCount: 100)
/// // Display: "10 of 100 videos"
///
/// // Filter + search
/// StatusBar(fileCount: 3, totalCount: 100)
/// // Display: "3 of 100 videos"
/// ```
struct StatusBar: View {
    /// File count after filtering
    ///
    /// ## Value Examples
    /// - Initial state (no filter): fileCount == totalCount
    /// - After search: fileCount < totalCount
    /// - No search results: fileCount == 0
    let fileCount: Int

    /// Total file count (before filtering)
    ///
    /// ## Value Examples
    /// - videoFiles.count (does not change)
    let totalCount: Int

    var body: some View {
        HStack {
            /// File counter text
            ///
            /// ## String Interpolation
            /// "\(fileCount) of \(totalCount) videos"
            /// - \(variable): Insert variable value into string
            ///
            /// **Examples:**
            /// ```swift
            /// fileCount = 10, totalCount = 100
            /// "\(fileCount) of \(totalCount) videos"
            /// → "10 of 100 videos"
            ///
            /// fileCount = 0, totalCount = 100
            /// "\(fileCount) of \(totalCount) videos"
            /// → "0 of 100 videos"
            /// ```
            Text("\(fileCount) of \(totalCount) videos")
                .font(.caption)              // Small font
                .foregroundColor(.secondary)  // Gray

            /// ## Spacer()
            /// - Takes up all remaining space
            /// - Left aligns text on left, right aligns content on right
            ///
            /// **Layout Effect:**
            /// ```
            /// Without Spacer:
            /// [10 of 100 videos][TODO]
            ///
            /// With Spacer:
            /// [10 of 100 videos]           [TODO]
            ///                   ↑ Spacer takes up space
            /// ```
            Spacer()

            /// TODO: Additional status information
            ///
            /// ## Possible Future Additions
            /// - Total file size: "Total: 10.5 GB"
            /// - Total playback time: "Duration: 2h 30m"
            /// - Last update: "Updated: 2024-01-15"
            ///
            /// **Implementation Example:**
            /// ```swift
            /// Text("Total: \(totalSize)")
            ///     .font(.caption)
            ///     .foregroundColor(.secondary)
            /// ```
        }
        .padding(.horizontal)  // Left/right padding
        .padding(.vertical, 8)  // Top/bottom padding
        .background(Color(nsColor: .controlBackgroundColor))  // macOS system background color
    }
}

// MARK: - Placeholder Views

/// PlaceholderView struct
/// Placeholder View displayed when no video file is selected.
///
/// ## When Displayed
/// - selectedFile == nil (no file selected)
/// - When app is first launched
/// - After deselection
///
/// ## UI Structure
/// ```
/// ┌────────────────────────────┐
/// │                            │
/// │         📹 (64pt)          │ ← SF Symbol: video.fill
/// │                            │
/// │  Select a video to view    │ ← Guidance message (.title2, bold)
/// │       details              │
/// │                            │
/// └────────────────────────────┘
/// ```
///
/// ## Usage Example
/// ```swift
/// // Conditional rendering in ContentView
/// if let file = selectedFile {
///     VideoPlayerView(videoFile: file)  // Play selected file
/// } else {
///     PlaceholderView()  // Display selection guidance
/// }
/// ```
struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            /// Video icon
            ///
            /// ## SF Symbol: video.fill
            /// - Filled video icon
            /// - Clearly expresses video-related UI
            Image(systemName: "video.fill")
                .font(.system(size: 64))        // Large icon (64pt)
                .foregroundColor(.secondary)    // Gray

            /// Guidance message
            ///
            /// ## Message Intent
            /// - "Select a video"
            /// - Guide user to next action
            Text("Select a video to view details")
                .font(.title2)               // Large font
                .fontWeight(.medium)         // Medium weight
                .foregroundColor(.secondary) // Gray
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Take up entire screen
    }
}

/// FileDetailView struct
/// View that displays detailed information of selected video file.
///
/// ## Display Information
/// - **Basic Info**: Filename, event type, timestamp, playback time, file size, channel count
/// - **Channel List**: Camera position, resolution, frame rate for each channel
/// - **Metadata**: GPS distance, average/max speed, impact event count, max G-Force
/// - **Notes**: User memo
///
/// ## UI Structure
/// ```
/// ┌────────────────────────────────┐
/// │ 📹 video_20240115_1430.mp4     │ ← Filename (.title, bold)
/// │ [Event] 2024-01-15 14:30       │ ← Event badge + timestamp
/// ├────────────────────────────────┤ ← Divider
/// │ File Information               │ ← Section title (.headline)
/// │ Duration      00:01:30         │ ← DetailRow
/// │ Size          512 MB           │
/// │ Channels      4                │
/// ├────────────────────────────────┤
/// │ Channels                       │
/// │ [📹 Front  1920x1080  30fps]   │ ← ChannelRow
/// │ [📹 Rear   1920x1080  30fps]   │
/// ├────────────────────────────────┤
/// │ Metadata                       │
/// │ Distance      5.2 km           │
/// │ Avg Speed     45 km/h          │
/// │ Max Speed     80 km/h          │
/// │ Impact Events 2                │
/// │ Max G-Force   3.5 G            │
/// ├────────────────────────────────┤
/// │ Notes                          │
/// │ Sudden stop on highway         │ ← User memo
/// └────────────────────────────────┘
/// ```
///
/// ## Conditional Section Rendering
/// - Channels: Display only when videoFile.channels.isEmpty == false
/// - Metadata: Display only when videoFile.hasGPSData || videoFile.hasAccelerationData
/// - Notes: Display only when videoFile.notes != nil
struct FileDetailView: View {
    /// Video file information to display
    let videoFile: VideoFile

    var body: some View {
        /// ## ScrollView
        /// - Scrollable when content exceeds screen
        /// - Handles cases with much file information
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                /// Basic information section
                VStack(alignment: .leading, spacing: 8) {
                    /// Filename
                    ///
                    /// ## videoFile.baseFilename
                    /// - Example: "video_20240115_1430.mp4"
                    /// - Display only filename without path
                    Text(videoFile.baseFilename)
                        .font(.title)        // Large font
                        .fontWeight(.bold)   // Bold

                    HStack {
                        /// Event type badge
                        ///
                        /// ## EventBadge
                        /// - Display event type with colored badge
                        /// - Examples: [Normal], [Parking], [Event]
                        EventBadge(eventType: videoFile.eventType)

                        /// Timestamp
                        ///
                        /// ## videoFile.timestampString
                        /// - Example: "2024-01-15 14:30:15"
                        /// - File recording time
                        Text(videoFile.timestampString)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                /// File information section
                VStack(alignment: .leading, spacing: 12) {
                    Text("File Information")
                        .font(.headline)  // Section title

                    /// Playback time
                    ///
                    /// ## DetailRow
                    /// - Component displaying label-value pairs
                    /// - HStack with label left-aligned, value right-aligned
                    ///
                    /// **Display Example:**
                    /// ```
                    /// Duration      00:01:30
                    /// ↑ Label       ↑ Value (right-aligned)
                    /// ```
                    DetailRow(label: "Duration", value: videoFile.durationString)
                    DetailRow(label: "Size", value: videoFile.totalFileSizeString)
                    DetailRow(label: "Channels", value: "\(videoFile.channelCount)")
                }

                /// Channel list section (conditional rendering)
                ///
                /// ## Display Condition
                /// - videoFile.channels.isEmpty == false
                /// - Display only when at least one channel exists
                if !videoFile.channels.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Channels")
                            .font(.headline)

                        /// Display each channel as ChannelRow
                        ///
                        /// ## ForEach
                        /// - Iterate through videoFile.channels array
                        /// - Render each ChannelInfo as ChannelRow
                        ///
                        /// **Rendering Example:**
                        /// ```swift
                        /// channels = [
                        ///     ChannelInfo(position: .front, ...),
                        ///     ChannelInfo(position: .rear, ...)
                        /// ]
                        ///
                        /// // Views created by ForEach
                        /// ChannelRow(channel: ChannelInfo(position: .front, ...))
                        /// ChannelRow(channel: ChannelInfo(position: .rear, ...))
                        /// ```
                        ForEach(videoFile.channels) { channel in
                            ChannelRow(channel: channel)
                        }
                    }
                }

                /// Metadata summary section (conditional rendering)
                ///
                /// ## Display Condition
                /// - videoFile.hasGPSData: When GPS data exists
                /// - videoFile.hasAccelerationData: When acceleration data exists
                /// - Display if either is true
                if videoFile.hasGPSData || videoFile.hasAccelerationData {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Metadata")
                            .font(.headline)

                        /// Get statistics from metadata.summary
                        ///
                        /// ## VideoMetadata.Summary
                        /// - GPS data: Distance traveled, average/max speed
                        /// - Acceleration data: Impact event count, max G-Force
                        let summary = videoFile.metadata.summary

                        /// Display GPS data (conditional)
                        if videoFile.hasGPSData {
                            DetailRow(label: "Distance", value: summary.distanceString)

                            /// Safe display with Optional Binding
                            ///
                            /// ## if let
                            /// - Executes only when summary.averageSpeedString is not nil
                            /// - Unwrapped value assigned to avgSpeed variable
                            if let avgSpeed = summary.averageSpeedString {
                                DetailRow(label: "Avg Speed", value: avgSpeed)
                            }
                            if let maxSpeed = summary.maximumSpeedString {
                                DetailRow(label: "Max Speed", value: maxSpeed)
                            }
                        }

                        /// Display acceleration data (conditional)
                        if videoFile.hasAccelerationData {
                            DetailRow(label: "Impact Events", value: "\(summary.impactEventCount)")
                            if let maxGForce = summary.maximumGForceString {
                                DetailRow(label: "Max G-Force", value: maxGForce)
                            }
                        }
                    }
                }

                /// Notes section (conditional rendering)
                ///
                /// ## Display Condition
                /// - videoFile.notes != nil
                /// - Display only when user has written memo
                ///
                /// ## Optional Binding
                /// ```swift
                /// if let notes = videoFile.notes {
                ///     // Executes only when notes is not nil
                ///     // notes variable is String type (not Optional)
                /// }
                /// ```
                if let notes = videoFile.notes {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.headline)

                        Text(notes)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()  // VStack external padding
        }
    }
}

/// DetailRow struct
/// Simple row component displaying label-value pairs.
///
/// ## UI Layout
/// ```
/// ┌────────────────────────────────┐
/// │ Duration            00:01:30   │ ← HStack
/// │ ↑ Label (left)      ↑ Value (right) │
/// └────────────────────────────────┘
/// ```
///
/// ## Usage Examples
/// ```swift
/// DetailRow(label: "Duration", value: "00:01:30")
/// DetailRow(label: "Size", value: "512 MB")
/// DetailRow(label: "Channels", value: "4")
/// ```
struct DetailRow: View {
    /// Label text (left)
    let label: String

    /// Value text (right)
    let value: String

    var body: some View {
        HStack {
            /// Label
            ///
            /// ## .foregroundColor(.secondary)
            /// - Gray color
            /// - Label is supplementary information so less emphasized
            Text(label)
                .foregroundColor(.secondary)

            /// ## Spacer()
            /// - Secure space between label and value
            /// - Left align label, right align value
            Spacer()

            /// Value
            ///
            /// ## .fontWeight(.medium)
            /// - Medium weight font
            /// - Value is main information so more emphasized
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)  // Slightly smaller font
    }
}

/// ChannelRow struct
/// Row component displaying video channel information.
///
/// ## Display Information
/// - Camera position: Front, Rear, Left, Right
/// - Resolution: 1920x1080, 1280x720, etc.
/// - Frame rate: 30fps, 60fps, etc.
///
/// ## UI Layout
/// ```
/// ┌────────────────────────────────┐
/// │ 📹 Front    1920x1080    30fps │ ← HStack (gray background)
/// │ ↑   ↑          ↑           ↑   │
/// │ Icon Position  Resolution  FPS │
/// └────────────────────────────────┘
/// ```
///
/// ## Usage Example
/// ```swift
/// let channel = ChannelInfo(
///     position: .front,
///     resolutionName: "1920x1080",
///     frameRateString: "30fps"
/// )
/// ChannelRow(channel: channel)
/// ```
struct ChannelRow: View {
    /// Channel information (camera position, resolution, frame rate, etc.)
    let channel: ChannelInfo

    var body: some View {
        HStack {
            /// Video icon
            Image(systemName: "video.fill")
                .foregroundColor(.secondary)

            /// Camera position
            ///
            /// ## channel.position.displayName
            /// - Display name of CameraPosition enum
            /// - Examples: "Front", "Rear", "Left", "Right"
            ///
            /// **Examples:**
            /// ```swift
            /// CameraPosition.front.displayName  → "Front"
            /// CameraPosition.rear.displayName   → "Rear"
            /// ```
            Text(channel.position.displayName)
                .fontWeight(.medium)  // Position more emphasized

            Spacer()

            /// Resolution
            ///
            /// ## channel.resolutionName
            /// - Examples: "1920x1080", "1280x720", "3840x2160" (4K)
            Text(channel.resolutionName)
                .font(.caption)
                .foregroundColor(.secondary)

            /// Frame rate
            ///
            /// ## channel.frameRateString
            /// - Examples: "30fps", "60fps", "120fps"
            Text(channel.frameRateString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)  // Default font size
        .padding(.vertical, 4)     // Top/bottom padding
        .padding(.horizontal, 8)   // Left/right padding
        .background(Color(nsColor: .controlBackgroundColor))  // Gray background
        .cornerRadius(6)  // Round corners
    }
}

// MARK: - Preview

/// SwiftUI Preview
///
/// ## What is PreviewProvider?
/// - Protocol that allows viewing Views in Xcode Canvas
/// - Can check UI without actual app build
/// - Can test in various conditions (device, dark mode, etc.)
///
/// ## How to Use
/// 1. Activate Xcode Canvas (⌘ + Option + Enter)
/// 2. Canvas automatically renders previews
/// 3. Preview updates in real-time when code is modified
///
/// ## Notes
/// - PreviewProvider only compiles in Debug builds
/// - Automatically excluded from Release builds (saves app size)
struct FileListView_Previews: PreviewProvider {
    static var previews: some View {
        FileListViewPreviewWrapper()
    }
}

/// FileListView Preview Wrapper
///
/// ## Why @State is Needed
/// FileListView accepts @Binding, so Preview must provide original data with @State.
///
/// **Preview Structure:**
/// ```
/// FileListViewPreviewWrapper (Wrapper)
/// └─ @State var videoFiles        ← Owns original data
/// └─ @State var selectedFile
///     ↓ Pass Binding with $
/// FileListView (Actual View)
/// └─ @Binding var videoFiles      ← Only holds reference
/// └─ @Binding var selectedFile
/// ```
///
/// ## VideoFile.allSamples
/// - Sample data for testing
/// - Fake VideoFile array with various event types and metadata
///
/// **Sample Data Example:**
/// ```swift
/// VideoFile.allSamples = [
///     VideoFile(baseFilename: "video1.mp4", eventType: .normal, ...),
///     VideoFile(baseFilename: "video2.mp4", eventType: .event, ...),
///     VideoFile(baseFilename: "video3.mp4", eventType: .parking, ...)
/// ]
/// ```
private struct FileListViewPreviewWrapper: View {
    /// Video file array for Preview
    ///
    /// ## VideoFile.allSamples
    /// - Sample data defined in Models/VideoFile.swift
    /// - Can test various scenarios in Preview
    @State private var videoFiles: [VideoFile] = VideoFile.allSamples

    /// Selected file for Preview
    ///
    /// ## Initialize as nil
    /// - No file selected initially
    /// - Automatically updates when file clicked in Preview
    @State private var selectedFile: VideoFile?

    var body: some View {
        /// Preview FileListView at 400x600 size
        ///
        /// ## .frame(width:, height:)
        /// - Fix Preview window size
        /// - Can check size in actual use
        FileListView(videoFiles: $videoFiles, selectedFile: $selectedFile)
            .frame(width: 400, height: 600)
    }
}
