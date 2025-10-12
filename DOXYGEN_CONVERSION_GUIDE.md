# Doxygen Conversion Guide for Swift Files

## Overview
This guide provides patterns for converting existing Swift documentation to Doxygen format while preserving all Korean educational comments and ASCII art.

## File Structure Reference
Match the style from already-converted files: GPSService.swift, GSensorService.swift

## Conversion Patterns

### 1. File Header

**Before:**
```swift
//
//  EXT4FileSystem.swift
//  BlackboxPlayer
//
//  Protocol-based EXT4 file system interface for easy C library integration
//
```

**After:**
```swift
/// @file EXT4FileSystem.swift
/// @brief Protocol-based EXT4 file system interface for easy C library integration
/// @author BlackboxPlayer Development Team
/// @details EXT4 파일시스템 인터페이스와 오류 타입 정의
```

### 2. Enums

**Before:**
```swift
/// EXT4 파일시스템 작업 중 발생할 수 있는 오류
///
/// 각 오류는 발생 원인과 복구 방법에 대한 정보를 포함합니다.
enum EXT4Error: Error, Equatable {
```

**After:**
```swift
/// @enum EXT4Error
/// @brief EXT4 파일시스템 작업 중 발생할 수 있는 오류
/// @details 각 오류는 발생 원인과 복구 방법에 대한 정보를 포함합니다.
enum EXT4Error: Error, Equatable {
```

### 3. Enum Cases

**Before:**
```swift
    /// SD 카드나 외장 저장장치를 찾을 수 없음
    ///
    /// 발생 시나리오:
    /// - SD 카드가 컴퓨터에 연결되지 않음
    case deviceNotFound
```

**After:**
```swift
    /// @brief SD 카드나 외장 저장장치를 찾을 수 없음
    ///
    /// 발생 시나리오:
    /// - SD 카드가 컴퓨터에 연결되지 않음
    case deviceNotFound
```

### 4. Structs

**Before:**
```swift
/// 블랙박스 EXT4 파일 시스템의 디바이스 정보
struct EXT4DeviceInfo {
```

**After:**
```swift
/// @struct EXT4DeviceInfo
/// @brief 블랙박스 EXT4 파일 시스템의 디바이스 정보
struct EXT4DeviceInfo {
```

### 5. Properties

**Before:**
```swift
    /// 장치 경로 (예: "/dev/disk2s1")
    let devicePath: String
```

**After:**
```swift
    /// @var devicePath
    /// @brief 장치 경로 (예: "/dev/disk2s1")
    let devicePath: String
```

### 6. Protocols

**Before:**
```swift
/// EXT4 파일 시스템 접근을 위한 프로토콜
protocol EXT4FileSystemProtocol {
```

**After:**
```swift
/// @protocol EXT4FileSystemProtocol
/// @brief EXT4 파일 시스템 접근을 위한 프로토콜
protocol EXT4FileSystemProtocol {
```

### 7. Methods/Functions

**Before:**
```swift
    /// EXT4 장치를 마운트합니다
    /// - Parameter devicePath: 마운트할 장치 경로
    /// - Throws: EXT4Error
    func mount(devicePath: String) throws
```

**After:**
```swift
    /// @brief EXT4 장치를 마운트합니다
    /// @param devicePath 마운트할 장치 경로
    /// @throws EXT4Error 마운트 실패 시
    func mount(devicePath: String) throws
```

### 8. Classes

**Before:**
```swift
/// Bridge class for integrating C/C++ EXT4 library
class EXT4Bridge: EXT4FileSystemProtocol {
```

**After:**
```swift
/// @class EXT4Bridge
/// @brief Bridge class for integrating C/C++ EXT4 library
class EXT4Bridge: EXT4FileSystemProtocol {
```

### 9. Methods with Return Values

**Before:**
```swift
    /// 디렉토리의 파일 목록을 조회합니다
    /// - Parameter path: 조회할 디렉토리 경로
    /// - Returns: 파일 정보 배열
    /// - Throws: EXT4Error
    func listFiles(at path: String) throws -> [EXT4FileInfo]
```

**After:**
```swift
    /// @brief 디렉토리의 파일 목록을 조회합니다
    /// @param path 조회할 디렉토리 경로
    /// @return 파일 정보 배열
    /// @throws EXT4Error 파일 접근 실패 시
    func listFiles(at path: String) throws -> [EXT4FileInfo]
```

### 10. Extensions

**Before:**
```swift
extension VideoFile {
    /// Create updated VideoFile with favorite status
    func withUpdatedMetadata(from service: FileManagerService) -> VideoFile {
```

**After:**
```swift
extension VideoFile {
    /// @brief Create updated VideoFile with favorite status
    /// @param service FileManagerService to use
    /// @return Updated VideoFile
    func withUpdatedMetadata(from service: FileManagerService) -> VideoFile {
```

## Important Rules

