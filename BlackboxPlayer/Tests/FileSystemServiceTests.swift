/// @file FileSystemServiceTests.swift
/// @brief Unit tests for FileSystemService
/// @author BlackboxPlayer Development Team
/// @details Unit tests that verify the file system access functionality of FileSystemService.

import XCTest
@testable import BlackboxPlayer

/*
 ═══════════════════════════════════════════════════════════════════════════
 FileSystemService Unit Tests
 ═══════════════════════════════════════════════════════════════════════════

 [Test Scope]
 1. listVideoFiles: Query video file list
 2. readFile: Read file
 3. getFileInfo: Query file information
 4. deleteFiles: Delete files
 5. Error handling: Various error scenarios

 [Test Strategy]
 - Use temporary directory: FileManager.default.temporaryDirectory
 - setUp/tearDown: Initialize and clean up test environment
 - Helper methods: Test file creation utilities

 [Test Principles]
 - Fast: Quick execution (minimize file I/O)
 - Independent: Ensure independence between tests
 - Repeatable: Reproducible results
 - Self-validating: Automatic verification
 - Timely: Test immediately after writing code

 ═══════════════════════════════════════════════════════════════════════════
 */

/// @class FileSystemServiceTests
/// @brief Unit test class for FileSystemService
final class FileSystemServiceTests: XCTestCase {
    // MARK: - Properties

    /// @var service
    /// @brief FileSystemService instance under test
    var service: FileSystemService!

    /// @var testDirectory
    /// @brief Temporary directory for testing
    var testDirectory: URL!

    // MARK: - Setup & Teardown

