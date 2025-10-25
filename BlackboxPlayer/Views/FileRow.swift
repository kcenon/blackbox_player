/// @file FileRow.swift
/// @brief Video file list row component
/// @author BlackboxPlayer Development Team
/// @details
/// A reusable UI component that displays individual rows in the video file list.
/// Displays event type badges, file information, metadata, and status indicators.

/*
 【FileRow Overview】

 This file implements a reusable UI component that displays individual rows in the video file list.


 ┌─────────────────────────────────────────────────────────────────────┐
 │ [IMPACT] 2024_03_15_14_23_45_F.mp4           14:23:45 PM   ▶       │
 │          2:34 mins  │  1.2 GB  │  2 channels  │  📍  ⚠️  ⭐         │
 └─────────────────────────────────────────────────────────────────────┘
 ~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~
 Event        File Info                 Metadata               Play
 Badge        (Name, Time)              (Duration, Size, Ch)   Button


 【Key Features】

 1. Event Type Badge
 - NORMAL (Recording)
 - IMPACT (Impact)
 - PARKING (Parking)
 - MANUAL (Manual)
 - EMERGENCY (Emergency)

 2. File Information
 - Filename (Monospaced font)
 - Timestamp (Date and time)

 3. Metadata
 - Duration (Playback time)
 - File size
 - Channel count

 4. Status Indicators
 - 📍 GPS: Contains GPS data
 - ⚠️ Impact: Contains impact events
 - ⭐ Favorite: Marked as favorite
 - ❌ Corrupted: File corrupted

 5. Selection State Display
 - Unselected: Transparent background
 - Selected: Accent color background + border


 【Usage Examples】

 ```swift
 // 1. Use in List
 List(videoFiles) { file in
 FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
 .onTapGesture {
 selectedFile = file
 }
 }

 // 2. Use in ForEach
 ForEach(videoFiles) { file in
 FileRow(videoFile: file, isSelected: false)
 }

 // 3. Use standalone
 FileRow(videoFile: .normal5Channel, isSelected: true)
 .padding()
 ```


 【SwiftUI Concepts】

 Key SwiftUI concepts you can learn from this file:

 1. Reusable Component
 - Independent View usable in multiple places
 - Data injection approach (let properties)

 2. Conditional Rendering
 - Display Views only under specific conditions using if statements
 - Optional chaining

 3. Layout Containers
 - HStack: Horizontal layout
 - VStack: Vertical layout
 - Spacer: Space distribution

 4. Label Component
 - Icon + text combination
 - SF Symbols integration

 5. Shapes and Modifiers
 - RoundedRectangle
 - .background(), .overlay()
 - .stroke(), .fill()

 6. Selection State Expression
 - Ternary operator (isSelected ? A : B)
 - Dynamic styling


 【Design Pattern】

 **Reusable Component:**

 FileRow follows these principles:

 ✓ Single Responsibility
 → Responsible only for displaying video file information

 ✓ Independence
 → Does not depend on external state
 → Only receives necessary data via injection

 ✓ Composition
 → Separated into small subviews (EventBadge)
 → Each part managed independently

 ✓ Declarative
 → Declares "what" rather than "how"
 → SwiftUI handles rendering


 【Related Files】

 - VideoFile.swift: Video file data model
 - EventType.swift: Event type enum
 - FileListView.swift: List view that uses FileRow

 */

import SwiftUI

/// @struct FileRow
/// @brief Video file list row component
///
/// @details
/// A reusable component that displays individual rows in the video file list.
///
/// **Key Features:**
/// - Event type badge (color coded)
/// - File information (name, timestamp)
/// - Metadata (duration, size, channels)
/// - Status indicators (GPS, impact, favorite, corrupted)
/// - Selection state display
///
/// **Usage Example:**
/// ```swift
/// List(videoFiles) { file in
///     FileRow(videoFile: file, isSelected: selectedFile?.id == file.id)
///         .onTapGesture {
///             selectedFile = file
///         }
/// }
/// ```
///
/// **Associated Types:**
/// - `VideoFile`: Video file data
/// - `EventType`: Event type enum
///
struct FileRow: View {
    // MARK: - Properties

