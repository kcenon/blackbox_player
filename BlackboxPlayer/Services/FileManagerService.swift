/// @file FileManagerService.swift
/// @brief Service for managing video files (favorites, notes, deletion)
/// @author BlackboxPlayer Development Team
/// @details Service for managing video file metadata and operations

/*
 ┌──────────────────────────────────────────────────────────────────────────┐
 │                     FileManagerService Overview                          │
 │                                                                          │
 │  This service is the core service responsible for managing metadata     │
 │  and file operations for blackbox video files.                          │
 │                                                                          │
 │  【Key Features】                                                        │
 │  1. Favorites Management                                                 │
 │     - Persistent storage using UserDefaults                             │
 │     - Duplicate-free ID management using Set<String> structure          │
 │                                                                          │
 │  2. Notes Management                                                     │
 │     - Text note storage per video file                                  │
 │     - Dictionary<UUID, String> structure                                │
 │                                                                          │
 │  3. File Operations                                                      │
 │     - Delete: Remove all channel files                                  │
 │     - Move: Move files to different directory                           │
 │     - Export: Copy to external location                                 │
 │                                                                          │
 │  4. Cache Management                                                     │
 │     - In-memory VideoFile cache                                         │
 │     - 5-minute expiration time, 1000 items size limit                   │
 │     - Thread safety guaranteed by NSLock                                │
 │                                                                          │
 │  5. Batch Operations                                                     │
 │     - Set favorites for multiple files                                  │
 │     - Delete multiple files and collect errors                          │
 │                                                                          │
 │  【Architecture Position】                                               │
 │                                                                          │
 │  Views (ContentView, MultiChannelPlayerView)                            │
 │    │                                                                     │
 │    ├─▶ FileManagerService ◀── This file                                 │
 │    │     │                                                               │
 │    │     ├─▶ UserDefaults (persistent storage for favorites, notes)    │
 │    │     ├─▶ FileManager (file system operations)                       │
 │    │     └─▶ NSLock (cache concurrent access control)                   │
 │    │                                                                     │
 │    └─▶ FileScanner (file search)                                        │
 │        └─▶ MetadataExtractor (metadata extraction)                      │
 │                                                                          │
 │  【Data Flow】                                                           │
 │                                                                          │
 │  User Action                                                             │
 │      │                                                                   │
 │      ├── Toggle favorite                                                │
 │      │      └─▶ setFavorite() → Save to UserDefaults                    │
 │      │                                                                   │
 │      ├── Write note                                                     │
 │      │      └─▶ setNote() → Save to UserDefaults                        │
 │      │                                                                   │
 │      ├── Delete file                                                    │
 │      │      └─▶ deleteVideoFile() → FileManager.removeItem()            │
 │      │                                                                   │
 │      └── Move/Export file                                               │
 │             └─▶ moveVideoFile() / exportVideoFile()                     │
 │                                                                          │
 └──────────────────────────────────────────────────────────────────────────┘

 【What is UserDefaults?】

 UserDefaults is a simple key-value storage provided by iOS/macOS.
 It is used to permanently store app settings or small data.

 ┌────────────────────────────────────────────────┐
 │  UserDefaults (persists after app termination) │
 │  ┌──────────────────────────────────────────┐  │
 │  │ Key: "com.blackboxplayer.favorites"      │  │
 │  │ Value: ["uuid-1", "uuid-2", "uuid-3"]    │  │
 │  │                                          │  │
 │  │ Key: "com.blackboxplayer.notes"          │  │
 │  │ Value: {                                 │  │
 │  │   "uuid-1": "Highway accident video",    │  │
 │  │   "uuid-2": "Parking lot collision"      │  │
 │  │ }                                        │  │
 │  └──────────────────────────────────────────┘  │
 └────────────────────────────────────────────────┘

 Advantages:
 - Simple API (set, get methods)
 - Automatic serialization/deserialization
 - Data persists after app restart

 Disadvantages:
 - Not suitable for large data (recommended under a few KB)
 - Complex queries not possible
 - Thread-safe but slow

 Usage example:
 ```swift
 // Save
 userDefaults.set(["uuid-1", "uuid-2"], forKey: "favorites")

 // Load
 let favorites = userDefaults.array(forKey: "favorites") as? [String]

 // Delete
 userDefaults.removeObject(forKey: "favorites")
 ```

 【What is NSLock?】

 NSLock is a locking mechanism that prevents multiple threads from accessing
 the same data simultaneously. Also known as "Mutex".

 ┌──────────────────────────────────────────────────────────┐
 │  Cache Dictionary (shared resource)                      │
 │  fileCache: [String: CachedFileInfo]                     │
 │                                                          │
 │  Thread A           NSLock          Thread B             │
 │     │                │                │                  │
 │     ├─ lock() ──────▶│◀───────────────┤ (waiting...)    │
 │     │                │                │                  │
 │     ├─ Read cache    │                │                  │
 │     │                │                │                  │
 │     ├─ unlock() ─────▶│                │                  │
 │     │                │                │                  │
 │     │                │◀─── lock() ────┤                  │
 │     │                │                │                  │
 │     │                │                ├─ Write cache    │
 │     │                │                │                  │
 │     │                │◀─── unlock() ──┤                  │
 └──────────────────────────────────────────────────────────┘

 Why is it needed?
 - SwiftUI operates in a multi-threaded environment
 - Main thread (UI) and background threads (file I/O) access cache simultaneously
 - Concurrent access can corrupt data (Race Condition)

 Usage pattern:
 ```swift
 cacheLock.lock()         // 1. Acquire lock (other threads wait)
 defer { cacheLock.unlock() }  // 2. Auto-release on function exit

 // 3. Safely access cache
 fileCache[key] = value
 ```

 Importance of defer:
 - Guarantees unlock() even if function exits early via return or throw
 - Without releasing lock, other threads wait forever (deadlock)

 【Cache LRU (Least Recently Used) Strategy】

 When cache size exceeds the limit (1000 items), removes the oldest 20% of entries.

 ┌──────────────────────────────────────────────────────────┐
 │  Cache State (1000 items)                                │
 │  ┌───────────────────────────────────────────────────┐   │
 │  │ Key         │ CachedAt                            │   │
 │  ├───────────────────────────────────────────────────┤   │
 │  │ file_001.mp4│ 2025-01-15 10:00:00 ◀── Oldest      │   │
 │  │ file_002.mp4│ 2025-01-15 10:01:23                 │   │
 │  │ file_003.mp4│ 2025-01-15 10:02:45                 │   │
 │  │ ...         │ ...                                 │   │
 │  │ file_999.mp4│ 2025-01-15 14:58:12                 │   │
 │  │ file_1000.mp4│2025-01-15 15:00:00 ◀── Newest      │   │
 │  └───────────────────────────────────────────────────┘   │
 │                                                          │
 │  When adding new item (becomes 1001 items)               │
 │  ↓                                                       │
 │  1. Sort by cachedAt                                     │
 │  2. Remove oldest 200 items (20%)                        │
 │  3. Add new item (total becomes 801 items)               │
 └──────────────────────────────────────────────────────────┘

 Why remove 20%?
 - Remove many at once to reduce removal frequency
 - Minimize CPU overhead
 - Secure memory headroom

 Cache expiration time (5 minutes):
 - File metadata doesn't change frequently
 - Saves disk I/O if re-accessed within 5 minutes
 - Reloads latest information after 5 minutes
 */

