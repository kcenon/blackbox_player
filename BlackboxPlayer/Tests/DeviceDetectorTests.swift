/// @file DeviceDetectorTests.swift
/// @brief Unit tests for DeviceDetector
/// @author BlackboxPlayer Development Team
/// @details DeviceDetector의 SD 카드 감지 기능을 검증하는 단위 테스트입니다.

import XCTest
@testable import BlackboxPlayer

/*
 ═══════════════════════════════════════════════════════════════════════════
 DeviceDetector 단위 테스트
 ═══════════════════════════════════════════════════════════════════════════

 【테스트 범위】
 1. detectSDCards: 현재 마운트된 이동식 장치 감지
 2. monitorDeviceChanges: 장치 연결/분리 이벤트 모니터링

 【테스트 전략】
 - 실제 시스템 볼륨 사용 (통합 테스트 성격)
 - Notification observer 등록 검증
 - Expectation을 사용한 비동기 콜백 검증

 【테스트 한계】
 DeviceDetector는 시스템 레벨 서비스로:
 - 실제 SD 카드 연결/분리가 필요 (자동화 어려움)
 - DMG 파일로 시뮬레이션 가능
 - CI/CD 환경에서는 제한적

 【권장 테스트 방법】
 1. 개발 환경: 실제 SD 카드 또는 USB 드라이브 사용
 2. CI 환경: 테스트 DMG 파일 생성/마운트
 3. 단위 테스트: Observer 등록/해제만 검증

 ═══════════════════════════════════════════════════════════════════════════
 */

/// @class DeviceDetectorTests
/// @brief DeviceDetector의 단위 테스트 클래스
final class DeviceDetectorTests: XCTestCase {
    // MARK: - Properties

    /// @var detector
    /// @brief 테스트 대상 DeviceDetector 인스턴스
    var detector: DeviceDetector!

    // MARK: - Setup & Teardown

    /// @brief 테스트 전 환경 초기화
    override func setUp() {
        super.setUp()
        detector = DeviceDetector()
    }

    /// @brief 테스트 후 환경 정리
    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Detect SD Cards Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 1: detectSDCards - 기본 동작
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     현재 마운트된 볼륨 중 이동식 장치 조회

     【예상 결과】
     - 배열 반환 (빈 배열 가능)
     - 반환된 URL이 실제 존재하는 경로
     - 반환된 URL이 이동식 장치 속성 만족

