# EXT4 C Library Integration Guide

This document provides detailed instructions for integrating the EXT4 C/C++ library into the BlackboxPlayer project.

## Overview

The BlackboxPlayer uses a protocol-based architecture to abstract EXT4 filesystem operations. This allows for:

- ✅ Development without the C library (using `MockEXT4FileSystem`)
- ✅ Easy testing with mock implementations
- ✅ Seamless integration when the C library becomes available
- ✅ Flexibility to switch implementations

## Architecture

```
┌─────────────────────────────────┐
│   App Layer (ViewModels/Views)  │
└────────────┬────────────────────┘
             │
             │ Uses protocol
             ↓
┌─────────────────────────────────┐
│  EXT4FileSystemProtocol         │  ← Interface
└────────────┬────────────────────┘
             │
       ┌─────┴─────┐
       │           │
       ↓           ↓
┌──────────┐  ┌────────────┐
│ Mock     │  │ EXT4Bridge │  ← Implementations
│          │  │ (C Wrapper)│
└──────────┘  └────────────┘
```

## Current Implementation Status

### ✅ Completed

1. **Protocol Definition** (`EXT4FileSystem.swift`)
   - `EXT4FileSystemProtocol` - Main interface
   - `EXT4Error` - Error types
   - `EXT4FileInfo` - File metadata
   - `EXT4DeviceInfo` - Device information

2. **Mock Implementation** (`MockEXT4FileSystem.swift`)
   - Fully functional in-memory implementation
   - Pre-populated with sample dashcam files
   - Used for development and testing

3. **Bridge Stub** (`EXT4Bridge.swift`)
   - Template for C library integration
   - Detailed integration instructions
   - TODO comments for each method

4. **Unit Tests** (`EXT4FileSystemTests.swift`)
   - Comprehensive test coverage
   - Performance tests
   - Error handling tests

### ⏳ Pending

1. **C Library Integration**
   - Waiting for vendor-provided EXT4 C/C++ library
   - Bridge implementation (EXT4Bridge.swift)

## Integration Steps

### Step 1: Obtain C Library

Contact the vendor to obtain the EXT4 C/C++ library. The library should provide:

- ✅ Source files (.c, .cpp)
- ✅ Header files (.h, .hpp)
- ✅ Build instructions
- ✅ API documentation
- ✅ License information

**Expected Functions:**

```c
// Device/Mount operations
int ext4_mount(const char *dev_name, const char *mount_point, bool read_only);
int ext4_umount(const char *mount_point);
int ext4_device_register(struct ext4_blockdev *bd, const char *dev_name);
int ext4_device_unregister(const char *dev_name);

// File operations
int ext4_fopen(ext4_file *f, const char *path, const char *mode);
int ext4_fclose(ext4_file *f);
size_t ext4_fread(ext4_file *f, void *buf, size_t size, size_t *rcnt);
size_t ext4_fwrite(ext4_file *f, const void *buf, size_t size, size_t *wcnt);
int ext4_fsize(ext4_file *f, uint64_t *size);

// Directory operations
int ext4_dir_open(ext4_dir *d, const char *path);
int ext4_dir_close(ext4_dir *d);
const ext4_direntry* ext4_dir_entry_next(ext4_dir *d);
int ext4_dir_mk(const char *path);
int ext4_dir_rm(const char *path);

// File management
int ext4_fremove(const char *path);
bool ext4_inode_exist(const char *path, int type);
```

### Step 2: Add C Library to Project

#### 2.1 Create Directory Structure

```bash
mkdir -p BlackboxPlayer/Utilities/EXT4/include
mkdir -p BlackboxPlayer/Utilities/EXT4/src
```

#### 2.2 Copy Library Files

```bash
# Copy header files
cp /path/to/ext4/headers/* BlackboxPlayer/Utilities/EXT4/include/

# Copy source files
cp /path/to/ext4/source/* BlackboxPlayer/Utilities/EXT4/src/
```

#### 2.3 Update BridgingHeader.h

Add the following imports to `BlackboxPlayer/Utilities/BridgingHeader.h`:

```c
// EXT4 filesystem library
#import "ext4.h"
#import "ext4_blockdev.h"
#import "ext4_fs.h"
#import "ext4_types.h"
#import "ext4_inode.h"
#import "ext4_super.h"
#import "ext4_dir.h"
```

### Step 3: Update Build Configuration

#### 3.1 Update project.yml