import Foundation

/*
 【FileManagerService Class】

 Service for managing video file metadata and file system operations.

 Key Responsibilities:
 1. Manage favorite status (isFavorite)
 2. Manage per-file notes (notes)
 3. File deletion/move/export
 4. VideoFile information caching (performance optimization)
 5. Batch operation support (simultaneous processing of multiple files)

 Design Patterns:
 - **Service Layer Pattern**: Separates business logic from View
 - **Repository Pattern**: Abstracts data storage (UserDefaults)
 - **Cache Pattern**: Keeps frequently used data in memory

 Dependencies:
 - UserDefaults: Persistent storage for favorites/notes
 - FileManager: File system operations (delete/move/copy)
 - NSLock: Protects cache in multi-threaded environment
 */
/// @class FileManagerService
/// @brief Service for managing video file metadata and operations
/// @details Service for managing video file metadata and file system operations.
class FileManagerService {
    // MARK: - Properties

    /*
     【UserDefaults Instance】

     Key-value storage for permanently storing app settings and small data.

     Storage Location:
     - macOS: ~/Library/Preferences/[BundleID].plist
     - iOS: /Library/Preferences/[BundleID].plist

     Stored Data:
     1. favorites: Array of favorited video file UUIDs
     2. notes: Dictionary of video file UUID → note text

     Features:
     - Data persists after app termination
     - Auto-synchronization (changes immediately saved to disk)
     - Thread-safe (concurrent access from multiple threads)
     */
    /// @var userDefaults
    /// @brief UserDefaults instance for persistent storage
    private let userDefaults: UserDefaults

    /*
     【UserDefaults Keys】

     UserDefaults is a key-value store, so keys are needed for saving/loading data.

     Reverse Domain Notation:
     - "com.blackboxplayer.favorites"
     - Includes app identifier to prevent conflicts with other apps/libraries
     - Apple's recommended naming convention

     Example:
     ```swift
     // Save
     userDefaults.set(["uuid-1"], forKey: "com.blackboxplayer.favorites")

     // Load
     let favorites = userDefaults.array(forKey: "com.blackboxplayer.favorites")
     ```

     Why declare as constants?
     - Prevents typos (compile-time checking)
     - Only one place to modify when changing keys
     - Supports code auto-completion
     */
    /// @var favoritesKey
    /// @brief UserDefaults key for favorites storage
    private let favoritesKey = "com.blackboxplayer.favorites"
    /// @var notesKey
    /// @brief UserDefaults key for notes storage
    private let notesKey = "com.blackboxplayer.notes"

    /*
     【File Information Cache】

     Caches VideoFile objects in memory to reduce repetitive file I/O.

     Structure:
     - Key: File path (String) - e.g., "/path/to/video.mp4"
     - Value: CachedFileInfo - VideoFile + cached time

     Cache Settings:
     - maxCacheAge: 5 minutes (300 seconds) - expires after this time
     - maxCacheSize: 1000 items - maximum cache entries

     Cache Hit vs Miss:
     ┌───────────────────────────────────────────┐
     │  Request: "/videos/event/20250115_100000.mp4"│
     │    ↓                                      │
     │  Is it in cache?                          │
     │    ├─ Yes & within 5 min → Cache hit (return) │
     │    ├─ Yes & over 5 min → Expired (reload) │
     │    └─ No → Cache miss (read file)        │
     └───────────────────────────────────────────┘

     Performance Impact:
     - Cache hit: 0.001s (memory lookup)
     - Cache miss: 0.1s (disk I/O + parsing)
     - 100x speed difference!
     */
    /// @var fileCache
    /// @brief File information cache
    private var fileCache: [String: CachedFileInfo] = [:]

    /*
     【NSLock - Lock for Thread Safety】

     fileCache can be accessed simultaneously from multiple threads.
     For example:
     - Main thread: Read cache from UI
     - Background thread: Write cache after file scan

     Concurrent Access Problem (Race Condition):
     ```
     Thread A                     Thread B
     fileCache[key] read (nil)
     fileCache[key] = value1
     fileCache[key] = value2

     Result: value1 is lost!
     ```

     Solution with NSLock:
     ```swift
     cacheLock.lock()  // Other threads wait here
     fileCache[key] = value
     cacheLock.unlock()  // Release lock
     ```

     Using defer pattern:
     ```swift
     cacheLock.lock()
     defer { cacheLock.unlock() }  // Auto-execute on function exit

     // Guarantees unlock() even with return or throw!
     if condition {
     return  // unlock() automatically called
     }
     ```
     */
    /// @var cacheLock
    /// @brief Lock for thread-safe cache access
    private let cacheLock = NSLock()

    /*
     【Cache Configuration Constants】

     maxCacheAge: 5 minutes (300 seconds)
     - Use cached data for 5 minutes
     - Re-read from file after 5 minutes
     - 5 minutes is appropriate since video metadata doesn't change often

     maxCacheSize: 1000 items
     - Stores about 1000 VideoFile objects (~10MB memory)
     - Removes oldest 20% (200 items) when exceeding 1000
     - Limits memory usage

     What is TimeInterval?
     - Swift's time interval type
     - Alias for Double (typealias TimeInterval = Double)
     - Expressed in seconds (300 = 300 seconds = 5 minutes)
     */
    /// @var maxCacheAge
    /// @brief Maximum cache age in seconds (5 minutes)
    private let maxCacheAge: TimeInterval = 300 // 5 minutes
    /// @var maxCacheSize
    /// @brief Maximum number of cached files
    private let maxCacheSize: Int = 1000 // Maximum cached files

    // MARK: - Initialization

    /*
     【Initialization Method】

     Creates a FileManagerService instance.

     Parameters:
     - userDefaults: UserDefaults instance (default: .standard)

     Default Value Pattern:
     ```swift
     init(userDefaults: UserDefaults = .standard)
     ```

     Usage Examples:
     ```swift
     // 1. Use default UserDefaults
     let service = FileManagerService()

     // 2. Use custom UserDefaults for testing
     let testDefaults = UserDefaults(suiteName: "test")!
     let testService = FileManagerService(userDefaults: testDefaults)
     ```

     Dependency Injection:
     - UserDefaults injected from outside
     - Allows using Mock UserDefaults for testing
     - Flexible configuration (app group UserDefaults, etc.)
     */
    /// @brief Initialize FileManagerService
    /// @param userDefaults UserDefaults instance for storage (default: .standard)
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Favorites

