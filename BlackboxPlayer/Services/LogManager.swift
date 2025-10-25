/// @file LogManager.swift
/// @brief Centralized logging manager for debugging
/// @author BlackboxPlayer Development Team
/// @details
/*
 ╔══════════════════════════════════════════════════════════════════════════════╗
 ║                                                                              ║
 ║                         LogManager - Centralized Logging System              ║
 ║                                                                              ║
 ║  Purpose:                                                                        ║
 ║    Centralized management of all application log messages with real-time        ║
 ║    UI display. Essential component for debugging, troubleshooting, and          ║
 ║    performance monitoring.                                                       ║
 ║                                                                              ║
 ║  Core Features:                                                                   ║
 ║    • Save log messages with timestamps                                          ║
 ║    • Log level classification (DEBUG, INFO, WARNING, ERROR)                     ║
 ║    • Thread-safe log storage                                                    ║
 ║    • Maintain maximum of 500 logs (circular buffer)                             ║
 ║    • Real-time observation in SwiftUI                                           ║
 ║                                                                              ║
 ║  Design Pattern:                                                                 ║
 ║    • Singleton pattern: Single instance used throughout the application        ║
 ║    • Observer pattern: SwiftUI views automatically detect log changes          ║
 ║    • Thread-Safe: Safe operation in multi-threaded environment using NSLock    ║
 ║                                                                              ║
 ║  Usage Example:                                                                     ║
 ║    ```swift                                                                  ║
 ║    // Simple logging                                                             ║
 ║    debugLog("Video decoding started")                                        ║
 ║    infoLog("File loaded successfully")                                       ║
 ║    warningLog("Low memory warning")                                          ║
 ║    errorLog("Failed to open file")                                           ║
 ║                                                                              ║
 ║    // Display logs in SwiftUI                                                   ║
 ║    struct DebugView: View {                                                  ║
 ║        @ObservedObject var logger = LogManager.shared                        ║
 ║                                                                              ║
 ║        var body: some View {                                                 ║
 ║            List(logger.logs) { log in                                        ║
 ║                Text(log.formattedMessage)                                    ║
 ║            }                                                                 ║
 ║        }                                                                     ║
 ║    }                                                                         ║
 ║    ```                                                                       ║
 ║                                                                              ║
 ╚══════════════════════════════════════════════════════════════════════════════╝


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ What is a logging system? Why is it needed?                                 │
 └──────────────────────────────────────────────────────────────────────────────┘

 Logging is the practice of recording events that occur during program execution.

 ┌───────────────────────────────────────────────────────────────────────────┐
 │ print() vs LogManager                                                     │
 ├───────────────────────────────────────────────────────────────────────────┤
 │                                                                           │
 │ Problems with print():                                                        │
 │   • Logs only appear in console → users cannot see them                     │
 │   • No timestamp → cannot determine when events occurred                    │
 │   • No level classification → cannot judge importance                       │
 │   • No search/filtering → difficult to find desired logs                    │
 │   • Messages get mixed in multi-threaded environments                       │
 │                                                                           │
 │ Advantages of LogManager:                                                    │
 │   • Real-time UI display → both users and developers can check              │
 │   • Accurate timestamps → can track chronological order                     │
 │   • Log levels → can filter by importance                                   │
 │   • Memory storage → searchable and analyzable                              │
 │   • Thread-safe → message order is guaranteed                               │
 │                                                                           │
 └───────────────────────────────────────────────────────────────────────────┘


 Real-world use cases:

 1. Debugging
 Track where and why problems occur
 Example: "Video decoding failed at frame 1523"

 2. Performance Monitoring
 Measure execution time for each step
 Example: "File scan completed in 2.3 seconds"

 3. User Support
 Share logs for remote assistance when users encounter issues
 Example: User reports "playback not working" → check logs → find "Codec not supported"

 4. Audit Logging
 Record important operations
 Example: "User deleted 10 files at 14:32:15"


 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Log Level Classification                                                     │
 └──────────────────────────────────────────────────────────────────────────────┘

 Logs are classified into 4 levels based on importance:

 1. DEBUG (debugging)
 • Most detailed information
 • Used only during development
 • Disabled in production
 • Example: "Entered function parseGPSData()"

 2. INFO (informational)
 • General informational messages
 • Verify normal operation
 • Enabled in production
 • Example: "Video file loaded successfully"

 3. WARNING (warning)
 • Potential problems
 • Operation continues but attention needed
 • Example: "Low memory warning: 90% used"

 4. ERROR (error)
 • Serious problems
 • Feature operation failure
 • Requires immediate resolution
 • Example: "Failed to initialize decoder: file not found"


 Real Usage Example:
 ```swift
 func loadVideoFile(_ path: String) throws {
 debugLog("loadVideoFile() called with path: \(path)")

 guard FileManager.default.fileExists(atPath: path) else {
 errorLog("File not found: \(path)")
 throw FileError.notFound
 }

 infoLog("File found, starting to load...")

 if memoryUsage > 0.9 {
 warningLog("High memory usage: \(memoryUsage * 100)%")
 }

 // ... loading logic ...

 infoLog("Video file loaded successfully")
 }
 ```
 */

