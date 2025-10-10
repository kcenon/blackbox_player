//
//  EXT4FileSystemTests.swift
//  BlackboxPlayerTests
//
//  Unit tests for EXT4 file system interface
//

import XCTest
@testable import BlackboxPlayer

final class EXT4FileSystemTests: XCTestCase {

    var fileSystem: MockEXT4FileSystem!

    override func setUpWithError() throws {
        try super.setUpWithError()
        fileSystem = MockEXT4FileSystem()
        fileSystem.reset()
    }

    override func tearDownWithError() throws {
        fileSystem = nil
        try super.tearDownWithError()
    }

    // MARK: - Mount/Unmount Tests

    func testMountDevice() throws {
        // Initially not mounted
        XCTAssertFalse(fileSystem.isMounted)

        // Mount a device
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Should be mounted now
        XCTAssertTrue(fileSystem.isMounted)
    }

    func testMountAlreadyMountedDevice() throws {
        // Mount first time
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Try to mount again should throw error
        XCTAssertThrowsError(try fileSystem.mount(devicePath: "/dev/disk2s1")) { error in
            XCTAssertEqual(error as? EXT4Error, EXT4Error.alreadyMounted)
        }
    }

    func testMountInvalidDevice() throws {
        // Try to mount invalid device path
        XCTAssertThrowsError(try fileSystem.mount(devicePath: "invalid/path"))
    }

    func testUnmountDevice() throws {
        // Mount and then unmount
        try fileSystem.mount(devicePath: "/dev/disk2s1")
        try fileSystem.unmount()

        // Should not be mounted
        XCTAssertFalse(fileSystem.isMounted)
    }

    func testUnmountWhenNotMounted() throws {
        // Try to unmount when not mounted
        XCTAssertThrowsError(try fileSystem.unmount()) { error in
            XCTAssertEqual(error as? EXT4Error, EXT4Error.notMounted)
        }
    }

    func testGetDeviceInfo() throws {
        // Mount device
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Get device info
        let info = try fileSystem.getDeviceInfo()

        // Verify device info
        XCTAssertEqual(info.devicePath, "/dev/disk2s1")
        XCTAssertNotNil(info.volumeName)
        XCTAssertGreaterThan(info.totalSize, 0)
        XCTAssertLessThanOrEqual(info.freeSpace, info.totalSize)
        XCTAssertTrue(info.isMounted)
    }

    func testGetDeviceInfoWhenNotMounted() throws {
        // Try to get device info when not mounted
        XCTAssertThrowsError(try fileSystem.getDeviceInfo()) { error in
            XCTAssertEqual(error as? EXT4Error, EXT4Error.notMounted)
        }
    }

    // MARK: - File Operation Tests

    func testListFiles() throws {
        // Mount device
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // List files in root
        let files = try fileSystem.listFiles(at: "")

        // Should have directories (normal, event, parking)
        XCTAssertGreaterThan(files.count, 0)

        // Check for expected directories
        let dirNames = files.filter { $0.isDirectory }.map { $0.name }
        XCTAssertTrue(dirNames.contains("normal"))
        XCTAssertTrue(dirNames.contains("event"))
        XCTAssertTrue(dirNames.contains("parking"))
    }

    func testListFilesInDirectory() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // List files in normal directory
        let files = try fileSystem.listFiles(at: "normal")

        // Should have video and metadata files
        XCTAssertGreaterThan(files.count, 0)

        // Check for video files
        let videoFiles = files.filter { $0.name.hasSuffix(".mp4") }
        XCTAssertGreaterThan(videoFiles.count, 0)