### DO:
1. ✓ Add Doxygen tags to ALL elements (file, class, struct, enum, protocol, properties, methods)
2. ✓ Use `/// ` style consistently (three slashes + space)
3. ✓ Preserve ALL Korean educational comments
4. ✓ Preserve ALL ASCII art and diagrams
5. ✓ Match indentation of original comments
6. ✓ Keep all detailed explanatory comments below the @brief/@param/@return tags

### DON'T:
1. ✗ DO NOT modify Swift code logic
2. ✗ DO NOT remove or shorten Korean comments
3. ✗ DO NOT remove ASCII art diagrams
4. ✗ DO NOT change comment structure (only add @tags)
5. ✗ DO NOT add emojis

## Tag Usage Summary

| Element | Tags to Use |
|---------|-------------|
| File header | `@file`, `@brief`, `@author`, `@details` |
| Class | `@class`, `@brief` |
| Struct | `@struct`, `@brief` |
| Enum | `@enum`, `@brief`, `@details` (optional) |
| Protocol | `@protocol`, `@brief` |
| Property/Variable | `@var`, `@brief` |
| Method/Function | `@brief`, `@param`, `@return`, `@throws` |
| Enum case | `@brief` only |

## Example: Complete Conversion

**Before:**
```swift
//
//  FileScanner.swift
//  BlackboxPlayer
//
//  Service for scanning and discovering dashcam video files
//

import Foundation

/// 디렉토리를 스캔하여 블랙박스 비디오 파일을 발견하고 조직화하는 서비스
class FileScanner {

    /// 지원하는 비디오 파일 확장자
    private let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv"]

    /// BlackVue 형식 파일명 패턴 (YYYYMMDD_HHMMSS_X.mp4)
    private let filenamePattern = #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#

    /// 디렉토리를 스캔하여 블랙박스 비디오 파일 발견
    /// - Parameter directoryURL: 스캔할 디렉토리의 URL
    /// - Returns: VideoFileGroup 배열 (최신순 정렬)
    /// - Throws: FileScannerError
    func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
        // Implementation
    }
}
```

**After:**
```swift
/// @file FileScanner.swift
/// @brief Service for scanning and discovering dashcam video files
/// @author BlackboxPlayer Development Team
/// @details 블랙박스 SD 카드의 디렉토리를 재귀적으로 스캔하여 비디오 파일을 발견

import Foundation

/// @class FileScanner
/// @brief 디렉토리를 스캔하여 블랙박스 비디오 파일을 발견하고 조직화하는 서비스
class FileScanner {

    /// @var videoExtensions
    /// @brief 지원하는 비디오 파일 확장자
    private let videoExtensions: Set<String> = ["mp4", "mov", "avi", "mkv"]

    /// @var filenamePattern
    /// @brief BlackVue 형식 파일명 패턴 (YYYYMMDD_HHMMSS_X.mp4)
    private let filenamePattern = #"^(\d{8})_(\d{6})_([FRLIi]+)\.(\w+)$"#

    /// @brief 디렉토리를 스캔하여 블랙박스 비디오 파일 발견
    /// @param directoryURL 스캔할 디렉토리의 URL
    /// @return VideoFileGroup 배열 (최신순 정렬)
    /// @throws FileScannerError 디렉토리 접근 실패 시
    func scanDirectory(_ directoryURL: URL) throws -> [VideoFileGroup] {
        // Implementation
    }
}
```

## Files to Convert

1. ✗ EXT4FileSystem.swift (1441 lines) - Partially converted
2. ✗ EXT4Bridge.swift (1738 lines)
3. ✗ MockEXT4FileSystem.swift (1798 lines)
4. ✗ FileManagerService.swift (1850 lines)
5. ✗ FileScanner.swift (1561 lines)

## Recommended Approach

Due to the size and complexity:

1. **Option A: Manual conversion with find-and-replace**
   - Use this guide with VSCode/Xcode find-and-replace
   - Convert file-by-file systematically
   - Validate after each file

2. **Option B: Automated tool**
   - Create a Python/Swift script using these patterns
   - Test on a small section first
   - Review output carefully

3. **Option C: Gradual conversion**
   - Convert public APIs first (protocols, main classes)
   - Then convert implementation details
   - Save Korean educational comments for last review

## Quality Checklist

After conversion, verify:
- [ ] All file headers have @file, @brief, @author tags
- [ ] All classes/structs/enums have @class/@struct/@enum and @brief
- [ ] All properties have @var and @brief
- [ ] All methods have @brief, @param, @return/@throws as needed
- [ ] All Korean comments preserved
- [ ] All ASCII art preserved
- [ ] No Swift code logic changed
- [ ] Consistent /// style throughout
- [ ] Proper indentation maintained

## Support

For questions or issues during conversion:
1. Refer to already-converted files: GPSService.swift, GSensorService.swift
2. Check official Doxygen documentation
3. Test with `doxygen` command to validate syntax
