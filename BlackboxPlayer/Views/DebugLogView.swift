/// @file DebugLogView.swift
/// @brief Debug log viewer overlay
/// @author BlackboxPlayer Development Team
/// @details
/// Implements an overlay UI that displays application debug logs in real-time.
/// Provides real-time log streaming, auto-scroll, and color-coded log levels.

/*
 【DebugLogView Overview】

 This file implements an overlay UI that displays application debug logs in real-time.


 ┌─────────────────────────────────────┐
 │  Debug Log         [Auto-scroll] 🗑️ │ ← Header (title + controls)
 ├─────────────────────────────────────┤
 │ 14:23:01 [INFO] App started         │
 │ 14:23:05 [DEBUG] Loading video...   │
 │ 14:23:10 [WARNING] Low buffer       │ ← Log list
 │ 14:23:15 [ERROR] Decode failed      │   (auto-scroll)
 │                                     │
 └─────────────────────────────────────┘


 【Key Features】

 1. Real-time log display
 - Receives logs from LogManager singleton
 - Automatically updates UI when new logs are added

 2. Auto-scroll
 - Automatically scrolls to bottom when new logs are added
 - Can be toggled On/Off with button

 3. Color-coded log levels
 - Debug: Gray (detailed debug information)
 - Info: White (general information)
 - Warning: Yellow (warnings)
 - Error: Red (errors)

 4. Log management
 - Clear button to delete all logs
 - Text selection enabled (for copying)


 【Usage Example】

 ```swift
 // 1. Display as overlay
 ZStack {
 // Main content
 ContentView()

 // Debug log overlay at bottom
 VStack {
 Spacer()
 DebugLogView()
 .padding()
 }
 }

 // 2. Log messages
 LogManager.shared.log("Video loaded", level: .info)
 LogManager.shared.log("Frame dropped", level: .warning)
 ```


 【SwiftUI Concepts】

 Key SwiftUI concepts demonstrated in this file:

 1. @ObservedObject
 - Observes changes in external objects
 - Automatically re-renders View when object changes

 2. @State
 - Stores View internal state
 - Re-renders View when state changes

 3. ScrollViewReader
 - Programmatically control scroll position
 - Navigate to specific items using scrollTo() method

 4. LazyVStack
 - Only renders visible items (performance optimization)
 - Efficient when there are many log entries

 5. onChange modifier
 - Detects changes in specific values
 - Performs additional actions when changes occur

 6. Private struct
 - Separates View into smaller sub-views
 - Improves code reusability and readability


 【Importance of Debug Log Viewer】

 A debug log viewer is essential for diagnosing issues during development and testing:

 ✓ Real-time feedback
 → Immediately see what the application is doing

 ✓ Issue tracking
 → Understand the sequence of events before and after errors

 ✓ Performance analysis
 → Measure time taken for specific operations

 ✓ User testing
 → Provide logs when QA team or beta testers report issues


 【Related Files】

 - LogManager.swift: Singleton class that manages and stores logs
 - LogEntry.swift: Data model for individual log entries

 */

import SwiftUI

/// @struct DebugLogView
/// @brief Debug log viewer overlay
///
/// @details
/// An overlay view that displays debug logs in real-time.
///
/// **Key Features:**
/// - Real-time log streaming
/// - Auto-scroll (toggleable)
/// - Color-coded log levels
/// - Log clear functionality
///
/// **Usage Example:**
/// ```swift
/// ZStack {
///     ContentView()
///     VStack {
///         Spacer()
///         DebugLogView()
///             .padding()
///     }
/// }
/// ```
///
/// **Related Types:**
/// - `LogManager`: Log data provider
/// - `LogEntry`: Individual log entry
///
struct DebugLogView: View {
    // MARK: - Properties

