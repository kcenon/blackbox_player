/**
 * @file VideoChannelTests.swift
 * @brief Video channel unit tests
 * @author BlackboxPlayer Team
 *
 * @details
 * Verifies decoding, buffering, and state management of individual video channels (VideoChannel)
 * Unit test collection. For each camera channel in multi-channel blackbox system
 * Tests independent operation.
 *
 * @section video_channel_overview What is VideoChannel?
 *
 * VideoChannel is a component that decodes one camera video and buffers frames
 * Component. Each channel operates independently, in multi-threaded environment
 * can be accessed safely.
 *
 * **Main Features:**
 *
 * 1. **Decoding Management**
 *    - Video decoding in background thread
 *    - FFmpeg VideoDecoder wrapping
 *    - Asynchronous frame generation
 *
 * 2. **Frame Buffering**
 *    - Store recent 30 frames (LRU cache)
 *    - Fast frame lookup (O(1) access)
 *    - Memory-efficient management
 *
 * 3. **State Management**
 *    - Idle → Ready → Decoding → Completed/Error
 *    - Propagate state changes via Combine Publisher
 *    - Can subscribe to state transition events
 *
 * 4. **Thread Safety**
 *    - Concurrent access from multiple threads possible
 *    - Protect data with internal locks
 *    - Prevent race conditions
 *
 * @section multichannel_structure Blackbox multi-channel structure
 *
 * ```
 * BlackboxPlayer
 * ├── VideoChannel (Front)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30pieces]
 * ├── VideoChannel (Rear)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30pieces]
 * ├── VideoChannel (Left)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30pieces]
 * ├── VideoChannel (Right)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30pieces]
 * └── VideoChannel (Interior)
 *     ├── VideoDecoder (FFmpeg)
 *     └── Frame Buffer [30pieces]
 * ```
 *
 * @section test_scope Test Scope
 *
 * 1. **Initialization Tests**
 *    - Channel ID assignment
 *    - Verify initial state (Idle)
 *    - Buffer initialization
 *
 * 2. **Decoding Tests**
 *    - Load video file
 *    - Frame decoding
 *    - State transition (Idle → Ready → Decoding)
 *
 * 3. **Buffering Tests**
 *    - Store frames
 *    - Frame lookup
 *    - LRU cache operation
 *    - Buffer overflow handling
 *
 * 4. **State Management Tests**
 *    - Verify state transition
 *    - Combine Publisher event
 *    - Error state handling
 *
 * 5. **Thread Safety Tests**
 *    - Verify concurrent access
 *    - Race condition tests
 *    - Data race detection
 *
 * 6. **Performance Tests**
 *    - Frame lookup speed
 *    - Buffer update performance
 *    - Memory usage
 *
 * @section combine_overview Combine Framework
 *
 * Combine is Apple's reactive programming framework, changes in data
 * provides patterns that automatically detect and react.
 *
 * **Main Concepts:**
 * - **Publisher**: Object that publishes values
 * - **Subscriber**: Object that subscribes to values
 * - **AnyCancellable**: Token for canceling subscriptions
 *
 * **Usage example:**
 * ```swift
 * channel.$state  // Publisher
 *     .sink { state in  // Subscriber
 *         print("State changed: \(state)")
 *     }
 *     .store(in: &cancellables)  // Subscription management
 * ```
 *
 * @section test_strategy Test Strategy
 *
 * - Remove external dependencies by using Mock data
 * - Utilize async/await for asynchronous tests
 * - Wait for state changes using XCTestExpectation
 * - Verify event stream using Combine sink
 *
 * @note These tests run with Mock data without actual video files.
 * Actual file decoding is verified in integration tests.
 */

//
//  ═══════════════════════════════════════════════════════════════════════════
//  VideoChannelTests.swift
//  BlackboxPlayerTests
//
//  📋 Project: BlackboxPlayer
//  🎯 Purpose: VideoChannel Unit Tests
//  📝 Description: Verifies decoding, buffering, and state management of video channels
//
//  ═══════════════════════════════════════════════════════════════════════════
//
//  🎬 What is VideoChannel?
//  ────────────────────────────────────────────────────────────────────────
//  Component that decodes one camera video and buffers frames.
//
//  📦 Main Features:
//  ```
//  1. Decoding Management
//     - Video decoding in background thread
//     - FFmpeg VideoDecoder wrapping
//
//  2. Frame Buffering
//     - Store recent 30 frames
//     - Fast frame lookup
//
//  3. State Management
//     - Idle → Ready → Decoding → Completed/Error
//     - Propagate state changes via Combine Publisher
//
//  4. Thread Safety
//     - Concurrent access from multiple threads possible
//     - Protect data with internal locks
//  ```
//
//  🔄 Blackbox multi-channel structure:
//  ```
//  BlackboxPlayer
//  ├── VideoChannel (Front)
//  │   ├── VideoDecoder
//  │   └── Frame Buffer [30pieces]
//  ├── VideoChannel (Rear)
//  │   ├── VideoDecoder
//  │   └── Frame Buffer [30pieces]
//  └── VideoChannel (Side)
//      ├── VideoDecoder
//      └── Frame Buffer [30pieces]
//  ```
//  ────────────────────────────────────────────────────────────────────────
//

/// XCTest framework
///
/// Apple's official Unit Tests framework.
import XCTest

/// Combine Framework
///
/// Apple's reactive programming framework.
///
/// 🔄 What is Reactive Programming?
/// ```
/// Programming paradigm that automatically detects and reacts to changes in data
///
/// Traditional approach:
/// if (state == .ready) {
///     // Manual state change check
/// }
///
/// Reactive approach:
/// channel.$state.sink { newState in
///     // Auto-execute on state change
/// }
/// ```
///
/// 💡 Combine's Main Concepts:
/// - Publisher: Object that publishes values
/// - Subscriber: Object that subscribes to values
/// - AnyCancellable: Token for canceling subscriptions
///
/// 📚 Usage example:
/// ```swift
/// channel.$state  // Publisher
///     .sink { state in  // Subscriber
///         print("State changed: \(state)")
///     }
///     .store(in: &cancellables)  // Subscription management
/// ```
import Combine

/// @testable import
///
/// Allows access to internal members of the test target module.
@testable import BlackboxPlayer

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Video channel tests (Unit Tests)
// ═══════════════════════════════════════════════════════════════════════════