    /*
     【Check Favorite Method】

     Checks if the given video file is marked as favorite.

     Parameters:
     - videoFile: VideoFile object to check

     Return Value:
     - true: File is favorited
     - false: File is not favorited

     Operation Sequence:
     1. Load favorites Set from UserDefaults via loadFavorites()
     2. Check if videoFile.id.uuidString exists in Set
     3. Set's contains() has O(1) time complexity

     Set vs Array:
     - Set: contains() = O(1) - hash table
     - Array: contains() = O(n) - sequential search

     Usage Example:
     ```swift
     let service = FileManagerService()
     let videoFile = VideoFile(...)

     if service.isFavorite(videoFile) {
     print("⭐ This file is favorited")
     }
     ```
     */
    /// @brief Check if video file is marked as favorite
    /// @param videoFile VideoFile to check
    /// @return true if favorited
    func isFavorite(_ videoFile: VideoFile) -> Bool {
        let favorites = loadFavorites()  // Load Set<String> from UserDefaults
        return favorites.contains(videoFile.id.uuidString)  // O(1) time complexity
    }

    /*
     【Set Favorite Method】

     Changes the favorite status of a video file.

     Parameters:
     - videoFile: Target VideoFile object
     - isFavorite: Favorite status to set

     Operation Sequence:
     1. Load current favorites Set via loadFavorites()
     2. Add or remove from Set based on isFavorite value
     3. Save modified Set to UserDefaults via saveFavorites()

     Set Operations:
     - insert(): Auto-prevents duplicates (ignores if already exists)
     - remove(): Ignores if not exists (no error)

     Usage Examples:
     ```swift
     // Add to favorites
     service.setFavorite(videoFile, isFavorite: true)

     // Remove from favorites
     service.setFavorite(videoFile, isFavorite: false)

     // Toggle
     let currentState = service.isFavorite(videoFile)
     service.setFavorite(videoFile, isFavorite: !currentState)
     ```

     Persistence:
     - Saved to UserDefaults, persists after app termination
     - Auto-synchronization (written to disk immediately upon change)
     */
    /// @brief Set favorite status for video file
    /// @param videoFile VideoFile to update
    /// @param isFavorite New favorite status
    func setFavorite(_ videoFile: VideoFile, isFavorite: Bool) {
        var favorites = loadFavorites()  // Load current favorites Set

        if isFavorite {
            // Add to favorites: Convert UUID to String and insert into Set
            favorites.insert(videoFile.id.uuidString)
        } else {
            // Remove from favorites: Remove UUID String from Set
            favorites.remove(videoFile.id.uuidString)
        }

        saveFavorites(favorites)  // Save modified Set to UserDefaults
    }

    /*
     【Get All Favorites Method】

     Returns all video file IDs currently marked as favorites.

     Return Value:
     - Set<String>: Set of UUID strings for favorited video files

     Usage Examples:
     ```swift
     let favorites = service.getAllFavorites()
     print("Favorite count: \(favorites.count)")

     // Check if specific file is favorited
     if favorites.contains("some-uuid-string") {
     print("This is in favorites")
     }

     // Iterate through all favorite files
     for uuid in favorites {
     print("Favorite file ID: \(uuid)")
     }
     ```

     Why return a Set?
     - Guarantees no duplicates
     - Fast contains() operation (O(1))
     - Order is not important
     */
    /// @brief Get all favorited video file IDs
    /// @return Set of video file UUIDs
    func getAllFavorites() -> Set<String> {
        return loadFavorites()  // Load Set from UserDefaults
    }

    /*
     【Clear All Favorites Method】

     Deletes all saved favorite information.

     Operation:
     - Removes data corresponding to favoritesKey from UserDefaults
     - Completely deleted from disk as well

     Usage Example:
     ```swift
     // Delete after confirmation dialog
     let alert = NSAlert()
     alert.messageText = "Do you want to delete all favorites?"
     alert.addButton(withTitle: "Delete")
     alert.addButton(withTitle: "Cancel")

     if alert.runModal() == .alertFirstButtonReturn {
     service.clearAllFavorites()
     print("All favorites have been deleted")
     }
     ```

     Caution:
     - Irreversible operation
     - Recommended to get user confirmation
     - Useful for app reinstallation or data reset features
     */
    /// @brief Clear all favorites
    func clearAllFavorites() {
        userDefaults.removeObject(forKey: favoritesKey)  // Remove key from UserDefaults
    }

    // MARK: - Notes

    /*
     【Get Note Method】

     Retrieves the note saved for a specific video file.

     Parameters:
     - videoFile: VideoFile object to get note for

     Return Value:
     - String?: Saved note text (nil if none)

     Operation Sequence:
     1. Load [UUID: String] Dictionary via loadNotes()
     2. Query Dictionary using videoFile.id.uuidString as key
     3. Return value if exists, otherwise nil

     Dictionary Query:
     - notes[key] returns Optional<String>
     - Automatically returns nil if key doesn't exist

     Usage Examples:
     ```swift
     if let note = service.getNote(for: videoFile) {
     print("Note: \(note)")
     } else {
     print("No note")
     }

     // Using nil coalescing operator
     let displayNote = service.getNote(for: videoFile) ?? "No note"
     ```
     */
    /// @brief Get note for video file
    /// @param videoFile VideoFile to get note for
    /// @return Note text or nil if no note
    func getNote(for videoFile: VideoFile) -> String? {
        let notes = loadNotes()  // Load Dictionary from UserDefaults
        return notes[videoFile.id.uuidString]  // Query Dictionary (nil if not found)
    }

    /*
     【Set Note Method】

     Saves or deletes a note for a video file.

     Parameters:
     - videoFile: Target VideoFile object
     - note: Note text to save (deletes note if nil)

     Operation Sequence:
     1. Load current notes Dictionary via loadNotes()
     2. Add to Dictionary if note exists and is not empty
     3. Remove from Dictionary if note is nil or empty
     4. Save modified Dictionary to UserDefaults via saveNotes()

     Empty String Check:
     - isEmpty: Checks if length is 0
     - isEmpty = false if only whitespace exists
     - Remove whitespace: note.trimmingCharacters(in: .whitespacesAndNewlines)

     Usage Examples:
     ```swift
     // Add note
     service.setNote(for: videoFile, note: "Highway accident video")

     // Delete note (nil)
     service.setNote(for: videoFile, note: nil)

     // Delete note (empty string)
     service.setNote(for: videoFile, note: "")

     // Set note from user input
     let userInput = textField.stringValue
     service.setNote(for: videoFile, note: userInput.isEmpty ? nil : userInput)
     ```
     */
    /// @brief Set note for video file
    /// @param videoFile VideoFile to set note for
    /// @param note Note text or nil to remove
    func setNote(for videoFile: VideoFile, note: String?) {
        var notes = loadNotes()  // Load current notes Dictionary

        if let note = note, !note.isEmpty {
            // Add to Dictionary if note exists and is not empty
            notes[videoFile.id.uuidString] = note
        } else {
            // Remove from Dictionary if note is nil or empty string
            notes.removeValue(forKey: videoFile.id.uuidString)
        }

        saveNotes(notes)  // Save modified Dictionary to UserDefaults
    }