    /// @var logManager
    /// @brief Log manager singleton instance
    ///
    /// **What is @ObservedObject?**
    ///
    /// @ObservedObject is a property wrapper that observes an externally created ObservableObject.
    ///
    /// **How it works:**
    /// ```
    /// 1. LogManager adds a log
    ///    ↓
    /// 2. @Published var logs changes
    ///    ↓
    /// 3. DebugLogView automatically re-renders
    ///    ↓
    /// 4. New log appears on screen
    /// ```
    ///
    /// **@ObservedObject vs @State:**
    ///
    /// | @ObservedObject                | @State                          |
    /// |--------------------------------|---------------------------------|
    /// | Observes external objects      | Stores View internal state      |
    /// | Can be shared across Views     | Only used in that View          |
    /// | Reference type (class)         | Value type (struct/enum/basic)  |
    /// | Suitable for singleton pattern | Suitable for simple UI state    |
    ///
    /// **Why use shared singleton?**
    ///
    /// LogManager should only have one instance across the entire app:
    /// - All code accesses the same log storage
    /// - Multiple Views display the same log list
    /// - Memory efficiency (prevents duplicate instances)
    ///
    @ObservedObject var logManager = LogManager.shared

    /// @var autoScroll
    /// @brief Auto-scroll toggle state
    ///
    /// **What is @State?**
    ///
    /// @State is a property wrapper that stores simple state used only within a View.
    ///
    /// **How it works:**
    /// ```swift
    /// // 1. Set initial value
    /// @State private var autoScroll = true  // starts as true
    ///
    /// // 2. Toggle changes state
    /// Toggle("Auto-scroll", isOn: $autoScroll)  // bind with $
    ///
    /// // 3. When state changes to false...
    /// //    → SwiftUI re-renders the View
    /// //    → onChange checks if autoScroll
    /// ```
    ///
    /// **Why use private?**
    ///
    /// Since autoScroll is only used within DebugLogView:
    /// - Encapsulation - external access prevented
    /// - Clear intent - "this state is internal only"
    /// - Code safety - prevents accidental external modification
    ///
    /// **Why default to true?**
    ///
    /// In most cases, auto-scrolling when new logs are added is useful:
    /// - During development: immediately see latest logs
    /// - During debugging: track events in real-time
    /// - User can toggle off if desired
    ///
    @State private var autoScroll = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            //
            // Header section: title + auto-scroll toggle + clear button
            //
            // Arranged horizontally using HStack:
            // [Title]                    [Toggle] [Button]
            HStack {
                // Title
                //
                // Displays "Debug Log" title
                //
                // .font(.headline):
                //   - Headline style (typically 17pt, Bold)
                //   - Supports system Dynamic Type (automatically adjusts to user's font size setting)
                //
                // .foregroundColor(.white):
                //   - Sets text color to white
                //   - Ensures visibility on black background (opacity 0.9)
                Text("Debug Log")
                    .font(.headline)
                    .foregroundColor(.white)

                // Spacer pushes controls to the right
                //
                // Spacer takes up all available space.
                //
                // Spacer's role in HStack:
                // [Text] [======= Spacer =======] [Toggle] [Button]
                //
                // Result: Toggle and Button are pushed to the right edge
                Spacer()

                // Auto-scroll toggle
                //
                // Toggle button that can turn auto-scroll functionality On/Off
                //
                // **How Toggle works:**
                //
                // ```swift
                // Toggle("Auto-scroll", isOn: $autoScroll)
                // //      ~~~~~~~~~~~~         ~~~~~~~~~~~
                // //      Label text           Bound state
                // ```
                //
                // **Meaning of $ symbol (Binding):**
                //
                // $autoScroll creates a "binding" to the autoScroll variable.
                //
                // What is Binding?
                //   - Two-way binding
                //   - Toggle can read and write the value
                //   - Automatically synchronizes when value changes
                //
                // Data flow:
                // ```
                // Toggle switch clicked
                //       ↓
                // Value changes through $autoScroll (true → false)
                //       ↓
                // @State detects change
                //       ↓
                // SwiftUI re-renders View
                //       ↓
                // UI updates with new state
                // ```
                //
                // **.toggleStyle(.switch):**
                //   - macOS switch style (On/Off switch similar to iOS)
                //   - Other styles: .checkbox (checkbox), .button (button)
                //
                // **.controlSize(.mini):**
                //   - Sets control size to mini
                //   - Size options: .mini < .small < .regular < .large
                //   - Display small since it goes in header
                //
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .foregroundColor(.white)

                // Clear button
                //
                // Button that deletes all logs
                //
                // **Button structure:**
                //
                // ```swift
                // Button(action: { /* code to execute */ }) {
                //     /* button appearance */
                // }
                // ```
                //
                // **action closure:**
                //
                // { logManager.clear() }
                //   - Code executed when button is clicked
                //   - Calls LogManager's clear() method
                //   - Removes all log entries from array
                //
                // **SF Symbols:**
                //
                // Image(systemName: "trash")
                //   - Uses Apple's SF Symbols icons
                //   - "trash" = trash can icon
                //   - Provides over 30,000 icons
                //   - Vector-based so sharp at all sizes
                //
                // **Button styling:**
                //
                // .buttonStyle(.plain)
                //   - Removes default button style
                //   - macOS buttons have blue background by default
                //   - Creates transparent button with plain style
                //
                // .help("Clear logs")
                //   - Shows tooltip on mouse hover
                //   - Explains button function to user
                //
                Button(action: { logManager.clear() }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Clear logs")
            }
            .padding()
            .background(Color.black.opacity(0.9))

            // Header/Body separator
            //
            // Separator line between header and log list
            //
            // Divider:
            //   - Thin horizontal line (vertical in HStack)
            //   - Uses system color (automatically adapts to light/dark mode)
            //   - Used for visual separation
            Divider()

            // Log list with auto-scroll
            //
            // Displays log entries in a scrollable list
            //
            // **What is ScrollViewReader?**
            //
            // ScrollViewReader is a container that enables programmatic control of scroll position.
            //
            // Basic structure:
            // ```swift
            // ScrollViewReader { proxy in
            //     ScrollView {
            //         // content...
            //     }
            //     .onChange(...) {
            //         proxy.scrollTo(targetID)  // scroll to specific item
            //     }
            // }
            // ```
            //
            // **What is proxy?**
            //
            // proxy is an object of type ScrollViewProxy:
            //   - Provides scrollTo() method
            //   - Scrolls to View with specific ID
            //   - Can include animation
            //
            // **Why is it needed?**
            //
            // Regular ScrollView only allows manual scrolling by user.
            // With ScrollViewReader:
            //   - Automatically scroll to bottom when new log is added
            //   - Jump to specific log
            //   - Scroll to search results
            //
            ScrollViewReader { proxy in
                ScrollView {
                    // **LazyVStack vs VStack:**
                    //
                    // LazyVStack:
                    //   - Only renders visible items (Lazy loading)
                    //   - Maintains performance even with thousands of logs
                    //   - Creates Views only when needed during scroll
                    //
                    // VStack:
                    //   - Renders all items immediately
                    //   - Slows down with many items
                    //   - Use when items are few and fixed
                    //
                    // Performance comparison:
                    // ```
                    // Based on 10,000 logs
                    //
                    // VStack:
                    //   - Initial render: creates all 10,000
                    //   - Memory: high
                    //   - Scroll performance: slow
                    //
                    // LazyVStack:
                    //   - Initial render: creates only ~20 visible
                    //   - Memory: low
                    //   - Scroll performance: fast
                    // ```
                    //
                    // **alignment: .leading:**
                    //   - Aligns all items to the left
                    //   - Log text is typically left-aligned
                    //
                    // **spacing: 4:**
                    //   - 4pt spacing between items
                    //   - Not too tight, not too wide
                    //
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // **Rendering log items with ForEach:**
                        //
                        // ForEach creates a View for each item in the collection.
                        //
                        // Basic structure:
                        // ```swift
                        // ForEach(collection) { item in
                        //     // View using item
                        // }
                        // ```
                        //
                        // **Identifiable protocol:**
                        //
                        // When LogEntry adopts Identifiable:
                        //   - ForEach uniquely identifies each item
                        //   - Automatically uses id property
                        //   - SwiftUI efficiently tracks updates
                        //
                        // LogEntry example:
                        // ```swift
                        // struct LogEntry: Identifiable {
                        //     let id = UUID()  // unique ID
                        //     let message: String
                        //     let timestamp: Date
                        //     let level: LogLevel
                        // }
                        // ```
                        //
                        // **Why is ID important?**
                        //
                        // Without ID:
                        // ```
                        // 10 logs → add 1 → re-render all 11 ❌
                        // ```
                        //
                        // With ID:
                        // ```
                        // 10 logs → add 1 → render only 1 new item ✓
                        // ```
                        //
                        ForEach(logManager.logs) { entry in
                            // **LogEntryRow sub-view:**
                            //
                            // Reusable sub-view that displays each log entry
                            //
                            // Reasons for separating into sub-view:
                            //   1. Code reusability (can use elsewhere)
                            //   2. Improved readability (each part clearly separated)
                            //   3. Easy maintenance (modify in one place)
                            //   4. Performance optimization (SwiftUI updates in smaller units)
                            //
                            LogEntryRow(entry: entry)
                                // **.id(entry.id):**
                                //
                                // Explicitly assigns an ID to the View
                                //
                                // Why is this needed when ForEach already uses ID?
                                //   - For use in ScrollViewProxy.scrollTo()
                                //   - Specifies target when scrolling to specific log
                                //
                                // Example:
                                // ```swift
                                // proxy.scrollTo(lastLog.id)
                                // //             ~~~~~~~~~~
                                // //             Scroll to View with this ID
                                // ```
                                //
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .background(Color.black.opacity(0.8))
                // **onChange modifier:**
                //
                // Modifier that detects and reacts to changes in specific values
                //
                // Basic structure:
                // ```swift
                // .onChange(of: value_to_observe) { new_value in
                //     // code to execute when value changes
                // }
                // ```
                //
                // **onChange in this code:**
                //
                // ```swift
                // .onChange(of: logManager.logs.count) { _ in
                //     // executes when log count changes
                // }
                // ```
                //
                // **When does it execute?**
                //
                // Adding log:
                // ```
                // 5 logs → LogManager.log() called → 6 logs
                //              ↓
                //         logs.count changes (5 → 6)
                //              ↓
                //         onChange closure executes
                //              ↓
                //         Performs auto-scroll
                // ```
                //
                // Clearing logs:
                // ```
                // 10 logs → LogManager.clear() called → 0 logs
                //              ↓
                //         logs.count changes (10 → 0)
                //              ↓
                //         onChange closure executes (but no scroll since lastLog is nil)
                // ```
                //
                // **Auto-scroll logic:**
                //
                .onChange(of: logManager.logs.count) { _ in
                    // **Condition check: if autoScroll, let lastLog = ...**
                    //
                    // This one line has two conditions:
                    //
                    // 1. Is autoScroll true?
                    //    - Only when user has enabled auto-scroll
                    //    - No scroll if false
                    //
                    // 2. lastLog = logManager.logs.last
                    //    - Gets last item of logs array
                    //    - Optional Binding (optional unwrapping)
                    //    - If no logs (empty array) is nil, so if block doesn't execute
                    //
                    // **What is Optional Binding?**
                    //
                    // logs.last returns Optional<LogEntry>:
                    //   - nil if array is empty
                    //   - Optional(last_item) if items exist
                    //
                    // Using if let:
                    //   - Block executes only when not nil
                    //   - lastLog is unwrapped value (LogEntry type)
                    //
                    // Example:
                    // ```swift
                    // // When logs exist
                    // logs = [log1, log2, log3]
                    // logs.last = Optional(log3)
                    // if let lastLog = logs.last {  // success, lastLog = log3
                    //     // this block executes
                    // }
                    //
                    // // When no logs
                    // logs = []
                    // logs.last = nil
                    // if let lastLog = logs.last {  // fails
                    //     // this block doesn't execute
                    // }
                    // ```
                    //
                    if autoScroll, let lastLog = logManager.logs.last {
                        // **Smooth scrolling with withAnimation:**
                        //
                        // withAnimation animates state changes within the block
                        //
                        // Without withAnimation:
                        // ```
                        // proxy.scrollTo(lastLog.id)
                        // // instant jump (abrupt movement)
                        // ```
                        //
                        // With withAnimation:
                        // ```
                        // withAnimation {
                        //     proxy.scrollTo(lastLog.id)
                        // }
                        // // smooth scroll (natural movement)
                        // ```
                        //
                        // **scrollTo method:**
                        //
                        // ```swift
                        // proxy.scrollTo(lastLog.id, anchor: .bottom)
                        // //             ~~~~~~~~~~~  ~~~~~~~~~~~~~
                        // //             Target ID    Alignment position
                        // ```
                        //
                        // **Meaning of anchor: .bottom:**
                        //
                        // anchor determines where to position the scrolled item on screen:
                        //
                        // .top: position item at top of screen
                        // ```
                        // ┌──────────────┐
                        // │ [Target item]│ ← positioned here
                        // │              │
                        // │              │
                        // └──────────────┘
                        // ```
                        //
                        // .bottom: position item at bottom of screen
                        // ```
                        // ┌──────────────┐
                        // │              │
                        // │              │
                        // │ [Target item]│ ← positioned here
                        // └──────────────┘
                        // ```
                        //
                        // .center: position item at center of screen
                        // ```
                        // ┌──────────────┐
                        // │              │
                        // │ [Target item]│ ← positioned here
                        // │              │
                        // └──────────────┘
                        // ```
                        //
                        // Why use .bottom in log viewer:
                        //   - Like chat apps, new items are added at bottom
                        //   - Latest log always visible at bottom of screen
                        //   - Natural reading flow (top → bottom)
                        //
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
        .cornerRadius(8)
        .shadow(radius: 10)
    }
}

// MARK: - Log Entry Row

/// @struct LogEntryRow
/// @brief Individual log entry row display component
///
/// @details
/// Sub-view that displays individual log entries
///
/// **Why use private struct:**
///
/// ```swift
/// private struct LogEntryRow: View { ... }
/// //~~~~~~
/// ```
///
/// The private keyword means this struct can only be used within the current file:
///
/// ✓ Encapsulation
///   → Not accessible from external files
///   → Hides internal implementation details
///
/// ✓ Namespace management
///   → No conflicts even if another file has a struct with same name
///   → Clear scope of use
///
/// ✓ Compilation optimization
///   → Compiler can optimize more aggressively
///   → Knows there's no external usage when private
///
/// **When to create private struct?**
///
/// - Sub-views only used within that View
/// - When no need to reuse in other files
/// - When wanting to separate View into smaller pieces
///
/// **Example:**
/// ```swift
/// // File A
/// struct DebugLogView: View {
///     var body: some View {
///         LogEntryRow(entry: someEntry)  // ✓ can use
///     }
/// }
///
/// private struct LogEntryRow: View { ... }
///
/// // File B
/// struct OtherView: View {
///     var body: some View {
///         LogEntryRow(entry: someEntry)  // ❌ cannot use (private)
///     }
/// }
/// ```
///
private struct LogEntryRow: View {
    // MARK: - Properties

    /// @var entry
    /// @brief Log entry data to display
    ///
    /// **let vs var:**
    ///
    /// Why use let:
    ///   - LogEntry doesn't change once received
    ///   - Guarantees immutability
    ///   - Clearly expresses intent ("this value doesn't change")
    ///
    /// **LogEntry structure:**
    /// ```swift
    /// struct LogEntry: Identifiable {
    ///     let id: UUID
    ///     let timestamp: Date
    ///     let level: LogLevel  // .debug, .info, .warning, .error
    ///     let message: String
    ///
    ///     var formattedMessage: String {
    ///         // "[14:23:05] [INFO] Application started"
    ///         return "[\(timeString)] [\(level)] \(message)"
    ///     }
    /// }
    /// ```
    ///
    let entry: LogEntry

    // MARK: - Body

    var body: some View {
        // **Text View:**
        //
        // Text view that displays log message
        //
        // entry.formattedMessage:
        //   - LogEntry's computed property
        //   - Formats timestamp + level + message
        //   - Example: "[14:23:05] [INFO] Application started"
        //
        Text(entry.formattedMessage)
            // **.font(.system(size:design:)):**
            //
            // Specifies detailed settings for system font
            //
            // **size: 11**
            //   - Small font size (default is ~17pt)
            //   - Logs need to display lots of information, so keep small
            //   - Too small reduces readability
            //
            // **design: .monospaced**
            //   - Monospaced font (fixed-width font)
            //   - All characters have same width
            //   - Logs align cleanly
            //
            // **Monospaced vs Proportional comparison:**
            //
            // Proportional (regular font):
            // ```
            // [14:23:05] [INFO   ] Message 1
            // [14:23:06] [WARNING] Message 2
            // [14:23:07] [ERROR  ] Message 3
            // //        ~~~~~~~~~ misaligned
            // ```
            //
            // Monospaced (fixed-width font):
            // ```
            // [14:23:05] [INFO   ] Message 1
            // [14:23:06] [WARNING] Message 2
            // [14:23:07] [ERROR  ] Message 3
            // //        ~~~~~~~~~ aligned
            // ```
            //
            // **Why use Monospaced font for logs?**
            //
            // ✓ Alignment
            //   → Timestamps, levels, messages align cleanly vertically
            //
            // ✓ Readability
            //   → Easy to recognize patterns
            //   → Numbers and code are clearly visible
            //
            // ✓ Developer-friendly
            //   → Used in most IDEs and terminals
            //   → Familiar style
            //
            .font(.system(size: 11, design: .monospaced))

            // **.foregroundColor(textColor):**
            //
            // Sets text color based on log level
            //
            // textColor is determined by the computed property below
            //
            .foregroundColor(textColor)

            // **.textSelection(.enabled):**
            //
            // Enables user to select (copy) text
            //
            // **Why is this needed?**
            //
            // Often need to copy logs:
            //   - Paste into bug reports
            //   - Share via Slack/email
            //   - Analyze with external tools
            //
            // Without .enabled:
            //   - Text doesn't get selected even when dragged
            //   - Cannot copy
            //
            // With .enabled:
            //   - Can select by mouse drag
            //   - Can copy with Cmd+C
            //
            .textSelection(.enabled)
    }

    // MARK: - Computed Properties

    /// Text color based on log level
    ///
    /// Returns text color based on log level
    ///
    /// **What is Computed Property?**
    ///
    /// ```swift
    /// private var textColor: Color {
    ///     // computes without storing
    ///     return someColor
    /// }
    /// ```
    ///
    /// Computed property calculates value on each request without storing it.
    ///
    /// **Stored Property vs Computed Property:**
    ///
    /// Stored Property:
    /// ```swift
    /// let entry: LogEntry  // stored in memory
    /// ```
    ///
    /// Computed Property:
    /// ```swift
    /// var textColor: Color {  // calculated each time
    ///     switch entry.level { ... }
    /// }
    /// ```
    ///
    /// **Why use Computed Property?**
    ///
    /// ✓ Prevents duplicate storage
    ///   → Information already exists in entry.level
    ///   → No need to store color separately
    ///
    /// ✓ Guarantees synchronization
    ///   → Color automatically changes when entry.level changes
    ///   → No inconsistency issues
    ///
    /// ✓ Memory efficiency
    ///   → Doesn't store color value
    ///   → Low computation cost (simple switch statement)
    ///
    /// **Color design by log level:**
    ///
    /// Colors visually convey information importance and urgency:
    ///
    /// .debug → .gray
    ///   - Detailed debug information
    ///   - Less important
    ///   - Blends into background
    ///
    /// .info → .white
    ///   - General informational messages
    ///   - Medium importance
    ///   - Clearly visible
    ///
    /// .warning → .yellow
    ///   - Warning messages
    ///   - Requires attention
    ///   - Noticeable but not urgent
    ///
    /// .error → .red
    ///   - Error messages
    ///   - Requires immediate attention
    ///   - Highly noticeable
    ///
    /// **Principles of color selection:**
    ///
    /// 1. Intuitiveness
    ///    - Red = danger, Yellow = caution (universal recognition)
    ///
    /// 2. Contrast
    ///    - Colors that are visible on black background
    ///
    /// 3. Distinctiveness
    ///    - Each color is clearly distinguishable
    ///
    /// 4. Accessibility
    ///    - Distinguishable for colorblind users (brightness difference)
    ///
    private var textColor: Color {
        switch entry.level {
        case .debug:
            return .gray
        case .info:
            return .white
        case .warning:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: - Preview

/// SwiftUI Preview
///
/// Preview that enables DebugLogView to be previewed in Xcode's Canvas
///
/// **What is PreviewProvider?**
///
/// PreviewProvider is a protocol that provides SwiftUI's preview functionality.
///
/// Preview advantages:
///   ✓ Real-time preview - instantly reflects code changes
///   ✓ Fast iteration - can check UI without building entire app
///   ✓ Test various environments - dark mode, different device sizes, etc.
///
/// **How Preview works:**
///
/// ```
/// 1. Xcode detects code
///    ↓
/// 2. Executes PreviewProvider's previews property
///    ↓
/// 3. Renders returned View in Canvas
///    ↓
/// 4. Automatically re-renders when code changes detected
/// ```
///
/// **This Preview's composition:**
///
/// ```
/// ZStack {
///     Color.blue          ← Background (blue, simulates app's main UI)
///     VStack {
///         Spacer()        ← Top space (pushes DebugLogView down)
///         DebugLogView()  ← View to test
///     }
/// }
/// ```
///
/// **ZStack's role:**
///
/// ZStack stacks Views along Z-axis (depth):
/// ```
/// Z-axis (front ← back)
/// DebugLogView (front)
///     ↓
/// Color.blue (back)
/// ```
///
/// Simulates actual usage environment:
///   - Blue background = main app screen
///   - DebugLogView = overlay on top
///
/// **VStack + Spacer's role:**
///
/// Inside VStack:
/// ```
/// ┌──────────────────┐
/// │                  │
/// │     Spacer()     │ ← Takes up all available space
/// │                  │
/// ├──────────────────┤
/// │  DebugLogView()  │ ← Positioned at bottom
/// └──────────────────┘
/// ```
///
/// Result: DebugLogView is fixed at bottom of screen
///
/// **onAppear modifier:**
///
/// onAppear is a closure that executes when View appears on screen
///
/// ```swift
/// .onAppear {
///     // executes when View appears
/// }
/// ```
///
/// **Why use onAppear in this Preview:**
///
/// To add sample logs to LogManager:
///   - When preview loads
///   - Automatically adds 4 sample logs
///   - Logs appear in DebugLogView
///
/// Without sample logs:
///   - Only see empty screen
///   - Cannot verify UI works properly
///
/// With sample logs:
///   - Verify color for each log level
///   - Check layout
///   - Test scroll functionality
///
/// **4 sample logs:**
///
/// 1. .info - "Application started"
///    → White, general startup message
///
/// 2. .debug - "Loading video file: test.mp4"
///    → Gray, debug information
///
/// 3. .warning - "Warning: Low buffer detected"
///    → Yellow, warning message
///
/// 4. .error - "Error: Failed to decode frame"
///    → Red, error message
///
/// Including all levels allows verification that color distinction works well.
///
struct DebugLogView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue
            VStack {
                Spacer()
                DebugLogView()
                    .padding()
            }
        }
        .onAppear {
            LogManager.shared.log("Application started", level: .info)
            LogManager.shared.log("Loading video file: test.mp4", level: .debug)
            LogManager.shared.log("Warning: Low buffer detected", level: .warning)
            LogManager.shared.log("Error: Failed to decode frame", level: .error)
        }
    }
}