/// VideoChannel Unit Tests class
///
/// Verifies basic functions of video channels.
///
/// 🎯 Test Scope:
/// ```
/// 1. initialization
///    - Create channel
///    - Identifiable (unique ID)
///    - Equatable (comparable)
///
/// 2. State Management
///    - State transition
///    - state name
///    - Combine Publisher
///
/// 3. buffer management
///    - buffer state lookup
///    - Buffer initialization
///    - Frame lookup
///
/// 4. error handling/processing
///    - invalid file
///    - uninitialized state
///    - duplicate initialization
///
/// 5. Thread Safety
///    - concurrent buffer access
///    - concurrent Frame lookup
///
/// 6. Memory management
///    - deinit cleanup
///    - stop() cleanup
///
/// 7. performance
///    - buffer state lookup
///    - Frame lookup
/// ```
final class VideoChannelTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Video channel instance
     */
    /**
     * Created anew for each test.
     */
    var channel: VideoChannel!

    /**
     * Test channel information
     */
    /**
     * Includes channel position, file path, and display name.
     */
    /**
     *
     * @section channelinfo___ 📝 ChannelInfo structure
     * @endcode
     * struct ChannelInfo {
     *     let position: CameraPosition  // .front, .rear, etc.
     *     let filePath: String          // video file path
     *     let displayName: String       // display name for UI
     * }
     * @endcode
     */
    var testChannelInfo: ChannelInfo!

    /**
     * Combine Subscription storage
     */
    /**
     * Stores Combine subscriptions to prevent memory leaks.
     */
    /**
     *
     * @section anycancellable___ 💡 What is AnyCancellable?
     * @endcode
     * Token for managing the lifecycle of Combine subscriptions
     */
    /**
     * Role:
     * 1. Can cancel subscriptions
     * 2. automatic Memory management
     * 3. Manage multiple subscriptions using Set
     * @endcode
     */
    /**
     *
     * @section _____ 📝 Usage pattern
     * @endcode
     * publisher
     *     .sink { value in ... }
     *     .store(in: &cancellables)  // Store in Set
     */
    /**
     * // cancellables = nil automatically cancels all subscriptions
     * @endcode
     */
    /**
     *
     * @section set__________ ⚠️ Why manage with Set
     * - Manage multiple subscriptions at once
     * - Cancel all in tearDown
     * - Prevent memory leaks
     */
    var cancellables: Set<AnyCancellable>!

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Setup & Teardown
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Initialize before each test execution
     */
    /**
     * XCTest automatically calls this before executing each test method.
     */
    /**
     *
     * @section ______ 🎯 Initialization
     * 1. Call parent class setUp
     * 2. continueAfterFailure flag set/setting/configuration
     * 3. cancellables empty Set create/creation
     * 4. Test channel information create/creation
     */
    /**
     *
     * @section continueafterfailure___false 💡 continueAfterFailure = false
     * Immediately stops the test upon first assertion failure.
     * (Ensures safety: prevents nil access)
     */
    override func setUpWithError() throws {
        /**
         * Call parent class setUp
         */
        super.setUp()

        /**
         * Set to stop immediately on failure
         */
        /**
         *
         * @section __ 💡 Reason
         * Continuing execution after first failure
         * may cause crash due to nil access
         */
        continueAfterFailure = false

        /**
         * Combine Subscription storage initialization
         */
        /**
         * Start with empty Set
         * Add subscription using .store(in: &cancellables) in tests
         */
        cancellables = []

        /**
         * Test channel information create/creation
         */
        /**
         *
         * @section _______ 💡 Test configuration
         * - position: .front (Front camera)
         * - filePath: "/path/to/test/video.mp4" (non-existent path)
         * - displayName: "Test Channel"
         */
        /**
         *
         * @section ________________ ⚠️ File path is intentionally incorrect
         * To test error handling
         */
        testChannelInfo = ChannelInfo(
            position: .front,
            filePath: "/path/to/test/video.mp4",
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
    }

    /**
     * Cleanup after each test execution
     */
    /**
     * XCTest automatically calls this after executing each test method.
     */
    /**
     * 🧹 Cleanup:
     * 1. Stop channel (terminate decoding thread)
     * 2. Release channel
     * 3. Release channel info
     * 4. Combine Cancel subscription
     * 5. Call parent class tearDown
     */
    /**
     *
     * @section _____________ 💡 Why cleanup order matters
     * @endcode
     * 1. channel?.stop()
     *    - Stop background decoding thread first
     *    - Terminate safely
     */
    /**
     * 2. channel = nil
     *    - Release channel memory
     *    - Clean up decoder
     */
    /**
     * 3. cancellables = nil
     *    - Cancel all Combine subscriptions
     *    - Prevent circular references
     * @endcode
     */
    override func tearDownWithError() throws {
        /**
         * Stop channel
         */
        /**
         * ?: Optional chaining
         * If channel is nil, doesn't call
         */
        /**
         * stop()'s Role:
         * - Stop decoding thread
         * - Buffer initialization
         * - Change state to idle
         */
        channel?.stop()

        /**
         * Release channel
         */
        /**
         * ARC releases memory by nil assignment
         */
        channel = nil

        /**
         * Release channel info
         */
        testChannelInfo = nil

        /**
         * Combine Cancel subscription
         */
        /**
         * Setting Set to nil
         * causes all AnyCancellable to deinit
         * automatically canceling subscriptions.
         */
        /**
         *
         * @section _________ 💡 Prevent memory leaks
         * Combine subscriptions create strong references, so
         * Must be released .
         */
        cancellables = nil

        /**
         * Call parent class tearDown
         */
        super.tearDown()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Initialization Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Channel initialization test
     */
    /**
     * Verifies that basic initialization of VideoChannel is performed correctly.
     */
    /**
     *
     * @section _____ 🎯 Verification Items
     * @endcode
     * 1. channel object creation successful
     * 2. initial state = .idle
     * 3. current frame = nil
     * 4. Verify channel information saved
     * @endcode
     */
    /**
     *
     * @section ______ 💡 Initialization Steps
     * @endcode
     * VideoChannel(channelInfo:)
     * ├── 1. Save channelInfo
     * ├── 2. Create unique ID (UUID)
     * ├── 3. Set state to .idle
     * ├── 4. Initialize frame buffer (empty buffer)
     * └── 5. currentFrame = nil
     * @endcode
     */
    /**
     * @test testChannelInitialization
     * @brief ⚠️ initialization vs initialize():
     *
     * @details
     *
     * @section ____vs_initialize__ ⚠️ initialization vs initialize()
     * - init: Only object creation (memory allocation)
     * - initialize(): decoder ready (file open)
     */
    func testChannelInitialization() {
        /**
         * Given/When: Create channel
         */
        /**
         * Create a new channel using testChannelInfo.
         */
        /**
         *
         * @section ______ 💡 At This Point
         * - Only object is created
         * - Decoder not yet initialized
         * - File not yet opened
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> initialization verify/verification
         */
        /**
         * Verify 4 conditions.
         *
         * 1. channel object creation successful
         */
        /**
         * XCTAssertNotNil: Verify object is not nil
         */
        XCTAssertNotNil(channel, "Channel should be initialized")

        /**
         * 2. Verify initial state is .idle
         */
        /**
         *
         * @section channelstate_idle 💡 ChannelState.idle
         * - State not yet initialized
         * - Decoder not created
         * - Cannot decode
         */
        XCTAssertEqual(channel.state, .idle, "Initial state should be idle")

        /**
         * 3. Verify current frame is nil
         */
        /**
         *
         * @section __ 💡 Reason
         * - Not yet decoded
         * - Buffer is empty
         */
        XCTAssertNil(channel.currentFrame, "Current frame should be nil initially")

        /**
         * 4. Verify channel information is correctly saved
         */
        /**
         * Verify position is .front
         */
        XCTAssertEqual(channel.channelInfo.position, .front, "Channel position should match")
    }

    /**
     * Identifiable protocol test
     */
    /**
     * Verifies that each channel has a unique ID.
     */
    /**
     * 🆔 What is Identifiable protocol?
     * @endcode
     * protocol Identifiable {
     *     var id: ID { get }  // unique identifier
     * }
     */
    /**
     * Used in SwiftUI's List, ForEach, etc. to distinguish items
     * @endcode
     */
    /**
     *
     * @section videochannel__id 💡 VideoChannel's ID
     * @endcode
     * class VideoChannel: Identifiable {
     *     let id: UUID = UUID()  // Random UUID on creation
     * }
     * @endcode
     */
    /**
     *
     * @section _____id_______ 🎯 Why is a unique ID necessary?
     * @endcode
     * To distinguish each channel in multi-channel player
     */
    /**
     * Examples:
     * - Front camera (ID: 1234-5678)
     * - Rear camera (ID: 9abc-def0)
     * - Side camera (ID: 1111-2222)
     */
    /**
     * @test testChannelIdentifiable
     * @brief Using in SwiftUI:
     *
     * @details
     * Using in SwiftUI:
     * ForEach(channels) { channel in
     *     VideoView(channel: channel)
     * }
     * @endcode
     */
    func testChannelIdentifiable() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create two channels with same information
         */
        /**
         *
         * @section ___ 💡 Key Point
         * - testChannelInfo is identical
         * - But each channel is an independent instance
         */
        let channel1 = VideoChannel(channelInfo: testChannelInfo)
        let channel2 = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> Verify IDs are different from each other
         */
        /**
         *
         * @section _____ 💡 Expected Behavior
         * @endcode
         * channel1.id = UUID("1234-5678-...")
         * channel2.id = UUID("9abc-def0-...")  ← Different!
         * @endcode
         */
        /**
         * UUID is randomly created on each initialization, so
         * the two channel IDs must always be different.
         */
        XCTAssertNotEqual(channel1.id, channel2.id, "Each channel should have unique ID")
    }

    /**
     * Equatable protocol test
     */
    /**
     * Verifies that ID-based equality comparison works correctly.
     */
    /**
     * ⚖️ What is Equatable protocol?
     * @endcode
     * protocol Equatable {
     *     static func == (lhs: Self, rhs: Self) -> Bool
     * }
     */
    /**
     * Makes two objects comparable using == operator
     * @endcode
     */
    /**
     *
     * @section videochannel_____ 💡 VideoChannel's Equality
     * @endcode
     * extension VideoChannel: Equatable {
     *     static func == (lhs: VideoChannel, rhs: VideoChannel) -> Bool {
     *         return lhs.id == rhs.id  // Compare only ID
     *     }
     * }
     */
    /**
     * In other words, if IDs are same, considered same channel
     * @endcode
     */
    /**
     * @test testChannelEquatable
     * @brief 🎯 Test scenario:
     *
     * @details
     *
     * @section ________ 🎯 Test Scenario
     * @endcode
     * 1. Same ID → Same channel (==)
     * 2. Different ID → Different channel (!=)
     * @endcode
     */
    func testChannelEquatable() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create specific UUID
         */
        /**
         *
         * @section uuid__ 💡 UUID()
         * Create random UUID
         * Example: "550E8400-E29B-41D4-A716-446655440000"
         */
        let channelID = UUID()

        /**
         * Create two channels with same ID
         */
        /**
         * Use VideoChannel(channelID:channelInfo:) initializer
         * (Can directly specify ID)
         */
        /**
         *
         * @section channel1__channel2_ 💡 channel1 and channel2 are
         * - Share the same ID
         * - Different instances
         */
        let channel1 = VideoChannel(channelID: channelID, channelInfo: testChannelInfo)
        let channel2 = VideoChannel(channelID: channelID, channelInfo: testChannelInfo)

        /**
         * Create third channel with different ID
         */
        /**
         * Create without specifying channelID
         * → Automatically creates new UUID
         */
        let channel3 = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> Verify equality
         *
         * 1. Same ID → Same channel
         */
        /**
         * XCTAssertEqual: Compare using == operator
         */
        /**
         *
         * @section __ 💡 expected
         * @endcode
         * channel1.id = channelID
         * channel2.id = channelID
         * → channel1 == channel2  ✅
         * @endcode
         */
        XCTAssertEqual(channel1, channel2, "Channels with same ID should be equal")

        /**
         * 2. Different ID → Different channel
         */
        /**
         *
         * @section __ 💡 expected
         * @endcode
         * channel1.id = channelID
         * channel3.id = New UUID (different)
         * → channel1 != channel3  ✅
         * @endcode
         */
        XCTAssertNotEqual(channel1, channel3, "Channels with different IDs should not be equal")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - State Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * State transition test
     */
    /**
     * Verifies the channel's initial state and display name.
     */
    /**
     *
     * @section channelstate_enum 🔄 ChannelState Enum
     * @endcode
     * enum ChannelState: Equatable {
     *     case idle         // Idle: initial state
     *     case ready        // Ready: decoder initialization complete
     *     case decoding     // Decoding: frame creation in progress
     *     case completed    // Completed: video ended
     *     case error(String) // Error: failure (includes message)
     * }
     * @endcode
     */
    /**
     *
     * @section ________ 💡 State Transition Flow
     * @endcode
     * Idle
     *  ↓ initialize()
     * Ready
     *  ↓ startDecoding()
     * Decoding
     *  ↓ video ends or stop()
     * Completed
     */
    /**
     * From any state:
     *  ↓ error occurs
     * Error
     * @endcode
     */
    /**
     * @test testStateTransitions
     * @brief 🎯 displayName Property:
     *
     * @details
     *
     * @section displayname___ 🎯 displayName Property
     * User-friendly string to display in UI
     */
    func testStateTransitions() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * Verify the state immediately after creation.
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> Verify initial state
         *
         * 1. Verify state is .idle
         */
        /**
         *
         * @section ___________idle 💡 Initial state is always .idle
         * - Decoder not initialized
         * - Cannot decode
         * - Waiting for initialize()
         */
        XCTAssertEqual(channel.state, .idle, "Initial state should be idle")

        /**
         * 2. Verify display name
         */
        /**
         *
         * @section displayname______ 💡 displayName Computed Property
         * @endcode
         * var displayName: String {
         *     switch self {
         *     case .idle: return "Idle"
         *     case .ready: return "Ready"
         *     // ...
         *     }
         * }
         * @endcode
         */
        XCTAssertEqual(channel.state.displayName, "Idle")
    }

    /**
     * state display name test
     */
    /**
     * Verifies displayName of all ChannelState cases.
     */
    /**
     * 🏷️ Test Targets:
     * @endcode
     * .idle       → "Idle"
     * .ready      → "Ready"
     * .decoding   → "Decoding"
     * .completed  → "Completed"
     * .error(msg) → "Error: {msg}"
     * @endcode
     */
    /**
     *
     * @section _____________ 💡 Why This Test Is Important
     * - Used when displaying state in UI
     * - Used in log messages
     * - Improves readability when debugging
     */
    /**
     * @test testStateDisplayNames
     * @brief 📱 UI Usage example:
     *
     * @details
     * 📱 UI Usage example:
     * @endcode
     * Text("Status: \(channel.state.displayName)")
     * // "Status: Decoding" display
     * @endcode
     */
    func testStateDisplayNames() {
        /**
         * Test display names of all states
         */
        /**
         *
         * @section _________________ 💡 Verify by directly creating each case
         *
         * 1. Idle state
         */
        /**
         * Initial state, not yet initialized 
         */
        XCTAssertEqual(ChannelState.idle.displayName, "Idle")

        /**
         * 2. Ready state
         */
        /**
         * initialize() completed, decoding ready completed
         */
        XCTAssertEqual(ChannelState.ready.displayName, "Ready")

        /**
         * 3. Decoding state
         */
        /**
         * After startDecoding(), frame creation in progress
         */
        XCTAssertEqual(ChannelState.decoding.displayName, "Decoding")

        /**
         * 4. Completed state
         */
        /**
         * Video decoding completed to the end
         */
        XCTAssertEqual(ChannelState.completed.displayName, "Completed")

        /**
         * 5. Error state
         */
        /**
         * Error occurred, message passed via associated value
         */
        /**
         *
         * @section enum_with_associated_values 💡 Enum with Associated Values
         * @endcode
         * case error(String)  // Stores String
         * @endcode
         */
        /**
         *
         * @section displayname___ 💡 displayName Implementation
         * @endcode
         * case .error(let message):
         *     return "Error: \(message)"
         * @endcode
         */
        XCTAssertEqual(ChannelState.error("test").displayName, "Error: test")
    }

    /**
     * State publishing test
     */
    /**
     * Verifies state change notification via Combine's @Published.
     */
    /**
     * 📡 @Published Property:
     * @endcode
     * class VideoChannel {
     *     @Published var state: ChannelState = .idle
     * }
     * @endcode
     */
    /**
     *
     * @section _published____ 💡 @Published's Operation
     * - When value changes, Publisher automatically publishes new value
     * - Access Publisher via $state
     * - Subscribers detect changes
     */
    /**
     *
     * @section reactive___ 🔄 Reactive Pattern
     * @endcode
     * VideoChannel (Publisher)
     *       ↓ state change
     *   Combine Framework
     *       ↓ event delivery
     *    UI / Logic (Subscriber)
     * @endcode
     */
    /**
     * @test testStatePublishing
     * @brief 🎯 Asynchronous Test Pattern:
     *
     * @details
     *
     * @section __________ 🎯 Asynchronous Test Pattern
     * Verify asynchronous events using XCTestExpectation.
     */
    func testStatePublishing() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Setup channel and asynchronous expectation
         */
        /**
         * Create channel
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * Create XCTestExpectation
         */
        /**
         *
         * @section xctestexpectation 💡 XCTestExpectation
         * Object that waits for asynchronous task completed
         */
        /**
         * @endcode
         * let exp = expectation(description: "Task description")
         * // ... asynchronous task ...
         * exp.fulfill()  // completed signal
         * waitForExpectations(timeout: 1.0)  // wait
         * @endcode
         */
        let expectation = expectation(description: "State change published")

        /**
         * Array to store received states
         */
        /**
         *
         * @section __ 💡 Reason
         * - Track state change count
         * - Can verify state change order
         */
        var receivedStates: [ChannelState] = []

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> state change subscription
         */
        /**
         *
         * @section _____ 💡 Subscription Chain
         * @endcode
         * channel.$state      // Publisher<ChannelState, Never>
         *   .sink { state in  // Subscriber
         *       // state: new state value
         *   }
         *   .store(in: &cancellables)  // save subscription
         * @endcode
         *
         * $state: Access Publisher
         */
        /**
         *
         * @section __prefix 💡 $ Prefix
         * Gets the Publisher of @Published property
         * @endcode
         * @Published var state: ChannelState  // value
         * $state                              // Publisher
         * @endcode
         */
        channel.$state
            /**
             * .sink: Create Subscriber
             */
            ///
            /**
             * Executed whenever closure receives a value
             */
            ///
            /**
             *
             * @section ____ 💡 Parameter
             * - state: newly published state value
             */
            ///
            /**
             *
             * @section __ 💡 Return
             * - AnyCancellable: subscription cancellation token
             */
            .sink { state in
                /**
                 * Add received state to array
                 */
                receivedStates.append(state)

                /**
                 * Complete when 2 or more received
                 */
                ///
                /**
                 *
                 * @section __2__ 💡 Why 2 items?
                 * 1. initial value (.idle)
                 * 2. first change
                 */
                ///
                /**
                 *
                 * @section ____ 💡 In reality
                 * No state change in test
                 * Only receives initial value (1 item)
                 */
                if receivedStates.count >= 2 {
                    /**
                     * fulfill(): Satisfy expectation
                     */
                    ///
                    /**
                     * Asynchronous task completed signal
                     */
                    expectation.fulfill()
                }
            }
            /**
             * .store(in:): Save subscription
             */
            ///
            /**
             * Add to cancellables Set
             * Automatically cancelled in tearDown
             */
            ///
            /**
             *
             * @section ___inout_____ 💡 &: inout Parameter
             * Directly modify Set
             */
            .store(in: &cancellables)

        /**
         * State change simulation omitted
         */
        /**
         *
         * @section __ ⚠️ Note
         * This test is an example showing subscription pattern.
         * Actual state change requires actual decoder.
         */
        /**
         *
         * @section _______ 💡 Actual Usage Example
         * @endcode
         * channel.initialize()  // .idle → .ready
         * channel.startDecoding()  // .ready → .decoding
         * @endcode
         *
         *
         * @par Given-When-Then:
         * - <b>Then:</b> Asynchronous wait
         */
        /**
         * waitForExpectations: Wait until expectation satisfied
         */
        /**
         *
         * @section ____ 💡 Parameter
         * - timeout: maximum wait time (seconds)
         */
        /**
         *
         * @section __ 💡 Operation
         * - Success when expectation.fulfill() is called
         * - Failure if timeout exceeded
         */
        /**
         *
         * @section ______ ⚠️ This test
         * May terminate with timeout due to
         * no actual state change
         * (test for demonstrating pattern)
         */
        waitForExpectations(timeout: 1.0)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Buffer Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * initial buffer state test
     */
    /**
     * Verifies buffer state immediately after creating channel.
     */
    /**
     * 📦 What is frame buffer?
     * @endcode
     * Memory structure that stores decoded video frames
     */
    /**
     * Structure:
     * [Frame 1] [Frame 2] [Frame 3] ... [Frame 30]
     *  ↑ Oldest           ↑ Latest
     */
    /**
     * Features:
     * - Stores maximum 30 frames
     * - Automatic removal of old frames (FIFO)
     * - Fast timestamp-based lookup
     * @endcode
     */
    /**
     *
     * @section bufferstatus___ 💡 BufferStatus structure
     * @endcode
     * struct BufferStatus {
     *     let current: Int           // current frame piecesnumber
     *     let max: Int              // maximum capacity
     *     let fillPercentage: Double // Fill ratio (0.0~1.0)
     * }
     * @endcode
     */
    /**
     * @test testInitialBufferStatus
     * @brief 🎯 Why is buffer necessary?
     *
     * @details
     *
     * @section ___________ 🎯 Why is buffer necessary?
     * - Prepare frames in advance for smooth playback
     * - Fast seeking (reuse already decoded frames)
     * - Asynchronous handling of decoding and rendering
     */
    func testInitialBufferStatus() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * Not yet started decoding
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> buffer state lookup
         */
        /**
         * getBufferStatus(): BufferStatus return
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * func getBufferStatus() -> BufferStatus {
         *     lock.lock()
         *     defer { lock.unlock() }
         *     return BufferStatus(
         *         current: buffer.count,
         *         max: maxBufferSize,
         *         fillPercentage: Double(buffer.count) / Double(maxBufferSize)
         *     )
         * }
         * @endcode
         */
        let status = channel.getBufferStatus()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> initial buffer state verify/verification
         *
         * 1. current frame piecesnumber = 0
         */
        /**
         *
         * @section _____ 💡 Initial State
         * Empty because not yet decoded
         */
        XCTAssertEqual(status.current, 0, "Buffer should be empty initially")

        /**
         * 2. maximum size = 30
         */
        /**
         *
         * @section 30_______ 💡 Why 30 Frame Limit
         * - Limit memory usage
         * - 30 fps * 1 second = approx. 1 second worth
         * - Sufficient buffering + memory efficient
         */
        XCTAssertEqual(status.max, 30, "Max buffer size should be 30")

        /**
         * 3. Fill ratio = 0%
         */
        /**
         *
         * @section __ 💡 Calculation
         * fillPercentage = current / max
         *                = 0 / 30
         *                = 0.0
         */
        XCTAssertEqual(status.fillPercentage, 0.0, "Fill percentage should be 0%")
    }

    /**
     * buffer Initialization Tests
     */
    /**
     * flushBuffer() method verifies that buffer is correctly emptied.
     */
    /**
     * 🚽 flushBuffer()'s Role:
     * @endcode
     * Remove all frames stored in buffer
     */
    /**
     * Use cases:
     * 1. stop() when calling
     * 2. seek() call when (move to new position)
     * 3. when error occurs
     * @endcode
     */
    /**
     *
     * @section __ 💡 implementation
     * @endcode
     * func flushBuffer() {
     *     lock.lock()
     *     defer { lock.unlock() }
     *     buffer.removeAll()  // remove all frames
     *     currentFrame = nil
     * }
     * @endcode
     */
    /**
     * @test testFlushBuffer
     * @brief 🎯 Why is Flush necessary?
     *
     * @details
     *
     * @section __flush_______ 🎯 Why is Flush necessary?
     * - Remove old frames when seeking
     * - save memory
     * - state initialization
     */
    func testFlushBuffer() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * (in reality buffer should have frames meaningful, but,
         *  here empty even in buffer normal operation verify)
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> Buffer initialization + state lookup
         */
        /**
         * order:
         * 1. flushBuffer() call
         * 2. getBufferStatus() call
         */
        channel.flushBuffer()
        let status = channel.getBufferStatus()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> whether buffer is empty verify
         */
        /**
         *
         * @section __ 💡 expected
         * current = 0 (remove all framescompleted)
         */
        /**
         *
         * @section _______ 💡 actual use example
         * @endcode
         * // 50frames in buffer
         * channel.seek(to: 10.0)  // 10sec move to
         * // flushBuffer() automatically called
         * // → remove all previous frames
         * // → 10sec decode anew from
         * @endcode
         */
        XCTAssertEqual(status.current, 0, "Buffer should be empty after flush")
    }

    /**
     * test getting frame from empty buffer
     */
    /**
     * when buffer is empty getFrame(at:) operation verifies.
     */
    /**
     *
     * @section getframe_at______ 🔍 getFrame(at:) method
     * @endcode
     * func getFrame(at timestamp: TimeInterval) -> VideoFrame?
     * @endcode
     */
    /**
     *
     * @section __ 💡 operation
     * @endcode
     * 1. find frame closest in buffer
     * 2. frame return
     * 3. return nil if not found
     */
    /**
     * Search algorithm:
     * - use binary search (O(log n))
     * - timestamp buffer sorted by criteria
     * @endcode
     */
    /**
     *
     * @section timeinterval 📝 TimeInterval
     * @endcode
     * typealias TimeInterval = Double
     * // sec unit time (example: 1.5 = 1.5sec)
     * @endcode
     */
    /**
     * @test testGetFrameFromEmptyBuffer
     * @brief 🎯 Usage example:
     *
     * @details
     *
     * @section _____ 🎯 usage example
     * @endcode
     * // 1.0sec get frame at time
     * if let frame = channel.getFrame(at: 1.0) {
     *     renderFrame(frame)
     * } else {
     *     print("Frame not found")
     * }
     * @endcode
     */
    func testGetFrameFromEmptyBuffer() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * buffer empty state
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> Frame lookup
         */
        /**
         * 1.0sec time point frame request
         */
        /**
         *
         * @section _____ 💡 buffer state
         * @endcode
         * Buffer: []  ← empty
         * request: 1.0sec frame
         * @endcode
         */
        let frame = channel.getFrame(at: 1.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> nil return verify
         */
        /**
         * XCTAssertNil: whether value is nil verify
         */
        /**
         *
         * @section _____ 💡 expected operation
         * - buffer is empty
         * - cannot search
         * - nil return
         */
        /**
         *
         * @section nil________ ⚠️ nilis not an error
         * buffer normal state without frames
         */
        XCTAssertNil(frame, "Should return nil when buffer is empty")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Error Handling Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * with non-existent file Initialization Tests
     */
    /**
     * with invalid file path initialize() call when error handling verifies.
     */
    /**
     *
     * @section ______ 🎯 test Purpose
     * - file error detect
     * - appropriate error occurs
     * - unsafe failure handling/processing
     */
    /**
     *
     * @section initialize______ 💡 initialize() method
     * @endcode
     * func initialize() throws {
     *     // 1. file verify existence
     *     // 2. VideoDecoder create/creation
     *     // 3. file open
     *     // 4. change state to .ready
     * }
     * @endcode
     */
    /**
     * ❌ failure Scenario:
     * @endcode
     * file path: "/path/to/test/video.mp4"
     *         ↓ file none
     * VideoDecoder.open() failure
     *         ↓
     * DecoderError.fileNotFound or
     * DecoderError.openFailed occurs
     * @endcode
     */
    /**
     * @test testInitializeWithNonExistentFile
     * @brief 🔍 XCTAssertThrowsError:
     *
     * @details
     *
     * @section xctassertthrowserror 🔍 XCTAssertThrowsError
     * throwing function whether error it occurs verify/verification
     */
    func testInitializeWithNonExistentFile() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> invalid with path Create channel
         */
        /**
         * testChannelInfofilePath is
         * "/path/to/test/video.mp4" (does not exist)
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: initialization attempt and error verify
         */
        /**
         * XCTAssertThrowsErroroperation:
         * @endcode
         * XCTAssertThrowsError(
         *     try code to test(),    // error expected to occur
         *     "failure message"
         * ) { error in
         *     // occurred error check
         * }
         * @endcode
         */
        /**
         *
         * @section _____ 💡 expected operation
         * 1. channel.initialize() call
         * 2. VideoDecoder file open attempt
         * 3. file none → Error throw
         * 4. test success
         */
        /**
         *
         * @section __________ ⚠️ error occurs does not
         * test failure (file verify/verification missing)
         */
        XCTAssertThrowsError(try channel.initialize()) { _ in
            /**
             * occurred error type verify
             */
            ///
            /**
             *
             * @section _____ 💡 expected error
             * - DecoderError.fileNotFound
             * - DecoderError.openFailed
             * - other file related error
             */
            ///
            /**
             *
             * @section ___________ 📝 error type verify example
             * @endcode
             * if case DecoderError.fileNotFound = error {
             *     // expected error
             * } else {
             *     XCTFail("Unexpected error: \(error)")
             * }
             * @endcode
             */
            // Should throw decoder error for non-existent file
        }
    }

    /**
     * initialization without seek test
     */
    /**
     * initialize()without calling seek()when calling
     * appropriate error handling verifies.
     */
    /**
     * 🚫 invalid Usage pattern:
     * @endcode
     * let channel = VideoChannel(...)
     * try channel.seek(to: 5.0)  // ❌ initialize() first required!
     * @endcode
     */
    /**
     *
     * @section _________ ✅ correct Usage pattern
     * @endcode
     * let channel = VideoChannel(...)
     * try channel.initialize()   // 1. first initialization
     * try channel.seek(to: 5.0)  // 2. then next seek
     * @endcode
     */
    /**
     *
     * @section channelerror_notinitialized 💡 ChannelError.notInitialized
     * @endcode
     * enum ChannelError: Error {
     *     case notInitialized  // initializationnot done
     *     case invalidState    // invalid state
     *     case decoderError    // decoder error
     * }
     * @endcode
     */
    /**
     * @test testSeekWithoutInitialization
     * @brief 🔍 if case pattern matching:
     *
     * @details
     *
     * @section if_case______ 🔍 if case pattern matching
     * enum to match cases Swift syntax
     */
    func testSeekWithoutInitialization() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> uninitialized channel
         */
        /**
         * Create channelonly and initialize() not call 
         */
        /**
         *
         * @section __ 💡 state
         * - state = .idle
         * - decoder = nil
         * - seek not possible
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: seek attempt and error verify
         */
        /**
         * 5.0sec position move to attempt
         */
        /**
         *
         * @section _____ 💡 expected operation
         * @endcode
         * channel.seek(to: 5.0)
         *     ↓ state .idle?
         *     ↓ decoder nil?
         * throw ChannelError.notInitialized
         * @endcode
         */
        XCTAssertThrowsError(try channel.seek(to: 5.0)) { error in
            /**
             * error type verify
             */
            ///
            /**
             * if case: enum pattern matching
             */
            ///
            /**
             *
             * @section __ 💡 syntax
             * @endcode
             * if case PatternType.case = value {
             *     // matching success
             * }
             * @endcode
             */
            ///
            /**
             *
             * @section __ 💡 example
             * @endcode
             * let error: Error = ChannelError.notInitialized
             * if case ChannelError.notInitialized = error {
             *     print("expected error")  // ✅
             * }
             * @endcode
             */
            if case ChannelError.notInitialized = error {
                /**
                 * expected error occurs
                 */
                ///
                /**
                 * notInitialized error is correct
                 * test passed
                 */
                // Expected error
            } else {
                /**
                 * unexpected error
                 */
                ///
                /**
                 * XCTFail: test forced failure
                 */
                ///
                /**
                 *
                 * @section __ 💡 Reason
                 * not notInitialized other error occurs
                 * → error handling/processing logic problem
                 */
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    /**
     * duplicate Initialization Tests
     */
    /**
     * initialize() twice when calling error handling verifies.
     */
    /**
     * 🚫 invalid Usage pattern:
     * @endcode
     * try channel.initialize()  // 1th initialization
     * try channel.initialize()  // ❌ duplicate initialization!
     * @endcode
     */
    /**
     *
     * @section _____ 💡 expected operation
     * @endcode
     * 1th initialize()
     *     ↓
     * state = .ready
     *     ↓
     * 2th initialize() attempt
     *     ↓
     * state .idleis not
     *     ↓
     * throw ChannelError.invalidState
     * @endcode
     */
    /**
     *
     * @section ____ ⚠️ cautions
     * - test actual video file required
     * - valid with file initialize() must succeed 
     * - current is stub (implementation planned)
     */
    /**
     *
     * @section _________ 🎯 implementation when verifying
     * @endcode
     * // Given: valid with file Create channel
     * let bundle = Bundle(for: type(of: self))
     * let videoPath = bundle.path(forResource: "test", ofType: "mp4")!
     * let info = ChannelInfo(position: .front, filePath: videoPath, ...)
     * channel = VideoChannel(channelInfo: info)
     */
    /**
     * // When: first th initialization success
     * try channel.initialize()  // ✅
     * XCTAssertEqual(channel.state, .ready)
     */
    /**
     * @test testDoubleInitialization
     * @brief // Then: second initialization failure
     *
     * @details
     * // Then: second initialization failure
     * XCTAssertThrowsError(try channel.initialize()) { error in
     *     if case ChannelError.invalidState = error {
     *         // expected error
     *     } else {
     *         XCTFail("Expected invalidState error")
     *     }
     * }
     * @endcode
     */
    func testDoubleInitialization() {
        /**
         *
         * @section ________________________ ⚠️ test actual video fileis required.
         */
        /**
         *
         * @section _____ 💡 implementation method
         * 1. test in bundle test_video.mp4 add
         * 2. from Bundle file path get
         * 3. first th initialize() call
         * 4. second initialize() call when error verify
         */
        // Note: This test requires a valid video file
        // Given: A channel with valid file
        // When: Initialize twice
        // Then: Should throw invalidState error
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Thread Safety Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * concurrent buffer access test
     */
    /**
     * multiple threads concurrently to access buffer when
     * verifies Thread Safety.
     */
    /**
     * 🔒 What is Thread Safety (Thread Safety)?
     * @endcode
     * multiple threads concurrently same access data
     * data damage or crash does not occur nature
     */
    /**
     * problem situation (when thread unsafe):
     * Thread 1: buffer.count read → 5
     * Thread 2: buffer.removeAll() → empty buffer
     * Thread 1: buffer[5] access → ❌ crash!
     * @endcode
     */
    /**
     * 🛡️ Protection mechanism:
     * @endcode
     * class VideoChannel {
     *     private let lock = NSLock()
     */
    /**
     *     func getBufferStatus() -> BufferStatus {
     *         lock.lock()          // 1. lock
     *         defer { lock.unlock() }  // 2. termination when unlock
     */
    /**
     *         // 3. unsafe data access
     *         return BufferStatus(current: buffer.count, ...)
     *     }
     * }
     * @endcode
     */
    /**
     * @test testConcurrentBufferAccess
     * @brief 💡 DispatchQueue.concurrentPerform:
     *
     * @details
     *
     * @section dispatchqueue_concurrentperform 💡 DispatchQueue.concurrentPerform
     * multiple threads concurrently perform Tasks
     */
    func testConcurrentBufferAccess() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel and set repeat count
         */
        /**
         * empty channel ready
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * 100times repeat
         */
        /**
         *
         * @section __ 💡 Reason
         * - sufficient concurrency test
         * - race condition(race condition) can be found
         */
        let iterations = 100

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> multiple in thread concurrent access
         */
        /**
         * concurrentPerform: concurrent execution
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * Thread 1: iteration 0, 1, 2, ...
         * Thread 2: iteration 10, 11, 12, ...
         * Thread 3: iteration 20, 21, 22, ...
         * ...
         * all iterations concurrently executed
         * @endcode
         */
        /**
         *
         * @section ____ 📝 parameter
         * - iterations: total iteration count
         * - _ in: each of iteration index (use not )
         */
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            /**
             * buffer state lookup
             */
            ///
            /**
             *
             * @section ______________ 💡 Thread Safety verify/verification point
             * - buffer.count read
             * - concurrently other thread buffer fix
             */
            _ = channel.getBufferStatus()

            /**
             * Buffer initialization
             */
            ///
            /**
             *
             * @section ______________ 💡 Thread Safety verify/verification point
             * - buffer.removeAll() call
             * - concurrently other thread buffer read
             */
            channel.flushBuffer()
        }

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> verify completed without crash
         */
        /**
         *
         * @section _________ 💡 test passing condition
         * - no crash occurs 
         * - data no damage
         * - final buffer state maintain consistency
         */
        /**
         * final state verify
         */
        let finalStatus = channel.getBufferStatus()

        /**
         * buffer should be empty 
         */
        /**
         *
         * @section __ 💡 Reason
         * all flushBuffer() calls completed
         * → buffer should be empty as normal
         */
        XCTAssertEqual(finalStatus.current, 0)
    }

    /**
     * concurrent Frame lookup test
     */
    /**
     * multiple threads concurrently when calling getFrame()
     * verifies Thread Safety.
     */
    /**
     *
     * @section ________ 🔍 test Scenario
     * @endcode
     * Thread 1: getFrame(at: 0.0)
     * Thread 2: getFrame(at: 1.0)
     * Thread 3: getFrame(at: 2.0)
     * ...
     * Thread 100: getFrame(at: 99.0)
     */
    /**
     * all concurrent execution
     * @endcode
     */
    /**
     *
     * @section getframe___________ 💡 of getFrame() Thread Safety
     * @endcode
     * func getFrame(at timestamp: TimeInterval) -> VideoFrame? {
     *     lock.lock()
     *     defer { lock.unlock() }
     */
    /**
     *     // buffer search (binary search)
     *     return buffer.first { ... }
     * }
     * @endcode
     */
    /**
     * @test testConcurrentGetFrame
     * @brief 🎯 verify/verification point:
     *
     * @details
     *
     * @section ______ 🎯 verify/verification point
     * - concurrent read Tasks safety
     * - buffer access prevent crash during
     * - consistent search result
     */
    func testConcurrentGetFrame() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * empty buffer state
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> multiple threads concurrently Frame lookup
         */
        /**
         * 100pieces in thread concurrent execution
         */
        /**
         *
         * @section __________timestamp___ 💡 each thread other timestamp lookup
         * @endcode
         * Thread 0: getFrame(at: 0.0)
         * Thread 1: getFrame(at: 1.0)
         * Thread 2: getFrame(at: 2.0)
         * ...
         * @endcode
         */
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            /**
             * index Doubleto convert
             */
            ///
            /**
             * example: index=5 → timestamp=5.0
             */
            _ = channel.getFrame(at: Double(index))
        }

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> completed without crash
         */
        /**
         * XCTAssertNotNil: channel whether object is valid verify
         */
        /**
         *
         * @section _________ 💡 test meaning of passed
         * - 100times concurrent lookup without crash
         * - data race condition none
         * - Thread Safety secured
         */
        /**
         *
         * @section __ ⚠️ caution
         * since buffer is empty all getFrame() return nil
         * (normal operation)
         */
        XCTAssertNotNil(channel)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Memory Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * channel deinit test
     */
    /**
     * VideoChannel when unlocked from memory
     * correctly whether cleaned up verifies.
     */
    /**
     *
     * @section arc__automatic_reference_counting_ 💾 ARC (Automatic Reference Counting)
     * @endcode
     * Swift's automatic Memory management system
     */
    /**
     * object create/creation:
     * let channel = VideoChannel(...)  // reference count = 1
     */
    /**
     * reference increment:
     * let ref2 = channel  // reference count = 2
     */
    /**
     * reference decrement:
     * ref2 = nil  // reference count = 1
     * channel = nil  // reference count = 0 → deinit call
     * @endcode
     */
    /**
     * 🧹 deinit's Role:
     * @endcode
     * class VideoChannel {
     *     deinit {
     *         // 1. decoding stop thread
     *         stop()
     */
    /**
     *         // 2. buffer cleanup
     *         buffer.removeAll()
     */
    /**
     *         // 3. Combine cancel subscription
     *         cancellables.removeAll()
     */
    /**
     *         // 4. decoder unlock
     *         decoder = nil
     *     }
     * }
     * @endcode
     */
    /**
     * @test testChannelDeinit
     * @brief 🔍 memory leak verification tool:
     *
     * @details
     *
     * @section ____________ 🔍 memory leak verify/verification tool
     * - Instruments (Leaks, Allocations)
     * - Memory Graph Debugger
     */
    func testChannelDeinit() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> with local variable Create channel
         */
        /**
         * var: mutable variable
         * ?: optional type
         */
        /**
         *
         * @section __ 💡 Reason
         * - nil can assign
         * - can control reference count
         */
        var testChannel: VideoChannel? = VideoChannel(channelInfo: testChannelInfo)

        /**
         * whether channel created verify
         */
        /**
         *
         * @section ____ 💡 time
         * - testChannel reference count = 1
         * - memory allocated
         */
        XCTAssertNotNil(testChannel)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> Release channel
         */
        /**
         * nil By assignment reference unlock
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * testChannel = nil
         *     ↓
         * reference count = 0
         *     ↓
         * ARC deinit call
         *     ↓
         * memory unlock
         * @endcode
         */
        testChannel = nil

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> nil verify
         */
        /**
         *
         * @section _____ 💡 verification items
         * - variable set to nil
         * - deinit called normally (no crash)
         * - resources cleaned up
         */
        /**
         *
         * @section __________ ⚠️ actual memory leak
         * Instruments should verify with tool 
         * (this test only verifies basic operation)
         */
        XCTAssertNil(testChannel)
    }

    /**
     * stop() resource cleanup test
     */
    /**
     * stop() whether method correctly cleans up all resources verifies.
     */
    /**
     * 🛑 stop() method's Role:
     * @endcode
     * func stop() {
     *     // 1. decoding stop thread
     *     decodingQueue.async {
     *         self.shouldStop = true
     *     }
     */
    /**
     *     // 2. Buffer initialization
     *     flushBuffer()
     */
    /**
     *     // 3. current frame removal
     *     currentFrame = nil
     */
    /**
     *     // 4. change state to idle
     *     state = .idle
     * }
     * @endcode
     */
    /**
     *
     * @section _____ 🎯 use time
     * - video stop playback
     * - new video load before
     * - before app termination
     * - when error occurs
     */
    /**
     * @test testStopCleansResources
     * @brief 💡 stop() vs deinit:
     *
     * @details
     *
     * @section stop___vs_deinit 💡 stop() vs deinit
     * - stop(): manually called, reusable
     * - deinit: automatically called, object destruction
     */
    func testStopCleansResources() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * channel ready in initial state
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> stop() call
         */
        /**
         * execute resource cleanup
         */
        /**
         *
         * @section _____ 💡 internal operation
         * @endcode
         * stop()
         *   ↓ decoding halt
         *   ↓ empty buffer
         *   ↓ state initialization
         * completed
         * @endcode
         */
        channel.stop()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> cleanup state verify/verification
         *
         * 1. state whether .idle verify
         */
        /**
         *
         * @section stop_______ 💡 stop() after state
         * always returns to .idle
         */
        XCTAssertEqual(channel.state, .idle)

        /**
         * 2. current whether frame is nil verify
         */
        /**
         *
         * @section __ 💡 Reason
         * in stop() set currentFrame = nil
         */
        XCTAssertNil(channel.currentFrame)

        /**
         * 3. whether buffer is empty verify
         */
        /**
         * getBufferStatus() call to verify state
         */
        let status = channel.getBufferStatus()

        /**
         * buffer count = 0
         */
        /**
         *
         * @section __ 💡 Reason
         * stop() flushBuffer() calls
         */
        XCTAssertEqual(status.current, 0, "Buffer should be empty after stop")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Performance Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * buffer state lookup Performance Tests
     */
    /**
     * getBufferStatus() measures method's performance.
     */
    /**
     * ⏱️ measure { } block:
     * @endcode
     * XCTest's performance measurement tool
     */
    /**
     * operation:
     * 1. execute block 10 times
     * 2. measure each execution time
     * 3. calculate average, standard deviation
     * 4. compare with baseline
     * @endcode
     */
    /**
     *
     * @section _____ 💡 performance criteria
     * @endcode
     * getBufferStatus() can be called per frame
     * → must execute very fast 
     * → goal: 1000calls in < 10ms
     * @endcode
     */
    /**
     *
     * @section ________ 📊 measurement result example
     * @endcode
     * Average: 5.234 ms
     * Relative standard deviation: 3.2%
     * Baseline: 5.0 ms
     * @endcode
     */
    /**
     * @test testBufferStatusPerformance
     * @brief 🎯 performance optimization point:
     *
     * @details
     *
     * @section __________ 🎯 performance optimization point
     * - NSLock use (fast lock)
     * - only simple calculations performed
     * - minimize memory allocation
     */
    func testBufferStatusPerformance() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * empty buffer state
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: measure performance
         */
        /**
         * measure: measure performance block
         */
        /**
         *
         * @section __ 💡 operation
         * block executed 10 times and
         * each execution time is measured 
         */
        measure {
            /**
             * 1000times buffer state lookup
             */
            ///
            /**
             *
             * @section 1000____ 💡 1000times Reason
             * - statistically meaningful measurement
             * - simulate actual usage pattern
             * - find performance bottleneck
             */
            for _ in 0..<1000 {
                /**
                 * buffer state lookup
                 */
                ///
                /**
                 * _: ignore result (not used)
                 */
                ///
                /**
                 *
                 * @section _____ 💡 measurement target
                 * - lock/unlock overhead
                 * - buffer.count access
                 * - BufferStatus create/creation
                 * - fillPercentage calculation
                 */
                _ = channel.getBufferStatus()
            }
        }

        /**
         *
         * @section _____ 💡 result verify
         * verify in Xcode test report
         * - Average: average execution time
         * - Std Dev: standard deviation
         * - Set Baseline: can set baseline
         */
    }

    /**
     * Frame lookup Performance Tests
     */
    /**
     * getFrame(at:) measures method's performance.
     */
    /**
     *
     * @section getframe________ 🔍 getFrame() performance characteristics
     * @endcode
     * empty buffer: O(1) - immediately nil return
     * full buffer: O(log n) - binary search
     */
    /**
     * worst case:
     * - buffer 30pieces
     * - binary search: log₂(30) ≈ 5 steps
     * @endcode
     */
    /**
     *
     * @section 0_033____ 💡 0.033sec interval
     * @endcode
     * 30 fps video's frame interval
     * 1sec / 30 frame = 0.033sec
     */
    /**
     * test pattern:
     * frame 0: 0.000sec
     * frame 1: 0.033sec
     * frame 2: 0.066sec
     * ...
     * @endcode
     */
    /**
     * @test testGetFramePerformance
     * @brief 🎯 performance goal:
     *
     * @details
     *
     * @section _____ 🎯 performance goal
     * - 1000times lookup in < 20ms
     * - sufficient for real-time playback
     */
    func testGetFramePerformance() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> Create channel
         */
        /**
         * empty buffer state
         * (in reality frames should be present for meaningful test, but,
         *  test basic measure performance)
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: measure performance
         */
        /**
         * in measure block 1000times Frame lookup
         */
        measure {
            /**
             * 1000times Frame lookup
             */
            ///
            /**
             *
             * @section ____ 💡 each iteration
             * i=0: getFrame(at: 0.0)
             * i=1: getFrame(at: 0.033)
             * i=2: getFrame(at: 0.066)
             * ...
             */
            for i in 0..<1000 {
                /**
                 * timestamp calculation
                 */
                ///
                /**
                 * Double(i) * 0.033
                 * = iexpected timestamp of th frame
                 */
                ///
                /**
                 *
                 * @section 0_033___30_fps___ 💡 0.033 = 30 fps interval
                 */
                _ = channel.getFrame(at: Double(i) * 0.033)
            }
        }

        /**
         *
         * @section __________ 💡 performance improvement ideas
         * - maintain buffer as sorted array
         * - binary search algorithm optimization
         * - cache recent lookup results
         * - time scope indexing
         */
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Integration Tests (integration test)
// ═══════════════════════════════════════════════════════════════════════════

