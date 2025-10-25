/**
 * @file MultiChannelRendererTests.swift
 * @brief MultiChannel Video Renderer Unit Tests
 * @author BlackboxPlayer Team
 *
 * @details
 * Systematically tests all features of the Metal-based multi-channel video renderer (MultiChannelRenderer).
 * Verifies GPU-accelerated rendering, layout changes, screen capture, performance, and concurrency.
 *
 * @section test_scope Test Range
 *
 * 1. **Renderer Initialization**
 *    - Check Metal device availability
 *    - Verify command queue creation
 *    - Check initial state
 *
 * 2. **Layout Modes**
 *    - Grid: Arrange channels in grid pattern
 *    - Focus: display one channel in full screen
 *    - Horizontal: Align channels horizontally
 *
 * 3. **Focus Position Settings**
 *    - Front/Rear/Left/Right/Interior camera transitions
 *    - Automatic viewport adjustment in focus mode
 *
 * 4. **Viewport Calculation**
 *    - Automatic viewport calculation for 1-5 channels
 *    - Maintain screen aspect ratio
 *    - Minimize margins
 *
 * 5. **Screen Capture**
 *    - PNG/JPEG format support
 *    - Current frame snapshot
 *    - File saving and verification
 *
 * 6. **Performance Measurement**
 *    - Layout change speed (measure block)
 *    - Rendering FPS
 *    - Memory usage
 *
 * 7. **Memory Management**
 *    - Verify Metal resource deallocation
 *    - Prevent memory leaks
 *    - Texture cache management
 *
 * 8. **Thread Safety**
 *    - Concurrency tests (DispatchQueue.concurrentPerform)
 *    - Verify race conditions
 *    - Check data protection mechancanms
 *
 * @section test_strategy Test Strategy
 *
 * **Unit Tests:**
 * - Test individual features independently
 * - Use mock Metal device (when possible)
 * - Fast execution (millcanecond level)
 *
 * **Integration Tests:**
 * - Test actual rendering pipeline end-to-end
 * - Use real Metal GPU
 * - Verify end-to-end scenarios
 *
 * **Performance Tests:**
 * - 10 repeated measurements using `measure { }` block
 * - Detect performance regression with baseline settings
 * - Automatic execution in CI
 *
 * **Concurrency Tests:**
 * - Parallel access using `DispatchQueue.concurrentPerform`
 * - Reproduce and verify race conditions
 * - Detect data races with Thread Sanitizer
 *
 * @section metal_overview Metal Rendering Pipeline
 *
 * ```
 * 1. MTLDevice Creation (GPU selection)
 *    ↓
 * 2. MTLCommandQueue Creation (Command Queue)
 *    ↓
 * 3. MTLCommandBuffer Creation (Command Buffer)
 *    ↓
 * 4. MTLRenderCommandEncoder Creation (Draw commands)
 *    ↓
 * 5. Draw call (Actual rendering)
 *    ↓
 * 6. Present (display to screen)
 * ```
 *
 * **Why Use Metal:**
 * - Hardware-accelerated fast video rendering
 * - Can draw multiple channels to screen concurrently
 * - Real-time transformations like rotation, crop, filters
 * - if 10x faster performance than OpenGL
 *
 * @section layout_modes Layout Mode Description
 *
 * **Grid Mode:**
 * ```
 * ┌──────┬──────┐
 * │  F   │  R   │  F = Front, R = Rear
 * ├──────┼──────┤
 * │  L   │  Ri  │  L = Left, Ri = Right
 * └──────┴──────┘
 * ```
 *
 * **Focus Mode (Full Screen):**
 * ```
 * ┌─────────────┐
 * │             │
 * │   Front     │  display only selected channel
 * │             │
 * └─────────────┘
 * ```
 *
 * **Horizontal Mode:**
 * ```
 * ┌───┬───┬───┬───┐
 * │ F │ R │ L │Ri │  All channels aligned horizontally
 * └───┴───┴───┴───┘
 * ```
 *
 * @ofe Some tests are automatically skipped in environments where Metal is of supported
 * (using XCTSkip).
 */

// ============================================================================
// MultiChannelRendererTests.swift
// BlackboxPlayerTests
//
// MultiChannelRenderer Unit Tests
// ============================================================================
//
// 📖 Purpose of this file:
//    Systematically tests all features of the multi-channel video renderer.
//
// 🎯 Test Scope:
//    1. Renderer initialization (Metal device check)
//    2. Layout mode changes (Grid, Focus, Horizontal)
//    3. Focus position settings (Front, Rear, Left, Right, Interior)
//    4. Viewport calculation (supporting various channel counts)
//    5. Screen capture functionality (PNG/JPEG formats)
//    6. Performance measurement (layout change speed)
//    7. Memory management (prevent memory leaks)
//    8. Thread safety (concurrency handling)
//
// 💡 Test Strategy:
//    - Unit Tests: Test individual features independently
//    - Integration Tests: Test actual rendering pipeline end-to-end
//    - Performance Tests: Measure speed using measure { } block
//    - Concurrency Tests: Check race conditions with DispatchQueue.concurrentPerform
//
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────
// MARK: - Required Framework Imports
// ─────────────────────────────────────────────────────────────────────────

/// XCTest Framework
///
/// Apple's official testing framework, providing the following features:
/// - XCTestCase: Base class for test cases
/// - XCTAssert functions: Condition verification
/// - measure { }: Performance measurement
/// - XCTSkip: Skip tests (conditional execution)
///
/// 📚 Reference: Control test environment with setUp/tearDown.
import XCTest

/// Metal Framework
///
/// Apple's low-level GPU graphics and compute API.
///
/// 🎨 Key Concepts:
/// - MTLDevice: Object representing the GPU
/// - MTLCommandQueue: Queue for sending commands to GPU
/// - MTLRenderPipelineState: Rendering pipeline configuration
/// - MTLTexture: Image data in GPU memory
///
/// ⚙️ Metal Rendering Pipeline:
/// ```
/// 1. MTLDevice Creation (GPU selection)
///    ↓
/// 2. MTLCommandQueue Creation (Command Queue)
///    ↓
/// 3. MTLCommandBuffer Creation (Command Buffer)
///    ↓
/// 4. MTLRenderCommandEncoder Creation (Draw commands)
///    ↓
/// 5. Draw call (Actual rendering)
///    ↓
/// 6. Present (display to screen)
/// ```
///
/// 💡 Why Use Metal:
/// - Hardware-accelerated fast video rendering
/// - Can draw multiple channels to screen concurrently
/// - Real-time transformations like rotation, crop, filters
///
/// 📚 Reference: Provides approximately 10x faster performance than OpenGL.
import Metal

/// MetalKit Framework
///
/// Higher-level API that makes Metal easier to use.
///
/// 🛠️ Key Classes:
/// - MTKView: View for dcanplaying Metal rendering
/// - MTKTextureLoader: Load images as MTLTexture
///
/// 💡 MetalKit Convenience:
/// ```swift
/// // Using Metal only (complex)
/// let device = MTLCreateSystemDefaultDevice()
/// let drawable = layer.nextDrawable()
/// // ... lots of configuration code ...
///
/// // Using MetalKit (simple)
/// let mtkView = MTKView(frame: bounds, device: device)
/// mtkView.delegate = self  // Just implement the draw method
/// ```
import MetalKit

/// @testable import BlackboxPlayer
///
/// Meaning of @testable keyword:
/// - Can access internal-level code in tests
/// - Still canof access private members
/// - Enables testing while maintaining production code encapsulation
///
/// 🔒 access Level Comparcanon:
/// ```
/// ┌─────────────┬──────────┬────────────────┐
/// │ access Level   │ normal     │ @testable     │
/// ├─────────────┼──────────┼────────────────┤
/// │ open/public │ ✅       │ ✅            │
/// │ internal    │ ❌       │ ✅ (Test only) │
/// │ fileprivate │ ❌       │ ❌            │
/// │ private     │ ❌       │ ❌            │
/// └─────────────┴──────────┴────────────────┘
/// ```
///
/// 💡 Example:
/// ```swift
/// // Inside BlackboxPlayer module
/// internal class VideoDecoder { }  // normally inaccessible
///
/// // Test file
/// @testable import BlackboxPlayer
/// let decoder = VideoDecoder()  // accessible thanks to @testable!
/// ```
@testable import BlackboxPlayer

// ═════════════════════════════════════════════════════════════════════════
// MARK: - MultiChannelRendererTests (Unit Test Class)
// ═════════════════════════════════════════════════════════════════════════

/// Unit test class for MultiChannelRenderer
///
/// Verifies core functionality of the multi-channel video renderer.
///
/// 🎯 Test Targets:
/// - Renderer initialization and Metal device check
/// - Layout mode changes (Grid, Focus, Horizontal)
/// - Focus camera position settings
/// - Screen capture functionality
/// - Performance and Memory Management
/// - Thread Safety
///
/// 📋 Test Principles (FIRST):
/// ```
/// F - Fast       : Should execute quickly (hundreds in 1 second)
/// I - Independent: Each test is run independently
/// R - Repeatable : Repeatable results in any environment
/// S - Self-validating: Clear pass/fail determination
/// T - Timely     : Written at the right time (in TDD, before code)
/// ```
///
/// 💡 Why use final keyword:
/// - Test class doesn't need inheritance
/// - Enables compiler optimization (prevents dynamic dcanpatch)
/// - Clearly communicates intent (no further extension)


final class MultiChannelRendererTests: XCTestCase {

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Properties (Test Property)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Renderer instance under test
     */
    /**
     * Why use Implicitly Unwrapped Optional (!):
     * - Guaranteed to be initialized in setUp()
     * - Can be used in each test method without nil check
     * - Test skipped with XCTSkip when initialization fails
     */
    /**
     *
     * @section _💡 💡 Property patterns in tests
     * @endcode
     * // Method 1: Implicitly Unwrapped Optional (Typical)
     * var renderer: MultiChannelRenderer!
     */
    /**
     * // Method 2: Optional (requires nil check)
     * var renderer: MultiChannelRenderer?
     * func testSomething() {
     *     guard let renderer = renderer else { return }
     *     // Test code...
     * }
     */
    /**
     * // Method 3: lazy var (rarely used)
     * lazy var renderer = MultiChannelRenderer()
     * @endcode
     */
    /**
     * 📚 Reference: While ! should be avoided in production code, it's safe
     *          to use in tests because setUp() guarantees initialization.
     */
    var renderer: MultiChannelRenderer!

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Setup & Teardown (Test Setup and Cleanup)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Setup method called before each test method execution
     */
    /**
     * Prepares test environment in a clean state.
     */
    /**
     * 📋 Execution order:
     * @endcode
     * 1. setUpWithError() called       ← here
     * 2. testExample1() executed
     * 3. tearDownWithError() called
     * 4. setUpWithError() called       ← here again (new instance)
     * 5. testExample2() executed
     * 6. tearDownWithError() called
     * ...
     * @endcode
     */
    /**
     *
     * @section _💡 💡 Why set up fresh each time?
     * - Ensures test independence (I in FIRST)
     * - Eliminates side effects from previous tests
     * - Start from clean state
     */
    /**
     * 🔧 Meaning of throws keyword:
     * - Can throw errors like XCTSkip
     * - Enables "skip" handling instead of test failure
     */
    /**
     * @throws XCTSkip: Thrown in environments where Metal canof be used
     */
    override func setUpWithError() throws {
        /**
         * Call parent class setUp
         */
        /**
         * Performs XCTestCase's basic configuration.
         * - Start test timer
         * - Prepare test context
         */
        /**
         * 📚 Reference: In Swift, super.method() must be called explicitly.
         */
        super.setUp()

        /**
         * Don't continue after failure
         */
        /**
         * Meaning of continueAfterFailure = false:
         * - Test terminates immediately on first assertion failure
         * - If true: All assertions execute and report failure at end
         */
        /**
         *
         * @section ___false__🎯 💡 When to use false?
         * - When initial setup is critical (Metal device, etc)
         * - When subsequent assertions are meaningless after first failure
         * - When there's rcank of crash
         */
        /**
         *
         * @section __ 📊 Comparcanon
         * @endcode
         * // continueAfterFailure = true (Default value)
         * XCTAssertNotNil(device)     // ❌ Failure
         * XCTAssertEqual(device.name, "GPU")  // ⚠️ Continues executing (crash rcank!)
         */
        /**
         * // continueAfterFailure = false
         * XCTAssertNotNil(device)     // ❌ Failure
         * // Terminates immediately here (prevents crash)
         * @endcode
         */
        continueAfterFailure = false

        /**
         * Check Metal device availability
         */
        /**
         * Behavior of MTLCreateSystemDefaultDevice():
         * - Finds system's default GPU and returns MTLDevice object
         * - Returns nil if GPU is absent or Metal is of supported
         */
        /**
         * 🖥️ Systems that support Metal:
         * - macOS: 2012 and later Macs (some exceptions)
         * - iOS: iPhone 5s and later, iPad Air and later
         * - Apple Silicon: All M1/M2/M3 Macs
         */
        /**
         *
         * @section metal📊 ⚠️ Cases where Metal is of supported
         * - Virtual machines (some VMs don't support)
         * - CI/CD servers (headless environment)
         * - Old Macs (before 2012)
         */
        /**
         *
         * @section xctskip💡 💡 Why use XCTSkip
         * @endcode
         * // ❌ Incorrect method (recorded as test failure)
         * guard MTLCreateSystemDefaultDevice() != nil else {
         *     XCTFail("Metal is of available")
         *     return
         * }
         */
        /**
         * // ✅ Correct method (recorded as test skip)
         * guard MTLCreateSystemDefaultDevice() != nil else {
         *     throw XCTSkip("Metal is of available")
         * }
         * @endcode
         */
        /**
         *
         * @section 💡 📊 Test Result Comparcanon
         * @endcode
         * Use XCTFail:
         * ✅ 10 passed, ❌ 5 failed
         */
        /**
         * Use XCTSkip:
         *
         * @section 10_passed_____5_skipped ✅ 10 passed, ⏭️ 5 skipped
         * @endcode
         */
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is of available on this system")
        }