    /*
     【Get All Notes Method】

     Returns notes for all saved video files.

     Return Value:
     - [String: String]: UUID → note text Dictionary

     Usage Examples:
     ```swift
     let allNotes = service.getAllNotes()
     print("Total notes: \(allNotes.count)")

     // Iterate through all notes
     for (uuid, note) in allNotes {
     print("File \(uuid): \(note)")
     }

     // Check note for specific UUID
     if let note = allNotes["some-uuid-string"] {
     print("Note: \(note)")
     }
     ```

     Use Cases:
     - Filter files with notes
     - Note search functionality
     - Display statistics (count of files with notes)
     */
    /// @brief Get all notes
    /// @return Dictionary of video file UUID to note
    func getAllNotes() -> [String: String] {
        return loadNotes()  // Load Dictionary from UserDefaults
    }

    /*
     【Clear All Notes Method】

     Deletes all saved notes.

     Operation:
     - Removes data corresponding to notesKey from UserDefaults
     - Completely deleted from disk as well

     Usage Example:
     ```swift
     // Delete after confirmation dialog
     let alert = NSAlert()
     alert.messageText = "Do you want to delete all notes?"
     alert.addButton(withTitle: "Delete")
     alert.addButton(withTitle: "Cancel")

     if alert.runModal() == .alertFirstButtonReturn {
     service.clearAllNotes()
     print("All notes have been deleted")
     }
     ```

     Caution:
     - Irreversible operation
     - Recommended to get user confirmation
     - Useful for app reinstallation or data reset features
     */
    /// @brief Clear all notes
    func clearAllNotes() {
        userDefaults.removeObject(forKey: notesKey)  // Remove key from UserDefaults
    }

    // MARK: - File Operations

    /*
     【Delete Video File Method】

     Deletes all channels of a video file from disk and removes related metadata (favorites, notes).

     Parameters:
     - videoFile: VideoFile object to delete

     Throws:
     - Error: Thrown if file deletion fails

     Operation Sequence:
     1. Obtain FileManager instance
     2. Iterate through all channel files
     3. Check existence and delete each file
     4. Remove from favorites
     5. Remove notes

     Channel File Example:
     ```
     videoFile.channels = [
     ChannelInfo(filePath: "/videos/20250115_100000_F.mp4"),  // Front
     ChannelInfo(filePath: "/videos/20250115_100000_R.mp4"),  // Rear
     ]
     ```

     Error Handling:
     ```swift
     do {
     try service.deleteVideoFile(videoFile)
     print("File has been deleted")
     } catch {
     print("Deletion failed: \(error.localizedDescription)")
     }
     ```

     FileManager.removeItem(atPath:):
     - Deletes file or directory
     - Throws error if file doesn't exist
     - Deletes all contents if directory
     */
    /// @brief Delete video file and all its channels
    /// @param videoFile VideoFile to delete
    /// @throws Error if deletion fails
    func deleteVideoFile(_ videoFile: VideoFile) throws {
        let fileManager = FileManager.default  // FileManager for file system operations

        // Delete all channel files
        // Iterate through and delete all channel files
        for channel in videoFile.channels {
            let filePath = channel.filePath  // Extract channel file path

            // Check if file exists
            if fileManager.fileExists(atPath: filePath) {
                // Delete file if it exists (throws on error)
                try fileManager.removeItem(atPath: filePath)
            }
        }

        // Remove from favorites and notes
        // Also remove from favorites and notes
        setFavorite(videoFile, isFavorite: false)  // Unmark favorite
        setNote(for: videoFile, note: nil)  // Delete note
    }