/// VideoChannel integration test class
///
/// performs entire workflow test using actual video file.
///
/// 🔗 What is integration test (Integration Tests)?
/// ```
/// test that verifies multiple components work together
///
/// Unit Tests vs Integration Tests:
///
/// Unit Tests:
/// - test single class/method
/// - Mock object use
/// - fast execution
///
/// Integration Tests:
/// - use actual dependencies
/// - entire workflow test
/// - slow execution
/// ```
///
/// 💡 test characteristics:
/// ```
/// 1. actual video file required
///    - test_video.mp4load from Bundle
///    - XCTSkipto skip if file missing
///
/// 2. perform actual decoding
///    - FFmpeg VideoDecoder use
///    - Thread.sleepto wait for decoding
///    - actual frame create/creation verify/verification
///
/// 3. entire function/feature verify/verification
///    - initialize → startDecoding → getFrame
///    - seek → new position decoding
///    - buffer management and frame order
/// ```
///
/// ⚠️ execution cautions:
/// - test_video.mp4 file must be included in test bundle 
/// - if file missing all tests XCTSkipskipped with
/// - executed slowly due to actual decoding (number sec takes)
final class VideoChannelIntegrationTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Video channel instance
     */
    /**
     * actual video with file initialization.
     */
    var channel: VideoChannel!

    /**
     * Test channel information
     */
    /**
     * includes test video file path.
     */
    var testChannelInfo: ChannelInfo!

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Setup & Teardown
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Initialize before each test execution
     */
    /**
     * find test video file and create channel.
     */
    /**
     * 📦 Bundle file access:
     * @endcode
     * let bundle = Bundle(for: type(of: self))
     * bundle.path(forResource: "filename", ofType: "extension")
     * @endcode
     */
    /**
     *
     * @section xctskip 💡 XCTSkip
     * @endcode
     * special error to skip test
     */
    /**
     * throw XCTSkip("Reason")
     *     ↓
     * test displayed as Skipped (not failure)
     */
    /**
     * when to use:
     * - required resource absent
     * - execute only in specific environment
     * - implementation wait during
     * @endcode
     */
    override func setUpWithError() throws {
        /**
         * Call parent class setUp
         */
        super.setUp()

        /**
         * find test video file
         */
        /**
         * Bundle(for:): test class Bundle
         */
        /**
         *
         * @section bundle___ 💡 What is Bundle?
         * @endcode
         * directory containing app resources
         */
        /**
         * structure:
         * MyApp.app/
         * ├── MyApp (execution file)
         * ├── Info.plist
         * └── Resources/
         *     ├── test_video.mp4  ← found here
         *     ├── icon.png
         *     └── ...
         * @endcode
         */
        let bundle = Bundle(for: type(of: self))

        /**
         * path(forResource:ofType:): file path find
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * from Bundle "test_video.mp4" file find
         *     ↓ if found
         * entire path return ("/path/to/test_video.mp4")
         *     ↓ if not found
         * nil return
         * @endcode
         */
        /**
         * guard let: nilthen execute else
         */
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            /**
             * skip test if file missing
             */
            ///
            /**
             * XCTSkip: test skip error
             */
            ///
            /**
             *
             * @section __ 💡 Reason
             * - displayed as skip not failure
             * - CI useful in environment
             * - optional test possible
             */
            throw XCTSkip("Test video file not found")
        }

        /**
         * channel information create/creation
         */
        /**
         * actual video file path use
         */
        testChannelInfo = ChannelInfo(
            position: .front,
            filePath: videoPath,
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )

        /**
         * Create channel
         */
        /**
         * actual with file initialization possible state
         */
        channel = VideoChannel(channelInfo: testChannelInfo)
    }

    /**
     * Cleanup after each test execution
     */
    /**
     * halt channel and release resources.
     */
    /**
     *
     * @section _____ 💡 cleanup order
     * 1. stop() - decoding halt, buffer cleanup
     * 2. channel = nil - memory unlock
     * 3. testChannelInfo = nil - information unlock
     */
    override func tearDownWithError() throws {
        /**
         * Stop channel
         */
        /**
         * decoding terminate thread, empty buffer
         */
        channel.stop()

        /**
         * Release channel
         */
        channel = nil

        /**
         * Release channel info
         */
        testChannelInfo = nil

        /**
         * Call parent class tearDown
         */
        super.tearDown()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Initialization Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * channel initialization integration test
     */
    /**
     * actual video call initialize() with file
     * verifies decoder readied normally.
     */
    /**
     *
     * @section ________ 🎬 test Scenario
     * @endcode
     * 1. Create channel (setUpcompleted in)
     * 2. initialize() call
     * 3. state .readyverify change to
     * @endcode
     */
    /**
     * @test testInitializeChannel
     * @brief 💡 initialize()internal operation of
     *
     * @details
     *
     * @section initialize_________ 💡 internal operation of initialize()
     * @endcode
     * initialize()
     *   ↓ file path verify
     *   ↓ VideoDecoder create/creation
     *   ↓ FFmpegopen file with
     *   ↓ video stream find
     *   ↓ codec initialization
     * state = .ready
     * @endcode
     */
    func testInitializeChannel() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> channel initialization
         */
        /**
         * try: error can occur
         */
        /**
         *
         * @section _____ 💡 success condition
         * - test_video.mp4 file exists
         * - valid video format
         * - supported codec
         */
        try channel.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> state verify
         */
        /**
         * XCTAssertEqual: compare value
         */
        /**
         *
         * @section __ 💡 expected
         * state = .ready (initialization completed)
         */
        /**
         *
         * @section _idle__ ⚠️ .idleif
         * initialization failure (test failure)
         */
        XCTAssertEqual(channel.state, .ready, "State should be ready after initialization")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Decoding Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * decoding start integration test
     */
    /**
     * startDecoding()call to start background decoding
     * verifies normally started.
     */
    /**
     *
     * @section ________ 🎬 test Scenario
     * @endcode
     * 1. initialize() - decoder ready
     * 2. startDecoding() - decoding start
     * 3. 0.5sec wait
     * 4. state and buffer verify
     * @endcode
     */
    /**
     * @test testStartDecoding
     * @brief 🔄 decoding process:
     *
     * @details
     *
     * @section ________ 🔄 decoding process
     * @endcode
     * startDecoding()
     *   ↓ execute in background queue
     *   ↓ loop:
     *   ↓   - AVPacket read
     *   ↓   - AVFrame decoding
     *   ↓   - add to buffer
     *   ↓   - state = .decoding
     * continuously executing...
     * @endcode
     */
    func testStartDecoding() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> channel initialization
         */
        /**
         * initialize()ready decoder with
         */
        try channel.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> decoding start
         */
        /**
         * startDecoding(): start background decoding
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * DispatchQueue.global().async {
         *     while !shouldStop {
         *         // Frame decoding
         *         // add to buffer
         *     }
         * }
         * @endcode
         */
        channel.startDecoding()

        /**
         * Frame wait for decoding
         */
        /**
         * Thread.sleep: current temporarily halt thread
         */
        /**
         *
         * @section 0_5_______ 💡 0.5sec wait Reason
         * @endcode
         * 30 fps video reference:
         * 0.5sec = 15 Frame can decode
         */
        /**
         * sufficient frames accumulated in buffer
         * @endcode
         */
        /**
         *
         * @section _______ ⚠️ in actual app
         * sleep instead asynchronous wait use
         */
        Thread.sleep(forTimeInterval: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> state and buffer verify/verification
         *
         * 1. state .decodingverify whether
         */
        /**
         *
         * @section __ 💡 expected
         * startDecoding() after → state = .decoding
         */
        XCTAssertEqual(channel.state, .decoding, "State should be decoding")

        /**
         * 2. bufferverify frames exist in
         */
        /**
         * getBufferStatus(): buffer state lookup
         */
        let status = channel.getBufferStatus()

        /**
         * XCTAssertGreaterThan: verify greater
         */
        /**
         *
         * @section __ 💡 expected
         * status.current > 0 (frame decoding completed)
         */
        /**
         *
         * @section 0__ ⚠️ 0if
         * decoding not operating (failure)
         */
        XCTAssertGreaterThan(status.current, 0, "Buffer should have frames")
    }

    /**
     * decoding after Frame lookup integration test
     */
    /**
     * decoding after decoding get frame at specific time with getFrame()
     * verifies can lookup.
     */
    /**
     *
     * @section ________ 🎬 test Scenario
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 0.5sec wait (Frame decoding)
     * 3. getFrame(at: 0.5) call
     * 4. frame return and timestamp verify
     * @endcode
     */
    /**
     * @test testGetFrameAfterDecoding
     * @brief 🔍 getFrame() operation:
     *
     * @details
     *
     * @section getframe_____ 🔍 getFrame() operation
     * @endcode
     * getFrame(at: 0.5)
     *   ↓ find frame closest in buffer
     *   ↓ binary search
     *   ↓ frame return
     * @endcode
     */
    func testGetFrameAfterDecoding() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> initialization and decoding start
         */
        /**
         * perform ready steps
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * Frame wait for decoding
         */
        /**
         * 0.5sec approximately 15frames decoding
         */
        Thread.sleep(forTimeInterval: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 0.5sec time Frame lookup
         */
        /**
         * getFrame(at:): specific time frame get
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * buffer: [0.0, 0.033, 0.066, ..., 0.5, ...]
         *          ↓ 0.5secclosest to frame find
         * return: Frame(timestamp: 0.5)
         * @endcode
         */
        let frame = channel.getFrame(at: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> frame verify/verification
         *
         * 1. verify frame returned
         */
        /**
         * XCTAssertNotNil: nilverify not
         */
        /**
         *
         * @section __ 💡 expected
         * frame != nil (frame exists)
         */
        /**
         *
         * @section nil__ ⚠️ nilif
         * no frames in buffer (failure)
         */
        XCTAssertNotNil(frame, "Should get frame from buffer")

        /**
         * 2. frame timestamp verify
         */
        /**
         * if let: optional binding
         */
        /**
         *
         * @section frame__nil_____ 💡 if frame is not nil
         * timestamp verify
         */
        if let frame = frame {
            /**
             * XCTAssertGreaterThanOrEqual: ≥ verify
             */
            ///
            /**
             *
             * @section __ 💡 expected
             * timestamp >= 0.0 (valid time)
             */
            ///
            /**
             * generally:
             * timestamp ≈ 0.5 (near requested time)
             */
            XCTAssertGreaterThanOrEqual(frame.timestamp, 0.0)
        }
    }

    /**
     * Seek and decoding integration test
     */
    /**
     * seek()move to specific position with
     * verifies decoding normally operates at new position.
     */
    /**
     *
     * @section ________ 🎬 test Scenario
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 0.3sec wait (initial Frame decoding)
     * 3. seek(to: 5.0) - 5sec position move to
     * 4. 0.5sec wait (new position decoding)
     * 5. getFrame(at: 5.0) verify
     * @endcode
     */
    /**
     * @test testSeekAndDecode
     * @brief 🎯 seek() operation:
     *
     * @details
     *
     * @section seek_____ 🎯 seek() operation
     * @endcode
     * seek(to: 5.0)
     *   ↓ temporarily halt decoding
     *   ↓ empty buffer (flushBuffer)
     *   ↓ VideoDecoder.seek(to: 5.0)
     *   ↓ 5sec move to I-Frame near
     *   ↓ resume decoding
     * 5sec decode anew from...
     * @endcode
     */
    func testSeekAndDecode() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> initialization and initial decoding
         */
        /**
         * decoder ready and start
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * initial Frame wait for decoding
         */
        /**
         * 0.3sec = approx 9pieces frame
         */
        Thread.sleep(forTimeInterval: 0.3)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 5secseek to
         */
        /**
         * seek(to:): move to specific time
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * current position: ~0.3sec
         *     ↓ seek(to: 5.0)
         * new position: 5.0sec
         *     ↓ Buffer initialization
         *     ↓ 5secdecode from
         * @endcode
         */
        try channel.seek(to: 5.0)

        /**
         * wait for decoding at new position
         */
        /**
         * 0.5sec for 5sec decode frames near
         */
        Thread.sleep(forTimeInterval: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 5sec verify frames near
         */
        /**
         * getFrame(at: 5.0): 5sec Frame lookup
         */
        let frame = channel.getFrame(at: 5.0)

        /**
         * 1. frame verify existence
         */
        /**
         *
         * @section __ 💡 expected
         * 5sec frames near in buffer
         */
        XCTAssertNotNil(frame, "Should get frame after seeking")

        /**
         * 2. frame timestamp verify
         */
        /**
         * if let: optional binding
         */
        if let frame = frame {
            /**
             * XCTAssertGreaterThanOrEqual: ≥ verify
             */
            ///
            /**
             *
             * @section __ 💡 expected
             * timestamp >= 5.0
             */
            ///
            /**
             * generally:
             * timestamp ≈ 5.0 (seek point)
             */
            ///
            /**
             *
             * @section i_frame_______ ⚠️ I-Frame depending on position
             * accurately 5.0may not be
             * (4.9 ~ 5.1 approximately)
             */
            XCTAssertGreaterThanOrEqual(frame.timestamp, 5.0, "Frame should be at or after seek point")
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Buffer Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * buffer filling and cleanup integration test
     */
    /**
     * decode until buffer is full
     * verifies buffer size limit operates correctly.
     */
    /**
     *
     * @section ________ 🎬 test Scenario
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 2.0sec wait (sufficient decoding time)
     * 3. buffer state verify
     * 4. maximum size and fill ratio verify/verification
     * @endcode
     */
    /**
     *
     * @section ________ 💡 buffer size limit
     * @endcode
     * maxBufferSize = 30
     */
    /**
     * @test testBufferFillAndCleanup
     * @brief operation:
     *
     * @details
     * operation:
     * - 30pieces framesave up to
     * - 31th frame add removes oldest frame
     * - FIFO (First In First Out) way
     * @endcode
     */
    func testBufferFillAndCleanup() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> initialization and decoding start
         */
        /**
         * decoder ready and start
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * buffer wait for filling
         */
        /**
         * 2.0sec = approx 60frames decoding attempt
         */
        /**
         *
         * @section __ 💡 operation
         * @endcode
         * 0.0 ~ 0.5sec: buffer 15pieces
         * 0.5 ~ 1.0sec: buffer 30pieces (full)
         * 1.0 ~ 2.0sec: buffer 30pieces (maintain maximum)
         *               → old frames removed
         * @endcode
         */
        Thread.sleep(forTimeInterval: 2.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> buffer state lookup
         */
        /**
         * getBufferStatus(): current buffer state
         */
        let status = channel.getBufferStatus()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> buffer size limit verify/verification
         *
         * 1. current size ≤ maximum size
         */
        /**
         * XCTAssertLessThanOrEqual: ≤ verify
         */
        /**
         *
         * @section __ 💡 expected
         * status.current <= status.max
         * example: current=30, max=30 ✅
         */
        /**
         *
         * @section current___max__ ⚠️ current > maxif
         * buffer size limit failure (failure)
         */
        XCTAssertLessThanOrEqual(status.current, status.max, "Buffer should not exceed max size")

        /**
         * 2. fill ratio ≤ 100%
         */
        /**
         * fillPercentage: current / max
         */
        /**
         *
         * @section __ 💡 expected
         * fillPercentage <= 1.0 (100%)
         * example: 30/30 = 1.0 ✅
         */
        /**
         *
         * @section __1_0__ ⚠️ > 1.0if
         * calculation error (failure)
         */
        XCTAssertLessThanOrEqual(status.fillPercentage, 1.0, "Fill percentage should not exceed 100%")
    }

    /**
     * frame timestamp order integration test
     */
    /**
     * timestamp of looked up frames in buffer
     * verifies sorted in correct order.
     */
    /**
     *
     * @section ________ 🎬 test Scenario
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 1.0sec wait (sufficient Frame decoding)
     * 3. 0.0, 1.0, 2.0sec Frame lookup
     * 4. timestamp order verify
     * @endcode
     */
    /**
     *
     * @section _____________ 💡 importance of timestamp order
     * @endcode
     * sorted buffer:
     * [0.0, 0.033, 0.066, ..., 1.0, ..., 2.0]
     */
    /**
     * binary search possible:
     * - O(log n) performance
     * - Fast frame lookup
     */
    /**
     * @test testFrameTimestampOrdering
     * @brief without order:
     *
     * @details
     * without order:
     * - linear search required O(n)
     * - slow performance
     * @endcode
     */
    func testFrameTimestampOrdering() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> initialization and decoding
         */
        /**
         * decoder ready and start
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * Frame wait for decoding
         */
        /**
         * 1.0sec = approx 30pieces frame
         */
        Thread.sleep(forTimeInterval: 1.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> lookup frames at multiple times
         */
        /**
         * 0.0, 1.0, 2.0sec frame get
         */
        /**
         *
         * @section _____ 💡 lookup order
         * even if not sequential 
         * find in buffer sorted by timestamp
         */
        let frame1 = channel.getFrame(at: 0.0)
        let frame2 = channel.getFrame(at: 1.0)
        let frame3 = channel.getFrame(at: 2.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> timestamp order verify
         */
        /**
         * if let: optional binding (3pieces all)
         */
        /**
         *
         * @section __ 💡 syntax
         * @endcode
         * if let f1 = frame1, let f2 = frame2, let f3 = frame3 {
         *     // execute only when all not nil
         * }
         * @endcode
         */
        if let f1 = frame1, let f2 = frame2, let f3 = frame3 {
            /**
             * 1. frame1 < frame2
             */
            ///
            /**
             * XCTAssertLessThan: < verify
             */
            ///
            /**
             *
             * @section __ 💡 expected
             * f1.timestamp < f2.timestamp
             * example: 0.0 < 1.0 ✅
             */
            XCTAssertLessThan(f1.timestamp, f2.timestamp, "Frames should be ordered by timestamp")

            /**
             * 2. frame2 < frame3
             */
            ///
            /**
             *
             * @section __ 💡 expected
             * f2.timestamp < f3.timestamp
             * example: 1.0 < 2.0 ✅
             */
            ///
            /**
             *
             * @section _______ ⚠️ if order wrong
             * buffer sorting failure (failure)
             */
            XCTAssertLessThan(f2.timestamp, f3.timestamp, "Frames should be ordered by timestamp")
        }
    }
}