```yaml
targets:
  BlackboxPlayer:
    settings:
      base:
        # Existing settings...
        HEADER_SEARCH_PATHS:
          - /opt/homebrew/Cellar/ffmpeg/8.0_1/include
          - BlackboxPlayer/Utilities/EXT4/include

        # C library compile flags
        OTHER_CFLAGS:
          - -DCONFIG_HAVE_OWN_ERRNO=1
          - -DCONFIG_HAVE_OWN_ASSERT=1
          - -DCONFIG_BLOCK_DEV_CACHE_SIZE=16

        # Optional: Enable debug logging
        # - -DCONFIG_DEBUG_PRINTF=1

    sources:
      - path: BlackboxPlayer
        excludes:
          - "**/*.md"
          - "Tests/**"
      - path: BlackboxPlayer/Utilities/EXT4/src
        type: group
        compilerFlags:
          - -std=c11
```

#### 3.2 Regenerate Xcode Project

```bash
xcodegen generate
```

### Step 4: Implement EXT4Bridge

Open `BlackboxPlayer/Services/EXT4Bridge.swift` and implement each method.

#### Example: Implement mount()

```swift
func mount(devicePath: String) throws {
    guard !_isMounted else {
        throw EXT4Error.alreadyMounted
    }

    // Create block device structure
    var blockdev = ext4_blockdev()

    // Initialize block device (512 byte sectors, 0 offset)
    let bdResult = ext4_blockdev_init(
        &blockdev,
        devicePath,
        512,  // sector size
        0     // offset
    )

    guard bdResult == EOK else {
        throw EXT4Error.deviceNotFound
    }

    // Register the block device
    let regResult = ext4_device_register(&blockdev, "ext4_dev")
    guard regResult == EOK else {
        throw EXT4Error.mountFailed(reason: "Failed to register device")
    }

    // Mount the filesystem
    let mountResult = ext4_mount("ext4_dev", "/mnt/ext4", false)
    guard mountResult == EOK else {
        ext4_device_unregister("ext4_dev")
        throw EXT4Error.mountFailed(
            reason: String(cString: strerror(Int32(mountResult)))
        )
    }

    self.mountPoint = "/mnt/ext4"
    self._isMounted = true
}
```

#### Example: Implement readFile()

```swift
func readFile(at path: String) throws -> Data {
    guard _isMounted else {
        throw EXT4Error.notMounted
    }

    let fullPath = (mountPoint ?? "") + "/" + normalizePath(path)

    // Open file
    var file = ext4_file()
    let openResult = ext4_fopen(&file, fullPath, "rb")
    guard openResult == EOK else {
        throw EXT4Error.fileNotFound(path: path)
    }
    defer { ext4_fclose(&file) }

    // Get file size
    var size: uint64_t = 0
    ext4_fsize(&file, &size)

    // Allocate buffer
    var buffer = Data(count: Int(size))
    var bytesRead: size_t = 0

    // Read data
    let readResult = buffer.withUnsafeMutableBytes { ptr in
        ext4_fread(&file, ptr.baseAddress, size, &bytesRead)
    }

    guard readResult == EOK else {
        throw EXT4Error.readFailed(
            path: path,
            reason: "Read failed with code \(readResult)"
        )
    }

    return buffer
}
```

### Step 5: Test Integration

#### 5.1 Run Unit Tests

```bash
xcodebuild test \
  -project BlackboxPlayer.xcodeproj \
  -scheme BlackboxPlayer \
  -destination 'platform=macOS'
```

#### 5.2 Integration Testing

Create integration tests with real SD card:

```swift
func testRealSDCardMount() throws {
    let bridge = EXT4Bridge()

    // Insert SD card and get device path
    let devicePath = "/dev/disk2s1"  // Adjust as needed

    // Mount
    try bridge.mount(devicePath: devicePath)
    XCTAssertTrue(bridge.isMounted)

    // Get device info
    let info = try bridge.getDeviceInfo()
    print("Mounted: \(info.volumeName ?? "unknown")")
    print("Size: \(info.totalSize) bytes")

    // List files
    let files = try bridge.listFiles(at: "")
    XCTAssertGreaterThan(files.count, 0)

    // Unmount
    try bridge.unmount()
    XCTAssertFalse(bridge.isMounted)
}
```

#### 5.3 Performance Testing

```swift
func testLargeFileReadPerformance() throws {
    let bridge = EXT4Bridge()
    try bridge.mount(devicePath: "/dev/disk2s1")

    measure {
        // Read a large video file (100MB+)
        let data = try? bridge.readFile(at: "normal/video.mp4")
        XCTAssertNotNil(data)
    }

    try bridge.unmount()
}
```

