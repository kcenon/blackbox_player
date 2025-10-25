/// @file FileSystemServiceTests.swift
/// @brief Unit tests for FileSystemService
/// @author BlackboxPlayer Development Team
/// @details FileSystemService의 파일 시스템 접근 기능을 검증하는 단위 테스트입니다.

import XCTest
@testable import BlackboxPlayer

/*
 ═══════════════════════════════════════════════════════════════════════════
 FileSystemService 단위 테스트
 ═══════════════════════════════════════════════════════════════════════════

 【테스트 범위】
 1. listVideoFiles: 비디오 파일 목록 조회
 2. readFile: 파일 읽기
 3. getFileInfo: 파일 정보 조회
 4. deleteFiles: 파일 삭제
 5. 에러 처리: 다양한 오류 시나리오

 【테스트 전략】
 - 임시 디렉토리 사용: FileManager.default.temporaryDirectory
 - setUp/tearDown: 테스트 환경 초기화 및 정리
 - Helper 메서드: 테스트 파일 생성 유틸리티

 【테스트 원칙】
 - Fast: 빠른 실행 (파일 I/O 최소화)
 - Independent: 테스트 간 독립성 보장
 - Repeatable: 반복 가능한 결과
 - Self-validating: 자동 검증
 - Timely: 코드 작성 직후 테스트

 ═══════════════════════════════════════════════════════════════════════════
 */

/// @class FileSystemServiceTests
/// @brief FileSystemService의 단위 테스트 클래스
final class FileSystemServiceTests: XCTestCase {
    // MARK: - Properties

    /// @var service
    /// @brief 테스트 대상 FileSystemService 인스턴스
    var service: FileSystemService!

    /// @var testDirectory
    /// @brief 테스트용 임시 디렉토리
    var testDirectory: URL!

    // MARK: - Setup & Teardown