        // Check for GPS files
        let gpsFiles = files.filter { $0.name.hasSuffix(".gps") }
        XCTAssertGreaterThan(gpsFiles.count, 0)
    }

    func testReadFile() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Read a file
        let data = try fileSystem.readFile(at: "normal/2025_01_10_09_00_00_F.gps")

        // Should have data
        XCTAssertGreaterThan(data.count, 0)
    }

    func testReadNonexistentFile() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Try to read nonexistent file
        XCTAssertThrowsError(try fileSystem.readFile(at: "nonexistent.txt")) { error in
            guard case EXT4Error.fileNotFound = error else {
                XCTFail("Expected fileNotFound error")
                return
            }
        }
    }

    func testWriteFile() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Write a file
        let testData = "Test content".data(using: .utf8)!
        try fileSystem.writeFile(data: testData, to: "test.txt")

        // Read it back
        let readData = try fileSystem.readFile(at: "test.txt")
        XCTAssertEqual(readData, testData)
    }

    func testFileExists() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Check existing file
        XCTAssertTrue(fileSystem.fileExists(at: "normal/2025_01_10_09_00_00_F.mp4"))

        // Check nonexistent file
        XCTAssertFalse(fileSystem.fileExists(at: "nonexistent.txt"))
    }

    func testGetFileInfo() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Get file info
        let info = try fileSystem.getFileInfo(at: "normal/2025_01_10_09_00_00_F.mp4")

        // Verify file info
        XCTAssertEqual(info.name, "2025_01_10_09_00_00_F.mp4")
        XCTAssertFalse(info.isDirectory)
        XCTAssertGreaterThan(info.size, 0)
    }

    func testDeleteFile() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Create a file
        let testData = "Test".data(using: .utf8)!
        try fileSystem.writeFile(data: testData, to: "delete_me.txt")

        // Verify it exists
        XCTAssertTrue(fileSystem.fileExists(at: "delete_me.txt"))

        // Delete it
        try fileSystem.deleteFile(at: "delete_me.txt")

        // Verify it's gone
        XCTAssertFalse(fileSystem.fileExists(at: "delete_me.txt"))
    }

    func testCreateDirectory() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Create a directory
        try fileSystem.createDirectory(at: "new_dir")

        // List root to verify
        let files = try fileSystem.listFiles(at: "")
        let dirNames = files.filter { $0.isDirectory }.map { $0.name }
        XCTAssertTrue(dirNames.contains("new_dir"))
    }

    // MARK: - Path Normalization Tests

    func testPathNormalization() {
        let tests: [(input: String, expected: String)] = [
            ("/test/path/", "test/path"),
            ("test/path", "test/path"),
            ("/test/path", "test/path"),
            ("test/path/", "test/path"),
            ("  /test/path/  ", "test/path")
        ]

        for test in tests {
            let normalized = fileSystem.normalizePath(test.input)
            XCTAssertEqual(normalized, test.expected,
                          "Failed for input: '\(test.input)'")
        }
    }

    // MARK: - Error Handling Tests

    func testOperationsWhenNotMounted() throws {
        // All file operations should fail when not mounted
        XCTAssertThrowsError(try fileSystem.listFiles(at: ""))
        XCTAssertThrowsError(try fileSystem.readFile(at: "test.txt"))
        XCTAssertThrowsError(try fileSystem.writeFile(data: Data(), to: "test.txt"))
        XCTAssertThrowsError(try fileSystem.getFileInfo(at: "test.txt"))
        XCTAssertThrowsError(try fileSystem.deleteFile(at: "test.txt"))
        XCTAssertThrowsError(try fileSystem.createDirectory(at: "test_dir"))
        XCTAssertFalse(fileSystem.fileExists(at: "test.txt"))
    }

    // MARK: - Performance Tests

    func testListManyFilesPerformance() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Add many test files
        for i in 0..<1000 {
            let data = Data(count: 100)
            fileSystem.addTestFile(path: "test/file_\(i).dat", data: data)
        }

        // Measure performance
        measure {
            _ = try? fileSystem.listFiles(at: "test")
        }
    }

    func testReadLargeFilePerformance() throws {
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        // Add a large file (10MB)
        let largeData = Data(count: 10 * 1024 * 1024)
        fileSystem.addTestFile(path: "large_file.dat", data: largeData)

        // Measure performance
        measure {
            _ = try? fileSystem.readFile(at: "large_file.dat")
        }
    }
}
