//
//  ═══════════════════════════════════════════════════════════════════════════
//  EXT4FileSystemTests.swift
//  BlackboxPlayerTests
//
//  📋 프로젝트: BlackboxPlayer
//  🎯 목적: EXT4 파일 시스템 인터페이스 유닛 테스트
//  📝 설명: 블랙박스 SD 카드의 EXT4 파일 시스템 작업을 검증합니다
//
//  ═══════════════════════════════════════════════════════════════════════════
//
//  📚 EXT4 파일 시스템이란?
//  ────────────────────────────────────────────────────────────────────────
//  Linux에서 가장 많이 사용되는 파일 시스템으로, 블랙박스 장치의
//  SD 카드에서 널리 사용됩니다.
//
//  🔍 주요 특징:
//  • 대용량 파일 지원 (최대 16TB)
//  • 저널링 (Journaling) - 데이터 손실 방지
//  • 향상된 성능과 안정성
//  • Linux 커널 2.6.28 이후 기본 파일 시스템
//
//  💾 블랙박스에서의 사용:
//  ```
//  SD 카드 (EXT4)
//  ├── normal/     (일반 주행 영상)
//  ├── event/      (이벤트 영상)
//  └── parking/    (주차 모드 영상)
//  ```
//
//  🧪 이 테스트가 검증하는 것:
//  1. Mount/Unmount 작업
//  2. 파일 읽기/쓰기/삭제
//  3. 디렉토리 생성/탐색
//  4. 경로 정규화
//  5. 에러 처리
//  6. 성능
//  ────────────────────────────────────────────────────────────────────────
//

/// XCTest 프레임워크
///
/// Apple의 공식 유닛 테스트 프레임워크입니다.
///
/// 📚 주요 기능:
/// - XCTestCase: 테스트 케이스 기본 클래스
/// - XCTAssert: 검증 함수들
/// - measure { }: 성능 측정
/// - setUp/tearDown: 테스트 전후 처리
import XCTest

/// @testable import
///
/// 테스트 대상 모듈의 internal 멤버에 접근할 수 있게 합니다.
///
/// 💡 일반 import vs @testable import:
/// ```swift
/// import BlackboxPlayer        // public만 접근 가능
/// @testable import BlackboxPlayer  // internal도 접근 가능
/// ```
///
/// 🎯 필요한 이유:
/// Swift는 기본적으로 다른 모듈의 internal 멤버에 접근할 수 없습니다.
/// 테스트 코드는 internal 구현도 검증해야 하므로 @testable을 사용합니다.
@testable import BlackboxPlayer

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - EXT4 파일 시스템 테스트
// ═══════════════════════════════════════════════════════════════════════════