    /*
     【Move Video File Method】

     Moves all channels of a video file to a different directory and returns the updated VideoFile with new paths.

     Parameters:
     - videoFile: VideoFile object to move
     - destinationURL: Destination directory URL

     Return Value:
     - VideoFile: VideoFile object updated with new paths

     Throws:
     - Error: Thrown if file move fails

     Operation Sequence:
     1. Create destination directory if it doesn't exist
     2. Move each channel file to new location
     3. Create ChannelInfo objects with new paths
     4. Create VideoFile object with new channel array
     5. Return updated VideoFile

     Usage Example:
     ```swift
     let sourceFile = VideoFile(basePath: "/videos/event/")
     let destination = URL(fileURLWithPath: "/videos/archive/")

     do {
     let movedFile = try service.moveVideoFile(sourceFile, to: destination)
     print("File moved to: \(movedFile.basePath)")
     } catch {
     print("Move failed: \(error.localizedDescription)")
     }
     ```

     Move vs Copy:
     - moveItem(): Deletes original, fast
     - copyItem(): Keeps original, slow

     Directory Creation:
     - createDirectory(withIntermediateDirectories: true)
     - Automatically creates intermediate directories (creates /a, /a/b when creating /a/b/c)
     */
    /// @brief Move video file to different directory
    /// @param videoFile VideoFile to move
    /// @param destinationURL Destination directory URL
    /// @return Updated VideoFile with new paths
    /// @throws Error if move fails
    func moveVideoFile(_ videoFile: VideoFile, to destinationURL: URL) throws -> VideoFile {
        let fileManager = FileManager.default  // FileManager for file system operations

        // Create destination directory if needed
        // Create destination directory if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true  // Auto-create intermediate paths
            )
        }

        // Move all channel files
        // Move all channel files to new location and create new ChannelInfo array
        var newChannels: [ChannelInfo] = []

        for channel in videoFile.channels {
            let sourceURL = URL(fileURLWithPath: channel.filePath)  // Current file path
            let filename = sourceURL.lastPathComponent  // Extract filename (e.g., "20250115_100000_F.mp4")
            let destinationFileURL = destinationURL.appendingPathComponent(filename)  // Create new path

            // Move file
            // Move file to new location (original is deleted)
            try fileManager.moveItem(at: sourceURL, to: destinationFileURL)

            // Create new ChannelInfo with updated path
            // Create ChannelInfo object with new path
            let newChannel = ChannelInfo(
                id: channel.id,
                position: channel.position,
                filePath: destinationFileURL.path,  // Updated file path
                width: channel.width,
                height: channel.height,
                frameRate: channel.frameRate,
                bitrate: channel.bitrate,
                codec: channel.codec,
                audioCodec: channel.audioCodec,
                isEnabled: channel.isEnabled,
                fileSize: channel.fileSize,
                duration: channel.duration
            )

            newChannels.append(newChannel)  // Add to new channel array
        }

        // Create new VideoFile with updated paths
        // Create and return VideoFile object with new channel array
        return VideoFile(
            id: videoFile.id,
            timestamp: videoFile.timestamp,
            eventType: videoFile.eventType,
            duration: videoFile.duration,
            channels: newChannels,  // Updated channel array
            metadata: videoFile.metadata,
            basePath: destinationURL.path,  // Updated base path
            isFavorite: videoFile.isFavorite,
            notes: videoFile.notes,
            isCorrupted: videoFile.isCorrupted
        )
    }

    /*
     【Export Video File Method】

     Copies all channels of a video file to an external location.
     Original files are kept intact.

     Parameters:
     - videoFile: VideoFile object to export
     - destinationURL: Destination directory URL

     Throws:
     - Error: Thrown if file copy fails

     Operation Sequence:
     1. Create destination directory if it doesn't exist
     2. Copy each channel file to new location
     3. Keep original files intact

     Usage Example:
     ```swift
     let videoFile = VideoFile(...)
     let exportPath = URL(fileURLWithPath: "/Users/user/Desktop/export/")

     do {
     try service.exportVideoFile(videoFile, to: exportPath)
     print("File has been exported")
     } catch {
     print("Export failed: \(error.localizedDescription)")
     }
     ```

     Move vs Export:
     - move: Deletes original, fast, only within same volume
     - export: Keeps original, slow, can export to different volume

     Progress Display:
     ```swift
     let totalFiles = videoFile.channels.count
     var completedFiles = 0

     for channel in videoFile.channels {
     // Copy operation...
     completedFiles += 1
     let progress = Double(completedFiles) / Double(totalFiles)
     print("Progress: \(Int(progress * 100))%")
     }
     ```
     */
    /// @brief Export video file to external location
    /// @param videoFile VideoFile to export
    /// @param destinationURL Export destination URL
    /// @throws Error if export fails
    func exportVideoFile(_ videoFile: VideoFile, to destinationURL: URL) throws {
        let fileManager = FileManager.default  // FileManager for file system operations

        // Create destination directory if needed
        // Create destination directory if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true  // Auto-create intermediate paths
            )
        }

        // Copy all channel files
        // Copy all channel files to new location (keep original)
        for channel in videoFile.channels {
            let sourceURL = URL(fileURLWithPath: channel.filePath)  // Original file path
            let filename = sourceURL.lastPathComponent  // Extract filename
            let destinationFileURL = destinationURL.appendingPathComponent(filename)  // Destination file path

            // Copy file
            // Copy file (keep original intact)
            try fileManager.copyItem(at: sourceURL, to: destinationFileURL)
        }
    }

    /*
     【Get Total File Size Method】

     Calculates the total size of multiple video files in bytes.

     Parameters:
     - videoFiles: Array of VideoFile objects

     Return Value:
     - UInt64: Total file size (bytes)

     Operation:
     - Sums totalFileSize of all files using reduce() function

     reduce() function explanation:
     ```swift
     let numbers = [1, 2, 3, 4, 5]
     let sum = numbers.reduce(0) { total, number in
     return total + number
     }
     // sum = 15
     ```

     Usage Example:
     ```swift
     let files = [videoFile1, videoFile2, videoFile3]
     let totalSize = service.getTotalSize(of: files)

     // Convert bytes to human-readable format
     let formatter = ByteCountFormatter()
     formatter.countStyle = .file
     let readableSize = formatter.string(fromByteCount: Int64(totalSize))
     print("Total size: \(readableSize)")  // "Total size: 1.5 GB"
     ```

     What is UInt64?
     - 64-bit unsigned integer (0 ~ 18,446,744,073,709,551,615)
     - Can represent up to 18 exabytes (18,000,000 terabytes)
     - Suitable for representing file sizes
     */
    /// @brief Get total size of all video files
    /// @param videoFiles Array of video files
    /// @return Total size in bytes
    func getTotalSize(of videoFiles: [VideoFile]) -> UInt64 {
        return videoFiles.reduce(0) { total, file in
            total + file.totalFileSize  // Accumulate size of each file
        }
    }

    /*
     【Get Available Disk Space Method】

     Queries available disk space on the volume at the specified path.

     Parameters:
     - path: Path to check (file or directory)

     Return Value:
     - UInt64?: Available space (bytes) or nil (if failed)

     Operation Sequence:
     1. Convert path to URL
     2. Query volume info via resourceValues(forKeys:)
     3. Extract available space using volumeAvailableCapacityKey
     4. Convert Int to UInt64 and return

     Usage Example:
     ```swift
     if let availableSpace = service.getAvailableDiskSpace(at: "/videos") {
     let formatter = ByteCountFormatter()
     formatter.countStyle = .file
     let readable = formatter.string(fromByteCount: Int64(availableSpace))
     print("Available: \(readable)")

     // Check for insufficient space
     let requiredSpace: UInt64 = 1_000_000_000  // 1 GB
     if availableSpace < requiredSpace {
     print("Warning: Insufficient disk space")
     }
     } else {
     print("Cannot determine disk space")
     }
     ```

     What is resourceValues(forKeys:)?
     - Method to query URL metadata
     - File size, creation date, volume info, etc.
     - Can throw errors with throws keyword

     volumeAvailableCapacityKey:
     - Space actually available for user
     - Excludes system reserved space
     - macOS: Typically 80-90% of total capacity
     */
    /// @brief Get available disk space at path
    /// @param path Path to check
    /// @return Available space in bytes or nil if cannot determine
    func getAvailableDiskSpace(at path: String) -> UInt64? {
        do {
            let url = URL(fileURLWithPath: path)  // Convert path to URL

            // Query volume info
            let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])

            // Extract available space and convert to UInt64
            return values.volumeAvailableCapacity.map { UInt64($0) }
        } catch {
            // Return nil on error
            return nil
        }
    }

    // MARK: - Batch Operations

    /*
     【Batch Set Favorite Method】

     Applies favorite status to multiple video files at once.

     Parameters:
     - videoFiles: Array of VideoFile objects
     - isFavorite: Favorite status to apply

     Operation Sequence:
     1. Load current favorites Set
     2. Iterate through all files and add/remove from Set
     3. Call saveFavorites() once

     Performance Optimization:
     - Individual call approach:
     ```swift
     for file in files {
     service.setFavorite(file, isFavorite: true)  // Save each time
     }
     // UserDefaults saves: 1000 times (for 1000 files)
     ```

     - Batch call approach:
     ```swift
     service.setFavorite(for: files, isFavorite: true)
     // UserDefaults saves: 1 time
     ```

     Usage Example:
     ```swift
     let selectedFiles = [videoFile1, videoFile2, videoFile3]

     // Add all selected files to favorites
     service.setFavorite(for: selectedFiles, isFavorite: true)
     print("\(selectedFiles.count) files added to favorites")

     // Remove all selected files from favorites
     service.setFavorite(for: selectedFiles, isFavorite: false)
     ```
     */
    /// @brief Apply favorite status to multiple files
    /// @param videoFiles Array of video files
    /// @param isFavorite Favorite status to apply
    func setFavorite(for videoFiles: [VideoFile], isFavorite: Bool) {
        var favorites = loadFavorites()  // Load current favorites Set

        // Iterate through all files and add or remove from Set
        for videoFile in videoFiles {
            if isFavorite {
                favorites.insert(videoFile.id.uuidString)  // Add to favorites
            } else {
                favorites.remove(videoFile.id.uuidString)  // Remove from favorites
            }
        }

        saveFavorites(favorites)  // Save to UserDefaults once (performance optimization)
    }

    /*
     【Batch Delete Files Method】

     Deletes multiple video files and returns collected errors.

     Parameters:
     - videoFiles: Array of VideoFile objects to delete

     Return Value:
     - [Error]: Array of errors that occurred (empty if all successful)

     Operation Sequence:
     1. Initialize error array
     2. Call deleteVideoFile() for each file
     3. Add to array if error occurs
     4. Return error array after processing all files

     Usage Example:
     ```swift
     let selectedFiles = [videoFile1, videoFile2, videoFile3]
     let errors = service.deleteVideoFiles(selectedFiles)

     if errors.isEmpty {
     print("All \(selectedFiles.count) files deleted")
     } else {
     print("Completed: \(selectedFiles.count - errors.count) files")
     print("Failed: \(errors.count) files")

     for error in errors {
     print("Error: \(error.localizedDescription)")
     }
     }
     ```

     Error Handling Strategy:
     - Continue deleting remaining files even if one deletion fails
     - Collect all errors and inform user
     - Allow partial success (some files deleted successfully)

     try-catch vs do-catch:
     ```swift
     // Individual error handling (current approach)
     for file in files {
     do {
     try deleteVideoFile(file)
     } catch {
     errors.append(error)  // Collect error and continue
     }
     }

     // Global error handling (not used)
     do {
     for file in files {
     try deleteVideoFile(file)  // Stops on first failure
     }
     } catch {
     // Handles only first error
     }
     ```
     */
    /// @brief Delete multiple video files
    /// @param videoFiles Array of video files to delete
    /// @return Array of errors (empty if all successful)
    func deleteVideoFiles(_ videoFiles: [VideoFile]) -> [Error] {
        var errors: [Error] = []  // Array to store occurred errors

        // Iterate through all files and attempt deletion
        for videoFile in videoFiles {
            do {
                try deleteVideoFile(videoFile)  // Delete file
            } catch {
                errors.append(error)  // Add to array if error occurs and continue
            }
        }

        return errors  // Return all occurred errors (empty if all successful)
    }

    // MARK: - Private Methods

    /*
     【Load Favorites (Private)】

     Loads favorites Set from UserDefaults.

     Return Value:
     - Set<String>: Favorited video file UUID Set (empty Set if none)

     Operation Sequence:
     1. Query array via userDefaults.array(forKey:)
     2. Attempt to cast to [String] type
     3. Convert to Set and return if successful
     4. Return empty Set if failed

     UserDefaults Storage Format:
     - Set cannot be stored directly
     - Convert to Array for storage: Array(favorites)
     - Convert back to Set when loading: Set(array)

     as? [String] Casting:
     - Ensures type safety
     - Returns nil if wrong type
     - Uses default value (empty Set) if nil

     Why private?
     - Internal implementation detail (UserDefaults usage)
     - External code should use getAllFavorites()
     - Encapsulation: Public API unaffected by implementation changes
     */
    private func loadFavorites() -> Set<String> {
        // Load as array from UserDefaults then convert to Set
        if let array = userDefaults.array(forKey: favoritesKey) as? [String] {
            return Set(array)  // Convert array to Set
        }
        return []  // Return empty Set if no data
    }

    /*
     【Save Favorites (Private)】

     Saves favorites Set to UserDefaults.

     Parameters:
     - favorites: Favorites Set<String> to save

     Operation:
     1. Convert Set to Array: Array(favorites)
     2. Save via userDefaults.set()
     3. Auto-synchronized to disk

     Why Set → Array Conversion:
     - UserDefaults can only store Property List types
     - Property List types: Array, Dictionary, String, Number, Date, Data
     - Set is not a Property List type
     - Therefore Array conversion is necessary

     Auto-synchronization:
     - UserDefaults automatically saves changes to disk
     - synchronize() call unnecessary (iOS 7+)
     - Auto-saves on app termination
     */
    private func saveFavorites(_ favorites: Set<String>) {
        // Convert Set to Array and save to UserDefaults
        userDefaults.set(Array(favorites), forKey: favoritesKey)
    }

    /*
     【Load Notes (Private)】

     Loads notes Dictionary from UserDefaults.

     Return Value:
     - [String: String]: UUID → note text Dictionary (empty Dictionary if none)

     Operation Sequence:
     1. Query Dictionary via userDefaults.dictionary(forKey:)
     2. Attempt to cast to [String: String] type
     3. Return if successful
     4. Return empty Dictionary if failed

     dictionary(forKey:) vs object(forKey:):
     - dictionary(forKey:): Returns [String: Any]
     - object(forKey:): Returns Any?
     - dictionary is safer with guaranteed type

     as? [String: String] Casting:
     - Checks if all Dictionary values are String
     - Returns nil if any value is different type
     - Ensures type safety
     */
    private func loadNotes() -> [String: String] {
        // Load Dictionary from UserDefaults
        if let dictionary = userDefaults.dictionary(forKey: notesKey) as? [String: String] {
            return dictionary  // Return Dictionary
        }
        return [:]  // Return empty Dictionary if no data
    }

    /*
     【Save Notes (Private)】

     Saves notes Dictionary to UserDefaults.

     Parameters:
     - notes: Notes Dictionary to save [UUID: note text]

     Operation:
     - Save Dictionary via userDefaults.set()
     - Auto-synchronized to disk

     Dictionary Storage:
     - Dictionary is a Property List type
     - [String: String] can be stored directly
     - Save directly without conversion

     Empty Dictionary Storage:
     - Empty Dictionary saved even if all notes deleted
     - Use removeObject(forKey:) to completely remove
     - But empty Dictionary is fine (small size)
     */
    private func saveNotes(_ notes: [String: String]) {
        // Save Dictionary to UserDefaults
        userDefaults.set(notes, forKey: notesKey)
    }

    // MARK: - File Cache

    /*
     【Get Cached File Info Method】

     Queries file information from memory cache.

     Parameters:
     - filePath: File path (used as cache key)

     Return Value:
     - VideoFile?: Cached VideoFile (nil if not found or expired)

     Operation Sequence:
     1. Lock cache with NSLock
     2. Guarantee unlock() with defer
     3. Query cache with filePath
     4. Check expiration if cache exists
     5. Return VideoFile if not expired
     6. Return nil if expired or not found

     Cache Expiration Check:
     ```swift
     let cachedAt = Date(timeIntervalSince1970: 1641974400)  // 2022-01-12 10:00:00
     let now = Date(timeIntervalSince1970: 1641974700)       // 2022-01-12 10:05:00
     let age = now.timeIntervalSince(cachedAt)               // 300 seconds (5 minutes)

     if age < maxCacheAge {  // 300 < 300 (false)
     // Expired, remove cache
     }
     ```

     Usage Example:
     ```swift
     if let cachedVideo = service.getCachedFileInfo(for: "/videos/file.mp4") {
     print("Cache hit! File info: \(cachedVideo.timestamp)")
     } else {
     print("Cache miss. Need to re-read file")
     }
     ```

     Thread Safety:
     - Protected by NSLock
     - Concurrent calls from multiple threads possible
     - unlock() guaranteed by defer (even on return)
     */
    /// @brief Get cached file information
    /// @param filePath Path to file
    /// @return Cached file info or nil if not cached or expired
    func getCachedFileInfo(for filePath: String) -> VideoFile? {
        cacheLock.lock()  // Lock cache (other threads wait)
        defer { cacheLock.unlock() }  // Auto-unlock on function exit

        // Query file info from cache
        guard let cached = fileCache[filePath] else {
            return nil  // Return nil if not in cache
        }

        // Check if cache is still valid
        // Check cache expiration
        let age = Date().timeIntervalSince(cached.cachedAt)  // Calculate cache age (seconds)
        guard age < maxCacheAge else {
            // Cache expired, remove it
            // Remove cache if expired and return nil
            fileCache.removeValue(forKey: filePath)
            return nil
        }

        return cached.videoFile  // Return valid cache
    }

    /*
     【Cache File Info Method】

     Saves VideoFile information to memory cache.

     Parameters:
     - videoFile: VideoFile object to cache
     - filePath: File path to use as cache key

     Operation Sequence:
     1. Lock cache with NSLock
     2. Guarantee unlock() with defer
     3. Check cache size limit (1000 items)
     4. Remove oldest 20% if limit exceeded
     5. Add new entry

     LRU Cache Strategy (Least Recently Used):
     ```
     Cache State: 1000 items (limit reached)

     1. Sort by cachedAt
     oldest ──────────────────────────▶ newest
     [file1, file2, file3, ..., file1000]

     2. Remove oldest 20% (200 items)
     [file201, file202, ..., file1000]  // 800 items

     3. Add new entry
     [file201, file202, ..., file1000, newFile]  // 801 items
     ```

     Why remove 20%?
     - Remove many at once to reduce removal frequency
     - Minimize overhead (sorting cost)
     - Secure memory headroom

     Usage Example:
     ```swift
     // Read file and save to cache
     let videoFile = try metadataExtractor.extractMetadata(from: filePath)
     service.cacheFileInfo(videoFile, for: filePath)

     // Returns immediately from cache on next call
     let cached = service.getCachedFileInfo(for: filePath)
     ```

     Performance:
     - Cache addition: O(1) (when no removal)
     - Cache removal: O(n log n) (sorting cost, n=1000)
     - Removal frequency: Approximately once per 801 additions
     */
    /// @brief Cache file information
    /// @param videoFile VideoFile to cache
    /// @param filePath File path to use as cache key
    func cacheFileInfo(_ videoFile: VideoFile, for filePath: String) {
        cacheLock.lock()  // Lock cache (other threads wait)
        defer { cacheLock.unlock() }  // Auto-unlock on function exit

        // Check cache size limit
        // Check cache size limit
        if fileCache.count >= maxCacheSize {
            // Remove oldest entries
            // Remove oldest entries

            // Sort keys by cachedAt (oldest first)
            let sortedKeys = fileCache.keys.sorted { key1, key2 in
                fileCache[key1]!.cachedAt < fileCache[key2]!.cachedAt
            }

            // Remove oldest 20% of cache
            // Remove 20% (200 items) of cache
            let removeCount = maxCacheSize / 5  // 1000 / 5 = 200
            for key in sortedKeys.prefix(removeCount) {  // First 200 items
                fileCache.removeValue(forKey: key)
            }
        }

        // Add to cache
        // Add new entry to cache
        fileCache[filePath] = CachedFileInfo(
            videoFile: videoFile,
            cachedAt: Date()  // Record current time
        )
    }

    /*
     【Invalidate Cache Method】

     Removes cache for a specific file.

     Parameters:
     - filePath: File path to invalidate

     Usage Examples:
     ```swift
     // Invalidate cache when file is modified
     try service.moveVideoFile(videoFile, to: newPath)
     service.invalidateCache(for: oldPath)

     // Invalidate cache when file is deleted
     try service.deleteVideoFile(videoFile)
     service.invalidateCache(for: videoFile.channels[0].filePath)
     ```

     Why is it needed?
     - Cache becomes inaccurate when file is moved/deleted/modified
     - Inaccurate cache causes bugs
     - Explicitly invalidate to load latest info on next read
     */
    /// @brief Invalidate cache for specific file
    /// @param filePath File path to invalidate
    func invalidateCache(for filePath: String) {
        cacheLock.lock()  // Lock cache
        defer { cacheLock.unlock() }  // Auto-release on function exit

        fileCache.removeValue(forKey: filePath)  // Remove from cache
    }

    /*
     【Clear All Cache Method】

     Completely empties memory cache.

     Usage Examples:
     ```swift
     // Clear cache on memory pressure
     if lowMemoryWarning {
     service.clearCache()
     print("Cache has been cleared")
     }

     // Clear cache when loading new folder
     service.clearCache()  // Remove cache of previous folder
     fileScanner.scanVideoFiles(at: newFolderPath)
     ```

     Memory Release:
     - removeAll() removes all Dictionary entries
     - Memory released immediately
     - Automatically managed by ARC (Automatic Reference Counting)
     */
    /// @brief Clear entire file cache
    func clearCache() {
        cacheLock.lock()  // Lock cache
        defer { cacheLock.unlock() }  // Auto-release on function exit

        fileCache.removeAll()  // Remove all cache entries
    }

    /*
     【Get Cache Statistics Method】

     Returns statistics of current cache state.

     Return Value:
     - count: Number of cached files
     - oldestAge: Age of oldest cache (in seconds, nil if none)

     Operation:
     1. Calculate cache count
     2. Calculate age of all cache entries
     3. Find maximum value (oldest)

     Usage Example:
     ```swift
     let (count, oldestAge) = service.getCacheStats()
     print("Cache entries: \(count)")

     if let age = oldestAge {
     let minutes = Int(age / 60)
     print("Oldest cache: \(minutes) minutes ago")

     if age > 240 {  // Over 4 minutes
     print("Some cache entries will expire soon")
     }
     }

     // Display in UI
     cacheCountLabel.stringValue = "\(count) files cached"
     ```

     map() function:
     ```swift
     let values = [1, 2, 3]
     let doubled = values.map { $0 * 2 }  // [2, 4, 6]

     // Here:
     let ages = fileCache.values.map { Date().timeIntervalSince($0.cachedAt) }
     // Converts CachedFileInfo → TimeInterval
     ```

     max() function:
     - Finds maximum value in array
     - Returns nil for empty array
     - Oldest cache = cache with largest age
     */
    /// @brief Get cache statistics
    /// @return Tuple of (cached files count, oldest cache age)
    func getCacheStats() -> (count: Int, oldestAge: TimeInterval?) {
        cacheLock.lock()  // Lock cache
        defer { cacheLock.unlock() }  // Auto-release on function exit

        let count = fileCache.count  // Number of cached files

        // Calculate age of all cache entries and find maximum
        let oldestAge = fileCache.values.map { Date().timeIntervalSince($0.cachedAt) }.max()

        return (count, oldestAge)  // Return as tuple
    }

    /*
     【Cleanup Expired Cache Method】

     Removes expired cache entries that are over 5 minutes old.

     Operation Sequence:
     1. Record current time
     2. Iterate through all cache entries and check expiration
     3. Collect keys of expired entries
     4. Remove from cache using collected keys

     filter() function:
     ```swift
     let numbers = [1, 2, 3, 4, 5]
     let evens = numbers.filter { $0 % 2 == 0 }  // [2, 4]

     // Here:
     let expired = fileCache.filter { key, value in
     now.timeIntervalSince(value.cachedAt) >= maxCacheAge
     }
     // Filters only expired entries
     ```

     map() function:
     ```swift
     let expired = [("key1", info1), ("key2", info2)]
     let keys = expired.map { $0.key }  // ["key1", "key2"]
     ```

     Usage Examples:
     ```swift
     // Periodic cleanup with background timer
     Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
     service.cleanupExpiredCache()
     print("Cleaned up expired cache")
     }

     // When app goes to background
     NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification) {
     service.cleanupExpiredCache()
     }
     ```

     Auto cleanup vs Manual cleanup:
     - getCachedFileInfo() checks expiration on query (automatic)
     - cleanupExpiredCache() explicitly cleans up (manual)
     - Call periodically to prevent memory waste
     */
    /// @brief Cleanup expired cache entries
    func cleanupExpiredCache() {
        cacheLock.lock()  // Lock cache
        defer { cacheLock.unlock() }  // Auto-release on function exit

        let now = Date()  // Current time

        // Collect keys of expired cache entries
        let expiredKeys = fileCache.filter { _, value in
            now.timeIntervalSince(value.cachedAt) >= maxCacheAge  // 5+ minutes elapsed
        }.map { $0.key }  // Extract only keys

        // Remove expired entries
        for key in expiredKeys {
            fileCache.removeValue(forKey: key)
        }
    }
}