import Foundation
import Combine

// MARK: - LogEntry Structure

/// @struct LogEntry
/// @brief Individual log entry (Timestamp + message + level)
///
/// This structure represents a single log message.
///
/// - Note: Identifiable Protocol
///   Required to uniquely identify each item in SwiftUI's List or ForEach.
///   The id property automatically creates a UUID for each log entry.
///
/// - Important: Reasons for using a struct
///   • Value Type: Creates independent values when copied → thread-safe
///   • Immutability: Logs cannot be changed once created → data integrity
///   • Lightweight: More memory efficient than classes
///
/// Usage Example:
/// ```swift
/// let entry = LogEntry(
///     timestamp: Date(),
///     message: "Video started",
///     level: .info
/// )
///
/// // Usage in SwiftUI
/// List(logs) { entry in  // id automatically used
///     Text(entry.formattedMessage)
/// }
/// ```
///
/// - SeeAlso: `LogManager`, `LogLevel`
struct LogEntry: Identifiable {
    // MARK: Properties

    /// @var id
    /// @brief Unique identifier (for SwiftUI List)
    ///
    /// UUID: Universally Unique Identifier
    /// - 128-bit number
    /// - Collision probability: 1/(2^128) ≈ 0% (virtually impossible)
    /// - Example: "550e8400-e29b-41d4-a716-446655440000"
    ///
    /// Why use UUID?
    /// - Timestamp alone cannot distinguish logs created in the same millisecond
    /// - Array indices change when items are deleted
    /// - UUID is a permanent identifier that never changes
    let id = UUID()

    /// @var timestamp
    /// @brief Log creation time
    ///
    /// Date type:
    /// - Represents a specific point in time
    /// - Internally stored as seconds elapsed from 2001-01-01 00:00:00 UTC
    /// - Includes timezone information (automatic conversion possible)
    ///
    /// Usage Example:
    /// ```swift
    /// let now = Date()  // current time
    /// let formatter = DateFormatter()
    /// formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    /// print(formatter.string(from: now))  // "2025-01-10 14:30:25"
    /// ```
    let timestamp: Date

    /// @var message
    /// @brief Log message content
    ///
    /// Log message writing guidelines:
    /// 1. Be clear and specific
    ///    Bad Example: "Error occurred"
    ///    Good Example: "Failed to decode video frame 1523: codec not supported"
    ///
    /// 2. Include context
    ///    Bad Example: "File loaded"
    ///    Good Example: "Loaded video.mp4 (1920x1080, 60fps, 5 channels)"
    ///
    /// 3. Include important values
    ///    Example: "Memory usage: 85% (1.2GB / 1.4GB)"
    let message: String

    /// @var level
    /// @brief Log level (DEBUG, INFO, WARNING, ERROR)
    ///
    /// This value determines the importance of the log.
    /// - DEBUG: Detailed information for developers
    /// - INFO: General information
    /// - WARNING: Attention needed
    /// - ERROR: Serious problem
    ///
    /// Usage Example:
    /// ```swift
    /// switch entry.level {
    /// case .debug:
    ///     color = .gray
    /// case .info:
    ///     color = .blue
    /// case .warning:
    ///     color = .orange
    /// case .error:
    ///     color = .red
    /// }
    /// ```
    let level: LogLevel

    // MARK: Computed Properties