    /*
     ───────────────────────────────────────────────────────────────────────
     setUp 메서드
     ───────────────────────────────────────────────────────────────────────

     【목적】
     각 테스트 실행 전 환경 초기화

     【작업】
     1. FileSystemService 인스턴스 생성
     2. 고유한 임시 디렉토리 생성

     【임시 디렉토리】
     UUID로 고유한 경로 생성:
     - /tmp/FileSystemServiceTests-UUID/
     - 테스트 간 격리 보장
     - 병렬 테스트 지원
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 테스트 전 환경 초기화
    override func setUp() {
        super.setUp()

        // FileSystemService 인스턴스 생성
        service = FileSystemService()

        // 고유한 임시 디렉토리 생성
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
     tearDown 메서드
     ───────────────────────────────────────────────────────────────────────

     【목적】
     각 테스트 실행 후 환경 정리

     【작업】
     1. 임시 디렉토리 삭제
     2. 리소스 해제

     【정리 실패 처리】
     정리 실패는 테스트 실패로 처리하지 않음:
     - 임시 디렉토리는 시스템이 주기적으로 정리
     - 다음 테스트에 영향 없음 (UUID로 격리)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 테스트 후 환경 정리
    override func tearDown() {
        // 임시 디렉토리 삭제
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
     테스트 1: listVideoFiles - 기본 동작
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     디렉토리에 비디오 파일과 비비디오 파일이 혼재

     【예상 결과】
     - 비디오 파일(.mp4, .h264, .avi)만 반환
     - 비비디오 파일(.txt, .jpg) 제외
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: 비디오 파일만 필터링하는지 검증
    func testListVideoFiles_FiltersVideoFilesOnly() throws {
        // Given: 테스트 파일 생성
        createTestFile(name: "video1.mp4")
        createTestFile(name: "video2.h264")
        createTestFile(name: "video3.avi")
        createTestFile(name: "document.txt")
        createTestFile(name: "image.jpg")

        // When: 비디오 파일 목록 조회
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: 비디오 파일만 반환되었는지 검증
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
     테스트 2: listVideoFiles - 재귀 탐색
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     하위 디렉토리에 비디오 파일이 있는 경우

     【예상 결과】
     - 모든 하위 디렉토리의 비디오 파일 발견
     - 디렉토리 구조와 관계없이 평면 배열로 반환
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: 재귀적으로 하위 디렉토리를 탐색하는지 검증
    func testListVideoFiles_SearchesRecursively() throws {
        // Given: 중첩된 디렉토리 구조 생성
        let normalDir = testDirectory.appendingPathComponent("Normal")
        let eventDir = testDirectory.appendingPathComponent("Event")

        try FileManager.default.createDirectory(at: normalDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: eventDir, withIntermediateDirectories: true)

        createTestFile(name: "root.mp4", in: testDirectory)
        createTestFile(name: "normal.mp4", in: normalDir)
        createTestFile(name: "event.mp4", in: eventDir)

        // When: 비디오 파일 목록 조회
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: 모든 하위 디렉토리의 파일 발견
        XCTAssertEqual(videoFiles.count, 3, "Should find files in all subdirectories")

        let fileNames = videoFiles.map { $0.lastPathComponent }
        XCTAssertTrue(fileNames.contains("root.mp4"), "Should find root level file")
        XCTAssertTrue(fileNames.contains("normal.mp4"), "Should find Normal/ file")
        XCTAssertTrue(fileNames.contains("event.mp4"), "Should find Event/ file")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 3: listVideoFiles - 빈 디렉토리
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     디렉토리가 비어있거나 비디오 파일이 없는 경우

     【예상 결과】
     - 빈 배열 반환
     - 오류 발생하지 않음
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: 빈 디렉토리에서 빈 배열을 반환하는지 검증
    func testListVideoFiles_ReturnsEmptyArrayForEmptyDirectory() throws {
        // Given: 빈 디렉토리

        // When: 비디오 파일 목록 조회
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: 빈 배열 반환
        XCTAssertEqual(videoFiles.count, 0, "Should return empty array for empty directory")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 4: listVideoFiles - 디렉토리 없음 에러
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     존재하지 않는 디렉토리 경로

     【예상 결과】
     - FileSystemError.fileNotFound throws
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: 존재하지 않는 디렉토리에 대해 fileNotFound 에러를 던지는지 검증
    func testListVideoFiles_ThrowsErrorForNonexistentDirectory() {
        // Given: 존재하지 않는 경로
        let nonexistentURL = URL(fileURLWithPath: "/nonexistent/directory")

        // When & Then: fileNotFound 에러 검증
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
     테스트 5: listVideoFiles - 대소문자 구분 없이
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     다양한 대소문자 조합의 확장자

     【예상 결과】
     - .MP4, .Mp4, .mp4 모두 인식
     - 대소문자 구분 없이 필터링
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief listVideoFiles: 대소문자 구분 없이 확장자를 인식하는지 검증
    func testListVideoFiles_CaseInsensitiveExtensions() throws {
        // Given: 다양한 대소문자 조합
        createTestFile(name: "video1.MP4")
        createTestFile(name: "video2.Mp4")
        createTestFile(name: "video3.mp4")
        createTestFile(name: "video4.H264")
        createTestFile(name: "video5.AVI")

        // When: 비디오 파일 목록 조회
        let videoFiles = try service.listVideoFiles(at: testDirectory)

        // Then: 모든 파일 인식
        XCTAssertEqual(videoFiles.count, 5, "Should recognize all case variations")
    }

    // MARK: - Read File Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 6: readFile - 기본 동작
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     파일 내용을 올바르게 읽어오는지 확인

     【예상 결과】
     - 파일 내용이 정확하게 읽힘
     - Data 객체로 반환
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief readFile: 파일 내용을 올바르게 읽는지 검증
    func testReadFile_ReadsFileContentCorrectly() throws {
        // Given: 테스트 파일 생성
        let testContent = "Test video data"
        let fileURL = createTestFile(name: "test.mp4", content: testContent)

        // When: 파일 읽기
        let data = try service.readFile(at: fileURL)

        // Then: 내용 검증
        let readContent = String(data: data, encoding: .utf8)
        XCTAssertEqual(readContent, testContent, "Should read file content correctly")
        XCTAssertEqual(data.count, testContent.utf8.count, "Data size should match")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 7: readFile - 빈 파일
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     크기가 0인 빈 파일

     【예상 결과】
     - 빈 Data 객체 반환
     - 오류 발생하지 않음
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief readFile: 빈 파일을 읽을 때 빈 Data를 반환하는지 검증
    func testReadFile_HandlesEmptyFile() throws {
        // Given: 빈 파일 생성
        let fileURL = createTestFile(name: "empty.mp4", content: "")

        // When: 파일 읽기
        let data = try service.readFile(at: fileURL)

        // Then: 빈 Data 반환
        XCTAssertEqual(data.count, 0, "Should return empty data for empty file")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 8: readFile - 존재하지 않는 파일
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     존재하지 않는 파일 경로

     【예상 결과】
     - FileSystemError.accessDenied 또는 readFailed throws
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief readFile: 존재하지 않는 파일에 대해 에러를 던지는지 검증
    func testReadFile_ThrowsErrorForNonexistentFile() {
        // Given: 존재하지 않는 파일 경로
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.mp4")

        // When & Then: 에러 검증
        XCTAssertThrowsError(try service.readFile(at: nonexistentURL)) { error in
            XCTAssertTrue(error is FileSystemError, "Should throw FileSystemError")
        }
    }

    // MARK: - Get File Info Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 9: getFileInfo - 기본 동작
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     파일의 메타데이터를 올바르게 조회하는지 확인

     【예상 결과】
     - name: 파일명
     - size: 파일 크기
     - isDirectory: false
     - path: 절대 경로
     - creationDate, modificationDate: 존재
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief getFileInfo: 파일 메타데이터를 올바르게 조회하는지 검증
    func testGetFileInfo_ReturnsCorrectMetadata() throws {
        // Given: 테스트 파일 생성
        let fileName = "test.mp4"
        let content = "Test content with specific size"
        let fileURL = createTestFile(name: fileName, content: content)

        // When: 파일 정보 조회
        let fileInfo = try service.getFileInfo(at: fileURL)

        // Then: 메타데이터 검증
        XCTAssertEqual(fileInfo.name, fileName, "File name should match")
        XCTAssertEqual(fileInfo.size, Int64(content.utf8.count), "File size should match")
        XCTAssertFalse(fileInfo.isDirectory, "Should not be a directory")
        XCTAssertEqual(fileInfo.path, fileURL.path, "Path should match")
        XCTAssertNotNil(fileInfo.creationDate, "Should have creation date")
        XCTAssertNotNil(fileInfo.modificationDate, "Should have modification date")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 10: getFileInfo - 디렉토리 정보
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     디렉토리에 대한 정보 조회

     【예상 결과】
     - isDirectory: true
     - 다른 속성도 올바르게 반환
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief getFileInfo: 디렉토리 정보를 올바르게 조회하는지 검증
    func testGetFileInfo_HandlesDirectoryInfo() throws {
        // Given: 하위 디렉토리 생성
        let subDir = testDirectory.appendingPathComponent("SubDirectory")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        // When: 디렉토리 정보 조회
        let dirInfo = try service.getFileInfo(at: subDir)

        // Then: 디렉토리 속성 검증
        XCTAssertEqual(dirInfo.name, "SubDirectory", "Directory name should match")
        XCTAssertTrue(dirInfo.isDirectory, "Should be marked as directory")
        XCTAssertEqual(dirInfo.path, subDir.path, "Path should match")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 11: getFileInfo - 존재하지 않는 파일
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     존재하지 않는 파일의 정보 조회

     【예상 결과】
     - FileSystemError.fileNotFound throws
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief getFileInfo: 존재하지 않는 파일에 대해 fileNotFound 에러를 던지는지 검증
    func testGetFileInfo_ThrowsErrorForNonexistentFile() {
        // Given: 존재하지 않는 파일 경로
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.mp4")

        // When & Then: fileNotFound 에러 검증
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
     테스트 12: deleteFiles - 단일 파일 삭제
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     파일 하나를 삭제

     【예상 결과】
     - 파일이 실제로 삭제됨
     - fileExists가 false 반환
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: 파일을 올바르게 삭제하는지 검증
    func testDeleteFiles_DeletesSingleFile() throws {
        // Given: 테스트 파일 생성
        let fileURL = createTestFile(name: "to_delete.mp4")

        // When: 파일 삭제
        try service.deleteFiles([fileURL])

        // Then: 파일이 삭제되었는지 검증
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path), "File should be deleted")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 13: deleteFiles - 여러 파일 삭제
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     여러 파일을 한 번에 삭제

     【예상 결과】
     - 모든 파일이 삭제됨
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: 여러 파일을 한 번에 삭제하는지 검증
    func testDeleteFiles_DeletesMultipleFiles() throws {
        // Given: 여러 테스트 파일 생성
        let file1 = createTestFile(name: "file1.mp4")
        let file2 = createTestFile(name: "file2.mp4")
        let file3 = createTestFile(name: "file3.mp4")

        // When: 여러 파일 삭제
        try service.deleteFiles([file1, file2, file3])

        // Then: 모든 파일이 삭제되었는지 검증
        XCTAssertFalse(FileManager.default.fileExists(atPath: file1.path), "File 1 should be deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file2.path), "File 2 should be deleted")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file3.path), "File 3 should be deleted")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 14: deleteFiles - 빈 배열
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     삭제할 파일이 없는 경우

     【예상 결과】
     - 오류 발생하지 않음
     - 정상 완료
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: 빈 배열을 전달했을 때 오류 없이 완료되는지 검증
    func testDeleteFiles_HandlesEmptyArray() throws {
        // Given: 빈 배열

        // When & Then: 오류 없이 완료
        XCTAssertNoThrow(try service.deleteFiles([]), "Should handle empty array without error")
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 15: deleteFiles - 존재하지 않는 파일
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     존재하지 않는 파일을 삭제하려고 시도

     【예상 결과】
     - FileSystemError.writeFailed throws
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief deleteFiles: 존재하지 않는 파일 삭제 시 에러를 던지는지 검증
    func testDeleteFiles_ThrowsErrorForNonexistentFile() {
        // Given: 존재하지 않는 파일 경로
        let nonexistentURL = testDirectory.appendingPathComponent("nonexistent.mp4")

        // When & Then: writeFailed 에러 검증
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
     헬퍼 메서드: createTestFile
     ───────────────────────────────────────────────────────────────────────

     【목적】
     테스트용 파일 생성 유틸리티

     【파라미터】
     - name: 파일명
     - content: 파일 내용 (기본값: "test")
     - in: 생성할 디렉토리 (기본값: testDirectory)

     【반환】
     생성된 파일의 URL
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief 테스트용 파일 생성 헬퍼
    ///
    /// @param name 파일명
    /// @param content 파일 내용 (기본값: "test")
    /// @param directory 생성할 디렉토리 (기본값: testDirectory)
    /// @return 생성된 파일의 URL
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
 테스트 실행 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【Xcode에서 실행】

 1. 전체 테스트 실행:
    - ⌘ + U

 2. 특정 테스트 클래스 실행:
    - 클래스 왼쪽의 다이아몬드 아이콘 클릭

 3. 특정 테스트 메서드 실행:
    - 메서드 왼쪽의 다이아몬드 아이콘 클릭

 【터미널에서 실행】

 전체 테스트:
 xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'

 특정 테스트 클래스:
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/FileSystemServiceTests

 특정 테스트 메서드:
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/FileSystemServiceTests/testListVideoFiles_FiltersVideoFilesOnly

 【테스트 커버리지】

 커버리지 포함 테스트 실행:
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -enableCodeCoverage YES

 커버리지 리포트 확인:
 open DerivedData/BlackboxPlayer/Logs/Test/<results>.xcresult

 【CI/CD 통합】

 GitHub Actions:
 - name: Run Tests
   run: xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS'

 ═══════════════════════════════════════════════════════════════════════════
 */