/// EXT4 파일 시스템 테스트 클래스
///
/// 블랙박스 SD 카드의 EXT4 파일 시스템 인터페이스를 검증합니다.
///
/// 🎯 테스트 범위:
/// ```
/// 1. Mount/Unmount
///    ├── 정상 마운트
///    ├── 중복 마운트 방지
///    ├── 잘못된 장치 경로
///    └── 장치 정보 조회
///
/// 2. 파일 작업
///    ├── 파일 목록 조회
///    ├── 파일 읽기/쓰기
///    ├── 파일 삭제
///    ├── 파일 존재 확인
///    └── 디렉토리 생성
///
/// 3. 경로 처리
///    └── 경로 정규화
///
/// 4. 에러 처리
///    └── 미마운트 상태 작업
///
/// 5. 성능
///    ├── 대량 파일 목록 조회
///    └── 대용량 파일 읽기
/// ```
///
/// 🧪 Mock 객체 사용:
/// 실제 EXT4 파일 시스템 대신 MockEXT4FileSystem을 사용하여
/// 테스트를 빠르고 안정적으로 실행합니다.
///
/// 💡 Mock 객체란?
/// 실제 객체를 흉내내는 테스트용 가짜 객체입니다.
/// - 빠름: 실제 디스크 I/O 없음
/// - 독립적: 외부 의존성 제거
/// - 제어 가능: 다양한 상황 시뮬레이션
final class EXT4FileSystemTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Mock EXT4 파일 시스템
     */
    /**
     * 테스트용 가짜 파일 시스템 객체입니다.
     */
    /**
     *
     * @section ___ext4__________________ 💾 실제 EXT4 파일 시스템 대신 사용하는 이유
     * 1. **속도**: 실제 디스크 I/O 없이 메모리에서 작동
     * 2. **독립성**: 외부 SD 카드나 장치 불필요
     * 3. **재현성**: 동일한 조건으로 테스트 반복 가능
     * 4. **안전성**: 실제 데이터 손상 위험 없음
     */
    /**
     *
     * @section _________implicitly_unwrapped_optional ⚠️ 느낌표(!) - Implicitly Unwrapped Optional
     * setUp에서 반드시 초기화되므로 안전합니다.
     */
    var fileSystem: MockEXT4FileSystem!

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Setup & Teardown
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 각 테스트 실행 전 초기화
     */
    /**
     * XCTest가 각 테스트 메서드 실행 전에 자동으로 호출합니다.
     */
    /**
     *
     * @section _____ 🔄 실행 순서
     * @endcode
     * setUpWithError()
     *   ↓
     * testMountDevice()
     *   ↓
     * tearDownWithError()
     *   ↓
     * setUpWithError()
     *   ↓
     * testMountAlreadyMountedDevice()
     *   ↓
     * tearDownWithError()
     *   ... (각 테스트마다 반복)
     * @endcode
     */
    /**
     *
     * @section throws____ 💡 throws 키워드
     * 초기화 중 에러가 발생하면 테스트를 실패로 처리합니다.
     */
    /**
     *
     * @section ______ 🎯 초기화 내용
     * 1. 부모 클래스의 setUp 호출
     * 2. Mock 파일 시스템 생성
     * 3. 파일 시스템 상태 리셋
     */
    /**
     * ⚙️ reset()의 역할:
     * - 이전 테스트의 영향 제거
     * - 마운트 상태 초기화
     * - 모든 파일 및 디렉토리 삭제
     */
    override func setUpWithError() throws {
        try super.setUpWithError()
        fileSystem = MockEXT4FileSystem()
        fileSystem.reset()
    }

    /**
     * 각 테스트 실행 후 정리
     */
    /**
     * XCTest가 각 테스트 메서드 실행 후에 자동으로 호출합니다.
     */
    /**
     * 🧹 정리 내용:
     * 1. fileSystem을 nil로 설정 (메모리 해제)
     * 2. 부모 클래스의 tearDown 호출
     */
    /**
     *
     * @section ______ 💾 메모리 관리
     * @endcode
     * fileSystem = nil  // ARC가 자동으로 메모리 해제
     * @endcode
     */
    /**
     *
     * @section _____ ⚠️ 순서 주의
     * 자식 클래스의 정리를 먼저 하고,
     * 그 다음 부모 클래스의 tearDown을 호출합니다.
     */
    override func tearDownWithError() throws {
        fileSystem = nil
        try super.tearDownWithError()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Mount/Unmount Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 장치 마운트 테스트
     */
    /**
     * 외부 저장 장치를 시스템에 연결하는 마운트 작업을 검증합니다.
     */
    /**
     *
     * @section ____mount___ 💾 마운트(Mount)란?
     * @endcode
     * 외부 저장 장치를 시스템에 연결하여 사용 가능한 상태로 만드는 것
     */
    /**
     * 🔌 마운트 전:
     * SD 카드 → [연결 안됨] → 시스템
     *           접근 불가능
     */
    /**
     * 🔌 마운트 후:
     * SD 카드 → [연결됨] → 시스템
     *           파일 읽기/쓰기 가능
     * @endcode
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 초기 상태: 마운트되지 않음
     * 2. 장치 마운트 실행
     * 3. 마운트 상태 확인
     */
    /**
     * 🖥️ 실제 장치 경로 예시:
     * - macOS: /dev/disk2s1
     * - Linux: /dev/sdb1
     * - Windows: E:\
     */
    /**
     * @test testMountDevice
     * @brief 💡 isMounted 속성:
     *
     * @details
     *
     * @section ismounted___ 💡 isMounted 속성
     * Boolean 값으로 현재 마운트 상태를 나타냅니다.
     * - true: 마운트됨 (파일 작업 가능)
     * - false: 마운트 안됨 (파일 작업 불가능)
     */
    func testMountDevice() throws {
        /**
         * 초기 상태: 마운트되지 않음
         */
        /**
         * XCTAssertFalse: 조건이 false인지 검증
         */
        XCTAssertFalse(fileSystem.isMounted)

        /**
         * 장치 마운트
         */
        /**
         * /dev/disk2s1: macOS에서 외부 디스크의 첫 번째 파티션
         * - /dev: device (장치) 디렉토리
         * - disk2: 두 번째 디스크 (0부터 시작하므로 세 번째 디스크)
         * - s1: slice 1 (첫 번째 파티션)
         */
        /**
         *
         * @section try____ ⚠️ try 키워드
         * mount()가 실패하면 에러를 던지므로 try로 호출해야 합니다.
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 마운트 상태 확인
         */
        /**
         * XCTAssertTrue: 조건이 true인지 검증
         * 마운트 작업 후 isMounted가 true로 변경되어야 합니다.
         */
        XCTAssertTrue(fileSystem.isMounted)
    }

    /**
     * 이미 마운트된 장치 재마운트 방지 테스트
     */
    /**
     * 이미 마운트된 장치를 다시 마운트하려 할 때
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     * 🚫 왜 중복 마운트를 방지해야 할까?
     * @endcode
     * 1. 데이터 일관성 문제
     *    - 두 마운트 포인트가 동시에 접근 시 충돌
     */
    /**
     * 2. 리소스 낭비
     *    - 중복된 파일 시스템 구조 유지
     */
    /**
     * 3. 예기치 않은 동작
     *    - 어느 마운트 포인트를 사용할지 불명확
     * @endcode
     */
    /**
     * ⚙️ XCTAssertThrowsError:
     * 코드가 에러를 던지는지 검증하는 함수입니다.
     */
    /**
     * @test testMountAlreadyMountedDevice
     * @brief 📝 사용 패턴:
     *
     * @details
     *
     * @section _____ 📝 사용 패턴
     * @endcode
     * XCTAssertThrowsError(try 에러를_던질_코드) { error in
     *     // 던져진 에러를 검사
     * }
     * @endcode
     */
    func testMountAlreadyMountedDevice() throws {
        /**
         * 첫 번째 마운트 (성공해야 함)
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 두 번째 마운트 시도 (실패해야 함)
         */
        /**
         * 📌 에러 검증:
         * 1. mount()가 에러를 던지는지 확인
         * 2. 던져진 에러가 EXT4Error.alreadyMounted인지 확인
         */
        /**
         *
         * @section as_____ 💡 as? 연산자
         * 타입 캐스팅을 시도하고 실패하면 nil을 반환합니다.
         * - error as? EXT4Error: error를 EXT4Error로 변환 시도
         */
        XCTAssertThrowsError(try fileSystem.mount(devicePath: "/dev/disk2s1")) { error in
            XCTAssertEqual(error as? EXT4Error, EXT4Error.alreadyMounted)
        }
    }

    /**
     * 잘못된 장치 경로 마운트 테스트
     */
    /**
     * 존재하지 않거나 잘못된 형식의 장치 경로로 마운트 시도 시
     * 에러가 발생하는지 검증합니다.
     */
    /**
     * 🚫 잘못된 경로의 예:
     * @endcode
     * "invalid/path"      → 형식 오류
     * "/dev/nonexistent"  → 존재하지 않는 장치
     * "/home/user/file"   → 일반 파일 (장치 아님)
     * ""                  → 빈 경로
     * @endcode
     */
    /**
     *
     * @section ______ 🎯 테스트 목적
     * 시스템이 잘못된 입력을 적절히 처리하는지 확인합니다.
     * 이는 프로그램의 안정성과 보안에 중요합니다.
     */
    /**
     * @test testMountInvalidDevice
     * @brief 💡 입력 검증의 중요성:
     *
     * @details
     *
     * @section __________ 💡 입력 검증의 중요성
     * - 프로그램 크래시 방지
     * - 보안 취약점 방지
     * - 명확한 에러 메시지 제공
     */
    func testMountInvalidDevice() throws {
        /**
         * 잘못된 형식의 장치 경로로 마운트 시도
         */
        /**
         * "invalid/path"는 유효한 장치 경로 형식이 아닙니다.
         * (보통 /dev/로 시작해야 함)
         */
        /**
         * 에러를 던지면 테스트 성공
         */
        XCTAssertThrowsError(try fileSystem.mount(devicePath: "invalid/path"))
    }

    /**
     * 장치 언마운트 테스트
     */
    /**
     * 마운트된 장치를 안전하게 분리하는 언마운트 작업을 검증합니다.
     */
    /**
     *
     * @section _____unmount___ 💾 언마운트(Unmount)란?
     * @endcode
     * 마운트된 장치를 시스템에서 안전하게 분리하는 것
     */
    /**
     * 🔌 언마운트 과정:
     * 1. 버퍼의 모든 데이터를 디스크에 기록 (flush)
     * 2. 열린 파일 핸들 모두 닫기
     * 3. 파일 시스템 메타데이터 업데이트
     * 4. 장치 연결 해제
     * @endcode
     */
    /**
     *
     * @section ____________ ⚠️ 언마운트가 중요한 이유
     * - 데이터 손실 방지: 버퍼의 데이터가 기록되지 않으면 손실
     * - 파일 시스템 손상 방지: 쓰기 중인 파일이 있으면 손상 가능
     * - 리소스 정리: 열린 파일 핸들 및 메모리 해제
     */
    /**
     * @test testUnmountDevice
     * @brief 🎯 테스트 시나리오:
     *
     * @details
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 언마운트 실행
     * 3. 마운트 상태 확인 (false여야 함)
     */
    func testUnmountDevice() throws {
        /**
         * 마운트 후 언마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")
        try fileSystem.unmount()

        /**
         * 언마운트 상태 확인
         */
        /**
         * 언마운트 후 isMounted는 false가 되어야 합니다.
         */
        XCTAssertFalse(fileSystem.isMounted)
    }

    /**
     * 마운트되지 않은 상태에서 언마운트 시도 테스트
     */
    /**
     * 마운트되지 않은 상태에서 언마운트를 시도할 때
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     * 🚫 왜 에러를 발생시켜야 할까?
     * @endcode
     * 1. 논리적 오류 감지
     *    - 프로그램 로직에 문제가 있음을 알림
     */
    /**
     * 2. 명확한 상태 표시
     *    - "마운트되지 않음" 상태를 명확히 전달
     */
    /**
     * 3. 디버깅 용이성
     *    - 문제 발생 지점을 쉽게 파악
     * @endcode
     */
    /**
     * @test testUnmountWhenNotMounted
     * @brief 📝 EXT4Error.notMounted:
     *
     * @details
     *
     * @section ext4error_notmounted 📝 EXT4Error.notMounted
     * 파일 시스템이 마운트되지 않은 상태를 나타내는 에러입니다.
     */
    func testUnmountWhenNotMounted() throws {
        /**
         * 마운트하지 않고 언마운트 시도
         */
        /**
         * 마운트되지 않은 상태에서 unmount()를 호출하면
         * EXT4Error.notMounted 에러를 던져야 합니다.
         */
        XCTAssertThrowsError(try fileSystem.unmount()) { error in
            XCTAssertEqual(error as? EXT4Error, EXT4Error.notMounted)
        }
    }

    /**
     * 장치 정보 조회 테스트
     */
    /**
     * 마운트된 장치의 상세 정보를 조회하는 기능을 검증합니다.
     */
    /**
     *
     * @section ______deviceinfo__________ 📊 장치 정보(DeviceInfo)에 포함되는 내용
     * @endcode
     * 1. devicePath: 장치 경로 (/dev/disk2s1)
     * 2. volumeName: 볼륨 이름 (예: "BLACKBOX_SD")
     * 3. totalSize: 전체 용량 (바이트)
     * 4. freeSpace: 사용 가능한 공간 (바이트)
     * 5. isMounted: 마운트 상태
     * @endcode
     */
    /**
     *
     * @section ________ 💾 용량 정보 활용
     * - 사용 가능한 공간 확인
     * - 녹화 가능 시간 계산
     * - 자동 파일 삭제 트리거
     */
    /**
     * @test testGetDeviceInfo
     * @brief 🎯 검증 항목:
     *
     * @details
     *
     * @section _____ 🎯 검증 항목
     * 1. 장치 경로가 올바른지
     * 2. 볼륨 이름이 존재하는지
     * 3. 전체 용량이 0보다 큰지
     * 4. 사용 가능한 공간이 전체 용량 이하인지
     * 5. 마운트 상태가 true인지
     */
    func testGetDeviceInfo() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 장치 정보 조회
         */
        /**
         * getDeviceInfo()는 DeviceInfo 구조체를 반환합니다.
         */
        let info = try fileSystem.getDeviceInfo()

        /**
         * 장치 정보 검증
         *
         * 1. 장치 경로 확인
         */
        XCTAssertEqual(info.devicePath, "/dev/disk2s1")

        /**
         * 2. 볼륨 이름 존재 확인
         */
        /**
         * XCTAssertNotNil: 값이 nil이 아닌지 검증
         * 볼륨 이름은 선택 사항일 수 있지만, 존재해야 합니다.
         */
        XCTAssertNotNil(info.volumeName)

        /**
         * 3. 전체 용량 확인
         */
        /**
         * XCTAssertGreaterThan: 첫 번째 값이 두 번째 값보다 큰지 검증
         * 전체 용량은 0보다 커야 합니다.
         */
        XCTAssertGreaterThan(info.totalSize, 0)

        /**
         * 4. 사용 가능한 공간 확인
         */
        /**
         * XCTAssertLessThanOrEqual: 첫 번째 값이 두 번째 값 이하인지 검증
         * 사용 가능한 공간은 전체 용량을 초과할 수 없습니다.
         */
        /**
         *
         * @section ______ 💡 논리적 관계
         * freeSpace ≤ totalSize
         */
        XCTAssertLessThanOrEqual(info.freeSpace, info.totalSize)

        /**
         * 5. 마운트 상태 확인
         */
        /**
         * 장치 정보를 조회할 수 있다면 마운트되어 있어야 합니다.
         */
        XCTAssertTrue(info.isMounted)
    }

    /**
     * 마운트되지 않은 상태에서 장치 정보 조회 테스트
     */
    /**
     * 마운트되지 않은 상태에서 장치 정보를 조회하려 할 때
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     * 🚫 왜 에러를 발생시켜야 할까?
     * @endcode
     * 마운트되지 않은 장치는:
     * - 파일 시스템 메타데이터에 접근 불가
     * - 용량 정보 읽기 불가
     * - 볼륨 이름 읽기 불가
     */
    /**
     * 따라서 유효한 정보를 반환할 수 없습니다.
     * @endcode
     */
    /**
     * @test testGetDeviceInfoWhenNotMounted
     * @brief 💡 에러 처리 패턴:
     *
     * @details
     *
     * @section ________ 💡 에러 처리 패턴
     * "작업을 수행할 수 없는 상태"에서는
     * 명확한 에러를 발생시켜 호출자에게 알려야 합니다.
     */
    func testGetDeviceInfoWhenNotMounted() throws {
        /**
         * 마운트하지 않고 정보 조회 시도
         */
        /**
         * 마운트되지 않은 상태에서 getDeviceInfo()를 호출하면
         * EXT4Error.notMounted 에러를 던져야 합니다.
         */
        XCTAssertThrowsError(try fileSystem.getDeviceInfo()) { error in
            XCTAssertEqual(error as? EXT4Error, EXT4Error.notMounted)
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - File Operation Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 파일 목록 조회 테스트
     */
    /**
     * 루트 디렉토리의 파일 및 디렉토리 목록을 조회하는 기능을 검증합니다.
     */
    /**
     * 📁 블랙박스 SD 카드 디렉토리 구조:
     * @endcode
     * / (루트)
     * ├── normal/   (일반 주행 영상)
     * ├── event/    (충격 감지 영상)
     * └── parking/  (주차 모드 영상)
     * @endcode
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 루트 디렉토리의 파일 목록 조회
     * 3. 예상 디렉토리들이 존재하는지 확인
     */
    /**
     *
     * @section listfiles_at_____ 💡 listFiles(at:) 함수
     * - 지정된 경로의 파일 및 디렉토리 목록을 배열로 반환
     * - 빈 문자열("")은 루트 디렉토리를 의미
     */
    /**
     * @test testListFiles
     * @brief 🔍 filter() 메서드:
     *
     * @details
     *
     * @section filter______ 🔍 filter() 메서드
     * Swift의 배열 필터링 함수입니다.
     * @endcode
     * let numbers = [1, 2, 3, 4, 5]
     * let evenNumbers = numbers.filter { $0 % 2 == 0 }  // [2, 4]
     * @endcode
     */
    func testListFiles() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 루트 디렉토리의 파일 목록 조회
         */
        /**
         * at: ""  → 루트 디렉토리
         * 반환값: [FileInfo] 배열
         */
        let files = try fileSystem.listFiles(at: "")

        /**
         * 파일이 하나 이상 존재해야 함
         */
        /**
         * 블랙박스 SD 카드는 최소한 normal, event, parking 디렉토리를 가집니다.
         */
        XCTAssertGreaterThan(files.count, 0)

        /**
         * 예상 디렉토리 확인
         */
        /**
         *
         * @section _____ 📝 처리 과정
         * 1. filter { $0.isDirectory }  → 디렉토리만 필터링
         * 2. map { $0.name }            → 이름만 추출
         */
        /**
         *
         * @section _0___ 💡 $0이란?
         * Swift 클로저의 첫 번째 매개변수를 나타내는 축약 표현입니다.
         * @endcode
         * files.filter { $0.isDirectory }
         * // 위 코드는 아래와 같습니다:
         * files.filter { file in file.isDirectory }
         * @endcode
         */
        let dirNames = files.filter { $0.isDirectory }.map { $0.name }

        /**
         * normal 디렉토리 존재 확인
         */
        /**
         * contains(): 배열에 특정 요소가 있는지 확인
         */
        XCTAssertTrue(dirNames.contains("normal"))

        /**
         * event 디렉토리 존재 확인
         */
        XCTAssertTrue(dirNames.contains("event"))

        /**
         * parking 디렉토리 존재 확인
         */
        XCTAssertTrue(dirNames.contains("parking"))
    }

    /**
     * 디렉토리 내 파일 목록 조회 테스트
     */
    /**
     * 특정 디렉토리(normal) 내의 파일 목록을 조회하고
     * 예상되는 파일 형식들이 존재하는지 검증합니다.
     */
    /**
     * 📁 normal 디렉토리 구조 예시:
     * @endcode
     * normal/
     * ├── 2025_01_10_09_00_00_F.mp4  (전방 영상)
     * ├── 2025_01_10_09_00_00_F.gps  (전방 GPS 데이터)
     * ├── 2025_01_10_09_00_00_R.mp4  (후방 영상)
     * ├── 2025_01_10_09_00_00_R.gps  (후방 GPS 데이터)
     * └── ...
     * @endcode
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * 1. 파일이 하나 이상 존재
     * 2. .mp4 비디오 파일 존재
     * 3. .gps 메타데이터 파일 존재
     */
    /**
     * @test testListFilesInDirectory
     * @brief 💡 hasSuffix() 메서드:
     *
     * @details
     *
     * @section hassuffix______ 💡 hasSuffix() 메서드
     * 문자열이 특정 접미사로 끝나는지 확인합니다.
     * @endcode
     * "video.mp4".hasSuffix(".mp4")  // true
     * "data.gps".hasSuffix(".mp4")   // false
     * @endcode
     */
    func testListFilesInDirectory() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * normal 디렉토리의 파일 목록 조회
         */
        /**
         * at: "normal"  → normal 디렉토리
         */
        let files = try fileSystem.listFiles(at: "normal")

        /**
         * 파일이 하나 이상 존재해야 함
         */
        /**
         * 블랙박스는 지속적으로 녹화하므로 normal 디렉토리에는
         * 항상 비디오 파일과 메타데이터 파일이 존재합니다.
         */
        XCTAssertGreaterThan(files.count, 0)

        /**
         * 비디오 파일 확인
         */
        /**
         * .mp4 확장자를 가진 파일들만 필터링
         */
        /**
         *
         * @section mp4__mpeg_4_part_14_ 📝 MP4 (MPEG-4 Part 14)
         * 가장 널리 사용되는 비디오 컨테이너 형식입니다.
         * - 압축률이 좋음
         * - 다양한 코덱 지원
         * - 대부분의 장치에서 재생 가능
         */
        let videoFiles = files.filter { $0.name.hasSuffix(".mp4") }
        XCTAssertGreaterThan(videoFiles.count, 0)

        /**
         * GPS 파일 확인
         */
        /**
         * .gps 확장자를 가진 파일들만 필터링
         */
        /**
         * 📍 GPS 파일의 역할:
         * - 비디오와 동기화된 GPS 좌표
         * - 타임스탬프
         * - 속도, 방향 등의 메타데이터
         */
        let gpsFiles = files.filter { $0.name.hasSuffix(".gps") }
        XCTAssertGreaterThan(gpsFiles.count, 0)
    }

    /**
     * 파일 읽기 테스트
     */
    /**
     * 파일 시스템에서 파일을 읽어 데이터를 가져오는 기능을 검증합니다.
     */
    /**
     * 📂 파일 경로:
     * "normal/2025_01_10_09_00_00_F.gps"
     */
    /**
     *
     * @section ______ 📝 파일명 규칙
     * @endcode
     * 2025_01_10_09_00_00_F.gps
     * │    │  │  │  │  │  │ └─ 확장자 (gps)
     * │    │  │  │  │  │  └─── 카메라 위치 (F=전방, R=후방)
     * │    │  │  │  │  └────── 초 (00)
     * │    │  │  │  └───────── 분 (00)
     * │    │  │  └──────────── 시 (09)
     * │    │  └─────────────── 일 (10)
     * │    └────────────────── 월 (01)
     * └─────────────────────── 년 (2025)
     * @endcode
     */
    /**
     *
     * @section data___ 💾 Data 타입
     * Swift의 바이트 배열을 나타내는 구조체입니다.
     * - 파일 읽기/쓰기
     * - 네트워크 통신
     * - 이미지/비디오 처리
     */
    /**
     * @test testReadFile
     * @brief 🎯 테스트 시나리오:
     *
     * @details
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. GPS 파일 읽기
     * 3. 데이터가 존재하는지 확인
     */
    func testReadFile() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 파일 읽기
         */
        /**
         * readFile(at:) 함수는 파일의 모든 내용을 Data로 반환합니다.
         */
        /**
         *
         * @section ______ ⚠️ 메모리 주의
         * 큰 파일을 읽을 때는 메모리 사용량에 주의해야 합니다.
         * GPS 파일은 일반적으로 작지만, 비디오 파일은 수백 MB일 수 있습니다.
         */
        let data = try fileSystem.readFile(at: "normal/2025_01_10_09_00_00_F.gps")

        /**
         * 데이터 존재 확인
         */
        /**
         * data.count: 바이트 수
         * GPS 파일에는 위치 정보가 저장되어 있으므로 0보다 커야 합니다.
         */
        XCTAssertGreaterThan(data.count, 0)
    }

    /**
     * 존재하지 않는 파일 읽기 테스트
     */
    /**
     * 존재하지 않는 파일을 읽으려 할 때
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     * 🚫 파일을 찾을 수 없는 경우:
     * @endcode
     * 1. 파일명 오타
     * 2. 경로 오류
     * 3. 파일이 삭제됨
     * 4. 권한 문제
     * @endcode
     */
    /**
     *
     * @section guard_case___ 📝 guard case 패턴
     * Swift의 패턴 매칭을 사용한 에러 검증입니다.
     */
    /**
     * @endcode
     * guard case EXT4Error.fileNotFound = error else {
     *     // error가 fileNotFound가 아니면 실패
     *     XCTFail("Expected fileNotFound error")
     *     return
     * }
     * // error가 fileNotFound면 계속 진행
     * @endcode
     */
    /**
     * @test testReadNonexistentFile
     * @brief 💡 XCTFail():
     *
     * @details
     *
     * @section xctfail__ 💡 XCTFail()
     * 테스트를 명시적으로 실패시키는 함수입니다.
     * 예상한 에러 타입이 아닐 때 사용합니다.
     */
    func testReadNonexistentFile() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 존재하지 않는 파일 읽기 시도
         */
        /**
         * "nonexistent.txt"는 실제로 존재하지 않는 파일입니다.
         */
        XCTAssertThrowsError(try fileSystem.readFile(at: "nonexistent.txt")) { error in
            /**
             * 에러 타입 검증
             */
            ///
            /**
             * guard case: 패턴 매칭으로 에러 타입 확인
             */
            ///
            /**
             *
             * @section _____ 🎯 검증 내용
             * error가 EXT4Error.fileNotFound인지 확인
             * 다른 에러면 XCTFail()로 테스트 실패
             */
            guard case EXT4Error.fileNotFound = error else {
                XCTFail("Expected fileNotFound error")
                return
            }
        }
    }

    /**
     * 파일 쓰기 테스트
     */
    /**
     * 파일 시스템에 새 파일을 생성하고 데이터를 쓰는 기능을 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 파일 쓰기
     * 3. 파일 읽기
     * 4. 읽은 데이터가 쓴 데이터와 일치하는지 확인
     */
    /**
     *
     * @section data_using______ 💾 data(using:) 메서드
     * String을 Data로 변환합니다.
     */
    /**
     * @endcode
     * "Hello".data(using: .utf8)
     * // 결과: Optional<Data> (48 65 6C 6C 6F)
     * //      └─ UTF-8 인코딩된 바이트 배열
     * @endcode
     */
    /**
     *
     * @section utf_8____ 📝 UTF-8 인코딩
     * 가장 널리 사용되는 유니코드 인코딩 방식입니다.
     * - ASCII와 호환
     * - 모든 유니코드 문자 표현 가능
     * - 공간 효율적
     */
    /**
     * @test testWriteFile
     * @brief ⚠️ 느낌표(!) - Force Unwrapping:
     *
     * @details
     *
     * @section _________force_unwrapping ⚠️ 느낌표(!) - Force Unwrapping
     * data(using:)는 Optional을 반환하지만,
     * 유효한 문자열과 UTF-8 인코딩은 항상 성공하므로 안전합니다.
     */
    func testWriteFile() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 테스트 데이터 준비
         */
        /**
         * "Test content"를 UTF-8 인코딩하여 Data로 변환
         */
        /**
         *
         * @section ______ 💡 느낌표(!)
         * Optional을 강제로 벗깁니다.
         * 문자열 → Data 변환은 항상 성공하므로 안전합니다.
         */
        let testData = "Test content".data(using: .utf8)!

        /**
         * 파일 쓰기
         */
        /**
         * writeFile(data:to:) 함수:
         * - data: 쓸 데이터
         * - to: 파일 경로
         */
        /**
         * 파일이 존재하지 않으면 새로 생성됩니다.
         */
        try fileSystem.writeFile(data: testData, to: "test.txt")

        /**
         * 파일 읽어서 검증
         */
        /**
         * 방금 쓴 파일을 다시 읽어서
         * 원본 데이터와 일치하는지 확인합니다.
         */
        let readData = try fileSystem.readFile(at: "test.txt")

        /**
         * 데이터 일치 확인
         */
        /**
         * XCTAssertEqual: 두 값이 같은지 검증
         */
        /**
         * Data 타입은 Equatable을 구현하므로
         * == 연산자로 비교 가능합니다.
         */
        /**
         *
         * @section _________ 🔍 바이트 단위 비교
         * 모든 바이트가 순서대로 일치해야 합니다.
         */
        XCTAssertEqual(readData, testData)
    }

    /**
     * 파일 존재 확인 테스트
     */
    /**
     * 파일이나 디렉토리가 존재하는지 확인하는 기능을 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 존재하는 파일 확인 (true 반환)
     * 3. 존재하지 않는 파일 확인 (false 반환)
     */
    /**
     *
     * @section fileexists_at_____ 💡 fileExists(at:) 함수
     * 파일이나 디렉토리가 존재하면 true, 없으면 false를 반환합니다.
     */
    /**
     *
     * @section _____ 🔍 사용 예시
     * @endcode
     * if fileSystem.fileExists(at: "video.mp4") {
     *     // 파일이 존재하면 읽기
     *     let data = try fileSystem.readFile(at: "video.mp4")
     * } else {
     *     // 파일이 없으면 에러 처리
     *     print("파일을 찾을 수 없습니다")
     * }
     * @endcode
     */
    /**
     * @test testFileExists
     * @brief 📝 에러를 던지지 않는 이유:
     *
     * @details
     *
     * @section _____________ 📝 에러를 던지지 않는 이유
     * - 파일이 없는 것은 에러가 아님 (정상적인 상태)
     * - Boolean 값으로 간단하게 확인 가능
     * - try를 사용하지 않아도 됨
     */
    func testFileExists() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 존재하는 파일 확인
         */
        /**
         * "normal/2025_01_10_09_00_00_F.mp4"는
         * Mock 파일 시스템에 존재하는 비디오 파일입니다.
         */
        /**
         * XCTAssertTrue: 값이 true인지 검증
         * 파일이 존재하므로 true를 반환해야 합니다.
         */
        XCTAssertTrue(fileSystem.fileExists(at: "normal/2025_01_10_09_00_00_F.mp4"))

        /**
         * 존재하지 않는 파일 확인
         */
        /**
         * "nonexistent.txt"는 존재하지 않는 파일입니다.
         */
        /**
         * XCTAssertFalse: 값이 false인지 검증
         * 파일이 없으므로 false를 반환해야 합니다.
         */
        XCTAssertFalse(fileSystem.fileExists(at: "nonexistent.txt"))
    }

    /**
     * 파일 정보 조회 테스트
     */
    /**
     * 파일의 상세 정보(이름, 크기, 타입 등)를 조회하는 기능을 검증합니다.
     */
    /**
     *
     * @section fileinfo_____________ 📊 FileInfo 구조체에 포함되는 정보
     * @endcode
     * 1. name: 파일 또는 디렉토리 이름
     * 2. isDirectory: 디렉토리 여부 (true/false)
     * 3. size: 파일 크기 (바이트)
     * 4. createdAt: 생성 시간 (Optional)
     * 5. modifiedAt: 수정 시간 (Optional)
     * @endcode
     */
    /**
     *
     * @section ________ 💾 파일 크기 단위
     * @endcode
     * 1 KB = 1,024 bytes
     * 1 MB = 1,024 KB = 1,048,576 bytes
     * 1 GB = 1,024 MB = 1,073,741,824 bytes
     */
    /**
     * 예: 블랙박스 1분 영상 = 약 60 MB
     * @endcode
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * 1. 파일 이름이 올바른지
     * 2. 디렉토리가 아닌지 (일반 파일인지)
     * 3. 파일 크기가 0보다 큰지
     */
    /**
     * @test testGetFileInfo
     * @brief 📝 isDirectory 플래그:
     *
     * @details
     *
     * @section isdirectory____ 📝 isDirectory 플래그
     * - true: 디렉토리
     * - false: 일반 파일
     */
    func testGetFileInfo() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 파일 정보 조회
         */
        /**
         * getFileInfo(at:) 함수는 FileInfo 구조체를 반환합니다.
         */
        /**
         *
         * @section ________normal_2025_01_10_09_00_00_f_mp4_ 🎯 조회 대상: "normal/2025_01_10_09_00_00_F.mp4"
         * - 경로: normal 디렉토리
         * - 파일명: 2025_01_10_09_00_00_F.mp4
         * - 타입: 비디오 파일 (전방 카메라)
         */
        let info = try fileSystem.getFileInfo(at: "normal/2025_01_10_09_00_00_F.mp4")

        /**
         * 파일 정보 검증
         *
         * 1. 파일 이름 확인
         */
        /**
         * info.name은 경로를 제외한 파일명만 포함합니다.
         * "normal/2025_01_10_09_00_00_F.mp4" → "2025_01_10_09_00_00_F.mp4"
         */
        XCTAssertEqual(info.name, "2025_01_10_09_00_00_F.mp4")

        /**
         * 2. 파일 타입 확인
         */
        /**
         * XCTAssertFalse: 값이 false인지 검증
         * .mp4는 일반 파일이므로 isDirectory는 false여야 합니다.
         */
        XCTAssertFalse(info.isDirectory)

        /**
         * 3. 파일 크기 확인
         */
        /**
         * 비디오 파일은 크기가 0보다 커야 합니다.
         * 빈 파일(0 bytes)이면 손상되었거나 잘못된 파일입니다.
         */
        XCTAssertGreaterThan(info.size, 0)
    }

    /**
     * 파일 삭제 테스트
     */
    /**
     * 파일을 삭제하는 기능을 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 테스트 파일 생성
     * 3. 파일 존재 확인
     * 4. 파일 삭제
     * 5. 파일이 삭제되었는지 확인
     */
    /**
     * 🗑️ 파일 삭제의 중요성:
     * @endcode
     * 블랙박스에서 파일 삭제는 매우 중요합니다:
     */
    /**
     * 1. 저장 공간 관리
     *    - SD 카드 용량이 가득 차면 오래된 파일 삭제
     *    - 낮은 우선순위 파일부터 삭제
     */
    /**
     * 2. 순환 녹화 (Loop Recording)
     *    - 가장 오래된 normal 영상 삭제
     *    - event와 parking 영상은 보호
     */
    /**
     * 3. 사용자 요청
     *    - 불필요한 영상 수동 삭제
     * @endcode
     */
    /**
     * @test testDeleteFile
     * @brief ⚠️ 삭제 주의사항:
     *
     * @details
     *
     * @section _______ ⚠️ 삭제 주의사항
     * - 삭제된 파일은 복구할 수 없음
     * - 중요한 event 영상은 보호해야 함
     * - 현재 녹화 중인 파일은 삭제하면 안됨
     */
    func testDeleteFile() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 테스트 파일 생성
         */
        /**
         * 삭제 테스트를 위해 임시 파일을 만듭니다.
         * "delete_me.txt"라는 이름으로 "Test" 문자열을 저장합니다.
         */
        let testData = "Test".data(using: .utf8)!
        try fileSystem.writeFile(data: testData, to: "delete_me.txt")

        /**
         * 파일이 생성되었는지 확인
         */
        /**
         * 삭제하기 전에 파일이 실제로 존재하는지 확인합니다.
         * 이 단계가 없으면 삭제가 실패해도 알 수 없습니다.
         */
        XCTAssertTrue(fileSystem.fileExists(at: "delete_me.txt"))

        /**
         * 파일 삭제
         */
        /**
         * deleteFile(at:) 함수로 파일을 삭제합니다.
         */
        /**
         *
         * @section _____ 💾 실제 동작
         * 1. 파일 시스템에서 파일 엔트리 제거
         * 2. 할당된 디스크 공간 해제
         * 3. 메타데이터 업데이트
         */
        try fileSystem.deleteFile(at: "delete_me.txt")

        /**
         * 파일이 삭제되었는지 확인
         */
        /**
         * 삭제 후 fileExists()는 false를 반환해야 합니다.
         */
        /**
         * XCTAssertFalse: 값이 false인지 검증
         * 파일이 삭제되었으므로 false여야 합니다.
         */
        XCTAssertFalse(fileSystem.fileExists(at: "delete_me.txt"))
    }

    /**
     * 디렉토리 생성 테스트
     */
    /**
     * 새로운 디렉토리를 생성하는 기능을 검증합니다.
     */
    /**
     * 📁 디렉토리의 역할:
     * @endcode
     * 디렉토리는 파일을 조직화하는 컨테이너입니다.
     */
    /**
     * 블랙박스 디렉토리 구조:
     * /
     * ├── normal/   ← 일반 주행 영상
     * ├── event/    ← 이벤트 영상 (충격 감지)
     * └── parking/  ← 주차 모드 영상
     * @endcode
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 새 디렉토리 생성
     * 3. 루트 디렉토리 목록 조회
     * 4. 생성된 디렉토리가 목록에 있는지 확인
     */
    /**
     *
     * @section createdirectory_at_____ 💡 createDirectory(at:) 함수
     * 지정된 경로에 새 디렉토리를 생성합니다.
     */
    /**
     *
     * @section mkdir________ 📝 mkdir 명령어와 유사
     * @endcode
     * # Linux/macOS 터미널에서
     * mkdir new_dir
     * @endcode
     */
    /**
     * @test testCreateDirectory
     * @brief ⚙️ 디렉토리 생성 옵션:
     *
     * @details
     * ⚙️ 디렉토리 생성 옵션:
     * - 이미 존재하면 에러
     * - 부모 디렉토리가 없으면 에러
     * - 재귀 생성 (createIntermediateDirectories) 옵션 가능
     */
    func testCreateDirectory() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 디렉토리 생성
         */
        /**
         * "new_dir"이라는 이름의 디렉토리를 루트에 생성합니다.
         */
        /**
         *
         * @section _______ 💾 생성 후 구조
         * @endcode
         * /
         * ├── normal/
         * ├── event/
         * ├── parking/
         * └── new_dir/  ← 새로 생성됨
         * @endcode
         */
        try fileSystem.createDirectory(at: "new_dir")

        /**
         * 루트 디렉토리 목록 조회
         */
        /**
         * 생성된 디렉토리가 실제로 존재하는지 확인하기 위해
         * 루트 디렉토리의 파일 목록을 조회합니다.
         */
        let files = try fileSystem.listFiles(at: "")

        /**
         * 디렉토리 이름 목록 추출
         */
        /**
         * 1. filter { $0.isDirectory }  → 디렉토리만 필터링
         * 2. map { $0.name }            → 이름만 추출
         */
        let dirNames = files.filter { $0.isDirectory }.map { $0.name }

        /**
         * 생성된 디렉토리 확인
         */
        /**
         * "new_dir"이 디렉토리 목록에 포함되어 있어야 합니다.
         */
        /**
         * XCTAssertTrue: 조건이 true인지 검증
         * contains()가 true를 반환하면 테스트 성공
         */
        XCTAssertTrue(dirNames.contains("new_dir"))
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Path Normalization Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 경로 정규화 테스트
     */
    /**
     * 다양한 형식의 경로를 표준 형식으로 변환하는 기능을 검증합니다.
     */
    /**
     * 📂 경로 정규화란?
     * @endcode
     * 다양한 경로 표현을 일관된 표준 형식으로 변환하는 것
     */
    /**
     * 입력 경로                  → 정규화된 경로
     * ────────────────────────────────────────
     * "/test/path/"             → "test/path"
     * "test/path"               → "test/path"
     * "/test/path"              → "test/path"
     * "  /test/path/  "         → "test/path"
     * @endcode
     */
    /**
     *
     * @section ______ 🎯 정규화 규칙
     * 1. 앞뒤 공백 제거 (trim)
     * 2. 앞의 슬래시(/) 제거
     * 3. 뒤의 슬래시(/) 제거
     * 4. 연속된 슬래시(//) 하나로 통일
     */
    /**
     *
     * @section ___________ 💡 정규화가 필요한 이유
     * @endcode
     * // 정규화하지 않으면 같은 경로를 다르게 인식:
     * "test/path"   ≠ "/test/path/"  ❌ 같은 경로인데 다르게 인식
     */
    /**
     * // 정규화 후:
     * "test/path"   == "test/path"   ✅ 올바르게 같다고 인식
     * @endcode
     */
    /**
     * @test testPathNormalization
     * @brief 📝 튜플 배열:
     *
     * @details
     *
     * @section _____ 📝 튜플 배열
     * Swift의 튜플을 사용하여 입력/출력 쌍을 정의합니다.
     * @endcode
     * (input: String, expected: String)
     * └─ 입력값       └─ 기대값
     * @endcode
     */
    func testPathNormalization() {
        /**
         * 테스트 케이스 정의
         */
        /**
         * 각 튜플은 (입력 경로, 예상 결과) 쌍입니다.
         */
        /**
         *
         * @section __________ 📝 테스트 케이스 설명
         * 1. "/test/path/"        → 앞뒤 슬래시 제거
         * 2. "test/path"          → 이미 정규화됨
         * 3. "/test/path"         → 앞 슬래시만 제거
         * 4. "test/path/"         → 뒤 슬래시만 제거
         * 5. "  /test/path/  "    → 공백과 슬래시 모두 제거
         */
        let tests: [(input: String, expected: String)] = [
            ("/test/path/", "test/path"),
            ("test/path", "test/path"),
            ("/test/path", "test/path"),
            ("test/path/", "test/path"),
            ("  /test/path/  ", "test/path")
        ]

        /**
         * 모든 테스트 케이스 실행
         */
        /**
         * for 루프로 각 케이스를 순회하며 검증합니다.
         */
        /**
         *
         * @section test_input__test_expected 💡 test.input과 test.expected
         * 튜플의 레이블을 사용하여 값에 접근합니다.
         */
        for test in tests {
            /**
             * 경로 정규화 실행
             */
            ///
            /**
             * normalizePath() 함수로 입력 경로를 정규화합니다.
             */
            let normalized = fileSystem.normalizePath(test.input)

            /**
             * 결과 검증
             */
            ///
            /**
             * XCTAssertEqual: 두 값이 같은지 검증
             */
            ///
            /**
             *
             * @section _________ 💡 세 번째 매개변수
             * 테스트 실패 시 출력될 메시지입니다.
             * 어떤 입력에서 실패했는지 명확히 알 수 있습니다.
             */
            ///
            /**
             *
             * @section _________string_interpolation_ 📝 문자열 보간법 (String Interpolation)
             * \(변수)를 사용하여 변수 값을 문자열에 삽입합니다.
             */
            XCTAssertEqual(normalized, test.expected,
                          "Failed for input: '\(test.input)'")
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Error Handling Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 마운트되지 않은 상태에서의 작업 테스트
     */
    /**
     * 파일 시스템이 마운트되지 않은 상태에서
     * 모든 파일 작업이 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     * 🚫 마운트되지 않은 상태에서 할 수 없는 작업:
     * @endcode
     * 1. 파일 목록 조회 (listFiles)
     * 2. 파일 읽기 (readFile)
     * 3. 파일 쓰기 (writeFile)
     * 4. 파일 정보 조회 (getFileInfo)
     * 5. 파일 삭제 (deleteFile)
     * 6. 디렉토리 생성 (createDirectory)
     * 7. 파일 존재 확인 (fileExists) → false 반환 (에러 아님)
     * @endcode
     */
    /**
     *
     * @section ______ 🎯 테스트 목적
     * 파일 시스템이 유효하지 않은 상태에서 작업을 시도할 때
     * 프로그램이 크래시하지 않고 명확한 에러를 반환하는지 확인합니다.
     */
    /**
     *
     * @section defensive_programming____________ 💡 Defensive Programming (방어적 프로그래밍)
     * 예상치 못한 상황에서도 안전하게 동작하도록 코드를 작성하는 것
     */
    /**
     * @test testOperationsWhenNotMounted
     * @brief 📝 XCTAssertThrowsError:
     *
     * @details
     *
     * @section xctassertthrowserror 📝 XCTAssertThrowsError
     * 코드가 에러를 던지는지만 확인합니다.
     * 구체적인 에러 타입은 클로저로 검증할 수 있습니다.
     */
    func testOperationsWhenNotMounted() throws {
        /**
         * 모든 파일 작업은 마운트되지 않은 상태에서 실패해야 함
         *
         * 1. 파일 목록 조회
         */
        /**
         * 마운트되지 않으면 파일 시스템에 접근할 수 없으므로
         * 목록을 조회할 수 없습니다.
         */
        XCTAssertThrowsError(try fileSystem.listFiles(at: ""))

        /**
         * 2. 파일 읽기
         */
        /**
         * 파일을 읽으려면 먼저 마운트되어 있어야 합니다.
         */
        XCTAssertThrowsError(try fileSystem.readFile(at: "test.txt"))

        /**
         * 3. 파일 쓰기
         */
        /**
         * Data(): 빈 데이터 객체 생성
         * 마운트되지 않으면 파일을 쓸 수 없습니다.
         */
        XCTAssertThrowsError(try fileSystem.writeFile(data: Data(), to: "test.txt"))

        /**
         * 4. 파일 정보 조회
         */
        /**
         * 파일 메타데이터에 접근하려면 마운트 필요
         */
        XCTAssertThrowsError(try fileSystem.getFileInfo(at: "test.txt"))

        /**
         * 5. 파일 삭제
         */
        /**
         * 마운트되지 않은 상태에서는 파일을 삭제할 수 없습니다.
         */
        XCTAssertThrowsError(try fileSystem.deleteFile(at: "test.txt"))

        /**
         * 6. 디렉토리 생성
         */
        /**
         * 마운트되지 않으면 디렉토리를 만들 수 없습니다.
         */
        XCTAssertThrowsError(try fileSystem.createDirectory(at: "test_dir"))

        /**
         * 7. 파일 존재 확인
         */
        /**
         * XCTAssertFalse: 값이 false인지 검증
         */
        /**
         *
         * @section fileexists______________ 💡 fileExists는 에러를 던지지 않습니다
         * - 마운트되지 않으면 당연히 파일이 없으므로 false 반환
         * - 이는 에러가 아닌 정상적인 동작입니다
         */
        XCTAssertFalse(fileSystem.fileExists(at: "test.txt"))
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Performance Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 대량 파일 목록 조회 성능 테스트
     */
    /**
     * 많은 수의 파일이 있는 디렉토리에서
     * 파일 목록 조회 성능을 측정합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 1,000개의 테스트 파일 생성
     * 3. 파일 목록 조회 성능 측정
     */
    /**
     *
     * @section __________ 📊 성능 측정의 중요성
     * @endcode
     * 블랙박스는 수천 개의 비디오 파일을 저장할 수 있습니다.
     * 파일 목록 조회가 느리면:
     * - UI가 느리게 반응
     * - 사용자 경험 저하
     * - 배터리 소모 증가
     * @endcode
     */
    /**
     * ⚙️ measure { } 블록:
     * XCTest가 제공하는 성능 측정 도구입니다.
     */
    /**
     *
     * @section _____ 💡 작동 방식
     * @endcode
     * 1. 블록을 10번 실행
     * 2. 평균 실행 시간 계산
     * 3. 표준 편차 계산
     * 4. 기준값과 비교 (baseline)
     * @endcode
     */
    /**
     *
     * @section ________ 📈 성능 기준 설정
     * - 첫 실행 시: 현재 성능을 기준(baseline)으로 저장
     * - 이후 실행: 기준과 비교하여 성능 저하 감지
     */
    /**
     * @test testListManyFilesPerformance
     * @brief 🔢 테스트 파일 생성:
     *
     * @details
     * 🔢 테스트 파일 생성:
     * @endcode
     * for i in 0..<1000 {  // 0부터 999까지
     *     Data(count: 100)  // 100바이트 데이터
     *     "test/file_\(i).dat"  // file_0.dat, file_1.dat, ...
     * }
     * @endcode
     */
    func testListManyFilesPerformance() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 많은 테스트 파일 추가
         */
        /**
         *
         * @section for______ 📝 for 루프 분석
         * - 0..<1000: 0부터 999까지 (1000개)
         * - Data(count: 100): 100바이트 크기의 데이터
         * - file_\(i).dat: 파일명에 인덱스 포함
         */
        /**
         *
         * @section _______ 💾 생성되는 파일
         * @endcode
         * test/
         * ├── file_0.dat
         * ├── file_1.dat
         * ├── file_2.dat
         * ...
         * └── file_999.dat
         * @endcode
         */
        /**
         *
         * @section addtestfile__ 🎯 addTestFile()
         * Mock 파일 시스템에 테스트용 파일을 추가하는 함수입니다.
         * 실제 디스크에 쓰지 않고 메모리에만 저장합니다.
         */
        for i in 0..<1000 {
            let data = Data(count: 100)
            fileSystem.addTestFile(path: "test/file_\(i).dat", data: data)
        }

        /**
         * 성능 측정
         */
        /**
         * measure { } 블록 안의 코드를 여러 번 실행하여
         * 평균 실행 시간을 측정합니다.
         */
        /**
         *
         * @section _____ 📊 측정 결과
         * - Average: 평균 실행 시간
         * - Standard Deviation: 표준 편차
         * - Relative Standard Deviation: 상대 표준 편차
         */
        /**
         *
         * @section try_ 💡 try?
         * 에러가 발생해도 무시하고 nil을 반환합니다.
         * 성능 측정이 목적이므로 결과값은 사용하지 않습니다.
         */
        /**
         * 💭 _ = ...:
         * 반환값을 사용하지 않음을 명시적으로 표시합니다.
         * 컴파일러 경고를 방지합니다.
         */
        measure {
            _ = try? fileSystem.listFiles(at: "test")
        }
    }

    /**
     * 대용량 파일 읽기 성능 테스트
     */
    /**
     * 큰 파일(10MB)을 읽는 성능을 측정합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 장치 마운트
     * 2. 10MB 크기의 테스트 파일 생성
     * 3. 파일 읽기 성능 측정
     */
    /**
     *
     * @section 10mb_______ 💾 10MB 파일의 의미
     * @endcode
     * 블랙박스 비디오 파일 크기:
     * - 1분 영상: 약 60 MB
     * - 10초 영상: 약 10 MB
     */
    /**
     * 따라서 10MB는 실제 사용 시나리오를 잘 반영합니다.
     * @endcode
     */
    /**
     *
     * @section ______ 📈 성능 중요성
     * @endcode
     * 파일 읽기가 느리면:
     * - 비디오 재생 시작이 지연
     * - 버퍼링 발생
     * - 사용자 경험 저하
     * @endcode
     */
    /**
     * 🔢 크기 계산:
     * @endcode
     * 10 * 1024 * 1024
     * └─ 10    └─ KB   └─ MB
     */
    /**
     * 계산 과정:
     * 1 KB = 1,024 bytes
     * 1 MB = 1,024 KB = 1,048,576 bytes
     * 10 MB = 10,485,760 bytes
     * @endcode
     */
    /**
     * @test testReadLargeFilePerformance
     * @brief ⚠️ 메모리 주의:
     *
     * @details
     *
     * @section ______ ⚠️ 메모리 주의
     * 10MB 파일을 메모리에 전체로 로드하므로
     * 메모리 사용량이 증가합니다.
     * 실제 앱에서는 스트리밍 방식을 고려해야 합니다.
     */
    func testReadLargeFilePerformance() throws {
        /**
         * 장치 마운트
         */
        try fileSystem.mount(devicePath: "/dev/disk2s1")

        /**
         * 대용량 파일 추가 (10MB)
         */
        /**
         *
         * @section _____ 📝 크기 계산
         * 10 * 1024 * 1024 = 10,485,760 bytes = 10 MB
         */
        /**
         * Data(count:):
         * 지정된 크기만큼 0으로 채워진 데이터를 생성합니다.
         */
        /**
         *
         * @section _________________________ 💡 테스트용이므로 실제 비디오 데이터는 아닙니다.
         * 파일 크기만 같으면 I/O 성능 측정에는 충분합니다.
         */
        let largeData = Data(count: 10 * 1024 * 1024)
        fileSystem.addTestFile(path: "large_file.dat", data: largeData)

        /**
         * 성능 측정
         */
        /**
         * 10MB 파일을 읽는 데 걸리는 시간을 측정합니다.
         */
        /**
         *
         * @section _____ 📊 예상 결과
         * - SSD: ~1-5ms
         * - HDD: ~10-50ms
         * - SD 카드: ~50-200ms
         */
        /**
         *
         * @section mock__________________ 💡 Mock 파일 시스템은 메모리 기반이므로
         * 실제 디스크보다 훨씬 빠릅니다.
         */
        measure {
            _ = try? fileSystem.readFile(at: "large_file.dat")
        }
    }
}