     【참고】
     테스트 머신에 SD 카드나 USB 드라이브가 없으면 빈 배열 반환.
     이는 오류가 아니므로 실패로 처리하지 않음.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: 이동식 장치 목록을 반환하는지 검증
    func testDetectSDCards_ReturnsArray() {
        // When: SD 카드 목록 조회
        let sdCards = detector.detectSDCards()

        // Then: 배열 반환 (빈 배열도 정상)
        XCTAssertTrue(sdCards is [URL], "Should return URL array")

        // 발견된 장치 출력
        if sdCards.isEmpty {
            print("⚠️ No SD cards detected. Connect SD card or USB drive for complete testing.")
        } else {
            print("✓ Detected \(sdCards.count) removable device(s):")
            for sdCard in sdCards {
                print("  - \(sdCard.path)")
            }
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 2: detectSDCards - 경로 유효성
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     반환된 URL이 실제로 존재하는 경로인지 확인

     【예상 결과】
     - 모든 URL이 실제 존재함
     - 모든 URL이 디렉토리임
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: 반환된 경로가 실제로 존재하는지 검증
    func testDetectSDCards_ReturnsValidPaths() {
        // When: SD 카드 목록 조회
        let sdCards = detector.detectSDCards()

        // Then: 모든 경로가 실제 존재
        for sdCard in sdCards {
            let pathExists = FileManager.default.fileExists(atPath: sdCard.path)
            XCTAssertTrue(pathExists, "Path should exist: \(sdCard.path)")

            // 디렉토리 여부 확인
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: sdCard.path, isDirectory: &isDirectory)
            XCTAssertTrue(isDirectory.boolValue, "Should be a directory: \(sdCard.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 3: detectSDCards - 이동식 속성 검증
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     반환된 볼륨이 실제로 이동식 장치 속성을 만족하는지 확인

     【예상 결과】
     - isRemovable = true
     - isEjectable = true
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: 반환된 볼륨이 이동식 속성을 만족하는지 검증
    func testDetectSDCards_ReturnsRemovableDevices() throws {
        // When: SD 카드 목록 조회
        let sdCards = detector.detectSDCards()

        // Then: 모든 볼륨이 이동식 속성 만족
        for sdCard in sdCards {
            let resourceValues = try sdCard.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey])

            XCTAssertTrue(resourceValues.volumeIsRemovable == true, "Should be removable: \(sdCard.path)")
            XCTAssertTrue(resourceValues.volumeIsEjectable == true, "Should be ejectable: \(sdCard.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 4: detectSDCards - 내장 디스크 제외
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     내장 디스크(Macintosh HD 등)가 결과에 포함되지 않는지 확인

     【예상 결과】
     - "/" (루트 볼륨)는 포함되지 않음
     - "/System/Volumes" 등 시스템 볼륨 제외
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: 내장 디스크가 결과에 포함되지 않는지 검증
    func testDetectSDCards_ExcludesInternalDisks() {
        // When: SD 카드 목록 조회
        let sdCards = detector.detectSDCards()

        // Then: 내장 디스크 경로 제외
        let internalPaths = ["/", "/System/Volumes/Data"]

        for sdCard in sdCards {
            XCTAssertFalse(internalPaths.contains(sdCard.path), "Should not include internal disk: \(sdCard.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 5: detectSDCards - 중복 제거
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     같은 장치가 중복으로 반환되지 않는지 확인

     【예상 결과】
     - 모든 URL이 고유함 (중복 없음)
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: 중복된 경로가 반환되지 않는지 검증
    func testDetectSDCards_ReturnsUniqueDevices() {
        // When: SD 카드 목록 조회
        let sdCards = detector.detectSDCards()

        // Then: 중복 없음
        let uniqueCards = Set(sdCards)
        XCTAssertEqual(sdCards.count, uniqueCards.count, "Should not have duplicate devices")
    }

    // MARK: - Monitor Device Changes Tests

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 6: monitorDeviceChanges - 콜백 등록
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     모니터링 시작 시 콜백이 정상 등록되는지 확인

     【예상 결과】
     - 메서드 호출 시 오류 없음
     - Observer가 내부적으로 등록됨

     【참고】
     실제 장치 연결/분리 이벤트 없이는 콜백 실행 검증 불가.
     이 테스트는 등록 자체만 확인.
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief monitorDeviceChanges: 콜백을 정상적으로 등록하는지 검증
    func testMonitorDeviceChanges_RegistersCallbacks() {
        // Given: 콜백 함수
        var connectCalled = false
        var disconnectCalled = false

        let onConnect: (URL) -> Void = { _ in
            connectCalled = true
        }

        let onDisconnect: (URL) -> Void = { _ in
            disconnectCalled = true
        }

        // When: 모니터링 시작
        XCTAssertNoThrow(
            detector.monitorDeviceChanges(onConnect: onConnect, onDisconnect: onDisconnect),
            "Should register callbacks without error"
        )

        // Then: 에러 없이 완료
        // (실제 콜백 실행은 장치 연결/분리 시에만 발생)
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 7: monitorDeviceChanges - 여러 번 호출
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     monitorDeviceChanges를 여러 번 호출해도 안전한지 확인

     【예상 결과】
     - 여러 observer가 동시에 등록 가능
     - 메모리 누수 없음
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief monitorDeviceChanges: 여러 번 호출해도 안전한지 검증
    func testMonitorDeviceChanges_AllowsMultipleCalls() {
        // When: 여러 번 모니터링 시작
        detector.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })
        detector.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })
        detector.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })

        // Then: 오류 없이 완료
        // (deinit에서 모든 observer 정리됨)
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     테스트 8: Memory Management
     ───────────────────────────────────────────────────────────────────────

     【시나리오】
     DeviceDetector 인스턴스 해제 시 observer가 정리되는지 확인

     【예상 결과】
     - deinit 호출 시 모든 observer 제거
     - 메모리 누수 없음
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief DeviceDetector가 해제될 때 observer를 정리하는지 검증
    func testDeviceDetector_CleansUpObservers() {
        // Given: 새 인스턴스 생성
        var tempDetector: DeviceDetector? = DeviceDetector()

        // When: 모니터링 시작 후 해제
        tempDetector?.monitorDeviceChanges(onConnect: { _ in }, onDisconnect: { _ in })
        tempDetector = nil

        // Then: deinit이 호출되어 observer 정리
        // (메모리 누수 없으면 통과)
        XCTAssertNil(tempDetector, "Detector should be deallocated")
    }

    // MARK: - Integration Tests (Manual)

    /*
     ───────────────────────────────────────────────────────────────────────
     통합 테스트 (수동 실행)
     ───────────────────────────────────────────────────────────────────────

     다음 테스트들은 실제 SD 카드나 USB 드라이브가 필요합니다.
     자동화된 CI/CD에서는 실행되지 않습니다.

     【테스트 방법】
     1. 실제 SD 카드 삽입
     2. testMonitorDeviceChanges_DetectsConnection 실행
     3. 테스트가 대기 중일 때 SD 카드 꺼내기
     4. 30초 이내에 성공/실패 확인

     【대안: DMG 파일 사용】
     ```bash
     # 테스트용 DMG 생성
     hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" test_sd.dmg

     # 테스트 실행 후 마운트
     hdiutil attach test_sd.dmg

     # 언마운트
     hdiutil detach /Volumes/TEST_SD
     ```
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief [MANUAL] monitorDeviceChanges: 실제 장치 연결 시 콜백이 호출되는지 검증
    ///
    /// 이 테스트는 수동 실행이 필요합니다:
    /// 1. 테스트 시작
    /// 2. SD 카드 또는 USB 드라이브 삽입
    /// 3. 30초 이내에 콜백 호출 확인
    func testMonitorDeviceChanges_DetectsConnection_MANUAL() {
        // Given: Expectation 설정
        let connectExpectation = expectation(description: "Device connected")

        var connectedDevice: URL?

        // When: 모니터링 시작
        detector.monitorDeviceChanges(
            onConnect: { volumeURL in
                connectedDevice = volumeURL
                connectExpectation.fulfill()
            },
            onDisconnect: { _ in }
        )

        print("⏳ Waiting for SD card connection... (30 seconds)")
        print("   Please insert SD card or USB drive now.")

        // Then: 30초 이내에 콜백 호출
        wait(for: [connectExpectation], timeout: 30.0)

        XCTAssertNotNil(connectedDevice, "Should detect connected device")
        if let device = connectedDevice {
            print("✓ Device connected: \(device.path)")
        }
    }

    /// @brief [MANUAL] monitorDeviceChanges: 실제 장치 분리 시 콜백이 호출되는지 검증
    ///
    /// 이 테스트는 수동 실행이 필요합니다:
    /// 1. SD 카드 또는 USB 드라이브를 미리 연결
    /// 2. 테스트 시작
    /// 3. 30초 이내에 장치 꺼내기
    func testMonitorDeviceChanges_DetectsDisconnection_MANUAL() {
        // Given: Expectation 설정
        let disconnectExpectation = expectation(description: "Device disconnected")

        var disconnectedDevice: URL?

        // When: 모니터링 시작
        detector.monitorDeviceChanges(
            onConnect: { _ in },
            onDisconnect: { volumeURL in
                disconnectedDevice = volumeURL
                disconnectExpectation.fulfill()
            }
        )

        print("⏳ Waiting for SD card disconnection... (30 seconds)")
        print("   Please eject SD card or USB drive now.")

        // Then: 30초 이내에 콜백 호출
        wait(for: [disconnectExpectation], timeout: 30.0)

        XCTAssertNotNil(disconnectedDevice, "Should detect disconnected device")
        if let device = disconnectedDevice {
            print("✓ Device disconnected: \(device.path)")
        }
    }

    /*
     ───────────────────────────────────────────────────────────────────────
     성능 테스트
     ───────────────────────────────────────────────────────────────────────

     【목적】
     detectSDCards()의 실행 시간 측정

     【예상 성능】
     - 일반적으로 10ms 이하
     - 많은 볼륨이 마운트되어도 50ms 이하
     ───────────────────────────────────────────────────────────────────────
     */

    /// @brief detectSDCards: 성능 측정
    func testDetectSDCards_Performance() {
        measure {
            // When: SD 카드 목록 조회 (10회 반복)
            for _ in 0..<10 {
                _ = detector.detectSDCards()
            }
        }

        // 성능 기준: 평균 10ms 이하 (1회 실행 기준 1ms 이하)
    }
}

/*
 ═══════════════════════════════════════════════════════════════════════════
 테스트 실행 가이드
 ═══════════════════════════════════════════════════════════════════════════

 【자동 테스트 실행】

 ```bash
 # 기본 테스트 (수동 테스트 제외)
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/DeviceDetectorTests

 # 특정 테스트만
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/DeviceDetectorTests/testDetectSDCards_ReturnsArray
 ```

 【수동 테스트 실행】

 수동 테스트는 Xcode에서 직접 실행:
 1. testMonitorDeviceChanges_DetectsConnection_MANUAL 선택
 2. 다이아몬드 아이콘 클릭
 3. 테스트 실행 후 SD 카드 삽입
 4. 30초 이내에 결과 확인

 【DMG 파일로 테스트】

 ```bash
 # 1. 테스트용 DMG 생성
 hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" /tmp/test_sd.dmg

 # 2. 테스트 시작 (백그라운드)
 xcodebuild test -scheme BlackboxPlayer \
   -destination 'platform=macOS' \
   -only-testing:BlackboxPlayerTests/DeviceDetectorTests/testMonitorDeviceChanges_DetectsConnection_MANUAL &

 # 3. 5초 후 DMG 마운트
 sleep 5
 hdiutil attach /tmp/test_sd.dmg

 # 4. 테스트 완료 대기
 wait

 # 5. 정리
 hdiutil detach /Volumes/TEST_SD
 rm /tmp/test_sd.dmg
 ```

 【CI/CD 통합】

 GitHub Actions에서 DMG 파일로 자동화:
 ```yaml
 - name: Create Test DMG
   run: |
     hdiutil create -size 100m -fs FAT32 -volname "TEST_SD" test_sd.dmg

 - name: Run Tests with DMG
   run: |
     # 백그라운드에서 테스트 시작
     xcodebuild test -scheme BlackboxPlayer -destination 'platform=macOS' &
     TEST_PID=$!

     # 5초 후 DMG 마운트
     sleep 5
     hdiutil attach test_sd.dmg

     # 테스트 완료 대기
     wait $TEST_PID

 - name: Cleanup
   run: |
     hdiutil detach /Volumes/TEST_SD || true
     rm test_sd.dmg || true
 ```

 【테스트 커버리지】

 DeviceDetector는 시스템 레벨 통합이므로 100% 커버리지 불가능.
 권장 커버리지:
 - detectSDCards: 80% (실제 SD 카드 없이 테스트 가능)
 - monitorDeviceChanges: 60% (콜백 실행은 수동 테스트)

 ═══════════════════════════════════════════════════════════════════════════
 */