    /// @var formattedMessage
    /// @brief Formatted log message string
    ///
    /// Output format: "[HH:mm:ss.SSS] [LEVEL] message"
    /// Example: "[14:30:25.123] [INFO] Video file loaded"
    ///
    /// - Returns: Complete log string including timestamp, level, and message
    ///
    /// - Note: Computed property
    ///   Not stored; recalculated every time it's called.
    ///   Consider caching if performance is critical, as DateFormatter is created each time.
    ///
    /// DateFormatter explanation:
    /// ```swift
    /// let formatter = DateFormatter()
    /// formatter.dateFormat = "HH:mm:ss.SSS"
    /// // HH: 24-hour format hour (00-23)
    /// // mm: minutes (00-59)
    /// // ss: seconds (00-59)
    /// // SSS: milliseconds (000-999)
    ///
    /// let now = Date()
    /// formatter.string(from: now)  // "14:30:25.123"
    /// ```
    ///
    /// Various date format examples:
    /// - "yyyy-MM-dd" → "2025-01-10"
    /// - "yyyy-MM-dd HH:mm:ss" → "2025-01-10 14:30:25"
    /// - "HH:mm:ss" → "14:30:25"
    /// - "a hh:mm:ss" → "PM 02:30:25"
    var formattedMessage: String {
        // Create DateFormatter
        // - Tool for converting Date to String
        // - Considers locale (region), timezone, etc. for formatting
        let formatter = DateFormatter()

        // Specify date format
        // HH:mm:ss.SSS = 14:30:25.123 format
        formatter.dateFormat = "HH:mm:ss.SSS"

        // Convert Date → String
        let timeString = formatter.string(from: timestamp)

        // Final format: [time] [level] message
        // Example: "[14:30:25.123] [INFO] Video loaded"
        return "[\(timeString)] [\(level.displayName)] \(message)"
    }
}

// MARK: - LogLevel Enumeration

/// @enum LogLevel
/// @brief Log level enumeration
///
/// Classifies log messages into 4 levels of importance.
///
/// - Note: String rawValue
///   Each case has a corresponding string value.
///   Example: LogLevel.debug.rawValue → "DEBUG"
///
/// - Important: Reasons for using enumeration
///   1. Type safety: Prevents typos (Example: "DEBG" is impossible)
///   2. Auto-completion: Xcode suggests possible values
///   3. Switch exhaustiveness: Forces handling of all cases
///   4. Easy to extend: Simple to add new levels
///
/// Usage Example:
/// ```swift
/// // Type safety
/// log("Message", level: .info)  // ✓ Correct
/// log("Message", level: "info")  // ✗ Compile error
///
/// // Switch exhaustiveness check
/// switch level {
/// case .debug: ...
/// case .info: ...
/// case .warning: ...
/// case .error: ...
/// // Compile error if all cases are not handled
/// }
/// ```
enum LogLevel: String {
    /// @brief DEBUG level: Detailed debugging information
    ///
    /// When to use:
    /// - Track function entry/exit
    /// - Print variable values
    /// - Check internal state
    /// - Enable only during development
    ///
    /// Example:
    /// ```swift
    /// debugLog("Entering parseGPSData()")
    /// debugLog("GPS points count: \(points.count)")
    /// debugLog("Current state: \(state)")
    /// ```
    case debug = "DEBUG"

    /// @brief INFO level: General information message
    ///
    /// When to use:
    /// - Main task completion
    /// - Verify normal operation
    /// - Record user actions
    /// - Enable in production as well
    ///
    /// Example:
    /// ```swift
    /// infoLog("Application started")
    /// infoLog("Video file loaded: video.mp4")
    /// infoLog("User opened settings")
    /// ```
    case info = "INFO"

    /// @brief WARNING level: Potential problem warning
    ///
    /// When to use:
    /// - Abnormal but not critical situations
    /// - Potential performance degradation
    /// - Resource shortage warnings
    /// - Discouraged usage patterns
    ///
    /// Example:
    /// ```swift
    /// warningLog("Low memory: 90% used")
    /// warningLog("Deprecated API used")
    /// warningLog("Network latency high: 500ms")
    /// ```
    case warning = "WARNING"

    /// @brief ERROR level: Serious error
    ///
    /// When to use:
    /// - Feature operation failure
    /// - Exception occurred
    /// - Unrecoverable situation
    /// - Immediate action required
    ///
    /// Example:
    /// ```swift
    /// errorLog("Failed to open file: \(error)")
    /// errorLog("Database connection lost")
    /// errorLog("Out of memory")
    /// ```
    case error = "ERROR"