    /// @var videoFile
    /// @brief Video file data to display
    ///
    /// **Why use let:**
    ///
    /// FileRow only displays data without modifying it:
    ///   - Guarantees immutability
    ///   - Clarifies intent ("This data is read-only")
    ///   - Prevents bugs (Cannot accidentally modify)
    ///
    /// **Key VideoFile Properties:**
    /// ```swift
    /// struct VideoFile {
    ///     let baseFilename: String         // "2024_03_15_14_23_45_F.mp4"
    ///     let eventType: EventType         // .impact
    ///     let timestampString: String      // "March 15, 2024 at 2:23 PM"
    ///     let durationString: String       // "2:34"
    ///     let totalFileSizeString: String  // "1.2 GB"
    ///     let channelCount: Int            // 2
    ///     let hasGPSData: Bool             // true
    ///     let hasImpactEvents: Bool        // true
    ///     let isFavorite: Bool             // false
    ///     let isCorrupted: Bool            // false
    ///     let isPlayable: Bool             // true
    /// }
    /// ```
    ///
    let videoFile: VideoFile

    /// @var isSelected
    /// @brief Whether the row is selected
    ///
    /// **Why inject from outside?**
    ///
    /// Selection state is managed by the parent View:
    ///
    /// ```swift
    /// // Parent View
    /// @State private var selectedFile: VideoFile?
    ///
    /// List(videoFiles) { file in
    ///     FileRow(
    ///         videoFile: file,
    ///         isSelected: selectedFile?.id == file.id  // Determined externally
    ///     )
    /// }
    /// ```
    ///
    /// Advantages of this approach:
    ///   - Parent controls selection logic
    ///   - FileRow only handles display (single responsibility)
    ///   - Supports various patterns like multi-select, single-select, etc.
    ///
    let isSelected: Bool

    // MARK: - Body