### Step 6: Switch from Mock to Real Implementation

Update dependency injection to use real implementation:

```swift
// In production code
class FileManagerService {
    private let fileSystem: EXT4FileSystemProtocol

    init(fileSystem: EXT4FileSystemProtocol = EXT4Bridge()) {
        self.fileSystem = fileSystem
    }
}

// In tests
class FileManagerServiceTests: XCTestCase {
    func testWithMock() {
        let mockFS = MockEXT4FileSystem()
        let service = FileManagerService(fileSystem: mockFS)
        // Test with mock
    }
}
```

## Error Handling

### Convert C Error Codes

```swift
func convertCError(_ code: Int32) -> EXT4Error {
    switch code {
    case ENOENT:
        return .fileNotFound(path: "")
    case EACCES, EPERM:
        return .permissionDenied
    case ENOSPC:
        return .insufficientSpace
    case EIO:
        return .corruptedFileSystem
    default:
        return .unknownError(code: code)
    }
}
```

### Resource Cleanup

Always use `defer` for cleanup:

```swift
func readFile(at path: String) throws -> Data {
    var file = ext4_file()
    let openResult = ext4_fopen(&file, path, "rb")
    guard openResult == EOK else {
        throw convertCError(openResult)
    }

    // Ensure file is closed even if error occurs
    defer {
        ext4_fclose(&file)
    }

    // ... rest of implementation
}
```

## Memory Management

### Use Autoreleasepool

For operations that process many files:

```swift
func listFiles(at path: String) throws -> [EXT4FileInfo] {
    var files: [EXT4FileInfo] = []

    autoreleasepool {
        var dir = ext4_dir()
        ext4_dir_open(&dir, path)
        defer { ext4_dir_close(&dir) }

        // Process entries
        while let entry = ext4_dir_entry_next(&dir) {
            files.append(convertEntry(entry))
        }
    }

    return files
}
```

## Performance Optimization

### 1. Buffered I/O

```swift
private let READ_BUFFER_SIZE = 1024 * 1024  // 1MB

func readFileLarge(at path: String) throws -> Data {
    var file = ext4_file()
    // ... open file

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: READ_BUFFER_SIZE)
    var bytesRead: size_t = 0

    repeat {
        ext4_fread(&file, &buffer, READ_BUFFER_SIZE, &bytesRead)
        data.append(contentsOf: buffer[0..<Int(bytesRead)])
    } while bytesRead > 0

    return data
}
```

### 2. Caching

Implement caching for frequently accessed metadata:

```swift
private var fileInfoCache: [String: EXT4FileInfo] = [:]

func getFileInfo(at path: String) throws -> EXT4FileInfo {
    if let cached = fileInfoCache[path] {
        return cached
    }

    let info = try fetchFileInfoFromC(path)
    fileInfoCache[path] = info
    return info
}
```

## Troubleshooting

### Issue: Mount fails with "Device busy"

**Solution**: Ensure device is unmounted first:
```bash
diskutil unmount /dev/disk2s1
```

### Issue: Permission denied

**Solution**: App needs proper entitlements:
```xml
<key>com.apple.security.device.usb</key>
<true/>
```

### Issue: Memory leaks

**Solution**: Profile with Instruments (Leaks template):
```bash
instruments -t Leaks BlackboxPlayer.app
```

### Issue: Slow performance

**Solution**: Profile with Instruments (Time Profiler):
```bash
instruments -t "Time Profiler" BlackboxPlayer.app
```

## Checklist

Before considering integration complete:

- [ ] All methods in EXT4Bridge implemented
- [ ] Unit tests passing
- [ ] Integration tests with real SD card passing
- [ ] No memory leaks (verified with Instruments)
- [ ] Performance acceptable (read 100MB file < 2 seconds)
- [ ] Error handling comprehensive
- [ ] Documentation updated
- [ ] Code reviewed
- [ ] Tested on multiple SD cards and devices

## References

- [EXT4 Filesystem Specification](https://ext4.wiki.kernel.org/)
- [lwext4 Library](https://github.com/gkostka/lwext4) (if using this library)
- [Apple File System Programming Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/)
- Project: [EXT4FileSystem.swift](../BlackboxPlayer/Services/EXT4FileSystem.swift)
- Project: [EXT4Bridge.swift](../BlackboxPlayer/Services/EXT4Bridge.swift)

---

**Last Updated**: 2025-10-10
**Status**: Awaiting C library from vendor
**Contact**: Development team for C library delivery