    /// @var displayName
    /// @brief Level name for screen display
    ///
    /// Returns rawValue as is.
    /// Can be localized if needed:
    /// ```swift
    /// var displayName: String {
    ///     switch self {
    ///     case .debug: return "Debug"
    ///     case .info: return "Info"
    ///     case .warning: return "Warning"
    ///     case .error: return "Error"
    ///     }
    /// }
    /// ```
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - LogManager Class

/// @class LogManager
/// @brief Centralized log manager
///
/// Uses Singleton pattern with a single instance throughout the application.
///
/// - Note: ObservableObject
///   Core protocol of SwiftUI and Combine frameworks.
///   UI automatically updates when @Published properties change.
///
/// - Important: Reasons for using a class
///   • Reference Type: Same instance shared throughout the app
///   • ObservableObject: Structs cannot be ObservableObject
///   • Singleton: Prevents creation of multiple instances
///
/// ┌─────────────────────────────────────────────────────────────────────────┐
/// │ What is the Singleton Pattern?                                           │
/// ├─────────────────────────────────────────────────────────────────────────┤
/// │                                                                         │
/// │ A design pattern that ensures only one instance of a class is created   │
/// │                                                                         │
/// │ Implementation:                                                         │
/// │   static let shared = LogManager()  // Single unique instance          │
/// │   private init() {}                 // Prevent external creation       │
/// │                                                                         │
/// │ Usage:                                                                  │
/// │   LogManager.shared.log("message")  // Always use same instance        │
/// │   let logger = LogManager()         // ✗ Compile error (init private) │
/// │                                                                         │
/// │ Why use Singleton?                                                      │
/// │   1. Global access: Can log from anywhere                              │
/// │   2. Memory efficiency: Maintain only one log array                    │
/// │   3. Consistency: All logs managed in one place                        │
/// │   4. Thread-safe: Centralized synchronization                          │
/// │                                                                         │
/// └─────────────────────────────────────────────────────────────────────────┘
///
/// Usage in SwiftUI:
/// ```swift
/// struct DebugView: View {
///     @ObservedObject var logger = LogManager.shared
///
///     var body: some View {
///         List(logger.logs) { log in
///             Text(log.formattedMessage)
///                 .foregroundColor(colorForLevel(log.level))
///         }
///     }
/// }
/// ```
///
/// - SeeAlso: `LogEntry`, `LogLevel`
class LogManager: ObservableObject {

    // MARK: - Singleton Instance

    /// @var shared
    /// @brief Shared instance (Singleton)
    ///
    /// static: Type-level property (belongs to class, independent of instances)
    /// let: Constant (cannot be changed after initialization)
    ///
    /// Usage Example:
    /// ```swift
    /// LogManager.shared.log("Hello")  // Can be used anywhere
    ///
    /// // Incorrect usage
    /// let logger1 = LogManager()  // ✗ Impossible because init is private
    /// ```
    static let shared = LogManager()

    // MARK: - Published Properties

    /// @var logs
    /// @brief Log entries array (real-time reflection in UI)
    ///
    /// @Published:
    /// - Property Wrapper from Combine framework
    /// - Automatically publishes notifications whenever value changes
    /// - SwiftUI receives notifications and automatically updates UI
    ///
    /// private(set):
    /// - Read is public, write is private
    /// - External code can only read, modifications only from within class
    /// - Guarantees data integrity
    ///
    /// How it works:
    /// ```
    /// logs.append(entry)  →  @Published detects change
    ///                    ↓
    ///            objectWillChange event published
    ///                    ↓
    ///          SwiftUI receives event
    ///                    ↓
    ///            body re-executed (re-render)
    /// ```
    ///
    /// Usage Example:
    /// ```swift
    /// // Read (possible from anywhere)
    /// let count = LogManager.shared.logs.count  // ✓
    ///
    /// // Write (not possible externally)
    /// LogManager.shared.logs.append(...)  // ✗ Compile error
    ///
    /// // Write only through methods
    /// LogManager.shared.log("message")  // ✓
    /// ```
    @Published private(set) var logs: [LogEntry] = []

    // MARK: - Private Properties

    /// @var maxLogs
    /// @brief Maximum log count (circular buffer)
    ///
    /// Why is a limit necessary?
    /// - Unlimited storage can cause out of memory errors
    /// - Older logs have lower importance
    /// - Prevents UI rendering performance degradation
    ///
    /// Circular Buffer:
    /// ```
    /// Example with maximum of 3 entries:
    ///
    /// [A]           → Add A
    /// [A, B]        → Add B
    /// [A, B, C]     → Add C (buffer full)
    /// [B, C, D]     → Add D (delete A, oldest entry)
    /// [C, D, E]     → Add E (delete B)
    /// ```
    ///
    /// Reasons for choosing 500:
    /// - Sufficient for typical debugging sessions
    /// - Memory usage: ~100KB (approximately 200 bytes per log)
    /// - Minimal UI rendering burden
    private let maxLogs = 500