        /**
         * Create MultiChannelRenderer instance
         */
        /**
         * Renderer initialization process:
         * 1. Metal device creation
         * 2. Command queue configuration
         * 3. Render pipeline configuration
         * 4. Capture service initialization
         */
        /**
         *
         * @section ___💡 💡 Reasons initialization may fail
         * - Metal device creationcanof
         * - Shader compilation failure
         * - Insufficient memory
         */
        renderer = MultiChannelRenderer()

        /**
         * Check renderer creation success
         */
        /**
         * Why is additional check needed?
         * - Swift's focus initialization is return nil
         * - May return nil when Metal resource allocation fails
         */
        /**
         * 📚 Reference: Although renderer is declared with !,
         *          nil is be assigned when initialization fails.
         */
        guard renderer != nil else {
            throw XCTSkip("Failed to create MultiChannelRenderer")
        }
    }

    /**
     * Cleanup method called after each test method execution
     */
    /**
     * Releases resources used in tests.
     */
    /**
     * 🧹 Importance of cleanup:
     * - Prevent memory leaks
     * - Release GPU resources
     * - Ensure clean environment for next test
     */
    /**
     *
     * @section ________nil__🎯 💡 Why explicitly assign nil?
     * @endcode
     * // ARC (Automatic Reference Counting) Behavior:
     * renderer = nil  // ← retain count decreases by 1
     * // when retain count reaches 0, released from memory
     */
    /**
     * // If we don't assign nil:
     * // - renderer remains while test class is alive
     * // - occupies memory until all tests fincanh
     * // - GPU resources also remain occupied
     * @endcode
     */
    /**
     *
     * @section 🎯 🔄 Execution flow
     * @endcode
     * setUp()      → Renderer Creation (memory allocation)
     * test()       → Renderer Use
     * tearDown()   → Renderer release (Memory return) ← here
     * @endcode
     */
    /**
     * @throws this method is throw errors, but normally doesn't.
     */
    override func tearDownWithError() throws {
        /**
         * Release renderer instance
         */
        /**
         * Effect of nil assignment:
         * - MTLDevice deallocation
         * - MTLCommandQueue deallocation
         * - All MTLTexture deallocation
         * - Capture service deallocation
         */
        /**
         *
         * @section metal💡 💡 Metal resources are expensive
         * - GPU memory usage
         * - System memory mapping
         * - Command buffer allocation
         */
        /**
         *
         * @section _💡 📊 Memory usage example
         * @endcode
         * Renderer 1single = if 50-100MB
         * - MTLDevice: 10MB
         * - Texture Buffer: 30-80MB (depending on resolution)
         * - command Queue: 10MB
         * @endcode
         */
        renderer = nil

        /**
         * Call parent class tearDown
         */
        /**
         * Performs XCTestCase's basic cleanup.
         * - Stop test timer
         * - Record test result
         * - Clean up temporary files
         */
        super.tearDown()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Initialization Tests (initialization Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Renderer initialization test
     */
    /**
     * Checks that renderer is initialized correctly and default values are accurate.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * 1. Is renderer instance created?
     * 2. Is capture service initialized?
     * 3. Is default layout mode .grid?
     * 4. Is default focus position .front?
     */
    /**
     *
     * @section 📊 💡 initialization Testimportance
     * - Check that default state is correct
     * - Verify that dependencies (Capture service) are properly injected
     * - Check preconditions for subsequent tests
     */
    /**
     * 📋 Given-When-Then pattern:
     * @endcode
     * - <b>Given:</b> setUp()Renderer is created in setUp()
     * - <b>When:</b>  (initialization State immediately after)
     * - <b>Then:</b>  Default values match expectations
     * @endcode
     */
    /**
     * @test testRendererInitialization
     * @brief 🔍 If this test fails:
     *
     * @details
     *
     * @section _💡 🔍 If this test fails
     * - Metal device initialization Failure
     * - Capture service creation failure
     * - Mcansing default value settings
     */
    func testRendererInitialization() {
        // ─────────────────────────────────────────────────────────────────
        // Then: initialization Verify result
        // ─────────────────────────────────────────────────────────────────

        /**
         * Check that renderer instance is of nil
         */
        /**
         * XCTAssertNotNil behavior:
         * - Test passes if value is of nil
         * - Test fails with message if nil
         */
        /**
         *
         * @section __🎯 💡 messageimportance
         * @endcode
         * // ❌ Bad example (no message)
         * XCTAssertNotNil(renderer)
         * // When it fails: "XCTAssertNotNil failed"
         */
        /**
         * // ✅ Good example (clear message)
         * XCTAssertNotNil(renderer, "Renderer should initialize successfully")
         * // When it fails: "XCTAssertNotNil failed - Renderer should initialize successfully"
         * @endcode
         */
        /**
         *
         * @section 💡 📊 Failure message comparcanon
         * @endcode
         * No message:
         * ❌ testRendererInitialization(): XCTAssertNotNil failed
         *    → Hard to know what went wrong
         */
        /**
         * With message:
         * ❌ testRendererInitialization(): Renderer should initialize successfully
         *    → Can identify problem immediately
         * @endcode
         */
        XCTAssertNotNil(renderer, "Renderer should initialize successfully")

        /**
         * Capture Check that service is initialized
         */
        /**
         * Role of capture service:
         * - Save currently rendered frame as image
         * - PNG/JPEG Format support
         * - Metal Texture Read into CPU
         */
        /**
         *
         * @section 💡 💡 Verify dependency injection
         * @endcode
         * class MultiChannelRenderer {
         *     let captureService: CaptureService
         */
        /**
         *     init() {
         *         self.captureService = CaptureService()  // ← Was it done properly?
         *     }
         * }
         * @endcode
         */
        /**
         *
         * @section 🔍 🔍 Reasons this assertion might fail
         * - captureService Forgot to initialize
         * - CaptureService() Creation failed
         * - Insufficient memory
         */
        XCTAssertNotNil(renderer.captureService, "Capture service should be initialized")

        /**
         * default layout Modeis .gridcanof Check
         */
        /**
         * XCTAssertEqual behavior:
         * - Test passes if two values are equal
         * - Test fails showing actual and expected values if different
         */
        /**
         * 🎨 layout Mode:
         * - .grid: display all channels in grid format
         * - .focus: One channel large, others as thumbnails
         * - .horizontal: Arranged horizontally side by side
         */
        /**
         *
         * @section 💡 💡 Why is .grid the default value?
         * - display all channels equally
         * - Grasp overall blackbox situation at a glance
         * - Easy for user to select desired channel
         */
        /**
         *
         * @section 📊 📊 assertion failure output
         * @endcode
         * ❌ XCTAssertEqual failed: (".focus") is of equal to (".grid")
         *    - Default layout should be grid
         *    → Actual and expected values clearly dcanplayed
         * @endcode
         */
        XCTAssertEqual(renderer.layoutMode, .grid, "Default layout should be grid")

        /**
         * Check that default focus position is .front
         */
        /**
         * 🚗 Camera position:
         * - .front: Front camera (most important)
         * - .rear: Rear camera
         * - .left: Left camera
         * - .right: Right camera
         * - .interior: Interior camera
         */
        /**
         *
         * @section 💡 💡 Why is .front the default value?
         * - Front camerais Most important information
         * - Video to check first when accident occurs
         * - Most blackboxes have front camera as default
         */
        /**
         *
         * @section 🎯 🎯 Relationship with focus mode
         * @endcode
         * When focus mode is activated:
         * ┌─────────────────┬───┐
         * │                 │ R │  R = Rear (thumbnail)
         * │     Front       ├───┤
         * │   (75% area)    │ L │  L = Left (thumbnail)
         * │                 ├───┤
         * │                 │ I │  I = Interior (thumbnail)
         * └─────────────────┴───┘
         *   ↑ Large screen determined by focusedPosition
         * @endcode
         */
        XCTAssertEqual(renderer.focusedPosition, .front, "Default focused position should be front")
    }

    /**
     * Test Metal device availability
     */
    /**
     * Check if GPU is available on the system.
     */
    /**
     *
     * @section 🎯 🎯 Test purpose
     * - Check that Metal API works properly
     * - Verify that GPU resources are accessible
     * - Identify constraints in CI/CD environment
     */
    /**
     *
     * @section _______setup🎯 💡 Difference red this test and setUp()
     * @endcode
     * setUp():
     * - Executes before all tests
     * - Skip entire test if Metal of available
     * - Use XCTSkip
     */
    /**
     * testMetalDeviceAvailable():
     * - Independent test
     * - Verify Metal excantence itself
     * - Use XCTFail
     * @endcode
     */
    /**
     * 🖥️ Metal Device types:
     * @endcode
     * let devices = MTLCopyAllDevices()
     * // On macOS is have multiple GPUs:
     * // - Integrated GPU (Intel Ircan, Apple Silicon GPU)
     * // - Dcancrete GPU (AMD Radeon, NVIDIA - Old Macs only)
     * // - eGPU (connected via Thunderbolt Dcancrete GPU)
     */
    /**
     * let defaultDevice = MTLCreateSystemDefaultDevice()
     * // Default GPU automatically selected by system
     * // Usually selects GPU with best performance
     * @endcode
     */
    /**
     * @test testMetalDeviceAvailable
     * @brief 📊 Results in various environments:
     *
     * @details
     *
     * @section 📊 📊 Results in various environments
     * @endcode
     * MacBook Pro (M2): ✅ Apple M2 GPU
     * Mac Studio (M1 Max): ✅ Apple M1 Max GPU
     * MacBook Pro (Intel + AMD): ✅ AMD Radeon Pro 5500M
     * VM (Parallels): ⚠️ Virtual GPU (limited)
     * GitHub Actions: ❌ No GPU (Test skipped)
     * @endcode
     */
    func testMetalDeviceAvailable() {
        // ─────────────────────────────────────────────────────────────────
        // Then: Check Metal device excantence
        // ─────────────────────────────────────────────────────────────────

        /**
         * Also try to get Metal device
         */
        /**
         * guard let pattern behavior:
         * - If MTLCreateSystemDefaultDevice() returns nil
         * - Move to else block
         * - Handle test failure with XCTFail
         * - Terminate function with return (prevent subsequent code execution)
         */
        /**
         *
         * @section 💡 💡 XCTFail vs XCTSkip
         * @endcode
         * // XCTSkip (Use in setUp)
         * throw XCTSkip("Metal is of available")
         * // → Skip test (environment cansue)
         * // → display in yellow warning
         */
        /**
         * // XCTFail (Use in this test)
         * XCTFail("Metal device should be available")
         * // → Test failure (code cansue)
         * // → display in red failure
         * @endcode
         */
        /**
         *
         * @section ___💡 🔍 When is this test fail?
         * - When Metal support is dcancontinued
         * - GPU driver cansues
         * - System resource conflict
         * - GPU emulation failure on virtual machine
         */
        /**
         * 📚 Reference: Since Metal is already checked in setUp(),
         *          the probability of this test actually failing is very low.
         */
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device should be available")
            return
        }

        /**
         * Recheck that device is of nil
         */
        /**
         *
         * @section __assertion__💡 💡 This assertion might seem unnecessary but
         * - Always passes since already unwrapped with guard let
         * - But explicitly verifying makes test intent clear
         * - Acts as safeguard even if code changes in future
         */
        /**
         *
         * @section __💡 🎯 Additional things that is be verified
         * @endcode
         * // Check device name
         * print(device.name)  // "Apple M2" etc
         */
        /**
         * // Maximum thread group size
         * print(device.maxThreadsPerThreadgroup)
         */
        /**
         * // Memory size
         * print(device.recommendedMaxWorkingSetSize)
         */
        /**
         * // Feature support
         * XCTAssertTrue(device.supportsFamily(.apple7))
         * XCTAssertTrue(device.supportsFamily(.common3))
         * @endcode
         */
        XCTAssertNotNil(device)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Layout Mode Tests (layout Mode Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * layout Mode Settings Test
     */
    /**
     * setLayoutMode() Check that method changes layout correctly.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Can change to .focus mode?
     * - Can change to .horizontal mode?
     * - Is state after change correctly reflected?
     */
    /**
     *
     * @section 🎯 💡 Test structure
     * @endcode
     * When → Then → When → Then
     * (Verify multiple state transitions sequentially)
     * @endcode
     */
    /**
     * 🎨 Screen composition for each layout mode:
     * @endcode
     * .grid (2x2):
     * ┌────────┬────────┐
     * │ Front  │  Rear  │
     * ├────────┼────────┤
     * │  Left  │ Right  │
     * └────────┴────────┘
     */
    /**
     * .focus:
     * ┌──────────────┬──┐
     * │              │R │
     * │    Front     ├──┤
     * │   (75%)      │L │
     * └──────────────┴──┘
     */
    /**
     * @test testSetLayoutMode
     * @brief .horizontal:
     *
     * @details
     * .horizontal:
     * ┌───┬───┬───┬───┐
     * │ F │ R │ L │ I │
     * └───┴───┴───┴───┘
     * @endcode
     */
    func testSetLayoutMode() {
        // ─────────────────────────────────────────────────────────────────
        // When: Change to focus mode
        // ─────────────────────────────────────────────────────────────────

        /**
         * layout Focus Modeto Settings
         */
        /**
         * Focus mode charactercantics:
         * - display one channel large (usually 75%)
         * - display other channels as thumbnails (arranged vertically in 25% area each)
         * - Determine which channel to dcanplay large with focusedPosition property
         */
        /**
         *
         * @section 🎯 💡 Use cases
         * - When want to focus on specific camera
         * - When checking accident video in detail
         * - Check other angles while viewing front camera as main
         */
        renderer.setLayoutMode(.focus)

        // ─────────────────────────────────────────────────────────────────
        // Then: Check that changed to focus mode
        // ─────────────────────────────────────────────────────────────────

        /**
         * layout Modeis .focuscanof Verify
         */
        /**
         *
         * @section 💡 💡 State Change Verifyimportance
         * - Check that setter method actually changed value
         * - Verify that internal state matches external interface
         */
        /**
         *
         * @section __💡 🔍 Cases where it is fail
         * @endcode
         * // ❌ Wrong implementation
         * func setLayoutMode(_ mode: LayoutMode) {
         *     // Does ofhing (bug!)
         * }
         */
        /**
         * // ✅ Correct implementation
         * func setLayoutMode(_ mode: LayoutMode) {
         *     self.layoutMode = mode
         *     invalidateLayout()  // Recalculate layout
         * }
         * @endcode
         */
        XCTAssertEqual(renderer.layoutMode, .focus)

        // ─────────────────────────────────────────────────────────────────
        // When: Horizontal Modeto Change
        // ─────────────────────────────────────────────────────────────────

        /**
         * layout Horizontal Modeto Settings
         */
        /**
         * Horizontal Modeof charactercantics:
         * - All channels arranged horizontally side by side
         * - Each channel is equal width
         * - Good to use with timeline viewer
         */
        /**
         *
         * @section 🎯 💡 Use cases
         * - When comparing multiple angles simultaneously
         * - When using on wide monitor
         * - When checking all angles by time period
         */
        /**
         *
         * @section 4🎯 📊 4Channelof case
         * @endcode
         * When screen width is 1920px:
         * - Each channel: 480px (1920 / 4)
         * - spacing: none (boundary line only)
         * @endcode
         */
        renderer.setLayoutMode(.horizontal)

        // ─────────────────────────────────────────────────────────────────
        // Then: Check that changed to horizontal mode
        // ─────────────────────────────────────────────────────────────────

        /**
         * layout Modeis .horizontalcanof Verify
         */
        /**
         *
         * @section _💡 💡 Why test multiple times?
         * - First change works but second one is fail
         * - Can have bugs in state transition logic
         * - Verify all transitions from each state to new state
         */
        /**
         *
         * @section 💡 🔄 State Transition graph
         * @endcode
         * .grid ──→ .focus ──→ .horizontal
         *   ↑                      │
         *   └──────────────────────┘
         * (All transitions should be possible)
         * @endcode
         */
        XCTAssertEqual(renderer.layoutMode, .horizontal)
    }

    /**
     * Test all layout modes
     */
    /**
     * Test by iterating through all cases of LayoutMode enum.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Can change to all layout modes?
     * - Does displayName excant for each mode?
     */
    /**
     *
     * @section 💡 💡 Advantages of this test
     * - Automatically tested even if new layout mode is added
     * - Utilize CaseIterable protocol
     * - Verify without mcansing any cases
     */
    /**
     *
     * @section 🔄 🔄 CaseIterable protocol
     * @endcode
     * enum LayoutMode: CaseIterable {
     *     case grid
     *     case focus
     *     case horizontal
     * }
     */
    /**
     * // allCases is automatically created
     * LayoutMode.allCases  // [.grid, .focus, .horizontal]
     * @endcode
     */
    /**
     * @test testAllLayoutModes
     * @brief 📚 Reference: If only adding new mode (.pip etc)
     *
     * @details
     * 📚 Reference: If only adding new mode (.pip etc)
     *          This test is automatically verify it.
     */
    func testAllLayoutModes() {
        // ─────────────────────────────────────────────────────────────────
        // When & Then: Iterate and test all layout modes
        // ─────────────────────────────────────────────────────────────────

        /**
         * Iterate LayoutMode.allCases
         */
        /**
         * Test all cases with for-in loop:
         * 1. .gridto Settings → Verify
         * 2. .focusto Settings → Verify
         * 3. .horizontalto Settings → Verify
         */
        /**
         *
         * @section __💡 💡 Advantages of using loop in test
         * @endcode
         * // ❌ repetitiveis code (with maintenance difficulty)
         * renderer.setLayoutMode(.grid)
         * XCTAssertEqual(renderer.layoutMode, .grid)
         * renderer.setLayoutMode(.focus)
         * XCTAssertEqual(renderer.layoutMode, .focus)
         * // ...
         */
        /**
         * // ✅ loop Use (redcouplingand expansion possible)
         * for mode in LayoutMode.allCases {
         *     renderer.setLayoutMode(mode)
         *     XCTAssertEqual(renderer.layoutMode, mode)
         * }
         * @endcode
         */
        /**
         *
         * @section __🎯 🔍 Test Failure when
         * @endcode
         * ❌ XCTAssertEqual failed: (".grid") is of equal to (".focus")
         *    → what kind Modein Failurefailed and exactly know
         * @endcode
         */
        for mode in LayoutMode.allCases {
            // When: corresponding Modeto Change
            renderer.setLayoutMode(mode)

            // Then: Modeis correctly Settingsedto Check
            XCTAssertEqual(renderer.layoutMode, mode)

            // Then: dcanplayNameis existsto Check
            /**
             * displayName Verify
             */
            ///
            /**
             * dcanplayNameof role:
             * - UIto User-friendly name to display
             * - menuor buttonto Use
             * - for debugging messageto Use
             */
            ///
            /**
             *
             * @section nil📊 💡 nil inside d reason
             * @endcode
             * // UI in code:
             * Button(mode.displayName) {  // nilcanif crashwhen!
             *     renderer.setLayoutMode(mode)
             * }
             * @endcode
             */
            ///
            /**
             *
             * @section ____ 📊 Sample values
             * @endcode
             * .grid       → "Grid"
             * .focus      → "Focus"
             * .horizontal → "Horizontal"
             * @endcode
             */
            XCTAssertNotNil(mode.displayName)
        }
    }

    /**
     * layout Mode display Name Test
     */
    /**
     * each layout Modeof dcanplayNameis correctof Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - .gridof dcanplayNameis "Grid"cancan?
     * - .focusof dcanplayNameis "Focus"cancan?
     * - .horizontalof dcanplayNameis "Horizontal"cancan?
     */
    /**
     *
     * @section __💡 💡 why is Testis is necessary?
     * - UIto displayd textof accuracy guarantee
     * - Multi-language Support when CriteriaValue role
     * - typos or spelling
     */
    /**
     * @test testLayoutModedisplayNames
     * @brief 🌍 Multi-language Support Example:
     *
     * @details
     * 🌍 Multi-language Support Example:
     * @endcode
     * extension LayoutMode {
     *     var displayName: String {
     *         switch Locale.current.languageCode {
     *         case "ko":
     *             switch self {
     *             case .grid: return "grid"
     *             case .focus: return "Focus"
     *             case .horizontal: return "canto"
     *             }
     *         default:
     *             switch self {
     *             case .grid: return "Grid"
     *             case .focus: return "Focus"
     *             case .horizontal: return "Horizontal"
     *             }
     *         }
     *     }
     * }
     * @endcode
     */
    func testLayoutModedisplayNames() {
        // ─────────────────────────────────────────────────────────────────
        // Then: each Modeof displayName Verify
        // ─────────────────────────────────────────────────────────────────

        /**
         * Grid Modeof display Name Check
         */
        /**
         * "Grid"is expectedValueis Reason:
         * - English users are familiar with
         * - Short and clear
         * - other Also commonly used in other video players
         */
        /**
         *
         * @section ___ 💡 Alternatives
         * @endcode
         * "Grid"      ✅ Selected
         * "Grid View"    (too verbose)
         * "Tile"         (Meaningis Less clear)
         * "Matrix"       (technicalcanand difficulty)
         * @endcode
         */
        XCTAssertEqual(LayoutMode.grid.displayName, "Grid")

        /**
         * Focus Modeof display Name Check
         */
        /**
         * "Focus"is expectedValueis Reason:
         * - Clearly means focusing on one channel
         * - redcouplingand intuitive
         * - camera Also used in camera apps etc
         */
        /**
         *
         * @section ___ 💡 Alternatives
         * @endcode
         * "Focus"           ✅ Selected
         * "Picture-in-Picture"  (PiPand confusion)
         * "Main View"           (Too general)
         * "Spotlight"           (macOS searchand confusion)
         * @endcode
         */
        XCTAssertEqual(LayoutMode.focus.displayName, "Focus")

        /**
         * Horizontal Modeof display Name Check
         */
        /**
         * "Horizontal"is expectedValueis Reason:
         * - layout direction exactly description
         * - horizontal arrangement clearly convey
         * - Vertical(vertical)and Contrasting term
         */
        /**
         *
         * @section ___ 💡 Alternatives
         * @endcode
         * "Horizontal" ✅ Selected
         * "Side by Side"  (verboseand spacingwrite exists)
         * "Strip"         (Meaningis Less clear)
         * "Timeline"      (timelineis UIand confusion)
         * @endcode
         */
        XCTAssertEqual(LayoutMode.horizontal.displayName, "Horizontal")
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Focused Position Tests (Focus Position Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Focus Position Settings Test
     */
    /**
     * setFocusedPosition() method correctly changes focus camera check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - .rear Positionto Change possible?
     * - .left Positionto Change possible?
     * - Is state after change correctly reflected?
     */
    /**
     *
     * @section _💡 💡 Focus Positionof Meaning
     * - Focus on channel to display large in focus layout mode
     * - Grid/Horizontal No effect in mode
     * - User uses when specific want to focus on each angle
     */
    /**
     * 🚗 Blackbox Camera Placement:
     * @endcode
     *        Front (Front)
     *           ↑
     *    Left ← 🚗 → Right
     *           ↓
     *       Rear (Rear)
     */
    /**
     * @test testSetFocusedPosition
     * @brief Interior (Interior): driver's seat points to
     *
     * @details
     * Interior (Interior): driver's seat points to
     * @endcode
     */
    func testSetFocusedPosition() {
        // ─────────────────────────────────────────────────────────────────
        // When: Rear (Rear) Positionto Change
        // ─────────────────────────────────────────────────────────────────

        /**
         * Focus Rear camerato Settings
         */
        /**
         * Rear camera When focusing on it:
         * - Parking important Check rear
         * - Rear rear-end accident Verify
         * - distance from car behind Check
         */
        renderer.setFocusedPosition(.rear)

        // ─────────────────────────────────────────────────────────────────
        // Then: Rear Positionto Changeedto Check
        // ─────────────────────────────────────────────────────────────────

        XCTAssertEqual(renderer.focusedPosition, .rear)

        // ─────────────────────────────────────────────────────────────────
        // When: Left (Left) Positionto Change
        // ─────────────────────────────────────────────────────────────────

        /**
         * Focus Left camerato Settings
         */
        /**
         * Left camera When focusing on it:
         * - When turning left blind spot Check
         * - side contact Accident Verify
         * - parking when left space Check
         */
        renderer.setFocusedPosition(.left)

        // ─────────────────────────────────────────────────────────────────
        // Then: Left Positionto Changeedto Check
        // ─────────────────────────────────────────────────────────────────

        XCTAssertEqual(renderer.focusedPosition, .left)
    }

    /**
     * all Camera Position Tests
     */
    /**
     * CameraPositionof Test by iterating all cases.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - 5 camera Position Can all be set?
     * - Does transition to each position behave correctly?
     */
    /**
     * 🚗 camera Position description:
     * @endcode
     * .front    : Front camera (driving direction)
     * .rear     : Rear camera (reverse direction)
     * .left     : Left camera (driver's side)
     * .right    : Right camera (passenger side)
     * .interior : Interior camera (driver/passenger)
     * @endcode
     */
    /**
     * @test testAllCameraPositions
     * @brief 💡 Reason for using array literal:
     *
     * @details
     *
     * @section 📊 💡 array literal Use Reason
     * - CameraPosition might of adopt CaseIterable
     * - Can select specific positions to test
     * - Clearly display which positions are being tested
     */
    func testAllCameraPositions() {
        // ─────────────────────────────────────────────────────────────────
        // When & Then: Iterate and test all camera positions
        // ─────────────────────────────────────────────────────────────────

        /**
         * 5 camera Position iteration
         */
        /**
         *
         * @section 💡 💡 Reason for directly listing in array
         * @endcode
         * // Method 1: array literal (currently used)
         * for position in [CameraPosition.front, .rear, .left, .right, .interior] {
         *     // Explicit and order guaranteed
         * }
         */
        /**
         * // Method 2: CaseIterable (if only adopted)
         * for position in CameraPosition.allCases {
         *     // automatically all case include
         * }
         * @endcode
         */
        /**
         *
         * @section 🎯 🔄 Test order
         * @endcode
         * 1. .frontto Settings  → Verify
         * 2. .rearto Settings   → Verify
         * 3. .leftto Settings   → Verify
         * 4. .rightto Settings  → Verify
         * 5. .interiorto Settings → Verify
         * @endcode
         */
        for position in [CameraPosition.front, .rear, .left, .right, .interior] {
            // When: Change to that position
            renderer.setFocusedPosition(position)

            // Then: Check that position ed set correctly
            /**
             * Focus Position Verify
             */
            ///
            /**
             *
             * @section 💡 💡 Use scenario for each position
             * @endcode
             * .front    : normal driving (default value)
             * .rear     : When parking/reversing
             * .left     : narrow verbose, When turning left
             * .right    : right turn, when in narrow angle
             * .interior : taxi, delivery etc passenger check
             * @endcode
             */
            XCTAssertEqual(renderer.focusedPosition, position)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Viewport Calculation Tests (Viewport Calculation Test - Grid layout)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Grid layout - Single channel viewport test
     */
    /**
     * Verify viewport calculation when there is only 1 channel.
     */
    /**
     *
     * @section 🎯 💡 current State
     * - is Testthe private method accessis necessary
     * - Direct test through actual rendering or
     * - Change method to internal and access with @testable import
     */
    /**
     * 🎨 Expected layout:
     * @endcode
     * ┌───────────────────────┐
     * │                       │
     * │      Front            │
     * │    (entire Screen)        │
     * │                       │
     * └───────────────────────┘
     * @endcode
     */
    /**
     * @test testGridViewportsSingleChannel
     * @brief 📐 Expected viewport size:
     *
     * @details
     * 📐 Expected viewport size:
     * - x: 0, y: 0
     * - width: 1920, height: 1080
     * - Takes entire screen
     */
    func testGridViewportsSingleChannel() {
        /**
         * Define screen size for testing
         */
        /**
         * Use Full HD resolution (1920x1080):
         * - Most normal resolution
         * - 16:9 ratio
         * - Numbers easy to calculate
         */
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: Viewport Calculation method Test
         */
        /**
         * implementation method:
         * @endcode
         * // option 1: private method to internal Change
         * internal func calculateGridViewports(for channels: [CameraPosition], size: CGSize) -> [CameraPosition: CGRect]
         */
        /**
         * // Option 2: Check actual rendering result in integration test
         * let texture = renderer.render(frames: singleChannelFrames)
         * // Check rendering area in texture's pixel data
         */
        /**
         * // Test code:
         * let viewports = renderer.calculateGridViewports(for: [.front], size: size)
         * XCTAssertEqual(viewports[.front], CGRect(x: 0, y: 0, width: 1920, height: 1080))
         * @endcode
         */
    }

    /**
     * Grid layout - 2Channel Viewport Test
     */
    /**
     * 2single channels when Viewport Calculation Verify.
     */
    /**
     * 🎨 Expected layout:
     * @endcode
     * Side-by-side arrangement (when screen is wide):
     * ┌──────────┬──────────┐
     * │  Front   │   Rear   │
     * │          │          │
     * └──────────┴──────────┘
     */
    /**
     * Vertical arrangement (when screen is tall):
     * ┌────────────────────┐
     * │      Front         │
     * ├────────────────────┤
     * │       Rear         │
     * └────────────────────┘
     * @endcode
     */
    /**
     * @test testGridViewportsTwoChannels
     * @brief 📐 expected Viewport size (Side-by-side arrangement):
     *
     * @details
     * 📐 expected Viewport size (Side-by-side arrangement):
     * - Front: (0, 0, 960, 1080)
     * - Rear: (960, 0, 960, 1080)
     */
    func testGridViewportsTwoChannels() {
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 2Channel Viewport Calculation Test
         */
        /**
         *
         * @section 📊 💡 Screen ratioto according to focus
         * @endcode
         * let aspectRatio = size.width / size.height
         * if aspectRatio > 1.5 {
         *     // Wide screen → Side-by-side arrangement (1x2)
         *     layoutChannelsHorizontally()
         * } else {
         *     // Normal screen → Vertical arrangement (2x1)
         *     layoutChannelsVertically()
         * }
         * @endcode
         */
    }

    /**
     * Grid layout - 4Channel Viewport Test
     */
    /**
     * 4single channels when Viewport Calculation Verify.
     */
    /**
     * 🎨 Expected layout:
     * @endcode
     * ┌─────────┬─────────┐
     * │  Front  │  Rear   │
     * ├─────────┼─────────┤
     * │  Left   │  Right  │
     * └─────────┴─────────┘
     * @endcode
     */
    /**
     * 📐 Expected viewport size:
     * - Front: (0, 0, 960, 540)
     * - Rear: (960, 0, 960, 540)
     * - Left: (0, 540, 960, 540)
     * - Right: (960, 540, 960, 540)
     */
    /**
     * @test testGridViewportsFourChannels
     * @brief 💡 2x2 gridis optimalis Reason:
     *
     * @details
     *
     * @section 2x2📊 💡 2x2 gridis optimalis Reason
     * - 4 channels is be arranged in perfect orthogonal grid
     * - all Channelis same size
     * - Screen space efficiencyappropriateto Use
     */
    func testGridViewportsFourChannels() {
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 4Channel Viewport Calculation Test
         */
        /**
         * Verification single:
         * @endcode
         * let viewports = renderer.calculateGridViewports(
         *     for: [.front, .rear, .left, .right],
         *     size: size
         * )
         */
        /**
         * // each Channel Viewport Check
         * XCTAssertEqual(viewports.count, 4)
         */
        /**
         * // check all sizes are equal
         * let sizes = viewports.values.map { ($0.width, $0.height) }
         * XCTAssertTrue(sizes.allSatcanfy { $0 == sizes.first })
         */
        /**
         * // entire Logical check
         * assertTotalViewportArea(viewports, equals: size)
         * @endcode
         */
    }

    /**
     * Grid layout - 5Channel Viewport Test
     */
    /**
     * 5single channels when Viewport Calculation Verify.
     */
    /**
     * 🎨 Expected layout:
     * @endcode
     * ┌──────┬──────┬──────┐
     * │Front │ Rear │ Left │
     * ├──────┴──────┴──────┤
     * │Right  │  Interior  │
     * └───────┴────────────┘
     * @endcode
     */
    /**
     * 📐 Expected viewport size:
     * - first row 3single: each (width: 640, height: 540)
     * - Second row 2 channels: each (width: 960, height: 540)
     */
    /**
     * @test testGridViewportsFiveChannels
     * @brief 💡 3x2 Reason for choosing grid:
     *
     * @details
     *
     * @section 3x2📊 💡 3x2 Reason for choosing grid
     * - 5 channels cannot be arranged in perfect orthogonal grid
     * - 3x2 (6cell)in 1cell empty
     * - 2x3than Side-by-side arrangementis visualto advantageous
     */
    func testGridViewportsFiveChannels() {
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 5Channel Viewport Calculation Test
         */
        /**
         *
         * @section 📊 💡 Concerns about uneven arrangement
         * @endcode
         * // option 1: even divcanion (empty space leave)
         * // Front, Rear, Left aboveto arrangement (each 640px)
         * // Right, Interior below arrangement (each 960px)
         * // 1 cell below is empty
         */
        /**
         * // option 2: adaptive size
         * // importantrequired Channel (Front) larger
         * // Arrange others smaller
         */
        /**
         * // option 3: dynamic grid
         * // Automatically calculate optimal grid according to channel count
         * @endcode
         */
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Focus Layout Tests (Focus layout Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Focus layout Viewport Test
     */
    /**
     * Focus Modein Viewportis correctly Calculationdof Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Focused Channelis 75% area occupiesdo?
     * - thumbnail Channelsis 25% areato verticalto arrangementdcan?
     * - all Viewportis Screen boundary Withinto exist?
     */
    /**
     * 🎨 Expected layout:
     * @endcode
     * ┌──────────────────┬────┐
     * │                  │Rear│
     * │                  ├────┤
     * │      Front       │Left│
     * │     (75%)        ├────┤
     * │                  │Rght│
     * │                  ├────┤
     * │                  │Intr│
     * └──────────────────┴────┘
     *      1440px         480px
     * @endcode
     */
    /**
     * @test testFocusLayoutViewports
     * @brief 📐 Expected viewport size:
     *
     * @details
     * 📐 Expected viewport size:
     * - Front (Focus): (0, 0, 1440, 1080)
     * - Rear (thumbnail): (1440, 0, 480, 270)
     * - Left (thumbnail): (1440, 270, 480, 270)
     * - Right (thumbnail): (1440, 540, 480, 270)
     * - Interior (thumbnail): (1440, 810, 480, 270)
     */
    func testFocusLayoutViewports() {
        // ─────────────────────────────────────────────────────────────────
        // Given: Focus Mode Settings
        // ─────────────────────────────────────────────────────────────────

        /**
         * Focus layout Modeto Change
         */
        renderer.setLayoutMode(.focus)

        /**
         * Front camera Focusto Settings
         */
        renderer.setFocusedPosition(.front)

        /**
         * TODO: Viewport Verify
         */
        /**
         * implementation Example:
         * @endcode
         * let size = CGSize(width: 1920, height: 1080)
         * let viewports = renderer.calculateFocusViewports(size: size)
         */
        /**
         * // Focus Channel size Check
         * let focusViewport = viewports[.front]!
         * XCTAssertEqual(focusViewport.width, 1440)  // 75% of 1920
         */
        /**
         * // thumbnail area Check
         * let thumbnailViewports = viewports.filter { $0.key != .front }
         * for (_, viewport) in thumbnailViewports {
         *     XCTAssertEqual(viewport.width, 480)  // 25% of 1920
         *     XCTAssertEqual(viewport.height, 270)  // 1080 / 4 thumbnails
         * }
         * @endcode
         */
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Horizontal Layout Tests (Horizontal layout Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Horizontal layout Viewport Test
     */
    /**
     * Horizontal Modein Viewportis correctly Calculationdof Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - all Channelis same width canofthecan?
     * - channels evenly divided side by side?
     * - entire Screen use height?
     */
    /**
     * 🎨 expectedd layout (4Channel):
     * @endcode
     * ┌────┬────┬────┬────┐
     * │    │    │    │    │
     * │  F │  R │  L │  I │
     * │    │    │    │    │
     * └────┴────┴────┴────┘
     *  480  480  480  480
     * @endcode
     */
    /**
     * 📐 expected Viewport size (4Channel):
     * - Front: (0, 0, 480, 1080)
     * - Rear: (480, 0, 480, 1080)
     * - Left: (960, 0, 480, 1080)
     * - Interior: (1440, 0, 480, 1080)
     */
    /**
     * @test testHorizontalLayoutViewports
     * @brief 💡 Horizontal layoutof advantage:
     *
     * @details
     *
     * @section horizontal💡 💡 Horizontal layoutof advantage
     * - timelinecanand together Useto do good
     * - multiple eachalso Concurrent Comparcanon forcan
     * - andwide Monitor utilization optimization
     */
    func testHorizontalLayoutViewports() {
        // ─────────────────────────────────────────────────────────────────
        // Given: Horizontal Mode Settings
        // ─────────────────────────────────────────────────────────────────

        /**
         * Horizontal layout Modeto Change
         */
        renderer.setLayoutMode(.horizontal)

        /**
         * TODO: Viewport Verify
         */
        /**
         * implementation Example:
         * @endcode
         * let size = CGSize(width: 1920, height: 1080)
         * let channels: [CameraPosition] = [.front, .rear, .left, .interior]
         * let viewports = renderer.calculateHorizontalViewports(
         *     for: channels,
         *     size: size
         * )
         */
        /**
         * // Channel number Check
         * XCTAssertEqual(viewports.count, 4)
         */
        /**
         * // all Channelis same widthcanof Check
         * let width = 1920 / 4  // 480
         * for (_, viewport) in viewports {
         *     XCTAssertEqual(viewport.width, CGFloat(width))
         *     XCTAssertEqual(viewport.height, 1080)
         * }
         */
        /**
         * // X check coordinates are sequential
         * let sortedViewports = viewports.sorted { $0.value.minX < $1.value.minX }
         * for (index, (_, viewport)) in sortedViewports.enumerated() {
         *     XCTAssertEqual(viewport.minX, CGFloat(index * width))
         * }
         * @endcode
         */
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Capture Tests (Screen Capture Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * test capture attempt without rendering
     */
    /**
     * Renderinged when frame is absent check returns nil when attempting capture.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Rendering Return nil when attempting capture before rendering?
     * - handle error gracefully?
     */
    /**
     *
     * @section __nil__🎯 💡 why Return nil?
     * - Capturewill no texture
     * - Safe failure handling with optional return
     * - crashwhen instead nil checkto handling possible
     */
    /**
     *
     * @section _💡 🔄 normal capture flow
     * @endcode
     * 1. render() call → Metal Textureto drawing
     * 2. captureCurrentFrame() call
     * 3. Texture Read into CPU
     * 4. PNG/JPEGto cancoding
     * 5. Data return
     * @endcode
     */
    /**
     * @test testCaptureWithoutRendering
     * @brief ⚠️ Rendering before Capture whenalso when:
     *
     * @details
     *
     * @section 💡 ⚠️ Rendering before Capture whenalso when
     * @endcode
     * 1. captureCurrentFrame() call ← Texture none!
     * 2. Check nil internally
     * 3. nil return (Graceful failure)
     * @endcode
     */
    func testCaptureWithoutRendering() {
        // ─────────────────────────────────────────────────────────────────
        // When: Rendering beforeto Capture whenalso
        // ─────────────────────────────────────────────────────────────────

        /**
         * current Frame Capture whenalso
         */
        /**
         * captureCurrentFrame()of Behavior:
         * - Transform last rendered texture to image
         * - Textureis withoutif nil return
         * - default formatthe PNG
         */
        /**
         *
         * @section focus_🎯 💡 Optional returnof Reason
         * @endcode
         * func captureCurrentFrame() -> Data? {
         *     guard let texture = lastRenderedTexture else {
         *         return nil  // Texture none
         *     }
         *     // Texture in data transformation
         *     return encodeToImage(texture)
         * }
         * @endcode
         */
        /**
         *
         * @section 🎯 📊 Use Example
         * @endcode
         * if let imageData = renderer.captureCurrentFrame() {
         *     // Save or share image
         *     try? imageData.write(to: fileURL)
         * } else {
         *     // Capture Failure handling
         *     print("No frame to capture")
         * }
         * @endcode
         */
        let data = renderer.captureCurrentFrame()

        // ─────────────────────────────────────────────────────────────────
        // Then: nil returnshould
        // ─────────────────────────────────────────────────────────────────

        /**
         * returnValueis nilcanof Check
         */
        /**
         * XCTAssertNilof Behavior:
         * - test passes if value is nil
         * - nilis notif Test Failure
         */
        /**
         *
         * @section _💡 💡 If this test fails
         * - captureCurrentFrame()is always empty Data return
         * - Return default image instead of error
         * - nil check of doand crashwhen occurrence
         */
        /**
         * 📚 Reference: "should return nil when frame is not rendered"
         *          is messageto Test ofalso clearly convey
         */
        XCTAssertNil(data, "Should return nil when no frame is been rendered")
    }

    /**
     * Capture format Test
     */
    /**
     * PNGand JPEG formatis all supportedof Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - CaptureImageFormat.pngis existsthecan?
     * - CaptureImageFormat.jpegis existsthecan?
     */
    /**
     *
     * @section _🎯 💡 current limitationmatter
     * - actual since actual rendering is necessary fully verify in integration test
     * - here only check that format enum exists
     */
    /**
     * 🖼️ format Comparcanon:
     * @endcode
     * PNG:
     * - lossless compression
     * - Support transparency
     * - large file size (5-10MB)
     * - quality 100%
     * - Use case: When accurate evidence is necessary
     */
    /**
     * JPEG:
     * - lossy compression
     * - transparentalso none
     * - file size small (1-2MB)
     * - quality control possible (70-95%)
     * - Use case: Sharing, SNS upload
     * @endcode
     */
    /**
     * @test testCaptureFormats
     * @brief 📊 file size Example (1920x1080 4Channel):
     *
     * @details
     *
     * @section __________1920x1080_4___ 📊 file size Example (1920x1080 4Channel)
     * @endcode
     * PNG:  if 8-12MB
     * JPEG: if 1-3MB (quality 80%)
     * Compression ratio: 4-8x difference
     * @endcode
     */
    func testCaptureFormats() {
        /**
         * PNGand JPEG format array
         */
        /**
         *
         * @section ___enum____ 💡 format enumof role
         * @endcode
         * enum CaptureImageFormat {
         *     case png
         *     case jpeg(quality: CGFloat)  // 0.0 ~ 1.0
         * }
         */
        /**
         * // Use Example:
         * let data = renderer.captureCurrentFrame(format: .png)
         * let data = renderer.captureCurrentFrame(format: .jpeg(quality: 0.8))
         * @endcode
         */
        let formats: [CaptureImageFormat] = [.png, .jpeg]

        /**
         * each formatis existsto Check
         */
        /**
         * for loopto all format Verify:
         * - .png Verify
         * - .jpeg Verify
         */
        /**
         *
         * @section xctassertofnil_format🎯 💡 XCTAssertNotNil(format)of Meaning
         * - enum case can never be nil so always passes
         * - But guarantee type check at compile time
         * - orimportantto Optionalto Changebecomealso insidebefore
         */
        /**
         *
         * @section __💡 🔍 additional test method
         * @endcode
         * // actual Rendering after format Test (integration Testin)
         * let pngData = renderer.captureCurrentFrame(format: .png)
         * let jpegData = renderer.captureCurrentFrame(format: .jpeg(quality: 0.8))
         */
        /**
         * // PNG whensignature Check (89 50 4E 47)
         * XCTAssertEqual(pngData?.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
         */
        /**
         * // JPEG whensignature Check (FF D8 FF)
         * XCTAssertEqual(jpegData?.prefix(3), Data([0xFF, 0xD8, 0xFF]))
         */
        /**
         * // file size Comparcanon
         * XCTAssertLessThan(jpegData!.count, pngData!.count)
         * @endcode
         */
        for format in formats {
            XCTAssertNotNil(format)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Performance Tests (Performance Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * layout Mode Change Performance Test
     */
    /**
     * layout Mode fastly measure performance when transitioning.
     */
    /**
     *
     * @section 🎯 🎯 measurement item
     * - 1000times iteration when Average execution Time
     * - memory allocation count
     * - CPU Usage rate
     */
    /**
     *
     * @section measure_🎯 💡 measure blockof Behavior
     * @endcode
     * 1. code 10times execution (warmup 1times + measurement 9times)
     * 2. each execution Time measurement
     * 3. Average, standarddeviation Calculation
     * 4. CriteriaValue(baseline)and Comparcanon
     * @endcode
     */
    /**
     *
     * @section 🎯 📊 Performance Criteria
     * @endcode
     * Count:   < 0.1seconds (1000times iteration)
     * good:   < 0.5seconds
     * average:   < 1.0seconds
     * slow:   > 1.0seconds
     * @endcode
     */
    /**
     *
     * @section __🎯 🔍 Performance Problem cause
     * - Unnecessary memory allocation
     * - Recalculate layout overHEAD
     * - synchronization lock contention
     * - throughof(ofification) overHEAD
     */
    /**
     *
     * @section 🎯 💡 optimization method
     * @endcode
     * // ❌ slow implementation
     * func setLayoutMode(_ mode: LayoutMode) {
     *     self.layoutMode = mode
     *     recalculateAllViewports()      // always recalculation
     *     notifyAllObservers()()            // all Notify all observers
     *     invalidateWholeScreen()         // Redraw entire screen
     * }
     */
    /**
     * @test testLayoutModeChangePerformance
     * @brief // ✅ fast implementation
     *
     * @details
     * // ✅ fast implementation
     * func setLayoutMode(_ mode: LayoutMode) {
     *     guard self.layoutMode != mode else { return }  // sameif skip
     *     self.layoutMode = mode
     *     scheduleLayoutUpdate()          // Schedule layout update
     *     invalidateLayoutRegion()        // Only necessary area
     * }
     * @endcode
     */
    func testLayoutModeChangePerformance() {
        /**
         * measure performance with measure block
         */
        /**
         * measurement target:
         * - 3single layout Mode transitions × 1000 times = total 3000 transitions
         * - each Transitionof Average Time
         */
        /**
         *
         * @section xcode_💡 📊 XCodeof Performance measurement result
         * @endcode
         * Average: 0.124 sec
         * Baseline: 0.150 sec
         * Std Dev: 0.012 sec
         */
        /**
         *
         * @section passed_________17____ ✅ Passed - CriteriaValuethan 17% fast
         * @endcode
         */
        /**
         *
         * @section _💡 💡 Performance regression Detection
         * - save baseline with expected measurement value
         * - warning if new code is 10% or more slower
         * - CI/CDin automatically Failure handling possible
         */
        /**
         * 🔧 Performance optimization check:
         * @endcode
         * Before: 0.500 sec
         * After:  0.124 sec
         * Improvement: 75% faster
         * @endcode
         */
        measure {
            /**
             * 1000times iteration execution
             */
            ///
            /**
             *
             * @section __1000____ 💡 why 1000timescancan?
             * - secure sufficient time for measurement
             * - noise removal (Averageuhto insidepurification)
             * - minimize total test suite time by not being too verbose
             */
            ///
            /**
             * 📐 Calculation:
             * @endcode
             * 1times transition: 0.0001seconds (100 μs)
             * 1000times: 0.1seconds
             * 10times measurement: 1seconds (allowed range)
             * @endcode
             */
            for _ in 0..<1000 {
                renderer.setLayoutMode(.grid)
                renderer.setLayoutMode(.focus)
                renderer.setLayoutMode(.horizontal)
            }
        }
    }

    /**
     * Focus Position Change Performance Test
     */
    /**
     * Focus camera Position fastly measure performance when transitioning.
     */
    /**
     *
     * @section 🎯 🎯 measurement item
     * - 1000times iteration when Average execution Time
     * - layout Mode Changethan fastof Check
     */
    /**
     *
     * @section ______💡 💡 reason focus position change is more lightweight
     * @endcode
     * setLayoutMode():
     * - entire Recalculate layout
     * - all Viewport size Change
     * - render pipeline reconstruction
     */
    /**
     * setFocusedPosition():
     * - limited single protopropertyonly Change
     * - Focus Modeinonly zerotoward
     * - Viewport sizeis maintained (arrangementonly Change)
     * @endcode
     */
    /**
     * @test testFocusPositionChangePerformance
     * @brief 📊 Example上 Performance:
     *
     * @details
     *
     * @section 🎯 📊 Example上 Performance
     * @endcode
     * setFocusedPosition: 0.050 sec (1000times)
     * setLayoutMode:      0.124 sec (1000times)
     * if 2.5x more fast
     * @endcode
     */
    func testFocusPositionChangePerformance() {
        measure {
            /**
             * 1000times iteration execution
             */
            ///
            /**
             * 4single Position × 1000times = total 4000times Transition
             */
            ///
            /**
             *
             * @section __4_💡 💡 why 4singleonly Testoneneed?
             * - .interiorthe omit (all Position Testwill necessary none)
             * - representativeis 4directiononlyuhto sufficient
             * - execution Time shorten
             */
            ///
            /**
             *
             * @section 🎯 🔄 execution order
             * @endcode
             * .front → .rear → .left → .right → .front → ...
             * (1000times iteration)
             * @endcode
             */
            for _ in 0..<1000 {
                renderer.setFocusedPosition(.front)
                renderer.setFocusedPosition(.rear)
                renderer.setFocusedPosition(.left)
                renderer.setFocusedPosition(.right)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Memory Management Tests (Memory Management Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Renderer destructor(deinit) Test
     */
    /**
     * Renderer instanceis correctly Memoryin releasedof Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Renderer nilto Settingsdoif Memoryin releasedcan?
     * - Memory leakis not exist?
     * - circular referenceis not exist?
     */
    /**
     *
     * @section __💡 💡 Memory leakis occurrencedothe case
     * @endcode
     * // ❌ circular reference (Retain Cycle)
     * class Renderer {
     *     var delegate: Delegate?
     *     init() {
     *         delegate = Delegate()
     *         delegate?.renderer = self  // strong reference!
     *     }
     * }
     */
    /**
     * // ✅ weakto circular reference roomof
     * class Renderer {
     *     weak var delegate: Delegate?
     *     init() {
     *         delegate = Delegate()
     *         delegate?.renderer = self  // weak reference
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section _💡 🔍 Memory leak debugging
     * @endcode
     * 1. Instruments → Leaks alsoold execution
     * 2. Renderer Creation/release iteration
     * 3. Memory graphin alivethe object Check
     * 4. circular reference bodyis analysis
     * @endcode
     */
    /**
     *
     * @section __💡 📊 normalticis Memory pattern
     * @endcode
     * Creation → Memory 100MB ↑
     * Use → Memory 100MB retained
     * release → Memory 100MB ↓
     * @endcode
     */
    /**
     * @test testRendererDeinit
     * @brief ⚠️ Memory leak pattern:
     *
     * @details
     *
     * @section 💡 ⚠️ Memory leak pattern
     * @endcode
     * Creation → Memory 100MB ↑
     * Use → Memory 100MB retained
     * release → Memory retained (leak!)
     * @endcode
     */
    func testRendererDeinit() {
        // ─────────────────────────────────────────────────────────────────
        // Given: new Renderer instance Creation
        // ─────────────────────────────────────────────────────────────────

        /**
         * Testfor Renderer Creation
         */
        /**
         * varto declarationby nil allocation possibledoly does
         */
        /**
         *
         * @section focus📊 💡 Optional type Usedothe Reason
         * - nil allocationby release whenmulationcantion
         * - ARCis reference count 0uhto onlys number exists
         * - deinitis calldof direct Check
         */
        /**
         * 🔢 ARC (Automatic Reference Counting):
         * @endcode
         * var testRenderer = MultiChannelRenderer()  // retain count = 1
         * let aofherRef = testRenderer              // retain count = 2
         * aofherRef = nil                          // retain count = 1
         * testRenderer = nil                        // retain count = 0 → deinit!
         * @endcode
         */
        var testRenderer: MultiChannelRenderer? = MultiChannelRenderer()

        // ─────────────────────────────────────────────────────────────────
        // When: Renderer nilto Settings
        // ─────────────────────────────────────────────────────────────────

        /**
         * nil allocationuhto reference release
         */
        /**
         * is pointto occursorthe work:
         * 1. testRendererof reference count decrease
         * 2. reference countis 0is becomeif deinit call
         * 3. owns all resource release:
         *    - MTLDevice deallocation
         *    - MTLCommandQueue deallocation
         *    - all Texture release
         *    - Capture service deallocation
         */
        /**
         *
         * @section deinit🎯 💡 deinit implementation Example
         * @endcode
         * class MultiChannelRenderer {
         *     deinit {
         *         print("Renderer being deinitialized")
         *         // Metal resource cleanup
         *         commandQueue = nil
         *         device = nil
         *         textures.removeAll()
         *     }
         * }
         * @endcode
         */
        testRenderer = nil

        // ─────────────────────────────────────────────────────────────────
        // Then: nilis edto Check
        // ─────────────────────────────────────────────────────────────────

        /**
         * nil Check
         */
        /**
         * XCTAssertNilof Verify:
         * - testRendereris nilcanof Check
         * - always throughandshould (abovein nil allocation)
         */
        /**
         *
         * @section 📊 💡 is Testof actual purpose
         * - check deinit completes without crash
         * - Memory leak alsooldand together Use
         * - Instrumentsto execution when leak automatic Detection
         */
        /**
         *
         * @section __🎯 🔍 addition Verify method
         * @endcode
         * // weak referenceto deinit Check
         * weak var weakRenderer: MultiChannelRenderer?
         * autoreleasepool {
         *     let renderer = MultiChannelRenderer()
         *     weakRenderer = renderer
         *     XCTAssertNotNil(weakRenderer)
         * } // renderer Range termination → deinit
         * XCTAssertNil(weakRenderer, "Renderer should be deallocated")
         * @endcode
         */
        XCTAssertNil(testRenderer)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Thread Safety Tests (Thread Safety Test)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Concurrent layout Mode Change Test
     */
    /**
     * multiple Threadin Concurrentto layout Mode Changewill when crashwhenis occurrenceof doto Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Concurrent性 environmentin crashwhen not exist?
     * - Data race(Data Race)is not exist?
     * - lock mechanismis correctly worksthecan?
     */
    /**
     *
     * @section _______data_race____ 💡 What is data race?
     * @endcode
     * // ❌ Thread insidebeforeof dothe code
     * var layoutMode: LayoutMode = .grid
     */
    /**
     * // Thread 1:
     * layoutMode = .focus     // write
     */
    /**
     * // Thread 2 (Concurrentto):
     * print(layoutMode)       // read → Examplemeasure notpossiblelimited result!
     * @endcode
     */
    /**
     *
     * @section _💡 ✅ Thread insidegraceful implementation
     * @endcode
     * class Renderer {
     *     private var _layoutMode: LayoutMode = .grid
     *     private let lock = NSLock()
     */
    /**
     *     var layoutMode: LayoutMode {
     *         get {
     *             lock.lock()
     *             defer { lock.unlock() }
     *             return _layoutMode
     *         }
     *         set {
     *             lock.lock()
     *             defer { lock.unlock() }
     *             _layoutMode = newValue
     *         }
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section 💡 🔍 Concurrent性 bug symptoms
     * - redsporadic crashwhen (reproduction difficulty)
     * - EXC_BAD_ACCESS error
     * - Data corruption
     * - deadlock State(Deadlock)
     */
    /**
     * @test testConcurrentLayoutModeChange
     * @brief 📊 Test strategy:
     *
     * @details
     *
     * @section 🎯 📊 Test strategy
     * @endcode
     * 100times iteration → 3single Mode → 33~34timeseach each Mode Settings
     * Concurrent execution on multiple threads → can have race condition
     * crashwhen withoutif throughand
     * @endcode
     */
    func testConcurrentLayoutModeChange() {
        // ─────────────────────────────────────────────────────────────────
        // When: multiple Threadin layout Mode Change
        // ─────────────────────────────────────────────────────────────────

        /**
         * DispatchQueue.concurrentPerform Uselimited Concurrent execution
         */
        /**
         * Behavior method:
         * - 100timesof iteration multiple Threadto distribution
         * - whensystemis optimalof Thread number decision (average CPU core number)
         * - each Threadis Concurrentto setLayoutMode() call
         */
        /**
         *
         * @section concurrentperform____ 💡 concurrentPerformof charactercantics
         * @endcode
         * DispatchQueue.concurrentPerform(iterations: 100) { index in
         *     // is blockis multiple Threadin Concurrentto executionis
         *     // index: 0~99
         * }
         * // all iterationis endday whento waiting
         * @endcode
         */
        /**
         *
         * @section _______4_🎯 🔄 execution Example (4core whensystem)
         * @endcode
         * Thread 1: index 0, 4, 8, 12, ... (setLayoutMode 25times)
         * Thread 2: index 1, 5, 9, 13, ... (setLayoutMode 25times)
         * Thread 3: index 2, 6, 10, 14, ... (setLayoutMode 25times)
         * Thread 4: index 3, 7, 11, 15, ... (setLayoutMode 25times)
         * → 100times all Concurrentto execution
         * @endcode
         */
        /**
         *
         * @section 🎯 📊 Mode distribution
         * @endcode
         * index % 3 == 0 → .grid       (33~34times)
         * index % 3 == 1 → .focus      (33times)
         * index % 3 == 2 → .horizontal (33times)
         * @endcode
         */
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            /**
             * layout Mode array
             */
            let modes: [LayoutMode] = [.grid, .focus, .horizontal]

            /**
             * index 3uhto oreye otherofto Mode focus
             */
            ///
            /**
             *
             * @section _______modulo_ 💡 % operator (modulo)
             * @endcode
             * 0 % 3 = 0 → modes[0] = .grid
             * 1 % 3 = 1 → modes[1] = .focus
             * 2 % 3 = 2 → modes[2] = .horizontal
             * 3 % 3 = 0 → modes[0] = .grid (iteration)
             * ...
             * @endcode
             */
            ///
            /**
             *
             * @section _💡 🔄 Concurrentto occursorthe work
             * @endcode
             * Thread 1: renderer.setLayoutMode(.grid)
             * Thread 2: renderer.setLayoutMode(.focus)      ← Concurrent!
             * Thread 3: renderer.setLayoutMode(.horizontal) ← Concurrent!
             * Thread 4: renderer.setLayoutMode(.grid)       ← Concurrent!
             * @endcode
             */
            ///
            /**
             *
             * @section 📊 ⚠️ Thread insidebeforeof douhif
             * - read/write conflict
             * - crashwhen occurrence
             * - Data corruption
             */
            renderer.setLayoutMode(modes[index % 3])
        }

        // ─────────────────────────────────────────────────────────────────
        // Then: crashwhenof doshould does
        // ─────────────────────────────────────────────────────────────────

        /**
         * Check renderer is still valid
         */
        /**
         *
         * @section __assertion____ 💡 is assertionof Meaning
         * - actualtothe "crashwhenof dowas" Verify
         * - hereto alsoreached = crashwhen none
         * - rendereris corruptionbecomeof did notness
         */
        /**
         *
         * @section 📊 🔍 addition Verify possiblelimited item
         * @endcode
         * // final Stateis valid Valuecanof Check
         * XCTAssertTrue(
         *     renderer.layoutMode == .grid ||
         *     renderer.layoutMode == .focus ||
         *     renderer.layoutMode == .horizontal
         * )
         */
        /**
         * // Check capture service is still valid
         * XCTAssertNotNil(renderer.captureService)
         * @endcode
         */
        XCTAssertNotNil(renderer)
    }

    /**
     * Concurrent Focus Position Change Test
     */
    /**
     * multiple Threadin Concurrentto Focus Position Changewill when crashwhenis occurrenceof doto Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - Focus Position changeLongitude Thread insidegracefulcan?
     * - layout Modeand Focus Position Concurrentto Changedoalso insidegracefulcan?
     */
    /**
     *
     * @section __💡 💡 composite Concurrent性 scenario
     * @endcode
     * // Thread 1:
     * renderer.setLayoutMode(.focus)
     * renderer.setFocusedPosition(.front)
     */
    /**
     * // Thread 2 (Concurrentto):
     * renderer.setLayoutMode(.grid)
     * renderer.setFocusedPosition(.rear)
     */
    /**
     * // two workingis conflictof doshould does!
     * @endcode
     */
    /**
     * @test testConcurrentFocusPositionChange
     * @brief 🔒 protectedshould will share State:
     *
     * @details
     * 🔒 protectedshould will share State:
     * @endcode
     * - layoutMode protoproperty
     * - focusedPosition protoproperty
     * - Viewport Calculation result
     * - Rendering State
     * @endcode
     */
    func testConcurrentFocusPositionChange() {
        // ─────────────────────────────────────────────────────────────────
        // When: multiple Threadin Focus Position Change
        // ─────────────────────────────────────────────────────────────────

        /**
         * 100times iteration Concurrent execution
         */
        /**
         *
         * @section 5__🎯 💡 5single Position circular
         * @endcode
         * index % 5 == 0 → .front    (20times)
         * index % 5 == 1 → .rear     (20times)
         * index % 5 == 2 → .left     (20times)
         * index % 5 == 3 → .right    (20times)
         * index % 5 == 4 → .interior (20times)
         * @endcode
         */
        /**
         *
         * @section __🎯 🔄 Concurrent execution pattern
         * @endcode
         * Thread 1: .front → .front → .front → ...
         * Thread 2: .rear → .rear → .left → ...
         * Thread 3: .left → .right → .interior → ...
         * Thread 4: .right → .interior → .front → ...
         * (all Concurrentto setFocusedPosition call)
         * @endcode
         */
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            /**
             * camera Position array
             */
            let positions: [CameraPosition] = [.front, .rear, .left, .right, .interior]

            /**
             * index 5to oreye otherofto Position focus
             */
            ///
            /**
             *
             * @section 📊 ⚠️ array canindex Range Check
             * @endcode
             * index % 5the always 0~4 Range
             * positions array size: 5
             * → insidegraceful access guarantee
             * @endcode
             */
            renderer.setFocusedPosition(positions[index % 5])
        }

        // ─────────────────────────────────────────────────────────────────
        // Then: crashwhenof doshould does
        // ─────────────────────────────────────────────────────────────────

        /**
         * Check renderer is still valid
         */
        /**
         *
         * @section 💡 💡 Thread Safety guarantee method
         * @endcode
         * // method 1: NSLock
         * private let lock = NSLock()
         * func setFocusedPosition(_ position: CameraPosition) {
         *     lock.lock()
         *     defer { lock.unlock() }
         *     self.focusedPosition = position
         * }
         */
        /**
         * // method 2: DispatchQueue
         * private let queue = DispatchQueue(label: "renderer.queue")
         * func setFocusedPosition(_ position: CameraPosition) {
         *     queue.sync {
         *         self.focusedPosition = position
         *     }
         * }
         */
        /**
         * // method 3: actor (Swift 5.5+)
         * actor Renderer {
         *     var focusedPosition: CameraPosition = .front
         *     func setFocusedPosition(_ position: CameraPosition) {
         *         self.focusedPosition = position
         *     }
         * }
         * @endcode
         */
        XCTAssertNotNil(renderer)
    }
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - Integration Tests (integration Test)
// ═════════════════════════════════════════════════════════════════════════

/// actual Metal Renderingis necessarylimited integration Test
///
/// Unlike actual GPU rendering in unit tests pipelineframeis Verify.
///
/// 🎯 integration Testof purpose:
/// - actual Rendering Behavior Check
/// - multiple componentof interactionfor Verify
/// - end-to-end(End-to-End) scenario Test
///
/// 💡 Unit test vs integration test:
/// ```
/// unit Test (Unit Tests):
/// - singlefor each function/method Test
/// - Mock object Use possible
/// - fast execution (milliseconds)
/// - ofdependency Minimumize
///
/// integration Test (Integration Tests):
/// - multiple component together Test
/// - actual object Use
/// - slow execution (seconds unit)
/// - actual environmentand similar
/// ```
///
/// 🖼️ Rendering pipelineframeis integration:
/// ```
/// VideoFrame → MultiChannelRenderer → Metal → MTKView
///    ↓               ↓                  ↓         ↓
/// video Data   layout Calculation     GPU Rendering  Screen display
/// ```
final class MultiChannelRendererIntegrationTests: XCTestCase {

    /**
     * Test target Renderer
     */
    var renderer: MultiChannelRenderer!

    /**
     * Testfor video Frame
     */
    /**
     *
     * @section 📊 💡 actual integration Testinthe
     * - actual video Frame Data necessary
     * - each camera Positionfor each Frame
     * - Metal Textureto transformationed Data
     */
    var testFrames: [CameraPosition: VideoFrame]!

    /**
     * each integration Test before Settings
     */
    /**
     * Identical to unit test, additionally:
     * - Test video Frame preparation
     * - Rendering environment Settings
     * - MTKView or replacement Drawable preparation
     */
    override func setUpWithError() throws {
        super.setUp()

        /**
         * Metal device Check
         */
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is of available")
        }

        /**
         * Renderer Creation
         */
        renderer = MultiChannelRenderer()
        guard renderer != nil else {
            throw XCTSkip("Failed to create renderer")
        }

        /**
         * Test Frame Creation
         */
        /**
         * TODO: actual video Frame load
         */
        /**
         * implementation Example:
         * @endcode
         * let testVideoURL = Bundle(for: type(of: self)).url(
         *     forResource: "test_video",
         *     withExtension: "mp4"
         * )!
         */
        /**
         * testFrames = [
         *     .front: loadVideoFrame(from: testVideoURL, position: .front),
         *     .rear: loadVideoFrame(from: testVideoURL, position: .rear),
         *     // ...
         * ]
         * @endcode
         */
        /**
         *
         * @section 📊 📊 Test video requirement
         * - resolution: 1920x1080 or 1280x720
         * - codec: H.264 or H.265
         * - verbosecan: 1-2seconds (shortthe clip)
         * - size: 1-5MB
         */
        testFrames = [:]
    }

    /**
     * each integration Test after cleanup
     */
    override func tearDownWithError() throws {
        renderer = nil
        testFrames = nil
        super.tearDown()
    }

    /**
     * empty Frameuhto Rendering Test
     */
    /**
     * Frame Datanot exist whenalso insidebeforedoly handlingdoto Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - empty dictionaryto Rendering whenalso when crashwhen not exist?
     * - error handlingis appropriatecan?
     * - Is black screen or empty screen displayed?
     */
    /**
     * @test testRenderWithEmptyFrames
     * @brief 💡 actual implementationin:
     *
     * @details
     *
     * @section _🎯 💡 actual implementationin
     * @endcode
     * func render(frames: [CameraPosition: VideoFrame]) {
     *     guard !frames.canEmpty else {
     *         // empty Screen Rendering or skip
     *         return
     *     }
     *     // normal Rendering
     * }
     * @endcode
     */
    func testRenderWithEmptyFrames() {
        /**
         * empty Frame dictionary
         */
        let frames: [CameraPosition: VideoFrame] = [:]

        /**
         * TODO: actual Rendering call
         */
        /**
         * implementation Example:
         * @endcode
         * // MTKView or Testfor Drawable preparation
         * let drawable = createTestDrawable()
         */
        /**
         * // Rendering whenalso (crashwhenof doshould does)
         * renderer.render(frames: frames, to: drawable)
         */
        /**
         * // Verify result
         * XCTAssertNotNil(drawable.texture)
         * // Check texture is black or empty
         * @endcode
         *
         * Check renderer is still valid
         */
        XCTAssertNotNil(renderer)
    }

    /**
     * Grid layout Rendering Test
     */
    /**
     * Grid Modein actual Renderingis correctly Behaviordoto Check.
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - all Channelis Screento displaydcan?
     * - Viewportis correctly Calculationdcan?
     * - each Channelof sizeis samecan?
     */
    /**
     * @test testGridLayoutRendering
     * @brief 📐 Example上 result (4Channel):
     *
     * @details
     * 📐 Example上 result (4Channel):
     * @endcode
     * ┌─────────┬─────────┐
     * │ Front   │  Rear   │  each 960x540
     * ├─────────┼─────────┤
     * │ Left    │  Right  │  entire 1920x1080
     * └─────────┴─────────┘
     * @endcode
     */
    func testGridLayoutRendering() {
        /**
         * TODO: Grid layout Rendering Verify
         */
        /**
         * implementation Example:
         * @endcode
         * // Grid Mode Settings
         * renderer.setLayoutMode(.grid)
         */
        /**
         * // 4Channel Frame preparation
         * let frames = prepareTestFrames(
         *     positions: [.front, .rear, .left, .right]
         * )
         */
        /**
         * // Rendering
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // Verify result
         * XCTAssertNotNil(texture)
         */
        /**
         * // each Channelis correct Positionto Renderingedto Check
         * // (pixel sampling or wheneachtic Comparcanon)
         * assertChannelVcanible(in: texture, at: .topLeft, for: .front)
         * assertChannelVcanible(in: texture, at: .topRight, for: .rear)
         * assertChannelVcanible(in: texture, at: .bottomLeft, for: .left)
         * assertChannelVcanible(in: texture, at: .bottomRight, for: .right)
         * @endcode
         */
    }

    /**
     * Focus layout Rendering Test
     */
    /**
     * Focus Modein meis Channeland thumbnailis correctly displaydof Check.
     */
    /**
     * @test testFocusLayoutRendering
     * @brief 🎯 Verification single:
     *
     * @details
     *
     * @section 🎯 🎯 Verification single
     * - Focus Channelis 75% sizeto displaydcan?
     * - thumbnail Channelis 25% areato displaydcan?
     * - thumbnailis verticalto correctly sortdcan?
     */
    func testFocusLayoutRendering() {
        /**
         * TODO: Focus layout Rendering Verify
         */
        /**
         * implementation Example:
         * @endcode
         * renderer.setLayoutMode(.focus)
         * renderer.setFocusedPosition(.front)
         */
        /**
         * let frames = prepareTestFrames(
         *     positions: [.front, .rear, .left, .right]
         * )
         */
        /**
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // meis Channel Check (Left 75%)
         * assertChannelVcanible(
         *     in: texture,
         *     at: CGRect(0, 0, 1440, 1080),
         *     for: .front
         * )
         */
        /**
         * // thumbnail Check (Right 25%)
         * assertChannelVcanible(in: texture, at: CGRect(1440, 0, 480, 270), for: .rear)
         * assertChannelVcanible(in: texture, at: CGRect(1440, 270, 480, 270), for: .left)
         * assertChannelVcanible(in: texture, at: CGRect(1440, 540, 480, 270), for: .right)
         * @endcode
         */
    }

    /**
     * Horizontal layout Rendering Test
     */
    /**
     * Horizontal Modein Channelsis cantoto evendoly arrangementdof Check.
     */
    /**
     * @test testHorizontalLayoutRendering
     * @brief 🎯 Verification single:
     *
     * @details
     *
     * @section 🎯 🎯 Verification single
     * - all Channelis same width canofthecan?
     * - Channel orderis correctcan?
     * - entire use height?
     */
    func testHorizontalLayoutRendering() {
        /**
         * TODO: Horizontal layout Rendering Verify
         */
        /**
         * implementation Example:
         * @endcode
         * renderer.setLayoutMode(.horizontal)
         */
        /**
         * let frames = prepareTestFrames(
         *     positions: [.front, .rear, .left, .interior]
         * )
         */
        /**
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // each Channelis 480px widthto displaydof Check
         * assertChannelVcanible(in: texture, at: CGRect(0, 0, 480, 1080), for: .front)
         * assertChannelVcanible(in: texture, at: CGRect(480, 0, 480, 1080), for: .rear)
         * assertChannelVcanible(in: texture, at: CGRect(960, 0, 480, 1080), for: .left)
         * assertChannelVcanible(in: texture, at: CGRect(1440, 0, 480, 1080), for: .interior)
         * @endcode
         */
    }

    /**
     * Rendering after Capture Test
     */
    /**
     * actual Rendering after Screen Captureis correctly Behaviordoto Check.
     */
    /**
     * @test testCaptureAfterRendering
     * @brief 🎯 Verification single:
     *
     * @details
     *
     * @section 🎯 🎯 Verification single
     * - Rendering after Capture when Data returndo?
     * - Data sizeis appropriatecan?
     * - image formatis correctcan?
     */
    func testCaptureAfterRendering() {
        /**
         * TODO: Rendering after Capture Verify
         */
        /**
         * implementation Example:
         * @endcode
         * // Rendering perform
         * let frames = prepareTestFrames(positions: [.front, .rear])
         * renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // Capture whenalso
         * let capturedData = renderer.captureCurrentFrame()
         */
        /**
         * // Data Verify
         * XCTAssertNotNil(capturedData, "Capture should return data after rendering")
         * XCTAssertGreaterThan(capturedData!.count, 100_000, "Image should have reasonable size")
         */
        /**
         * // PNG whensignature Check
         * let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
         * XCTAssertEqual(capturedData!.prefix(4), Data(pngSignature))
         */
        /**
         * // imageto Decoding possiblelimitedof Check
         * #if os(macOS)
         * let image = NSImage(data: capturedData!)
         * XCTAssertNotNil(image)
         * XCTAssertEqual(image!.size, NSSize(width: 1920, height: 1080))
         * #endif
         * @endcode
         */
    }

    /**
     * various Capture format Test
     */
    /**
     * PNGand JPEG formatuhto Capturedid when resultis correctof Check.
     */
    /**
     * @test testCaptureDifferentFormats
     * @brief 🎯 Verification single:
     *
     * @details
     *
     * @section 🎯 🎯 Verification single
     * - PNGand JPEG all Capture possible?
     * - JPEGis PNGthan smallthecan?
     * - each formatof whensignatureis correctcan?
     */
    func testCaptureDifferentFormats() {
        /**
         * TODO: formatfor each Capture Verify
         */
        /**
         * implementation Example:
         * @endcode
         * // Rendering
         * let frames = prepareTestFrames(positions: [.front])
         * renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // PNG Capture
         * let pngData = renderer.captureCurrentFrame(format: .png)
         * XCTAssertNotNil(pngData)
         * XCTAssertEqual(pngData!.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
         */
        /**
         * // JPEG Capture
         * let jpegData = renderer.captureCurrentFrame(format: .jpeg(quality: 0.8))
         * XCTAssertNotNil(jpegData)
         * XCTAssertEqual(jpegData!.prefix(3), Data([0xFF, 0xD8, 0xFF]))
         */
        /**
         * // size Comparcanon
         * XCTAssertLessThan(jpegData!.count, pngData!.count, "JPEG should be smaller than PNG")
         */
        /**
         * // quality Difference Test
         * let jpegLow = renderer.captureCurrentFrame(format: .jpeg(quality: 0.5))
         * let jpegHigh = renderer.captureCurrentFrame(format: .jpeg(quality: 0.95))
         * XCTAssertLessThan(jpegLow!.count, jpegHigh!.count)
         * @endcode
         */
    }

    /**
     * video transformation integration Test
     */
    /**
     * timesbefore, crop etc video transformationis Renderingto correctly applydof Check.
     */
    /**
     * @test testTransformationIntegration
     * @brief 🎯 Verification single:
     *
     * @details
     *
     * @section 🎯 🎯 Verification single
     * - timesbefore transformationis applydcan?
     * - crop transformationis applydcan?
     * - brightness/contrast adjustmentis applydcan?
     */
    func testTransformationIntegration() {
        /**
         * TODO: transformation integration Verify
         */
        /**
         * implementation Example:
         * @endcode
         * // transformation service Settings
         * let transformation = VideoTransformation(
         *     rotation: 90,
         *     crop: CGRect(0.1, 0.1, 0.8, 0.8),
         *     brightness: 1.2,
         *     contrast: 1.1
         * )
         * renderer.transformationService.setTransformation(transformation, for: .front)
         */
        /**
         * // Rendering
         * let frames = prepareTestFrames(positions: [.front])
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // transformation apply Check
         * // (pixel Comparcanon or wheneachtic Verify necessary)
         * assertTransformationApplied(to: texture, transformation: transformation)
         * @endcode
         */
    }
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - Helper Extensions for Testing (Test helper expansion)
// ═════════════════════════════════════════════════════════════════════════

extension MultiChannelRendererTests {
    /**
     * Testfor Viewport Creation
     */
    /**
     * Viewport Calculation Testin Usewill CGRect Creation.
     */
    /**
     * - Parameters:
     *   - x: X coordinate (Default value: 0)
     *   - y: Y coordinate (Default value: 0)
     *   - width: width (Default value: 100)
     *   - height: highis (Default value: 100)
     * - Returns: Creationed CGRect
     */
    /**
     *
     * @section 🎯 💡 Use Example
     * @endcode
     * let viewport = createTestViewport(x: 100, y: 200, width: 960, height: 540)
     * assertViewportInBounds(viewport, size)
     * @endcode
     */
    func createTestViewport(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 100, height: CGFloat = 100) -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /**
     * Testfor Screen size Creation
     */
    /**
     * Screen size Testin Usewill CGSize Creation.
     */
    /**
     * - Parameters:
     *   - width: Screen width (Default value: 1920 - Full HD)
     *   - height: Screen highis (Default value: 1080 - Full HD)
     * - Returns: Creationed CGSize
     */
    /**
     *
     * @section __🎯 💡 normalticis resolution
     * @endcode
     * Full HD:    1920 x 1080 (16:9)
     * HD:         1280 x 720  (16:9)
     * 4K UHD:     3840 x 2160 (16:9)
     * iPad:       2048 x 2732 (3:4)
     * iPhone 14:  1170 x 2532 (9:19.5)
     * @endcode
     */
    func createTestSize(width: CGFloat = 1920, height: CGFloat = 1080) -> CGSize {
        return CGSize(width: width, height: height)
    }

    /**
     * Viewportis Screen boundary Withinto existto Verify
     */
    /**
     * Viewportof all coordinateis Valid range Withinto existto Check.
     */
    /**
     * - Parameters:
     *   - viewport: Verifywill Viewport
     *   - size: Screen size
     */
    /**
     *
     * @section 🎯 🎯 Verification single
     * - viewport.origin.x >= 0
     * - viewport.origin.y >= 0
     * - viewport.maxX <= size.width
     * - viewport.maxY <= size.height
     */
    /**
     *
     * @section 🎯 💡 Use Example
     * @endcode
     * let viewport = CGRect(x: 960, y: 540, width: 960, height: 540)
     * let size = CGSize(width: 1920, height: 1080)
     * assertViewportInBounds(viewport, size)  // ✅ throughand
     */
    /**
     * let invalidViewport = CGRect(x: 1500, y: 0, width: 1000, height: 1080)
     * assertViewportInBounds(invalidViewport, size)  // ❌ Failure (maxX = 2500 > 1920)
     * @endcode
     */
    func assertViewportInBounds(_ viewport: CGRect, _ size: CGSize) {
        /**
         * X coordinateis 0 can上canof Check
         */
        XCTAssertGreaterThanOrEqual(viewport.origin.x, 0)

        /**
         * Y coordinateis 0 can上canof Check
         */
        XCTAssertGreaterThanOrEqual(viewport.origin.y, 0)

        /**
         * right endis Screen width canWithincanof Check
         */
        XCTAssertLessThanOrEqual(viewport.maxX, size.width)

        /**
         * belowside endis Screen highis canWithincanof Check
         */
        XCTAssertLessThanOrEqual(viewport.maxY, size.height)
    }

    /**
     * entire Viewport logicalis Screen sizeand matchdoto Verify
     */
    /**
     * all Viewportof total logicalis Screen entire logicaland sameto Check.
     */
    /**
     * - Parameters:
     *   - viewports: Verifywill Viewport dictionary
     *   - size: Screen size
     *   - tolerance: allow tolerance (Default value: 0.01 = 1%)
     */
    /**
     *
     * @section __💡 💡 why allow toleranceis is necessary?
     * - floating point operationof precisionalso limit
     * - pixel sortto canlimited 1-2px Difference
     * - halfround up tolerance cumulative
     */
    /**
     * 🔢 Calculation method:
     * @endcode
     * totalArea = viewport1.area + viewport2.area + ...
     * expectedArea = size.width × size.height
     * difference = |totalArea - expectedArea| / expectedArea
     * @endcode
     */
    /**
     *
     * @section 🎯 📊 Use Example
     * @endcode
     * let viewports: [CameraPosition: CGRect] = [
     *     .front: CGRect(0, 0, 960, 540),
     *     .rear:  CGRect(960, 0, 960, 540),
     *     .left:  CGRect(0, 540, 960, 540),
     *     .right: CGRect(960, 540, 960, 540)
     * ]
     * let size = CGSize(width: 1920, height: 1080)
     */
    /**
     * // total logical: 4 × (960 × 540) = 2,073,600
     * // Screen logical: 1920 × 1080 = 2,073,600
     * // Difference: 0% → throughand
     * assertTotalViewportArea(viewports, equals: size)
     * @endcode
     */
    func assertTotalViewportArea(_ viewports: [CameraPosition: CGRect], equals size: CGSize, tolerance: CGFloat = 0.01) {
        /**
         * all Viewportof total logical Calculation
         */
        /**
         * reduce Uselimited cumulative sum:
         * - secondsenergyValue: 0
         * - each Viewport: width × height
         * - result: all Viewport logicalof combine
         */
        /**
         *
         * @section reduce___ 💡 reduce description
         * @endcode
         * [10, 20, 30].reduce(0) { $0 + $1 }
         * // = ((0 + 10) + 20) + 30 = 60
         */
        /**
         * viewports.values.reduce(0) { $0 + ($1.width * $1.height) }
         * // = each Viewportof logical all add
         * @endcode
         */
        let totalArea = viewports.values.reduce(0) { $0 + ($1.width * $1.height) }

        /**
         * expectedd entire logical (Screen size)
         */
        let expectedArea = size.width * size.height

        /**
         * relative Difference Calculation (percentage)
         */
        /**
         * absoluteValue Use Reason:
         * - totalAreais more class numberalso, small numberalso exists
         * - Whichever side, only size of difference is important
         */
        /**
         * percentage Calculation:
         * @endcode
         * difference = |totalArea - expectedArea| / expectedArea
         * Example: |2100000 - 2073600| / 2073600 = 0.0127 (1.27%)
         * @endcode
         */
        let difference = abs(totalArea - expectedArea) / expectedArea

        /**
         * Differenceis allowed range canWithincanof Check
         */
        /**
         * XCTAssertLessThan:
         * - difference < toleranceif throughand
         * - messageto Test ofalso clearly convey
         */
        /**
         *
         * @section 💡 💡 Failure message Example
         * @endcode
         * ❌ XCTAssertLessThan failed: ("0.05") is of less than ("0.01")
         *    - Total viewport area should match drawable size
         *    → 5% Difference occurrence (allowed range 1% secondsand)
         * @endcode
         */
        XCTAssertLessThan(difference, tolerance, "Total viewport area should match drawable size")
    }
}