// MARK: - VideoFile Extension

/*
 【VideoFile Extension】

 Extension is a powerful Swift feature for adding new functionality to existing types.

 Why use Extension?
 1. Code separation: Separates VideoFile definition from FileManagerService-related functionality
 2. Convenience: Can call as videoFile.withUpdatedMetadata(from:)
 3. Extend without modification: Add functionality without modifying VideoFile's original code

 Extension vs Subclassing:
 - Extension: Adds functionality to existing type (cannot add stored properties)
 - Subclass: Creates new type (can add stored properties)

 Usage Example:
 ```swift
 let videoFile = VideoFile(...)

 // Call Extension method
 let updated = videoFile.withUpdatedMetadata(from: service)

 // Chaining
 let files = scanner.scanFiles()
 .map { $0.withUpdatedMetadata(from: service) }
 .filter { $0.isFavorite }
 ```
 */
extension VideoFile {
    /*
     【Update Metadata Method】

     Retrieves favorite and note information from FileManagerService and
     creates a new VideoFile instance.

     Parameters:
     - service: FileManagerService instance

     Return Value:
     - VideoFile: New VideoFile with updated metadata

     Immutability:
     - Swift's value types (struct) recommend immutability
     - Create new object without modifying existing one
     - Safe and predictable code

     Operation Sequence:
     1. Query favorite status from service
     2. Query notes from service
     3. Create new VideoFile with queried information
     4. Keep existing values for other properties

     Usage Examples:
     ```swift
     // Update metadata after file scan
     let scannedFiles = fileScanner.scanVideoFiles(at: "/videos")
     let updatedFiles = scannedFiles.map { file in
     file.withUpdatedMetadata(from: fileManagerService)
     }

     // Update individual file
     let videoFile = VideoFile(isFavorite: false, notes: nil, ...)
     let updated = videoFile.withUpdatedMetadata(from: service)
     // updated.isFavorite = actual value stored in service
     // updated.notes = actual note stored in service
     ```

     Why use this pattern?
     - FileScanner creates VideoFile from file system
     - No favorite/note information at this point (stored in UserDefaults)
     - Inject metadata after creation using this method
     - Separation of concerns: File scanning ≠ Metadata management
     */
    /// @brief Create updated VideoFile with favorite status
    /// @param service FileManagerService to use
    /// @return Updated VideoFile
    func withUpdatedMetadata(from service: FileManagerService) -> VideoFile {
        // Query favorites and notes from service
        let isFavorite = service.isFavorite(self)
        let notes = service.getNote(for: self)

        // Create new VideoFile with updated information
        return VideoFile(
            id: id,
            timestamp: timestamp,
            eventType: eventType,
            duration: duration,
            channels: channels,
            metadata: metadata,
            basePath: basePath,
            isFavorite: isFavorite,  // Updated favorite status
            notes: notes,  // Updated note
            isCorrupted: isCorrupted
        )
    }
}