    /// @var lock
    /// @brief Lock for thread safety
    ///
    /// NSLock:
    /// - Protects shared resources in multi-threaded environment
    /// - Allows only one thread access at a time
    /// - Prevents data races
    ///
    /// ┌─────────────────────────────────────────────────────────────────────┐
    /// │ Data Race Example                                                    │
    /// ├─────────────────────────────────────────────────────────────────────┤
    /// │                                                                     │
    /// │ Without NSLock:                                                      │
    /// │                                                                     │
    /// │ Thread A: logs.append(entry1)                                       │
    /// │           └─ Check logs count: 499                                  │
    /// │           └─ Start adding entry1 at position 500...                 │
    /// │                                                                     │
    /// │ Thread B: logs.append(entry2)  (simultaneously!)                   │
    /// │           └─ Check logs count: 499  (A not finished yet)            │
    /// │           └─ Start adding entry2 at position 500...                 │
    /// │                                                                     │
    /// │ Result: 💥 Collision! One of entry1 or entry2 is lost!              │
    /// │                                                                     │
    /// │ ────────────────────────────────────────────────────────────────── │
    /// │                                                                     │
    /// │ With NSLock:                                                         │
    /// │                                                                     │
    /// │ Thread A: lock.lock()     // 🔒 Lock                                 │
    /// │           logs.append(entry1)                                        │
    /// │           lock.unlock()   // 🔓 Unlock                               │
    /// │                                                                     │
    /// │ Thread B: lock.lock()     // ⏳ Wait until A finishes...             │
    /// │           logs.append(entry2)  // Execute after A completes         │
    /// │           lock.unlock()                                              │
    /// │                                                                     │
    /// │ Result: ✓ Safe! Processed sequentially                              │
    /// │                                                                     │
    /// └─────────────────────────────────────────────────────────────────────┘
    ///
    /// Usage pattern:
    /// ```swift
    /// lock.lock()        // Acquire lock
    /// defer {
    ///     lock.unlock()  // Automatically release on function exit
    /// }
    /// // Code to protect
    /// logs.append(entry)
    /// ```
    private let lock = NSLock()

    // MARK: - Initialization

    /// @brief Private initialization method (Singleton pattern)
    ///
    /// private:
    /// - Cannot be created externally
    /// - Attempting LogManager() to create new instance causes compile error
    /// - Only the shared instance can be used
    ///
    /// Why is init empty?
    /// - All properties have default values
    /// - logs = [] (empty array)
    /// - maxLogs = 500 (constant)
    /// - lock = NSLock() (automatic initialization)
    /// - No additional initialization logic needed
    private init() {}

    // MARK: - Public Methods

    /// @brief Record log message
    ///
    /// This method is implemented to be thread-safe.
    /// Safe to call simultaneously from multiple threads.
    ///
    /// @param message Log message to record
    /// @param level Log level (default value: .info)
    ///
    /// - Note: Default Parameters
    ///   level = .info is a default parameter.
    ///   Automatically uses .info if omitted.
    ///   ```swift
    ///   log("Hello")              // level .info
    ///   log("Error", level: .error)  // level .error
    ///   ```
    ///
    /// - Important: Operation sequence
    ///   1. Create LogEntry (record current time)
    ///   2. Acquire lock (block other threads)
    ///   3. Add to logs array
    ///   4. Delete oldest log if exceeds 500
    ///   5. Release lock (allow other threads)
    ///   6. Print to console (for debugging)
    ///
    /// Usage Example:
    /// ```swift
    /// // Basic usage (INFO level)
    /// LogManager.shared.log("Video loaded")
    ///
    /// // Explicit level specification
    /// LogManager.shared.log("Low memory", level: .warning)
    /// LogManager.shared.log("File not found", level: .error)
    ///
    /// // Use convenience functions (recommended)
    /// infoLog("Video loaded")
    /// warningLog("Low memory")
    /// errorLog("File not found")
    /// ```
    func log(_ message: String, level: LogLevel = .info) {
        // 1. Create LogEntry
        // - Automatically record current time
        // - Save message and level
        let entry = LogEntry(timestamp: Date(), message: message, level: level)

        // 2. Start thread-safe section
        lock.lock()

        // 3. Add log
        // - SwiftUI automatically detects because of @Published
        // - UI automatically updates
        logs.append(entry)

        // 4. Maintain circular buffer (maximum 500)
        // Delete oldest log when exceeds 500
        if logs.count > maxLogs {
            // removeFirst: delete from beginning of array
            // logs.count - maxLogs: delete excess count
            // Example: 505 → delete 5 → maintain 500
            logs.removeFirst(logs.count - maxLogs)
        }

        // 5. End thread-safe section
        lock.unlock()

        // 6. Console output (for additional debugging)
        // - Display immediately in Xcode console
        // - Fast debugging even without UI
        // - Consider conditional disabling in production
        print("[\(level.displayName)] \(message)")
    }