    var body: some View {
        // **HStack - Horizontal Layout:**
        //
        // HStack arranges child Views horizontally.
        //
        // Layout of this row:
        // ```
        // [Badge] [File Info]           [Play Button]
        // ~~~~~~  ~~~~~~~~~~~~~~~~~~~   ~~~~~~~~~~~~
        // 80pt    Variable size (Spacer) Fixed size
        // ```
        //
        // **spacing: 12**
        //   - 12pt spacing between each element
        //   - Not too tight, adequately separated
        //
        HStack(spacing: 12) {
            // MARK: Event Type Badge

            // Event type badge
            //
            // Displays the event type as a colored badge.
            //
            // **EventBadge Subcomponent:**
            //
            // EventBadge is a separate View defined at the bottom of this file:
            //   - Receives event type
            //   - Displays text on colored background
            //   - Reusable
            //
            // Examples:
            // ```
            // IMPACT: "IMPACT" on red background
            // NORMAL: "NORMAL" on green background
            // ```
            //
            EventBadge(eventType: videoFile.eventType)
                // **.frame(width: 80):**
                //
                // Fixes the badge width at 80pt.
                //
                // Why use fixed width:
                //   - Badge position consistent across all rows
                //   - Clean vertical alignment
                //   - Maintains consistency regardless of text length
                //
                // Width comparison:
                // ```
                // Fixed width (80pt):
                // [NORMAL    ] File 1
                // [IMPACT    ] File 2
                // [EMERGENCY ] File 3
                // ~~~~~~~~~~~~ ← All start at same position
                //
                // Variable width:
                // [NORMAL] File 1
                // [IMPACT] File 2
                // [EMERGENCY] File 3
                // ~~~~~~~~~~~ ← Different start positions
                // ```
                //
                .frame(width: 80)

            // MARK: File Information

            // File information
            //
            // Section that displays detailed file information.
            //
            // **VStack - Vertical Layout:**
            //
            // VStack arranges child Views vertically.
            //
            // Structure:
            // ```
            // ┌─────────────────────────┐
            // │ 2024_03_15_14_23_45.mp4 │ ← Filename
            // ├─────────────────────────┤
            // │ March 15, 2024 at 2:23  │ ← Timestamp
            // ├─────────────────────────┤
            // │ 🕐 2:34 │ 📄 1.2GB │... │ ← Metadata
            // └─────────────────────────┘
            // ```
            //
            // **alignment: .leading**
            //   - Left-aligns all items
            //   - Text reads naturally
            //
            // **spacing: 4**
            //   - 4pt spacing between items
            //   - Compact but distinguishable
            //
            VStack(alignment: .leading, spacing: 4) {
                // MARK: Filename

                // Filename
                //
                // Displays the base name of the file.
                //
                // videoFile.baseFilename:
                //   - Example: "2024_03_15_14_23_45_F.mp4"
                //   - Filename only, not full path
                //
                Text(videoFile.baseFilename)
                    // **.font(.system(.body, design: .monospaced)):**
                    //
                    // Uses system font with some additional settings.
                    //
                    // **.body:**
                    //   - Body text size (typically 17pt)
                    //   - Most commonly used size
                    //
                    // **design: .monospaced:**
                    //   - Monospaced font (fixed width)
                    //   - All characters have same width
                    //   - Filenames should often look code-like
                    //
                    // **Why use Monospaced font for filenames?**
                    //
                    // Filenames follow a specific format:
                    // ```
                    // YYYY_MM_DD_HH_MM_SS_Position.mp4
                    // 2024_03_15_14_23_45_F.mp4
                    // 2024_03_15_14_23_45_R.mp4
                    // ~~~~ ~~ ~~ ~~ ~~ ~~ ~
                    // Fixed-width font ensures clean alignment
                    // ```
                    //
                    .font(.system(.body, design: .monospaced))

                    // **.fontWeight(.medium):**
                    //
                    // Sets font weight to medium.
                    //
                    // Weight options:
                    //   - .ultraLight (thinnest)
                    //   - .thin
                    //   - .light
                    //   - .regular (default)
                    //   - .medium ← currently used
                    //   - .semibold
                    //   - .bold
                    //   - .heavy
                    //   - .black (thickest)
                    //
                    // Why use Medium:
                    //   - Slightly emphasized over Regular
                    //   - Not as heavy as Bold
                    //   - Filename is primary info, so appropriately highlighted
                    //
                    .fontWeight(.medium)

                    // **.lineLimit(1):**
                    //
                    // Limits text to maximum 1 line.
                    //
                    // Handling long filenames:
                    // ```
                    // Without limit:
                    // very_very_very_long_filename_that_
                    // wraps_to_multiple_lines.mp4
                    //
                    // lineLimit(1):
                    // very_very_very_long_filenam...
                    // ```
                    //
                    // Why limit to 1 line:
                    //   - Keeps list row height consistent
                    //   - Prevents layout breaking
                    //   - Shows more items on screen
                    //
                    .lineLimit(1)

                // MARK: Timestamp

                // Timestamp
                //
                // Displays the date and time when the file was created.
                //
                // videoFile.timestampString:
                //   - Example: "March 15, 2024 at 2:23 PM"
                //   - String formatted via DateFormatter
                //
                Text(videoFile.timestampString)
                    // **.font(.caption):**
                    //
                    // Caption is a small text style for secondary information.
                    //
                    // Text style hierarchy:
                    // ```
                    // .largeTitle  (largest and most important)
                    // .title
                    // .title2
                    // .title3
                    // .headline
                    // .body        (regular text)
                    // .callout
                    // .subheadline
                    // .footnote
                    // .caption     (smallest and most secondary) ← currently used
                    // .caption2
                    // ```
                    //
                    // Why use Caption:
                    //   - Timestamp is secondary information
                    //   - Less important than filename
                    //   - Expresses visual hierarchy
                    //
                    .font(.caption)

                    // **.foregroundColor(.secondary):**
                    //
                    // Sets text color to secondary.
                    //
                    // **System Colors (Semantic Colors):**
                    //
                    // SwiftUI provides semantic colors:
                    //
                    // .primary:
                    //   - Primary text
                    //   - Light mode: black
                    //   - Dark mode: white
                    //
                    // .secondary: ← currently used
                    //   - Secondary text
                    //   - Light mode: gray
                    //   - Dark mode: light gray
                    //
                    // .tertiary:
                    //   - Tertiary text
                    //   - Lighter gray
                    //
                    // **Advantages of System Colors:**
                    //
                    // ✓ Automatic dark mode support
                    //   → No need for developer to handle separately
                    //
                    // ✓ Accessibility
                    //   → System automatically adjusts contrast
                    //
                    // ✓ Consistency
                    //   → Same feel across all macOS apps
                    //
                    .foregroundColor(.secondary)

                // MARK: Metadata Info

                // Metadata info
                //
                // Displays file metadata with icons.
                //
                // Horizontal layout with HStack:
                // [🕐 2:34] [📄 1.2GB] [🎥 2 channels] [📍] [⚠️] [⭐]
                //
                HStack(spacing: 12) {
                    // MARK: Duration

                    // Duration
                    //
                    // Displays video playback duration.
                    //
                    // **Label Component:**
                    //
                    // Label is a SwiftUI component that combines icon and text.
                    //
                    // Basic structure:
                    // ```swift
                    // Label("Text", systemImage: "icon.name")
                    // //    ~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~
                    // //    Text     SF Symbols icon name
                    // ```
                    //
                    // Rendering result:
                    // ```
                    // 🕐 2:34
                    // ~~ ~~~~~
                    // Icon Text
                    // ```
                    //
                    // **Advantages of Label:**
                    //
                    // ✓ Automatic alignment
                    //   → Icon and text automatically center-aligned
                    //
                    // ✓ Style consistency
                    //   → System standard styles applied
                    //
                    // ✓ Accessibility
                    //   → VoiceOver handles automatically
                    //
                    // videoFile.durationString:
                    //   - Example: "2:34" (2 minutes 34 seconds)
                    //   - Or "1:23:45" (1 hour 23 minutes 45 seconds)
                    //
                    // systemImage: "clock":
                    //   - Clock icon from SF Symbols
                    //   - Intuitively represents playback duration
                    //
                    Label(videoFile.durationString, systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // MARK: File Size

                    // File size
                    //
                    // Displays the file size.
                    //
                    // videoFile.totalFileSizeString:
                    //   - Example: "1.2 GB", "567 MB"
                    //   - Formatted via ByteCountFormatter
                    //   - Human-readable format
                    //
                    // systemImage: "doc":
                    //   - Document/file icon
                    //   - Represents file size
                    //
                    Label(videoFile.totalFileSizeString, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // MARK: Channel Count

                    // Channel count
                    //
                    // Displays the number of video channels (cameras).
                    //
                    // "\(videoFile.channelCount) channels":
                    //   - String interpolation (\(...))
                    //   - Example: "2 channels", "5 channels"
                    //
                    // **Multi-camera System:**
                    //
                    // Dashcams use multiple cameras simultaneously:
                    //   - 1 channel: Front only
                    //   - 2 channels: Front + Rear
                    //   - 4 channels: Front + Rear + Left + Right
                    //   - 5 channels: 4 channels + Interior
                    //
                    // systemImage: "video":
                    //   - Video camera icon
                    //   - Represents number of channels/cameras
                    //
                    Label("\(videoFile.channelCount) channels", systemImage: "video")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // MARK: Status Indicators

                    // GPS indicator
                    //
                    // Displays only when GPS data is present.
                    //
                    // **Conditional Rendering:**
                    //
                    // In SwiftUI, using if statements allows showing or hiding Views based on conditions.
                    //
                    // ```swift
                    // if condition {
                    //     SomeView()  // Only rendered when condition is true
                    // }
                    // ```
                    //
                    // **How it works:**
                    //
                    // When videoFile.hasGPSData is true:
                    // ```
                    // 🕐 2:34 │ 📄 1.2GB │ 🎥 2 channels │ 📍
                    // //                                    ~~
                    // //                                    GPS icon shown
                    // ```
                    //
                    // When videoFile.hasGPSData is false:
                    // ```
                    // 🕐 2:34 │ 📄 1.2GB │ 🎥 2 channels
                    // //                                    No GPS icon
                    // ```
                    //
                    // **Why conditional display?**
                    //
                    // ✓ Information conciseness
                    //   → Showing icon without GPS data causes confusion
                    //
                    // ✓ Visual clarity
                    //   → Icon present means "GPS available"
                    //   → Icon absent means "No GPS"
                    //
                    // ✓ Space efficiency
                    //   → Only shows necessary icons
                    //
                    if videoFile.hasGPSData {
                        // **SF Symbols - location.fill:**
                        //
                        // "location.fill" is a filled location pin icon.
                        //
                        // SF Symbols naming convention:
                        //   - Base name: location (outline only)
                        //   - .fill: location.fill (filled form)
                        //   - .circle: location.circle (inside circle)
                        //   - .slash: location.slash (with slash)
                        //
                        // Why use .fill?
                        //   - More noticeable
                        //   - Clear even at small size (.caption)
                        //   - Indicates "active" state
                        //
                        Image(systemName: "location.fill")
                            .font(.caption)
                            // Blue: Evokes GPS/location (Google Maps, Apple Maps, etc.)
                            .foregroundColor(.blue)
                    }

                    // Impact indicator
                    //
                    // Displays only when impact events are present.
                    //
                    // videoFile.hasImpactEvents:
                    //   - Analyzes acceleration data from VideoMetadata
                    //   - True if impact is 2.5G or higher
                    //
                    if videoFile.hasImpactEvents {
                        // **SF Symbols - exclamationmark.triangle.fill:**
                        //
                        // Warning triangle icon.
                        //
                        // Standard warning symbol:
                        //   - Road signs (⚠️)
                        //   - Software warning messages
                        //   - Hazard warnings
                        //
                        // Why use this icon?
                        //   - Universally recognized
                        //   - Intuitively conveys need for caution
                        //   - Represents impact/danger
                        //
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            // Orange: Represents warning/caution (between yellow and red)
                            .foregroundColor(.orange)
                    }

                    // Favorite indicator
                    //
                    // Displays only when marked as favorite.
                    //
                    // videoFile.isFavorite:
                    //   - User manually marked as favorite
                    //   - For quickly finding important videos
                    //
                    if videoFile.isFavorite {
                        // **SF Symbols - star.fill:**
                        //
                        // Filled star icon.
                        //
                        // Universal meaning of star icon:
                        //   - Favorites
                        //   - Bookmarks
                        //   - Important items
                        //   - Rating
                        //
                        // Used in most apps:
                        //   - Safari: Bookmarks
                        //   - Mail: VIP emails
                        //   - Files: Favorite folders
                        //
                        Image(systemName: "star.fill")
                            .font(.caption)
                            // Yellow: Evokes gold star/trophy (positive, valuable)
                            .foregroundColor(.yellow)
                    }

                    // Corrupted indicator
                    //
                    // Displays only when file is corrupted.
                    //
                    // videoFile.isCorrupted:
                    //   - File read failure
                    //   - Missing metadata
                    //   - Abnormal file structure
                    //
                    if videoFile.isCorrupted {
                        // **SF Symbols - xmark.circle.fill:**
                        //
                        // X mark inside filled circle icon.
                        //
                        // Meaning of X mark:
                        //   - Error
                        //   - Failure
                        //   - Unavailable
                        //   - Corrupted
                        //
                        // Why use .circle.fill:
                        //   - More noticeable than plain X
                        //   - Circular background emphasizes icon
                        //   - "Stop" or "prohibited" feeling
                        //
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            // Red: Represents error/danger (universal warning color)
                            .foregroundColor(.red)
                    }
                }
            }

            // MARK: Spacer

            // Spacer pushes playback button to the right
            //
            // Spacer takes up all available space and pushes elements to the edges.
            //
            // Role of Spacer in HStack:
            // ```
            // [Badge] [File Info] [====== Spacer ======] [Play Button]
            // ```
            //
            // Without Spacer:
            // ```
            // [Badge] [File Info] [Play Button]
            // //                  ~~~~~~~~~~~~ Sticks right next to file info
            // ```
            //
            // With Spacer:
            // ```
            // [Badge] [File Info]                      [Play Button]
            // //                                        ~~~~~~~~~~~~ Pushed to right edge
            // ```
            //
            Spacer()

            // MARK: Playback Button

            // Playback button
            //
            // Displays play button only when file is playable.
            //
            // **Conditional Button Display:**
            //
            // videoFile.isPlayable:
            //   - File is not corrupted
            //   - All required data is present
            //   - Supported codec
            //
            // Why hide button when not playable:
            //   - Clicking with no result causes confusion
            //   - Clear user feedback
            //   - Removes unnecessary UI elements
            //
            if videoFile.isPlayable {
                Button(action: {
                    // TODO: Play video
                    //
                    // In actual implementation:
                    //   1. Open video player view
                    //   2. Load file into VideoPlayerViewModel
                    //   3. Start playback
                    //
                    // Example:
                    // ```swift
                    // playerViewModel.load(videoFile)
                    // showPlayer = true
                    // ```
                }) {
                    // **SF Symbols - play.circle.fill:**
                    //
                    // Play icon inside filled circle.
                    //
                    // Standard for play icon:
                    //   - Triangle (▶️)
                    //   - Points to the right
                    //   - Universally recognized
                    //
                    // Why use .circle.fill:
                    //   - Clearly expresses it's a button
                    //   - Clickable area appears larger
                    //   - More visually prominent
                    //
                    Image(systemName: "play.circle.fill")
                        // **.font(.title2):**
                        //
                        // Sets icon size to title2.
                        //
                        // Size comparison:
                        //   - .caption (small)
                        //   - .body (medium)
                        //   - .title3 (large)
                        //   - .title2 (larger) ← currently used
                        //   - .title (largest)
                        //
                        // Why use title2:
                        //   - Button should be easy to click
                        //   - Primary action so should be noticeable
                        //   - Too large would take up layout space
                        //
                        .font(.title2)

                        // **.foregroundColor(.accentColor):**
                        //
                        // Uses the app's accent color.
                        //
                        // **What is Accent Color?**
                        //
                        // A brand color used consistently throughout the app:
                        //   - Defined in Assets.xcassets
                        //   - Used for buttons, links, selected items, etc.
                        //   - Indicates elements users can interact with
                        //
                        // Examples:
                        //   - iOS: Blue (default)
                        //   - Custom: Company brand color
                        //
                        // Advantages:
                        //   ✓ Consistency - Same color throughout app
                        //   ✓ Easy to change - Modify in one place to change entire app
                        //   ✓ Branding - Expresses app identity
                        //
                        .foregroundColor(.accentColor)
                }
                // **.buttonStyle(.plain):**
                //
                // Removes default button styling.
                //
                // macOS button styles:
                //   - Default: Blue background, rounded corners
                //   - .plain: No background, only content
                //
                // Why use Plain:
                //   - play.circle.fill icon already looks like a button
                //   - Additional background unnecessary
                //   - Clean design
                //
                .buttonStyle(.plain)
            }
        }
        // **.padding(.vertical, 8):**
        //
        // Adds 8pt vertical padding (top and bottom).
        //
        // Padding:
        // ```
        // ┌───────────────────────┐
        // │    ← 8pt padding      │
        // │ [Row Content]         │
        // │    ← 8pt padding      │
        // └───────────────────────┘
        // ```
        //
        .padding(.vertical, 8)
        // **.padding(.horizontal, 12):**
        //
        // Adds 12pt horizontal padding (left and right).
        //
        // Padding:
        // ```
        // ┌────────────────────────┐
        // │ 12pt  [Row Content] 12pt│
        // └────────────────────────┘
        // ```
        //
        .padding(.horizontal, 12)

        // MARK: Selection Style

        // **.background(...):**
        //
        // Sets the row background.
        //
        // **Background based on selection state:**
        //
        .background(
            RoundedRectangle(cornerRadius: 8)
                // **Ternary Operator:**
                //
                // ```swift
                // condition ? valueIfTrue : valueIfFalse
                // ```
                //
                // isSelected ? Color.accentColor.opacity(0.1) : Color.clear
                // ~~~~~~~~~~   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   ~~~~~~~~~~~
                // Condition    Selected (accent 10% opacity)    Unselected (clear)
                //
                // **What is opacity(0.1)?**
                //
                // Sets color transparency:
                //   - 0.0 = Fully transparent (invisible)
                //   - 0.1 = 90% transparent (barely visible) ← currently used
                //   - 0.5 = 50% transparent (semi-transparent)
                //   - 1.0 = Opaque (fully visible)
                //
                // Why use low opacity like 0.1?
                //   - Too strong background reduces text readability
                //   - Subtle highlight indicates selection state
                //   - Clean and refined design
                //
                // Selection state comparison:
                // ```
                // Unselected:
                // ┌─────────────────────────────┐
                // │ [Row Content]               │ ← Transparent background
                // └─────────────────────────────┘
                //
                // Selected:
                // ┌─────────────────────────────┐
                // │ [Row Content]               │ ← Light blue background
                // └─────────────────────────────┘
                // ```
                //
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )

        // **.overlay(...):**
        //
        // Overlays border on top of the row.
        //
        // **Background vs Overlay:**
        //
        // .background:
        //   - Renders behind View
        //   - Layer below content
        //
        // .overlay:
        //   - Renders in front of View
        //   - Layer above content
        //
        // Layer order:
        // ```
        // Overlay (border) ← Front
        //     ↓
        // Content (text, icons, etc.)
        //     ↓
        // Background (background color) ← Back
        // ```
        //
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                // **.stroke(...):**
                //
                // Draws only the shape outline (no fill).
                //
                // .fill vs .stroke:
                // ```
                // .fill:
                // ┌──────┐
                // │██████│ ← Fills interior with color
                // └──────┘
                //
                // .stroke:
                // ┌──────┐
                // │      │ ← Only draws border
                // └──────┘
                // ```
                //
                // **Border based on selection state:**
                //
                // isSelected ? Color.accentColor : Color.clear
                // ~~~~~~~~~~   ~~~~~~~~~~~~~~~~~~   ~~~~~~~~~~~
                // Condition    Selected (accent)      Unselected (clear)
                //
                // lineWidth: 2
                //   - Sets border thickness to 2pt
                //   - Too thin is invisible
                //   - Too thick is noisy
                //
                // **Combined effect of background + border:**
                //
                // Selected row:
                // ```
                // ┌─────────────────────────────┐ ← Blue border (2pt)
                // │                             │
                // │ [Row Content]               │ ← Light blue background (10%)
                // │                             │
                // └─────────────────────────────┘
                // ```
                //
                // Why use both:
                //   ✓ Background only: Too subtle, may be missed
                //   ✓ Border only: May have weak contrast with background
                //   ✓ Background + Border: Clear and visually emphasized
                //
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Event Badge

/// @struct EventBadge
/// @brief Event type colored badge component
///
/// @details
/// Component that displays event type as a colored badge.
///
/// **Usage Example:**
/// ```swift
/// EventBadge(eventType: .impact)  // Red "IMPACT" badge
/// EventBadge(eventType: .normal)  // Green "NORMAL" badge
/// ```
///
/// **Associated Types:**
/// - `EventType`: Event type enum
///
struct EventBadge: View {
    // MARK: - Properties

    /// Event type
    ///
    /// The event type to display.
    ///
    /// **EventType enum:**
    /// ```swift
    /// enum EventType {
    ///     case normal     // Normal recording - Green
    ///     case impact     // Impact event - Red
    ///     case parking    // Parking mode - Blue
    ///     case manual     // Manual recording - Orange
    ///     case emergency  // Emergency recording - Purple
    ///     case unknown    // Unknown - Gray
    ///
    ///     var displayName: String { ... }
    ///     var colorHex: String { ... }
    /// }
    /// ```
    ///
    let eventType: EventType

    // MARK: - Body

    var body: some View {
        // **Badge text:**
        //
        // eventType.displayName.uppercased()
        //   - displayName: Event type display name ("Impact", "Normal", etc.)
        //   - uppercased(): Converts to all uppercase ("IMPACT", "NORMAL")
        //
        // **Why use uppercase?**
        //
        // ✓ Visual emphasis
        //   → Uppercase appears stronger and clearer
        //
        // ✓ Standard badge style
        //   → Status badges typically use uppercase
        //   → UI pattern in GitHub, Slack, etc.
        //
        // ✓ Consistency
        //   → All badges have same style
        //
        // Example:
        // ```
        // Lowercase: impact  ← Less noticeable
        // Uppercase: IMPACT  ← More emphasized
        // ```
        //
        Text(eventType.displayName.uppercased())
            // **.font(.caption):**
            //
            // Uses small text size.
            //
            // Badge is secondary information so:
            //   - Too large would overwhelm primary content
            //   - Appropriately small looks like a badge
            //
            .font(.caption)

            // **.fontWeight(.bold):**
            //
            // Displays font in bold.
            //
            // Why use Bold:
            //   - Remains clear even at small size (.caption)
            //   - Emphasizes badge importance
            //   - Improves contrast with colored background
            //
            .fontWeight(.bold)

            // **.foregroundColor(.white):**
            //
            // Displays text in white.
            //
            // Why use white:
            //   - Best readability on colored backgrounds
            //   - Works well with all background colors (green, red, blue, etc.)
            //   - Accessibility - sufficient contrast
            //
            // Color contrast example:
            // ```
            // Red background + white text:   IMPACT  ✓ Visible
            // Red background + black text:   IMPACT  ✗ Not visible
            // ```
            //
            .foregroundColor(.white)

            // **.padding(.horizontal, 8):**
            //
            // Adds 8pt padding to left and right of text.
            //
            // Padding:
            // ```
            // ┌──────────────┐
            // │ 8pt│IMPACT│8pt│
            // └──────────────┘
            // ```
            //
            // Why padding is needed:
            //   - Text stuck to background edge looks cramped
            //   - Enlarges clickable area
            //   - Visual balance
            //
            .padding(.horizontal, 8)

            // **.padding(.vertical, 4):**
            //
            // Adds 4pt padding to top and bottom of text.
            //
            // Padding:
            // ```
            // ┌──────────┐
            // │   4pt    │
            // │ IMPACT   │
            // │   4pt    │
            // └──────────┘
            // ```
            //
            // Why vertical padding is smaller than horizontal:
            //   - Horizontal: 8pt (wider)
            //   - Vertical: 4pt (narrower)
            //   - Result: Horizontally elongated badge shape (typical badge form)
            //
            .padding(.vertical, 4)

            // **.background(...):**
            //
            // Sets the badge background.
            //
            .background(
                RoundedRectangle(cornerRadius: 4)
                    // **.fill(Color(hex: eventType.colorHex)):**
                    //
                    // Fills background with color based on event type.
                    //
                    // **Color(hex:) Custom Initializer:**
                    //
                    // Swift's Color doesn't natively support hex colors.
                    // This project appears to have added a custom extension:
                    //
                    // ```swift
                    // extension Color {
                    //     init(hex: String) {
                    //         // "#FF0000" → Red
                    //         // "#00FF00" → Green
                    //         // ...
                    //     }
                    // }
                    // ```
                    //
                    // **eventType.colorHex:**
                    //
                    // Each event type has a unique hex color code:
                    //
                    // ```
                    // .normal     → "#4CAF50" (green)
                    // .impact     → "#F44336" (red)
                    // .parking    → "#2196F3" (blue)
                    // .manual     → "#FF9800" (orange)
                    // .emergency  → "#9C27B0" (purple)
                    // .unknown    → "#9E9E9E" (gray)
                    // ```
                    //
                    // **Material Design Colors:**
                    //
                    // These colors appear to be from Google's Material Design palette:
                    //   ✓ Visually balanced
                    //   ✓ Accessibility considered (sufficient contrast)
                    //   ✓ Modern design
                    //
                    // **cornerRadius: 4:**
                    //
                    // Rounds corners to 4pt.
                    //
                    // Rounded corner effect:
                    // ```
                    // cornerRadius: 0 (sharp corners):
                    // ┌──────────┐
                    // │ IMPACT   │
                    // └──────────┘
                    //
                    // cornerRadius: 4 (slightly rounded):
                    // ╭──────────╮
                    // │ IMPACT   │
                    // ╰──────────╯
                    //
                    // cornerRadius: 20 (very rounded, capsule shape):
                    // ╭─────────╮
                    // │ IMPACT  │
                    // ╰─────────╯
                    // ```
                    //
                    // Why use 4pt:
                    //   - Not too sharp (soft feeling)
                    //   - Not too round (prevents bubble appearance)
                    //   - Typical badge/tag style
                    //
                    .fill(Color(hex: eventType.colorHex))
            )
    }
}

// MARK: - Preview

/// SwiftUI Preview
///
/// Preview that allows viewing FileRow in Xcode's Canvas.
///
/// **This Preview's Composition:**
///
/// Displays 5 different VideoFile samples to check various states:
///
/// 1. **normal5Channel**: Normal recording, 5 channels
///    - Not selected
///    - Green "NORMAL" badge
///
/// 2. **impact2Channel**: Impact event, 2 channels
///    - Selected (blue background + border)
///    - Red "IMPACT" badge
///    - Impact indicator shown
///
/// 3. **parking1Channel**: Parking mode, 1 channel
///    - Not selected
///    - Blue "PARKING" badge
///
/// 4. **favoriteRecording**: Marked as favorite
///    - Not selected
///    - Yellow star indicator shown
///
/// 5. **corruptedFile**: Corrupted file
///    - Not selected
///    - Red X indicator shown
///    - No play button (not playable)
///
/// **VStack(spacing: 8):**
///
/// Arranges each row vertically with 8pt spacing:
/// ```
/// ┌─────────────────┐
/// │ Row 1           │
/// ├─────────────────┤ ← 8pt spacing
/// │ Row 2 (selected)│
/// ├─────────────────┤ ← 8pt spacing
/// │ Row 3           │
/// └─────────────────┘
/// ```
///
/// **.previewLayout(.sizeThatFits):**
///
/// Adjusts preview to fit content size.
///
/// Layout options:
///   - .device: Actual device size (iPhone, iPad, etc.)
///   - .fixed(width:height:): Fixed size
///   - .sizeThatFits: Auto-adjust to content ← currently used
///
/// Why use sizeThatFits:
///   - Removes unnecessary empty space
///   - Focuses on component
///   - Faster preview loading
///
struct FileRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 8) {
            FileRow(videoFile: .normal5Channel, isSelected: false)
            FileRow(videoFile: .impact2Channel, isSelected: true)
            FileRow(videoFile: .parking1Channel, isSelected: false)
            FileRow(videoFile: .favoriteRecording, isSelected: false)
            FileRow(videoFile: .corruptedFile, isSelected: false)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