// MARK: - Supporting Types

/*
 【CachedFileInfo Structure】

 Wrapper structure that holds VideoFile and cache timestamp for storage in cache.

 Properties:
 - videoFile: VideoFile object to cache
 - cachedAt: Time when cached (used for expiration check)

 Why not store just VideoFile?
 - Need storage time to check cache expiration
 - TimeInterval age = Date().timeIntervalSince(cachedAt)
 - Expired if age >= maxCacheAge

 private access control:
 - Used only internally within FileManagerService
 - No need to expose externally
 - Encapsulation: Hides implementation details

 Structure:
 ┌─────────────────────────────────────────────┐
 │  fileCache: [String: CachedFileInfo]        │
 │  ┌───────────────────────────────────────┐  │
 │  │ Key: "/videos/20250115_100000_F.mp4"  │  │
 │  │ Value: CachedFileInfo {               │  │
 │  │   videoFile: VideoFile(...),          │  │
 │  │   cachedAt: 2025-01-15 10:00:00       │  │
 │  │ }                                     │  │
 │  └───────────────────────────────────────┘  │
 └─────────────────────────────────────────────┘

 Usage Example:
 ```swift
 // Save to cache
 let cached = CachedFileInfo(
 videoFile: videoFile,
 cachedAt: Date()
 )
 fileCache[filePath] = cached

 // Query from cache
 if let cached = fileCache[filePath] {
 let age = Date().timeIntervalSince(cached.cachedAt)
 if age < 300 {  // Within 5 minutes
 return cached.videoFile
 }
 }
 ```
 */
/// @struct CachedFileInfo
/// @brief Cached file information with timestamp
private struct CachedFileInfo {
    /// @var videoFile
    /// @brief Cached VideoFile object
    let videoFile: VideoFile
    /// @var cachedAt
    /// @brief Timestamp when cached (for expiration check)
    let cachedAt: Date
}