    /// @brief Clear all logs
    ///
    /// Called from UI's "Clear logs" button.
    ///
    /// - Note: Thread-safe
    ///   Protected by lock, safe to call clear() while logging.
    ///
    /// - Important: @Published behavior
    ///   @Published detects change when logs.removeAll() is called
    ///   → SwiftUI automatically updates UI (log list emptied)
    ///
    /// Usage Example:
    /// ```swift
    /// // SwiftUI button
    /// Button("Clear Logs") {
    ///     LogManager.shared.clear()
    /// }
    ///
    /// // Pre-test initialization
    /// override func setUpWithError() throws {
    ///     LogManager.shared.clear()  // Delete logs from previous tests
    /// }
    /// ```
    func clear() {
        // Thread-safe section
        lock.lock()

        // Delete all logs
        // - removeAll() makes array empty
        // - Memory immediately released
        logs.removeAll()

        lock.unlock()
    }
}

// MARK: - Convenience Functions

/*
 ┌──────────────────────────────────────────────────────────────────────────────┐
 │ Global Convenience Functions                                                 │
 └──────────────────────────────────────────────────────────────────────────────┘

 Instead of LogManager.shared.log("message", level: .debug)
 you can simply use debugLog("message").

 Advantages:
 1. Less typing (4 lines → 1 line)
 2. Improved readability
 3. Easy refactoring (internal implementation changes don't affect usage code)

 Comparison:
 ```swift
 // Basic approach (verbose)
 LogManager.shared.log("Starting process", level: .debug)
 LogManager.shared.log("Process complete", level: .info)
 LogManager.shared.log("Low memory", level: .warning)
 LogManager.shared.log("Failed", level: .error)

 // Convenience functions (concise)
 debugLog("Starting process")
 infoLog("Process complete")
 warningLog("Low memory")
 errorLog("Failed")
 ```
 */

/// @brief Record DEBUG level log
///
/// Record detailed debugging information during development.
/// Recommended to disable in production.
///
/// @param message log message
///
/// Usage Example:
/// ```swift
/// func parseGPSData(_ data: Data) {
///     debugLog("Entering parseGPSData, data size: \(data.count)")
///
///     let points = extractPoints(data)
///     debugLog("Extracted \(points.count) GPS points")
///
///     debugLog("Exiting parseGPSData")
/// }
/// ```
func debugLog(_ message: String) {
    LogManager.shared.log(message, level: .debug)
}

/// @brief Record INFO level log
///
/// Record general informational messages.
/// Enable in production to verify normal operation.
///
/// @param message log message
///
/// Usage Example:
/// ```swift
/// func loadVideoFile(_ path: String) throws {
///     infoLog("Loading video file: \(path)")
///
///     let file = try load(path)
///     infoLog("Video loaded: \(file.duration)s, \(file.channelCount) channels")
/// }
/// ```
func infoLog(_ message: String) {
    LogManager.shared.log(message, level: .info)
}

/// @brief Record WARNING level log
///
/// Record potential problems or situations requiring attention.
/// Operation continues but action may be needed.
///
/// @param message log message
///
/// Usage Example:
/// ```swift
/// func allocateBuffer() {
///     let memoryUsage = getMemoryUsage()
///     if memoryUsage > 0.9 {
///         warningLog("High memory usage: \(memoryUsage * 100)%")
///     }
///
///     if bufferSize > recommendedSize {
///         warningLog("Buffer size exceeds recommended: \(bufferSize)MB")
///     }
/// }
/// ```
func warningLog(_ message: String) {
    LogManager.shared.log(message, level: .warning)
}

/// @brief Record ERROR level log
///
/// Record serious errors or failure situations.
/// Problems requiring immediate action.
///
/// @param message log message
///
/// Usage Example:
/// ```swift
/// func initializeDecoder() throws {
///     do {
///         try decoder.initialize()
///     } catch {
///         errorLog("Failed to initialize decoder: \(error.localizedDescription)")
///         throw error
///     }
/// }
/// ```
func errorLog(_ message: String) {
    LogManager.shared.log(message, level: .error)
}