    /*
     ───────────────────────────────────────────────────────────────────────
     setUp Method
     ───────────────────────────────────────────────────────────────────────

     [Purpose]
     Initialize environment before each test execution

     [Tasks]
     1. Create FileSystemService instance
     2. Create unique temporary directory

     [Temporary Directory]
     Generate unique path with UUID:
     - /tmp/FileSystemServiceTests-UUID/
     - Ensure isolation between tests
     - Support parallel testing
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief Initialize environment before test
    override func setUp() {
        super.setUp()

        // Create FileSystemService instance
        service = FileSystemService()

        // Create unique temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent("FileSystemServiceTests-\(UUID().uuidString)")

        do {
            try FileManager.default.createDirectory(
                at: testDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            XCTFail("Failed to create test directory: \(error)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     tearDown Method
     ───────────────────────────────────────────────────────────────────────

     [Purpose]
     Clean up environment after each test execution

     [Tasks]
     1. Delete temporary directory
     2. Release resources

     [Cleanup Failure Handling]
     Cleanup failures are not treated as test failures:
     - Temporary directories are periodically cleaned by system
     - No impact on next test (isolated with UUID)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief Clean up environment after test
    override func tearDown() {
        // Delete temporary directory
        if FileManager.default.fileExists(atPath: testDirectory.path) {
            try? FileManager.default.removeItem(at: testDirectory)
        }

        service = nil
        testDirectory = nil

        super.tearDown()
    }

    // MARK: - List Video Files Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 1: listVideoFiles - Basic Operation
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Directory contains mixed video and non-video files

     [Expected Result]
     - Returns only video files (.mp4, .h264, .avi)
     - Excludes non-video files (.txt, .jpg)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: Verify that only video files are filtered
    func testListVideoFiles_FiltersVideoFilesOnly() throws {
        // Given: Create test files
        createTestFile(name: "video1.mp4")
        createTestFile(name: "video2.h264")
        createTestFile(name: "video3.avi")
        createTestFile(name: "document.txt")
        createTestFile(name: "image.jpg")

        // When: Query video file list
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: Verify that only video files are returned
        XCTAssertEqual(videoFiles.count, 3, "Should find exactly 3 video files")

        let extensions = videoFiles.map { $0.pathExtension.lowercased() }
        XCTAssertTrue(extensions.contains("mp4"), "Should include .mp4 files")
        XCTAssertTrue(extensions.contains("h264"), "Should include .h264 files")
        XCTAssertTrue(extensions.contains("avi"), "Should include .avi files")
        XCTAssertFalse(extensions.contains("txt"), "Should not include .txt files")
        XCTAssertFalse(extensions.contains("jpg"), "Should not include .jpg files")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 2: listVideoFiles - Recursive Search
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Video files exist in subdirectories

     [Expected Result]
     - Find video files in all subdirectories
     - Return as flat array regardless of directory structure
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: Verify that subdirectories are searched recursively
    func testListVideoFiles_SearchesRecursively() throws {
        // Given: Create nested directory structure
        let normalDir = testDirectory.appendingPathComponent("Normal")
        let eventDir = testDirectory.appendingPathComponent("Event")

        try FileManager.default.createDirectory(at: normalDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eventDir, withIntermediateDirectories: true)

        createTestFile(name: "root.mp4", in: testDirectory)
        createTestFile(name: "normal.mp4", in: normalDir)
        createTestFile(name: "event.mp4", in: eventDir)

        // When: Query video file list
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: Find files in all subdirectories
        XCTAssertEqual(videoFiles.count, 3, "Should find files in all subdirectories")

        let fileNames = videoFiles.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("root.mp4"), "Should find root level file")
        XCTAssertTrue(fileNames.contains("normal.mp4"), "Should find Normal/ file")
        XCTAssertTrue(fileNames.contains("event.mp4"), "Should find Event/ file")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 3: listVideoFiles - Empty Directory
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Directory is empty or has no video files

     [Expected Result]
     - Returns empty array
     - No error occurs
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: Verify that empty array is returned for empty directory
    func testListVideoFiles_ReturnsEmptyArrayForEmptyDirectory() throws {
        // Given: Empty directory

        // When: Query video file list
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: Return empty array
        XCTAssertEqual(videoFiles.count, 0, "Should return empty array for empty directory")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 4: listVideoFiles - Directory Not Found Error
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Non-existent directory path

     [Expected Result]
     - Throws FileSystemError.fileNotFound
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: Verify that it throws fileNotFound error for non-existent directory
    func testListVideoFiles_ThrowsErrorForNonexistentDirectory() {
        // Given: Non-existent path
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/directory")

        // When & Then: Verify fileNotFound error
        XCTAssertThrowsError(try service.listVideoFiles(at: nonexistentURL)) { error in
            XCTAssertTrue(error is FileSystemError, "Should throw FileSystemError")
            if case FileSystemError.fileNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected FileSystemError.fileNotFound, got \(error)")
            }
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 5: listVideoFiles - Case Insensitive
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Various case combinations of extensions

     [Expected Result]
     - Recognize .MP4, .Mp4, .mp4 all
     - Filter case-insensitively
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: Verify that extensions are recognized case-insensitively
    func testListVideoFiles_CaseInsensitiveExtensions() throws {
        // Given: Various case combinations
        createTestFile(name: "video1.MP4")
        createTestFile(name: "video2.Mp4")
        createTestFile(name: "video3.mp4")
        createTestFile(name: "video4.H264")
        createTestFile(name: "video5.AVI")

        // When: Query video file list
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: Recognize all files
        XCTAssertEqual(videoFiles.count, 5, "Should recognize all case variations")
    }

    // MARK: - Read File Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 6: readFile - Basic Operation
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that file content is read correctly

     [Expected Result]
     - File content is read accurately
     - Return as Data object
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief readFile: Verify that file content is read correctly
    func testReadFile_ReadsFileContentCorrectly() throws {
        // Given: Create test files
        let testContent = "Test video data"
        let fileURL = createTestFile(name: "test.mp4", content: testContent)

        // When: Read file
        let data = try service.readFile(at: fileURL)

        // Then: Verify content
        let readContent = String(data: data, encoding: .utf8)
        XCTAssertEqual(readContent, testContent, "Should read file content correctly")
        XCTAssertEqual(data.count, testContent.utf8.count, "Data size should match")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 7: readFile - Empty File
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Empty file with size 0

     [Expected Result]
     - Return empty Data object
     - No error occurs
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief readFile: Verify that empty Data is returned when reading empty file
    func testReadFile_HandlesEmptyFile() throws {
        // Given: Create empty file
        let fileURL = createTestFile(name: "empty.mp4", content: "")

        // When: Read file
        let data = try service.readFile(at: fileURL)

        // Then: Return empty Data
        XCTAssertEqual(data.count, 0, "Should return empty data for empty file")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 8: readFile - Non-existent File
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Non-existent file path

     [Expected Result]
     - Throws FileSystemError.accessDenied or readFailed
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief readFile: Verify that error is thrown for non-existent file
    func testReadFile_ThrowsErrorForNonexistentFile() {
        // Given: Non-existent file path
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.mp4")

        // When & Then: Verify error
        XCTAssertThrowsError(try service.readFile(at: nonexistentURL)) { error in
            XCTAssertTrue(error is FileSystemError, "Should throw FileSystemError")
        }
    }

    // MARK: - Get File Info Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 9: getFileInfo - Basic Operation
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Verify that file metadata is queried correctly

     [Expected Result]
     - name: Filename
     - size: File size
     - isDirectory: false
     - path: Absolute path
     - creationDate, modificationDate: Exist
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief getFileInfo: Verify that file metadata is queried correctly
    func testGetFileInfo_ReturnsCorrectMetadata() throws {
        // Given: Create test files
        let fileName = "test.mp4"
        let content = "Test content with specific size"
        let fileURL = createTestFile(name: fileName, content: content)

        // When: Query file information
        let fileInfo = try service.getFileInfo(at: fileURL)

        // Then: Verify metadata
        XCTAssertEqual(fileInfo.name, fileName, "File name should match")
        XCTAssertEqual(fileInfo.size, Int64(content.utf8.count), "File size should match")
        XCTAssertFalse(fileInfo.isDirectory, "Should not be a directory")
        XCTAssertEqual(fileInfo.path, fileURL.path, "Path should match")
        XCTAssertNotNil(fileInfo.creationDate, "Should have creation date")
        XCTAssertNotNil(fileInfo.modificationDate, "Should have modification date")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 10: getFileInfo - Directory Information
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Query information about directory

     [Expected Result]
     - isDirectory: true
     - Other attributes are also returned correctly
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief getFileInfo: Verify that directory information is queried correctly
    func testGetFileInfo_HandlesDirectoryInfo() throws {
        // Given: Create subdirectory
        let subDir = testDirectory.appendingPathComponent("SubDirectory")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // When: Query directory information
        let dirInfo = try service.getFileInfo(at: subDir)

        // Then: Verify directory attributes
        XCTAssertEqual(dirInfo.name, "SubDirectory", "Directory name should match")
        XCTAssertTrue(dirInfo.isDirectory, "Should be marked as directory")
        XCTAssertEqual(dirInfo.path, subDir.path, "Path should match")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 11: getFileInfo - Non-existent File
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Query information of non-existent file

     [Expected Result]
     - Throws FileSystemError.fileNotFound
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief getFileInfo: Verify that it throws fileNotFound error for non-existent file
    func testGetFileInfo_ThrowsErrorForNonexistentFile() {
        // Given: Non-existent file path
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.mp4")

        // When & Then: Verify fileNotFound error
        XCTAssertThrowsError(try service.getFileInfo(at: nonexistentURL)) { error in
            XCTAssertTrue(error is FileSystemError, "Should throw FileSystemError")
            if case FileSystemError.fileNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected FileSystemError.fileNotFound, got \(error)")
            }
        }
    }

    // MARK: - Delete Files Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 12: deleteFiles - Delete Single File
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Delete one file

     [Expected Result]
     - File is actually deleted
     - fileExists returns false
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: Verify that file is deleted correctly
    func testDeleteFiles_DeletesSingleFile() throws {
        // Given: Create test files
        let fileURL = createTestFile(name: "to_delete.mp4")

        // When: Delete file
        try service.deleteFiles([fileURL])

        // Then: Verify file was deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "File should be deleted")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 13: deleteFiles - Delete Multiple Files
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Delete multiple files at once

     [Expected Result]
     - All files are deleted
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: Verify that multiple files are deleted at once
    func testDeleteFiles_DeletesMultipleFiles() throws {
        // Given: Create multiple test files
        let file1 = createTestFile(name: "file1.mp4")
        let file2 = createTestFile(name: "file2.mp4")
        let file3 = createTestFile(name: "file3.mp4")

        // When: Delete multiple files
        try service.deleteFiles([file1, file2, file3])

        // Then: Verify all files were deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path), "File 1 should be deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file2.path), "File 2 should be deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file3.path), "File 3 should be deleted")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 14: deleteFiles - Empty Array
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     When there are no files to delete

     [Expected Result]
     - No error occurs
     - Complete normally
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: Verify that it completes without error when passed empty array
    func testDeleteFiles_HandlesEmptyArray() throws {
        // Given: Empty array

        // When & Then: Complete without error
        XCTAssertNoThrow(try service.deleteFiles([]), "Should handle empty array without error")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     Test 15: deleteFiles - Non-existent File
     ───────────────────────────────────────────────────────────────────────

     [Scenario]
     Attempt to delete non-existent file

     [Expected Result]
     - Throws FileSystemError.writeFailed
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: Verify that error is thrown when deleting non-existent file
    func testDeleteFiles_ThrowsErrorForNonexistentFile() {
        // Given: Non-existent file path
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.mp4")

        // When & Then: Verify writeFailed error
        XCTAssertThrowsError(try service.deleteFiles([nonexistentURL])) { error in
            XCTAssertTrue(error is FileSystemError, "Should throw FileSystemError")
            if case FileSystemError.writeFailed = error {
                // Expected error
            } else {
                XCTFail("Expected FileSystemError.writeFailed, got \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    /*
     ───────────────────────────────────────────────────────────────────────
     Helper Method: createTestFile
     ───────────────────────────────────────────────────────────────────────

     [Purpose]
     Test file creation utility

     [Parameters]
     - name: Filename
     - content: File content (default: "test")
     - in: Directory to create in (default: testDirectory)

     [Return]
     URL of created file
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief Helper for creating test files
    ///
    /// @param name Filename
    /// @param content File content (default: "test")
    /// @param directory Directory to create in (default: testDirectory)
    /// @return URL of created file
    @discardableResult
    private func createTestFile(
        name: String,
        content: String = "test",
        in directory: URL? = nil
    ) -> URL {
        let targetDirectory = directory ?? testDirectory!
        let fileURL = targetDirectory.appendingPathComponent(name)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            XCTFail("Failed to create test file: \(error)")
        }

        return fileURL
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 Test Execution Guide
 ═══════════════════════════════════════════════════════════════════════════

 [Running in Xcode]

 1. Run all tests:
    - ⌘ + U

 2. Run specific test class:
    - Click the diamond icon to the left of the class

 3. Run specific test method:
    - Click the diamond icon to the left of the method

 [Running in Terminal]

 All tests:
 xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'

 Specific test class:
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/FileSystemServiceTests

 Specific test method:
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/FileSystemServiceTests/testListVideoFiles_FiltersVideoFilesOnly

 [Test Coverage]

 Run tests with coverage:
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -enableCodeCoverage YES

 View coverage report:
 open DerivedData/BlackboxPlayer/Logs/Test/<results>.xcresult

 [CI/CD Integration]

 GitHub Actions:
 - name: Run Tests
   run: xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'

 ═══════════════════════════════════════════════════════════════════════════
 */
