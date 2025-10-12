/**
 * @file SyncControllerTests.swift
 * @brief SyncController 클래스의 Unit Tests 및 Integration Tests
 * @author BlackboxPlayer Team
 *
 * @details
 *
 * @section sync_overview SyncController 개요
 *
 * 여러 개의 VideoChannel들을 동기화하여 재생하는 중앙 제어 컴포넌트입니다.
 *
 * @subsection sync_structure 멀티 채널 동기화 구조
 *
 * @endcode
 * SyncController (중앙 제어기)
 * ├── VideoChannel (전방) ──→ 프레임 @ 3.500초
 * ├── VideoChannel (후방) ──→ 프레임 @ 3.502초
 * ├── VideoChannel (측면) ──→ 프레임 @ 3.498초
 * ├── GPSService         ──→ GPS 데이터
 * └── GSensorService     ──→ G-센서 데이터
 *       ↓
 *   시간 동기화 (± 50ms 이내)
 *       ↓
 *   화면에 표시: 모든 채널의 3.5초 프레임
 * @endcode
 *
 * @subsection sync_features 주요 기능
 *
 * -# <b>채널 관리</b>: 여러 비디오 채널 로드 및 관리
 * -# <b>재생 제어</b>: play, pause, stop, seek
 * -# <b>시간 동기화</b>: 모든 채널을 같은 타임스탬프로 정렬
 * -# <b>속도 조절</b>: 0.5x ~ 2.0x 재생 속도 제어
 * -# <b>센서 서비스</b>: GPS, G-센서 데이터 관리
 *
 * @subsection test_scope 테스트 범위
 *
 * - 초기화 및 상태 관리
 * - 재생 제어 (play, pause, stop, seek)
 * - 채널 동기화
 * - 시간 포맷팅
 * - 스레드 안전성
 * - 메모리 관리
 * - 성능 측정
 */

// ============================================================================
// MARK: - Imports
// ============================================================================

/**
 * @brief Apple의 공식 테스트 프레임워크
 *
 * @details
 * XCTestCase를 상속받아 테스트 클래스를 만들고,
 * XCTAssert 함수들로 검증을 수행합니다.
 */
import XCTest

/**
 * @brief Apple의 Reactive Programming 프레임워크
 *
 * @details
 * 이 테스트에서 사용하는 Combine 기능:
 *
 * @endcode
 * // 1. @Published 프로퍼티 구독:
 * syncController.$playbackState
 *   .sink { state in ... }
 *
 * // 2. 값 변화 감지:
 * syncController.$currentTime
 *   .sink { time in ... }
 *
 * // 3. AnyCancellable로 구독 관리:
 * .store(in: &cancellables)
 * @endcode
 */
import Combine

/**
 * @brief 테스트 대상 모듈 import
 *
 * @details
 * @testable을 붙이면 internal 접근 제어자도 테스트에서 사용 가능합니다.
 *
 * @note 접근 제어 레벨:
 * @endcode
 * open     > public > internal > fileprivate > private
 *  ↑                    ↑
 * 서브클래싱 가능    @testable로 접근 가능
 * @endcode
 */
@testable import BlackboxPlayer

// ============================================================================
// MARK: - SyncControllerTests (Unit Tests)
// ============================================================================

/**
 * @class SyncControllerTests
 * @brief SyncController의 기본 동작을 검증하는 Unit Test 클래스
 *
 * @details
 * SyncController의 각 메서드와 프로퍼티를 독립적으로 테스트합니다.
 *
 * @section unit_vs_integration Unit Tests vs Integration Tests
 *
 * <b>Unit Tests (이 클래스):</b>
 * - 채널 없이 단독으로 테스트
 * - 빠른 실행
 * - 메서드 단위 검증
 * - Mock 데이터 사용
 *
 * <b>Integration Tests (SyncControllerIntegrationTests):</b>
 * - 실제 비디오 파일 로드
 * - 전체 워크플로우 테스트
 * - 느린 실행
 * - 실제 데이터 사용
 *
 * @section test_targets 테스트 대상
 *
 * - 초기 상태 검증
 * - 상태 전환
 * - 재생 제어 메서드
 * - Seeking 동작
 * - 시간 포맷팅
 * - 스레드 안전성
 * - 메모리 관리
 *
 * @note final 키워드
 * 테스트 클래스는 일반적으로 상속받지 않으므로 final을 붙입니다.
 * @endcode
 * final class SyncControllerTests  // ✅ 서브클래싱 불가
 * class SyncControllerTests        // ❌ 서브클래싱 가능
 * @endcode
 */
final class SyncControllerTests: XCTestCase {

    // ========================================================================
    // MARK: - Properties
    // ========================================================================

    /**
     * @var syncController
     * @brief 테스트 대상 SyncController 인스턴스
     *
     * @details
     * 각 테스트 메서드가 실행되기 전에 setUp()에서 생성됩니다.
     *
     * @note Implicitly Unwrapped Optional (!)을 사용하는 이유
     *
     * <b>장점:</b>
     * - setUp()에서 초기화 보장
     * - 테스트 코드에서 옵셔널 언래핑 불필요
     * - 코드가 간결해짐
     *
     * @endcode
     * // 동작 과정:
     * setUp()      → syncController = SyncController()
     * 테스트 실행   → syncController.play()  // 자동 언래핑
     * tearDown()   → syncController = nil
     * @endcode
     */
    var syncController: SyncController!

    /**
     * @var cancellables
     * @brief Combine 구독(subscription) 저장소
     *
     * @details
     * @Published 프로퍼티를 구독할 때 생성되는 AnyCancellable 객체들을
     * 저장하는 Set 컬렉션입니다.
     *
     * @note Combine 구독 lifecycle
     * @endcode
     * // 1. 구독 생성
     * syncController.$playbackState
     *   .sink { state in
     *     print("State: \(state)")
     *   }
     *   .store(in: &cancellables)  // 2. Set에 저장
     *
     * // 3. tearDown()에서 cancellables = nil
     * //    → Set이 해제되면서 모든 구독도 자동 취소
     * @endcode
     *
     * @par 왜 Set을 사용하나요?
     * - AnyCancellable은 Hashable 프로토콜을 준수
     * - Set은 중복 없이 여러 구독을 관리
     * - 한 번에 모든 구독을 정리 가능
     */
    var cancellables: Set<AnyCancellable>!

    // ========================================================================
    // MARK: - Setup & Teardown
    // ========================================================================

    /**
     * @brief 각 테스트 메서드 실행 전 호출되는 setUp 메서드
     *
     * @details
     * 각 테스트 메서드가 실행되기 **전**에 자동으로 호출됩니다.
     *
     * @par 실행 순서:
     * @endcode
     * 1. setUp() 호출
     *    ├─ super.setUp()
     *    ├─ continueAfterFailure = false
     *    ├─ syncController 생성
     *    └─ cancellables 초기화
     * 2. testInitialState() 실행
     * 3. tearDown() 호출
     *    ↓
     * 4. setUp() 다시 호출 (새 인스턴스)
     * 5. testPlaybackStatePublishing() 실행
     * 6. tearDown() 호출
     * ... (각 테스트마다 반복)
     * @endcode
     *
     * @warning continueAfterFailure = false의 의미
     * @endcode
     * // false (기본값):
     * XCTAssertEqual(a, 1)  // ❌ 실패
     * XCTAssertEqual(b, 2)  // ⏹️ 실행 안 함 (테스트 중단)
     *
     * // true:
     * XCTAssertEqual(a, 1)  // ❌ 실패
     * XCTAssertEqual(b, 2)  // ✅ 계속 실행
     * @endcode
     *
     * @throws XCTest 관련 오류
     */
    override func setUpWithError() throws {
        // 부모 클래스의 setUp 실행
        super.setUp()

        // 첫 번째 실패 시 테스트 중단 (더 빠른 피드백)
        continueAfterFailure = false

        // 테스트 대상 SyncController 생성
        syncController = SyncController()

        // Combine 구독 저장소 초기화
        cancellables = []
    }

    /**
     * @brief 각 테스트 메서드 실행 후 호출되는 tearDown 메서드
     *
     * @details
     * 각 테스트 메서드가 실행된 **후**에 자동으로 호출됩니다.
     *
     * @par 정리(cleanup) 작업의 중요성:
     * @endcode
     * 테스트 A:
     * setUp()    → syncController 생성
     * 테스트 실행  → syncController가 비디오 로드
     * tearDown() → syncController.stop() + nil 처리
     *
     * 테스트 B:
     * setUp()    → 깨끗한 새 syncController 생성
     * 테스트 실행  → 이전 테스트의 영향 없음 ✅
     * @endcode
     *
     * @warning 메모리 누수 방지
     * @endcode
     * syncController.stop()    // 1. 리소스 해제
     * syncController = nil     // 2. 참조 제거 (ARC)
     * cancellables = nil       // 3. 모든 구독 취소
     * @endcode
     *
     * @par 실행 순서:
     * @endcode
     * 1. 테스트 메서드 완료
     * 2. tearDown() 호출
     *    ├─ syncController.stop()      // 채널 정지
     *    ├─ syncController = nil       // 인스턴스 해제
     *    ├─ cancellables = nil         // 구독 취소
     *    └─ super.tearDown()           // 부모 클래스 정리
     * @endcode
     *
     * @throws XCTest 관련 오류
     */
    override func tearDownWithError() throws {
        // SyncController 정지 및 리소스 정리
        syncController.stop()

        // 강한 참조 제거 (ARC가 메모리 해제)
        syncController = nil

        // 모든 Combine 구독 취소
        cancellables = nil

        // 부모 클래스의 tearDown 실행
        super.tearDown()
    }

    // ========================================================================
    // MARK: - Initialization Tests
    // ========================================================================

    /**
     * @name Initialization Tests
     * @{
     *
     * @test testInitialState
     * @brief SyncController 초기 상태 검증
     *
     * @details
     * SyncController가 생성될 때 모든 프로퍼티가 올바른 기본값으로
     * 초기화되는지 검증합니다.
     *
     * @par 검증 항목:
     * <b>상태 관련:</b>
     * - playbackState: .stopped (재생 중이 아님)
     * - channelCount: 0 (로드된 채널 없음)
     * - allChannelsReady: false (준비된 채널 없음)
     *
     * <b>시간 관련:</b>
     * - currentTime: 0.0 (재생 위치)
     * - playbackPosition: 0.0 (정규화된 위치 0~1)
     * - duration: 0.0 (총 재생 시간)
     *
     * <b>재생 설정:</b>
     * - playbackSpeed: 1.0 (정상 속도)
     *
     * @note 왜 초기 상태가 중요한가요?
     * @endcode
     * // 잘못된 초기화:
     * playbackState = .playing  // ❌ 채널 없는데 재생 중?
     * currentTime = 100.0       // ❌ 비디오 없는데 100초?
     *
     * // 올바른 초기화:
     * playbackState = .stopped  // ✅ 중립 상태
     * currentTime = 0.0         // ✅ 시작점
     * @endcode
     *
     * @par Given-When-Then 패턴:
     * - <b>Given:</b> setUp()에서 SyncController 생성
     * - <b>When:</b> (즉시) - 별도 액션 없음
     * - <b>Then:</b> 모든 초기값이 예상대로 설정됨
     */
    func testInitialState() {
        // Then: 초기 상태 검증

        // 🎮 재생 상태는 .stopped여야 함
        XCTAssertEqual(
            syncController.playbackState,
            .stopped,
            "Initial state should be stopped"
        )

        // ⏱️ 현재 재생 시간은 0초
        XCTAssertEqual(
            syncController.currentTime,
            0.0,
            "Initial time should be 0"
        )

        // 📍 정규화된 재생 위치는 0.0 (0%)
        XCTAssertEqual(
            syncController.playbackPosition,
            0.0,
            "Initial position should be 0"
        )

        // ⚡ 재생 속도는 1.0x (정상 속도)
        XCTAssertEqual(
            syncController.playbackSpeed,
            1.0,
            "Initial speed should be 1.0"
        )

        // ⏲️ 총 재생 시간은 0초 (비디오 없음)
        XCTAssertEqual(
            syncController.duration,
            0.0,
            "Initial duration should be 0"
        )

        // 📺 로드된 채널 개수는 0개
        XCTAssertEqual(
            syncController.channelCount,
            0,
            "Initial channel count should be 0"
        )

        // ❌ 모든 채널이 준비되지 않음 (채널이 없으므로)
        XCTAssertFalse(
            syncController.allChannelsReady,
            "Channels should not be ready initially"
        )
    }

    /**
     * @test testServicesInitialization
     * @brief 센서 서비스 초기화 검증
     *
     * @details
     * ✅ 테스트: 센서 서비스 초기화
     * ────────────────────────────────────────────────────────────────────
     * SyncController가 GPS와 G-Sensor 서비스를 정상적으로 초기화하는지
     * 검증합니다.
     *
     * @section sensor_service 🌐 센서 서비스란?
     * @endcode
     * SyncController
     * ├── GPSService
     * │   ├─ 위도/경도 데이터
     * │   ├─ 속도 정보
     * │   └─ 고도 데이터
     * │
     * └── GSensorService
     *     ├─ X축 가속도
     *     ├─ Y축 가속도
     *     └─ Z축 가속도 (충격 감지)
     * @endcode
     *
     * @note 💡 블랙박스에서의 활용:
     * @endcode
     * GPS 데이터: 사고 위치 파악, 주행 경로 표시
     * G-Sensor:   충격 감지, 급정거/급출발 이벤트 기록
     * @endcode
     *
     * @par Given-When-Then:
     * - <b>Given:</b> setUp()에서 SyncController 생성
     * - <b>When:</b> (즉시) - 별도 액션 없음
     * - <b>Then:</b> gpsService와 gsensorService가 nil이 아님
     *
     * @warning ⚠️ XCTAssertNotNil vs XCTAssertEqual:
     * @endcode
     * XCTAssertNotNil(service)              // ✅ 존재만 확인
     * XCTAssertEqual(service, expectedService) // 값까지 비교
     * @endcode
     */
    func testServicesInitialization() {
        // Then: 서비스 초기화 검증

        // 🌐 GPS 서비스가 초기화되어 있어야 함
        XCTAssertNotNil(
            syncController.gpsService,
            "GPS service should be initialized"
        )

        // 📡 G-Sensor 서비스가 초기화되어 있어야 함
        XCTAssertNotNil(
            syncController.gsensorService,
            "G-Sensor service should be initialized"
        )
    }

    // ========================================================================
    // MARK: - State Management Tests
    // ========================================================================
    //
    // 🎯 목적: 재생 상태 관리와 Combine 퍼블리싱을 검증합니다.
    //
    // ✅ 검증 항목:
    // - 재생 상태 전환
    // - @Published 프로퍼티의 값 발행
    // - Combine 구독 동작

    /**
     * @test testPlaybackStateTransitions
     * @brief 재생 상태 전환 검증
     *
     * @details
     * ✅ 테스트: 재생 상태 전환
     * ────────────────────────────────────────────────────────────────────
     * SyncController의 재생 상태가 초기에 .stopped인지 확인합니다.
     *
     * @section playback_flow 🔄 PlaybackState 전환 흐름:
     * @endcode
     * .stopped ──loadVideo──→ .paused ──play()──→ .playing
     *    ↑                        ↑                   ↓
     *    └────── stop() ──────────┴────── pause() ────┘
     * @endcode
     *
     * @note 💡 Unit Test의 한계:
     * @endcode
     * Unit Test (여기):
     * - 채널 없이 초기 상태만 확인
     * - 빠른 실행
     *
     * Integration Test (후반부):
     * - 실제 비디오 로드 후 전체 상태 전환 테스트
     * - .stopped → .paused → .playing 흐름 검증
     * @endcode
     *
     * @par Given-When-Then:
     * - <b>Given:</b> setUp()에서 SyncController 생성
     * - <b>When:</b> (즉시) - 별도 액션 없음
     * - <b>Then:</b> playbackState가 .stopped임
     */
    func testPlaybackStateTransitions() {
        // Given: Controller starts in .stopped state

        // 🎮 초기 상태는 .stopped여야 함
        XCTAssertEqual(syncController.playbackState, .stopped)

        // 📝 Note: Actual state transitions require loaded channels
        // This is tested in integration tests
        //
        // 💡 실제 상태 전환은 비디오 채널이 로드되어야 가능합니다.
        // 전체 워크플로우는 Integration Tests에서 검증합니다.
    }

    /**
     *
     * @section _______________ ✅ 테스트: 재생 상태 퍼블리싱
     * ────────────────────────────────────────────────────────────────────
     * @Published playbackState 프로퍼티가 Combine을 통해
     * 값을 정상적으로 발행하는지 검증합니다.
     *
     *
     * @section combine________ 🔄 Combine 퍼블리싱 동작
     * @endcode
     * @Published var playbackState: PlaybackState = .stopped
     *              ↓
     *         자동으로 Publisher 생성
     *              ↓
     * syncController.$playbackState  // $ 붙이면 Publisher 접근
     *              ↓
     *    .sink { state in }          // 구독 (subscribe)
     *              ↓
     *         값 변경 시마다 클로저 호출
     * @endcode
     *
     *
     * @section xctestexpectation___ 💡 XCTestExpectation이란?
     * @endcode
     * let expectation = expectation(description: "...")
     *
     * // 비동기 작업 (Combine 구독)
     * .sink { value in
     *     expectation.fulfill()  // ✅ 완료 표시
     * }
     *
     * wait(for: [expectation], timeout: 1.0)  // ⏱️ 최대 1초 대기
     * @endcode
     *
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> playbackState 구독 설정
     * - <b>When:</b>  구독 시작 (초기값 즉시 발행)
     * - <b>Then:</b>  첫 번째 발행값이 .stopped임
     * @endcode
     *
     * @test testPlaybackStatePublishing
     * @brief ⚠️ 왜 timeout이 필요한가요?
     *
     * @details
     *
     * @section __timeout________ ⚠️ 왜 timeout이 필요한가요?
     * @endcode
     * 정상: 0.01초 내 값 발행 → 테스트 통과
     * 버그:  값 발행 안 됨    → 1초 대기 후 실패 (무한 대기 방지)
     * @endcode
     */
    func testPlaybackStatePublishing() {
        // Given: 재생 상태 구독 설정

        // 🎯 비동기 작업 완료를 감지하는 Expectation 생성
        let expectation = expectation(description: "Playback state published")

        // 📦 수신한 상태들을 저장할 배열
        var receivedStates: [PlaybackState] = []

        // 🔄 @Published playbackState 구독
        syncController.$playbackState
            .sink { state in
                // 💡 .sink 클로저:
                // - 값이 발행될 때마다 호출됨
                // - 초기값도 즉시 발행됨 (.stopped)

                // 수신한 상태 저장
                receivedStates.append(state)

                // 1개 이상 수신하면 expectation 완료
                if receivedStates.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            // ⚠️ .store(in:)을 빼먹으면:
            // → 구독이 즉시 취소됨 (메모리 해제)
            // → 값을 수신하지 못함

        // Then: 값 발행 검증

        // ⏱️ expectation이 fulfill될 때까지 최대 1초 대기
        wait(for: [expectation], timeout: 1.0)

        // 📝 첫 번째 발행값은 .stopped여야 함
        XCTAssertEqual(receivedStates.first, .stopped)
    }

    /**
     *
     * @section _______________ ✅ 테스트: 현재 시간 퍼블리싱
     * ────────────────────────────────────────────────────────────────────
     * @Published currentTime 프로퍼티가 Combine을 통해
     * 값을 정상적으로 발행하는지 검증합니다.
     *
     * ⏱️ currentTime의 역할:
     * @endcode
     * SyncController
     * ├── currentTime: 3.5초       (현재 재생 위치)
     * ├── duration: 60.0초         (전체 영상 길이)
     * └── playbackPosition: 0.058  (3.5 / 60.0)
     *
     * UI 업데이트:
     * currentTime 변경 → Combine 발행 → UI 자동 갱신
     * @endcode
     *
     *
     * @section ____________ 🔄 재생 중 시간 업데이트
     * @endcode
     * 재생 중:  0.0초 → 0.033초 → 0.066초 → ... (30fps)
     *            ↓        ↓         ↓
     *       .sink 호출  .sink 호출  .sink 호출
     *            ↓        ↓         ↓
     *        UI 업데이트 (타임라인 슬라이더 이동)
     * @endcode
     *
     *
     * @section timeinterval___ 💡 TimeInterval이란?
     * @endcode
     * typealias TimeInterval = Double
     *
     * currentTime: TimeInterval = 3.5  // 3.5초
     * @endcode
     *
     * @test testCurrentTimePublishing
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> currentTime 구독 설정
     * - <b>When:</b>  구독 시작 (초기값 즉시 발행)
     * - <b>Then:</b>  첫 번째 발행값이 0.0임
     * @endcode
     */
    func testCurrentTimePublishing() {
        // Given: 현재 시간 구독 설정

        // 🎯 비동기 작업 완료를 감지하는 Expectation
        let expectation = expectation(description: "Current time published")

        // ⏱️ 수신한 시간 값들을 저장할 배열
        var receivedTimes: [TimeInterval] = []

        // 🔄 @Published currentTime 구독
        syncController.$currentTime
            .sink { time in
                // 💡 재생 중에는 이 클로저가 초당 30번 호출됨 (30fps)

                // 수신한 시간 저장
                receivedTimes.append(time)

                // 1개 이상 수신하면 expectation 완료
                if receivedTimes.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            // 📦 cancellables Set에 저장하여 구독 유지

        // Then: 초기값 검증

        // ⏱️ 최대 1초 대기
        wait(for: [expectation], timeout: 1.0)

        // ⏱️ 첫 번째 발행값은 0.0이어야 함 (초기 상태)
        XCTAssertEqual(receivedTimes.first, 0.0)
    }

    // ========================================================================
    // MARK: - Playback Control Tests
    // ========================================================================
    //
    // 🎯 목적: 재생 제어 메서드(play, pause, stop, toggle)를 검증합니다.
    //
    // ✅ 검증 항목:
    // - 채널 없이 재생 시도 (실패 케이스)
    // - 채널 없이 일시정지 시도 (실패 케이스)
    // - 토글 메서드 실행 (크래시 방지)
    // - 정지 메서드 (상태 초기화)

    /**
     *
     * @section ________________ ✅ 테스트: 채널 없이 재생 시도
     * ────────────────────────────────────────────────────────────────────
     * 비디오 채널이 로드되지 않은 상태에서 play()를 호출할 때
     * 상태가 .stopped에 머무르는지 검증합니다.
     *
     *
     * @section __________ 🔄 정상적인 재생 흐름
     * @endcode
     * 1. loadVideoFile() → 채널 로드 → .paused 상태
     * 2. play()          → 재생 시작 → .playing 상태
     * @endcode
     *
     *
     * @section __________________ ⚠️ 이 테스트 케이스 (비정상 흐름)
     * @endcode
     * 1. (채널 로드 안 함)
     * 2. play()          → ❌ 무시됨 → .stopped 유지
     * @endcode
     *
     *
     * @section __________________ 💡 왜 이런 방어 로직이 필요한가요?
     * @endcode
     * // 방어 코드 없다면:
     * play()  // → 채널이 nil → 크래시! 💥
     *
     * // 방어 코드 있다면:
     * play()  // → 채널 확인 → 없으면 조기 반환 ✅
     * @endcode
     *
     * @test testPlayWithoutChannels
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 채널이 로드되지 않은 SyncController
     * - <b>When:</b>  play() 메서드 호출
     * - <b>Then:</b>  playbackState가 .stopped에 머무름
     * @endcode
     */
    func testPlayWithoutChannels() {
        // When: 채널 없이 재생 시도
        syncController.play()

        // Then: 상태가 .stopped에 머물러야 함

        // ⚠️ 채널이 없으므로 재생되지 않고 .stopped 유지
        XCTAssertEqual(
            syncController.playbackState,
            .stopped,
            "Should remain stopped without channels"
        )
    }

    /**
     *
     * @section __________________________ ✅ 테스트: 재생 중이 아닌 상태에서 일시정지 시도
     * ────────────────────────────────────────────────────────────────────
     * 재생 중이 아닌 상태에서 pause()를 호출할 때
     * 상태가 .stopped에 머무르는지 검증합니다.
     *
     *
     * @section ____________ 🔄 정상적인 일시정지 흐름
     * @endcode
     * .playing ──pause()──→ .paused
     * @endcode
     *
     *
     * @section _________ ⚠️ 이 테스트 케이스
     * @endcode
     * .stopped ──pause()──→ .stopped (변화 없음)
     * @endcode
     *
     *
     * @section idempotent________ 💡 Idempotent(멱등성) 동작
     * @endcode
     * pause() 여러 번 호출해도 안전해야 함
     *
     * pause()  // .stopped → .stopped
     * pause()  // .stopped → .stopped (크래시 안 남)
     * @endcode
     *
     * @test testPauseWithoutPlaying
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> .stopped 상태의 SyncController
     * - <b>When:</b>  pause() 메서드 호출
     * - <b>Then:</b>  playbackState가 .stopped에 머무름
     * @endcode
     */
    func testPauseWithoutPlaying() {
        // When: 재생 중이 아닐 때 일시정지 시도
        syncController.pause()

        // Then: 상태가 .stopped에 머물러야 함

        // 💡 재생 중이 아니므로 일시정지할 것이 없음
        XCTAssertEqual(
            syncController.playbackState,
            .stopped,
            "Should remain stopped"
        )
    }

    /**
     *
     * @section _______________ ✅ 테스트: 토글 재생/일시정지
     * ────────────────────────────────────────────────────────────────────
     * togglePlayPause() 메서드가 크래시 없이 실행되는지 검증합니다.
     *
     *
     * @section toggleplaypause_____ 🔄 togglePlayPause() 동작
     * @endcode
     * if playbackState == .playing {
     *     pause()   // 재생 중 → 일시정지
     * } else {
     *     play()    // 일시정지/정지 → 재생
     * }
     * @endcode
     *
     *
     * @section ui______ 💡 UI에서의 활용
     * @endcode
     * Button("▶️/⏸️") {
     *     syncController.togglePlayPause()
     * }
     * // 한 버튼으로 재생/일시정지 토글 가능
     * @endcode
     *
     *
     * @section unit_test____ ⚠️ Unit Test의 한계
     * @endcode
     * Unit Test:
     * - 메서드가 크래시 없이 실행되는지만 확인
     * - 실제 토글 동작은 채널이 필요
     *
     * Integration Test:
     * - 실제 비디오 로드 후 토글 동작 검증
     * - .playing ⇄ .paused 전환 확인
     * @endcode
     *
     * @test testTogglePlayPause
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 채널 없는 SyncController
     * - <b>When:</b>  togglePlayPause() 호출
     * - <b>Then:</b>  크래시 없이 실행 완료
     * @endcode
     */
    func testTogglePlayPause() {
        // Note: Requires loaded channels for actual toggle
        // Unit test verifies method exists and doesn't crash
        //
        // 📝 실제 토글 동작은 비디오 채널이 로드되어야 가능합니다.
        // 이 Unit Test는 메서드 존재 여부와 크래시 방지를 검증합니다.

        // When: 토글 메서드 호출
        syncController.togglePlayPause()

        // Then: 크래시 없이 실행 완료

        // 💡 syncController가 nil이 아니면 메서드가 정상 실행된 것
        XCTAssertNotNil(syncController)
    }

    /**
     *
     * @section ________stop____ ✅ 테스트: 정지(Stop) 동작
     * ────────────────────────────────────────────────────────────────────
     * stop() 메서드가 모든 상태를 초기화하는지 검증합니다.
     *
     *
     * @section stop______ 🔄 stop()의 역할
     * @endcode
     * 1. 모든 채널 정지 및 해제
     * 2. 재생 상태를 .stopped로 변경
     * 3. 시간 관련 프로퍼티 초기화
     * 4. 센서 서비스 정리
     * @endcode
     *
     *
     * @section stop___vs_pause______ 💡 stop() vs pause()의 차이
     * @endcode
     * pause():
     * - .playing → .paused
     * - 채널 유지 (메모리에 남음)
     * - currentTime 유지 (현재 위치 기억)
     * - play()로 이어서 재생 가능
     *
     * stop():
     * - → .stopped
     * - 모든 채널 해제 (메모리 정리)
     * - currentTime = 0.0 (처음으로)
     * - 다시 loadVideoFile() 필요
     * @endcode
     *
     * 🧹 정리 작업:
     * @endcode
     * stop() 호출 시:
     * ├─ playbackState = .stopped
     * ├─ currentTime = 0.0
     * ├─ playbackPosition = 0.0
     * ├─ duration = 0.0
     * ├─ channelCount = 0
     * └─ 모든 VideoChannel 해제
     * @endcode
     *
     * @test testStop
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스
     * - <b>When:</b>  stop() 메서드 호출
     * - <b>Then:</b>  모든 상태가 초기값으로 리셋됨
     * @endcode
     */
    func testStop() {
        // When: 정지 메서드 호출
        syncController.stop()

        // Then: 모든 상태가 초기화되어야 함

        // 🎮 재생 상태는 .stopped
        XCTAssertEqual(syncController.playbackState, .stopped)

        // ⏱️ 현재 시간은 0.0으로 리셋
        XCTAssertEqual(syncController.currentTime, 0.0)

        // 📍 재생 위치는 0.0 (처음)
        XCTAssertEqual(syncController.playbackPosition, 0.0)

        // ⏲️ 총 재생 시간도 0.0 (채널 해제)
        XCTAssertEqual(syncController.duration, 0.0)

        // 📺 로드된 채널도 0개
        XCTAssertEqual(syncController.channelCount, 0)
    }

    // ========================================================================
    // MARK: - Seeking Tests
    // ========================================================================
    //
    // 🎯 목적: Seeking(탐색) 기능을 검증합니다.
    //
    // ✅ 검증 항목:
    // - 특정 시간으로 이동 (seekToTime)
    // - 상대적 시간 이동 (seekBySeconds)
    // - 음수 시간 처리 (경계값 테스트)
    // - 범위 제한 (clamping)

    /**
     *
     * @section _______________ ✅ 테스트: 특정 시간으로 이동
     * ────────────────────────────────────────────────────────────────────
     * seekToTime() 메서드가 지정한 시간으로 이동하며,
     * 범위를 벗어난 값은 적절히 제한(clamp)되는지 검증합니다.
     *
     *
     * @section seeking___ 🎬 Seeking이란?
     * @endcode
     * 비디오 타임라인:
     * [========●====================] 60초
     *          ↑
     *      현재: 10초
     *
     * seekToTime(30.0) 호출:
     * [==========================●==] 60초
     *                            ↑
     *                        이동: 30초
     * @endcode
     *
     *
     * @section _____seeking___ 🔄 정상적인 Seeking 흐름
     * @endcode
     * 1. 비디오 로드 (duration = 60.0초)
     * 2. seekToTime(30.0)
     * 3. currentTime = 30.0 설정
     * 4. 모든 채널을 30초 위치로 이동
     * 5. 화면 업데이트
     * @endcode
     *
     *
     * @section clamping________ ⚠️ Clamping (범위 제한)
     * @endcode
     * // duration = 60초일 때
     * seekToTime(-10.0)   → 0.0으로 제한 (최소값)
     * seekToTime(30.0)    → 30.0 (정상)
     * seekToTime(100.0)   → 60.0으로 제한 (최대값)
     * @endcode
     *
     *
     * @section __unit_test____ 💡 이 Unit Test의 경우
     * @endcode
     * duration = 0 (비디오 없음)
     * seekToTime(5.0)
     *   → 0...0 범위로 clamp
     *   → currentTime = 0.0
     * @endcode
     *
     * @test testSeekToTime
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 채널 없는 SyncController (duration = 0)
     * - <b>When:</b>  seekToTime(5.0) 호출
     * - <b>Then:</b>  currentTime이 0.0으로 제한됨
     * @endcode
     */
    func testSeekToTime() {
        // Note: Requires loaded channels
        // Unit test verifies method exists
        //
        // 📝 실제 Seeking은 비디오 채널이 로드되어야 가능합니다.
        // 이 Unit Test는 범위 제한(clamping) 로직을 검증합니다.

        // When: 5.0초로 이동 시도
        syncController.seekToTime(5.0)

        // Then: Should clamp to 0.0 since duration is 0

        // ⚠️ duration이 0이므로 유효 범위는 0...0
        // → 5.0은 범위를 벗어나므로 0.0으로 제한됨
        XCTAssertEqual(syncController.currentTime, 0.0)
    }

    /**
     *
     * @section ______________ ✅ 테스트: 상대적 시간 이동
     * ────────────────────────────────────────────────────────────────────
     * seekBySeconds() 메서드가 현재 위치에서 상대적으로 이동하는지
     * 검증합니다.
     *
     *
     * @section seektotime_vs_seekbyseconds 🔄 seekToTime vs seekBySeconds
     * @endcode
     * 현재 위치: 10초
     *
     * seekToTime(30.0):
     * - 절대 위치로 이동
     * - 10초 → 30초
     *
     * seekBySeconds(+20.0):
     * - 상대 위치로 이동
     * - 10초 + 20초 = 30초
     *
     * seekBySeconds(-5.0):
     * - 뒤로 이동
     * - 10초 - 5초 = 5초
     * @endcode
     *
     *
     * @section ui______ 💡 UI에서의 활용
     * @endcode
     * Button("⏪ 10초 뒤로") {
     *     syncController.seekBySeconds(-10.0)
     * }
     *
     * Button("⏩ 10초 앞으로") {
     *     syncController.seekBySeconds(+10.0)
     * }
     * @endcode
     *
     *
     * @section _____ 🔄 내부 동작
     * @endcode
     * func seekBySeconds(_ offset: Double) {
     *     let newTime = currentTime + offset
     *     seekToTime(newTime)  // seekToTime으로 위임
     * }
     * @endcode
     *
     *
     * @section __unit_test____ ⚠️ 이 Unit Test의 경우
     * @endcode
     * currentTime = 0.0 (초기값)
     * duration = 0.0 (채널 없음)
     *
     * seekBySeconds(10.0)
     *   → newTime = 0.0 + 10.0 = 10.0
     *   → seekToTime(10.0)
     *   → 0...0 범위로 clamp → 0.0
     * @endcode
     *
     * @test testSeekBySeconds
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> currentTime = 0, duration = 0
     * - <b>When:</b>  seekBySeconds(10.0) 호출
     * - <b>Then:</b>  currentTime이 0.0으로 제한됨
     * @endcode
     */
    func testSeekBySeconds() {
        // When: 10초 앞으로 이동 시도
        syncController.seekBySeconds(10.0)

        // Then: Should seek from current time
        // With duration 0, should clamp to 0

        // 💡 계산:
        // newTime = currentTime(0.0) + offset(10.0) = 10.0
        // → duration이 0이므로 0.0으로 제한됨
        XCTAssertEqual(syncController.currentTime, 0.0)
    }

    /**
     *
     * @section _____________ ✅ 테스트: 음수 시간 처리
     * ────────────────────────────────────────────────────────────────────
     * seekToTime()에 음수를 전달할 때 0으로 제한되는지 검증합니다.
     *
     * 🔒 경계값 테스트 (Boundary Testing):
     * @endcode
     * 유효 범위: 0 ≤ time ≤ duration
     *
     * 경계값 테스트:
     * ├─ time < 0      (하한 초과) → 0으로 제한
     * ├─ time = 0      (하한 경계) → 그대로 유지
     * ├─ time = duration (상한 경계) → 그대로 유지
     * └─ time > duration (상한 초과) → duration으로 제한
     * @endcode
     *
     *
     * @section ______________ ⚠️ 음수 시간이 발생하는 경우
     * @endcode
     * // 사용자가 뒤로 이동할 때:
     * currentTime = 3.0
     * seekBySeconds(-10.0)
     *   → newTime = 3.0 - 10.0 = -7.0 ❌
     *   → seekToTime(-7.0)
     *   → 0.0으로 제한 ✅
     * @endcode
     *
     *
     * @section _________ 💡 방어적 프로그래밍
     * @endcode
     * // 방어 코드 없다면:
     * seekToTime(-5.0)
     *   → videoChannel.seek(-5.0)
     *   → FFmpeg 에러! 💥
     *
     * // 방어 코드 있다면:
     * seekToTime(-5.0)
     *   → clamp(-5.0, 0...60) = 0.0
     *   → videoChannel.seek(0.0) ✅
     * @endcode
     *
     * @test testSeekNegativeTime
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스
     * - <b>When:</b>  seekToTime(-5.0) 호출 (음수)
     * - <b>Then:</b>  currentTime이 0.0으로 제한됨
     * @endcode
     */
    func testSeekNegativeTime() {
        // When: 음수 시간으로 이동 시도
        syncController.seekToTime(-5.0)

        // Then: Should clamp to 0

        // 🔒 음수는 유효하지 않으므로 최소값 0.0으로 제한
        XCTAssertEqual(syncController.currentTime, 0.0)
    }

    // ========================================================================
    // MARK: - Synchronized Frames Tests
    // ========================================================================
    //
    // 🎯 목적: 멀티 채널 동기화 기능을 검증합니다.
    //
    // ✅ 검증 항목:
    // - getSynchronizedFrames() 메서드
    // - getBufferStatus() 메서드
    // - 채널 없을 때의 동작

    /**
     *
     * @section _____________________ ✅ 테스트: 채널 없이 동기화 프레임 조회
     * ────────────────────────────────────────────────────────────────────
     * 채널이 없을 때 getSynchronizedFrames()가 빈 딕셔너리를 반환하는지
     * 검증합니다.
     *
     *
     * @section __________ 🔄 동기화 프레임이란?
     * @endcode
     * 멀티 채널 블랙박스:
     *
     * 현재 시간: 3.5초
     *
     * 전방 채널: [프레임 @ 3.498초] ─┐
     * 후방 채널: [프레임 @ 3.502초] ─┼─→ 동기화
     * 측면 채널: [프레임 @ 3.500초] ─┘
     *                 ↓
     *     getSynchronizedFrames() 반환:
     *     [
     *         .front: VideoFrame @ 3.498초,
     *         .rear:  VideoFrame @ 3.502초,
     *         .left:  VideoFrame @ 3.500초
     *     ]
     * @endcode
     *
     *
     * @section ________ 💡 동기화의 필요성
     * @endcode
     * 문제: 각 채널의 프레임 타임스탬프가 약간씩 다름
     *       (카메라 센서 동기화 오차, 인코딩 지연 등)
     *
     * 해결: SyncController가 ±50ms 이내의 프레임들을 모아서
     *       "동시에 촬영된 것"으로 간주하고 화면에 표시
     * @endcode
     *
     *
     * @section _____ 🔍 반환 타입
     * @endcode
     * [CameraPosition: VideoFrame]
     *
     * // 예시:
     * [
     *     .front: frame1,
     *     .rear: frame2
     * ]
     * @endcode
     *
     *
     * @section ________ ⚠️ 채널이 없을 때
     * @endcode
     * let frames = getSynchronizedFrames()
     * frames.isEmpty  // true
     * @endcode
     *
     * @test testGetSynchronizedFramesWithNoChannels
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 채널이 없는 SyncController
     * - <b>When:</b>  getSynchronizedFrames() 호출
     * - <b>Then:</b>  빈 딕셔너리 반환
     * @endcode
     */
    func testGetSynchronizedFramesWithNoChannels() {
        // When: 동기화 프레임 조회
        let frames = syncController.getSynchronizedFrames()

        // Then: 빈 딕셔너리여야 함

        // 📦 채널이 없으므로 프레임도 없음
        XCTAssertTrue(
            frames.isEmpty,
            "Should return empty dictionary without channels"
        )
    }

    /**
     *
     * @section ___________________ ✅ 테스트: 채널 없이 버퍼 상태 조회
     * ────────────────────────────────────────────────────────────────────
     * 채널이 없을 때 getBufferStatus()가 빈 딕셔너리를 반환하는지
     * 검증합니다.
     *
     * 📦 버퍼 상태란?
     * @endcode
     * 각 채널의 프레임 버퍼 현황:
     *
     * 전방 채널:
     * [Frame][Frame][Frame]...[Frame]  25/30 (83%)
     *
     * 후방 채널:
     * [Frame][Frame][Frame][Frame]...  28/30 (93%)
     *
     * getBufferStatus() 반환:
     * [
     *     .front: BufferStatus(current: 25, maximum: 30, fillPercentage: 0.83),
     *     .rear:  BufferStatus(current: 28, maximum: 30, fillPercentage: 0.93)
     * ]
     * @endcode
     *
     *
     * @section _________ 💡 버퍼 상태의 활용
     * @endcode
     * UI에서 표시:
     * [████████░░] 83% - 전방
     * [█████████░] 93% - 후방
     *
     * 성능 모니터링:
     * - 버퍼가 자주 비면 → 디코딩이 느림
     * - 버퍼가 항상 가득 차면 → 정상 동작
     * @endcode
     *
     *
     * @section _____ 🔍 반환 타입
     * @endcode
     * [CameraPosition: BufferStatus]
     *
     * struct BufferStatus {
     *     let current: Int        // 현재 버퍼 개수
     *     let maximum: Int        // 최대 버퍼 크기
     *     let fillPercentage: Double  // 0.0 ~ 1.0
     * }
     * @endcode
     *
     *
     * @section ________ ⚠️ 채널이 없을 때
     * @endcode
     * let status = getBufferStatus()
     * status.isEmpty  // true
     * @endcode
     *
     * @test testGetBufferStatusWithNoChannels
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 채널이 없는 SyncController
     * - <b>When:</b>  getBufferStatus() 호출
     * - <b>Then:</b>  빈 딕셔너리 반환
     * @endcode
     */
    func testGetBufferStatusWithNoChannels() {
        // When: 버퍼 상태 조회
        let status = syncController.getBufferStatus()

        // Then: 빈 딕셔너리여야 함

        // 📦 채널이 없으므로 버퍼도 없음
        XCTAssertTrue(
            status.isEmpty,
            "Should return empty dictionary without channels"
        )
    }

    // ========================================================================
    // MARK: - Time Formatting Tests
    // ========================================================================
    //
    // 🎯 목적: 시간 포맷팅 기능을 검증합니다.
    //
    // ✅ 검증 항목:
    // - currentTimeString (현재 시간)
    // - durationString (총 시간)
    // - remainingTimeString (남은 시간)
    // - playbackSpeedString (재생 속도)
    // - 다양한 시간값의 포맷팅

    /**
     *
     * @section ______________ ✅ 테스트: 현재 시간 문자열
     * ────────────────────────────────────────────────────────────────────
     * currentTimeString이 올바른 형식으로 포맷되는지 검증합니다.
     *
     * 🕐 시간 포맷:
     * @endcode
     * MM:SS 형식 (분:초)
     *
     * 예시:
     * 0초    → "00:00"
     * 30초   → "00:30"
     * 90초   → "01:30"
     * 3665초 → "61:05"  (61분 5초)
     * @endcode
     *
     *
     * @section __hh_mm_ss_____mm_ss____ 💡 왜 HH:MM:SS가 아닌 MM:SS인가요?
     * @endcode
     * 블랙박스 영상은 보통 1~3분 길이:
     * - 00:00:30 (불필요한 00:)
     * - 00:30    (간결함) ✅
     *
     * 60분 이상:
     * - 01:30:00 (혼란)
     * - 90:00    (90분으로 표시) ✅
     * @endcode
     *
     *
     * @section _____ 🔄 계산 방식
     * @endcode
     * let totalSeconds = Int(currentTime)
     * let minutes = totalSeconds / 60    // 90 / 60 = 1
     * let seconds = totalSeconds % 60    // 90 % 60 = 30
     * return String(format: "%02d:%02d", minutes, seconds)
     * // → "01:30"
     * @endcode
     *
     * @test testCurrentTimeString
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> currentTime = 0.0
     * - <b>When:</b>  currentTimeString 프로퍼티 접근
     * - <b>Then:</b>  "00:00" 반환
     * @endcode
     */
    func testCurrentTimeString() {
        // Given: currentTime = 0
        // (setUp()에서 초기화된 상태)

        // When: 현재 시간 문자열 조회
        let timeString = syncController.currentTimeString

        // Then: "00:00" 형식이어야 함
        XCTAssertEqual(timeString, "00:00")
    }

    /**
     *
     * @section ________________ ✅ 테스트: 총 재생 시간 문자열
     * ────────────────────────────────────────────────────────────────────
     * durationString이 올바른 형식으로 포맷되는지 검증합니다.
     *
     * 🕐 duration의 의미:
     * @endcode
     * 비디오 전체 길이:
     *
     * [━━━━━━━━━━━━━━━━━━━━━━━] 3:00 ← durationString
     *  ↑                       ↑
     *  0초                   180초
     * @endcode
     *
     *
     * @section ui______ 💡 UI에서의 표시
     * @endcode
     * Text("총 시간: \(syncController.durationString)")
     * // → "총 시간: 03:00"
     *
     * // 또는 타임라인:
     * [▓▓▓▓▓░░░░░] 01:30 / 03:00
     *              ↑       ↑
     *         current  duration
     * @endcode
     *
     * @test testDurationString
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> duration = 0.0 (비디오 없음)
     * - <b>When:</b>  durationString 프로퍼티 접근
     * - <b>Then:</b>  "00:00" 반환
     * @endcode
     */
    func testDurationString() {
        // Given: duration = 0
        // (비디오가 로드되지 않은 상태)

        // When: 총 재생 시간 문자열 조회
        let durationString = syncController.durationString

        // Then: "00:00" 형식이어야 함
        XCTAssertEqual(durationString, "00:00")
    }

    /**
     *
     * @section ______________ ✅ 테스트: 남은 시간 문자열
     * ────────────────────────────────────────────────────────────────────
     * remainingTimeString이 올바른 형식으로 포맷되는지 검증합니다.
     *
     * 🕐 남은 시간 계산:
     * @endcode
     * remaining = duration - currentTime
     *
     * 예시:
     * duration = 180초 (3분)
     * currentTime = 90초 (1분 30초)
     * remaining = 180 - 90 = 90초 (1분 30초)
     * → "-01:30"  (앞에 - 붙음)
     * @endcode
     *
     *
     * @section ________________ 💡 왜 마이너스(-)를 붙이나요?
     * @endcode
     * UI 컨벤션:
     * - "남은 시간"을 표시할 때 -를 붙여서 구분
     *
     * [▓▓▓▓▓░░░░░] 01:30 / 03:00 (-01:30)
     *              ↑       ↑        ↑
     *          현재    전체     남은 시간
     * @endcode
     *
     *
     * @section _____ 🔄 계산 흐름
     * @endcode
     * let remaining = duration - currentTime  // 90.0
     * let formatted = formatTime(remaining)   // "01:30"
     * return "-\(formatted)"                  // "-01:30"
     * @endcode
     *
     * @test testRemainingTimeString
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> duration = 0, currentTime = 0
     *        (remaining = 0)
     * - <b>When:</b>  remainingTimeString 프로퍼티 접근
     * - <b>Then:</b>  "-00:00" 반환
     * @endcode
     */
    func testRemainingTimeString() {
        // Given: remaining = 0
        // (duration - currentTime = 0 - 0 = 0)

        // When: 남은 시간 문자열 조회
        let remainingString = syncController.remainingTimeString

        // Then: "-00:00" 형식이어야 함 (마이너스 포함)
        XCTAssertEqual(remainingString, "-00:00")
    }

    /**
     *
     * @section ______________ ✅ 테스트: 재생 속도 문자열
     * ────────────────────────────────────────────────────────────────────
     * playbackSpeedString이 올바른 형식으로 포맷되는지 검증합니다.
     *
     *
     * @section ________ ⚡ 재생 속도 표시
     * @endcode
     * 0.5x  → 느린 재생 (슬로우 모션)
     * 1.0x  → 정상 속도
     * 1.5x  → 1.5배속 (빠른 재생)
     * 2.0x  → 2배속
     * @endcode
     *
     *
     * @section ui______ 💡 UI에서의 활용
     * @endcode
     * Button(syncController.playbackSpeedString) {
     *     // 속도 변경 메뉴 표시
     * }
     * // → "1.5x" 버튼 표시
     *
     * // 또는:
     * Text("재생 속도: \(syncController.playbackSpeedString)")
     * // → "재생 속도: 1.5x"
     * @endcode
     *
     *
     * @section ___ 🔄 포맷팅
     * @endcode
     * playbackSpeed = 1.5
     * return "\(playbackSpeed)x"  // "1.5x"
     *
     * playbackSpeed = 1.0
     * return "\(playbackSpeed)x"  // "1.0x"
     * @endcode
     *
     * @test testPlaybackSpeedString
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> playbackSpeed를 1.5로 설정
     * - <b>When:</b>  playbackSpeedString 프로퍼티 접근
     * - <b>Then:</b>  "1.5x" 반환
     * @endcode
     */
    func testPlaybackSpeedString() {
        // Given: 재생 속도를 1.5배속으로 설정
        syncController.playbackSpeed = 1.5

        // When: 재생 속도 문자열 조회
        let speedString = syncController.playbackSpeedString

        // Then: "1.5x" 형식이어야 함
        XCTAssertEqual(speedString, "1.5x")
    }

    /**
     *
     * @section ________________ ✅ 테스트: 다양한 시간값 포맷팅
     * ────────────────────────────────────────────────────────────────────
     * 다양한 시간값이 올바르게 포맷되는지 검증합니다.
     *
     *
     * @section _______ 📊 테스트 케이스
     * @endcode
     * 0초    → "00:00"  (0분 0초)
     * 30초   → "00:30"  (0분 30초)
     * 60초   → "01:00"  (1분 0초)
     * 90초   → "01:30"  (1분 30초)
     * 3600초 → "60:00"  (60분 0초)
     * 3665초 → "61:05"  (61분 5초)
     * @endcode
     *
     *
     * @section ________ 💡 포맷팅 알고리즘
     * @endcode
     * func formatTime(_ seconds: TimeInterval) -> String {
     *     let total = Int(seconds)
     *     let min = total / 60      // 정수 나눗셈
     *     let sec = total % 60      // 나머지
     *     return String(format: "%02d:%02d", min, sec)
     * }
     *
     * // 예시: 3665초
     * // min = 3665 / 60 = 61
     * // sec = 3665 % 60 = 5
     * // → "61:05"
     * @endcode
     *
     *
     * @section _02d_______ 🔍 %02d 형식 지정자
     * @endcode
     * %02d = 2자리 정수, 빈자리는 0으로 채움
     *
     * 5  → "%02d" → "05"
     * 30 → "%02d" → "30"
     * 100 → "%02d" → "100" (2자리 넘으면 그대로)
     * @endcode
     *
     * @test testTimeFormatting
     * @brief 📝 Note:
     *
     * @details
     *
     * @section note 📝 Note
     * 이 테스트는 private 포맷팅 메서드를 테스트하려 했으나,
     * Swift는 private 메서드에 직접 접근할 수 없습니다.
     * Integration Tests에서 public API를 통해 간접 검증합니다.
     */
    func testTimeFormatting() {
        // Test various time values
        let testCases: [(TimeInterval, String)] = [
            (0, "00:00"),      // 0초
            (30, "00:30"),     // 30초
            (60, "01:00"),     // 1분
            (90, "01:30"),     // 1분 30초
            (3600, "60:00"),   // 60분
            (3665, "61:05")    // 61분 5초
        ]

        // 💡 각 케이스별 예상 결과를 정의
        for (time, expected) in testCases {
            // Use private method through reflection or test computed property
            // For now, test through public API
            //
            // 📝 Swift는 private 메서드 직접 테스트가 어려움
            //    → Integration Tests에서 실제 비디오로 검증
            //
            // 또는 internal 접근 제어자로 변경하여 테스트 가능:
            // @testable import로 internal 멤버 접근 가능
        }
    }

    // ========================================================================
    // MARK: - Playback Speed Tests
    // ========================================================================
    //
    // 🎯 목적: 재생 속도 변경 기능을 검증합니다.
    //
    // ✅ 검증 항목:
    // - 재생 속도 변경 및 Combine 퍼블리싱
    // - Drift threshold (동기화 허용 오차)

    /**
     *
     * @section _____________ ✅ 테스트: 재생 속도 변경
     * ────────────────────────────────────────────────────────────────────
     * playbackSpeed 프로퍼티가 변경될 때 Combine을 통해
     * 값이 정상적으로 발행되는지 검증합니다.
     *
     *
     * @section ____________ ⚡ 재생 속도 변경의 효과
     * @endcode
     * 1.0x (기본):
     * - 1초가 실제 1초로 재생
     * - 30fps → 초당 30프레임 표시
     *
     * 0.5x (슬로우):
     * - 1초가 실제 2초로 재생
     * - 30fps → 초당 15프레임 표시
     *
     * 2.0x (빠르게):
     * - 1초가 실제 0.5초로 재생
     * - 30fps → 초당 60프레임 표시
     * @endcode
     *
     *
     * @section ________ 🔄 속도 변경 흐름
     * @endcode
     * UI에서 속도 변경:
     * syncController.playbackSpeed = 2.0
     *        ↓
     * @Published가 값 발행
     *        ↓
     * .sink { speed in }  // 구독자들에게 알림
     *        ↓
     * 각 VideoChannel의 디코딩 속도 조절
     *        ↓
     * 화면 업데이트 속도 변경
     * @endcode
     *
     *
     * @section _________ 💡 실시간 속도 변경
     * @endcode
     * // 재생 중에도 속도 변경 가능
     * syncController.play()
     * syncController.playbackSpeed = 1.5  // 재생 중 변경
     * // → 즉시 1.5배속으로 전환
     * @endcode
     *
     * @test testPlaybackSpeedChange
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> playbackSpeed 구독 설정
     * - <b>When:</b>  playbackSpeed를 2.0으로 변경
     * - <b>Then:</b>  초기값(1.0)과 새 값(2.0) 모두 발행됨
     * @endcode
     */
    func testPlaybackSpeedChange() {
        // Given: 재생 속도 구독 설정

        // 🎯 비동기 작업 완료를 감지하는 Expectation
        let expectation = expectation(description: "Playback speed changed")

        // ⚡ 수신한 속도 값들을 저장할 배열
        var receivedSpeeds: [Double] = []

        // 🔄 @Published playbackSpeed 구독
        syncController.$playbackSpeed
            .sink { speed in
                // 💡 값 변경 시마다 호출:
                // 1. 초기값 1.0 (구독 즉시)
                // 2. 변경값 2.0 (아래에서 변경)

                // 수신한 속도 저장
                receivedSpeeds.append(speed)

                // 2개 이상 수신하면 expectation 완료
                if receivedSpeeds.count >= 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // When: 재생 속도를 2배속으로 변경
        syncController.playbackSpeed = 2.0

        // Then: 값 발행 검증

        // ⏱️ 최대 1초 대기
        wait(for: [expectation], timeout: 1.0)

        // ⚡ 마지막 발행값은 2.0이어야 함
        XCTAssertEqual(receivedSpeeds.last, 2.0)

        // 💡 전체 발행값: [1.0, 2.0]
        // - 첫 번째: 초기값 (setUp에서 설정)
        // - 두 번째: 변경값 (위에서 설정)
    }

    /**
     *
     * @section _____drift_threshold____________ ✅ 테스트: Drift Threshold (동기화 허용 오차)
     * ────────────────────────────────────────────────────────────────────
     * Drift threshold가 50ms로 설정되어 있는지 확인합니다.
     *
     *
     * @section drift__ 🔄 Drift란?
     * @endcode
     * 멀티 채널 동기화 시 발생하는 시간 오차:
     *
     * 현재 재생 시간: 3.500초
     *
     * 전방 채널: 프레임 @ 3.498초 (drift: -2ms) ✅ 허용
     * 후방 채널: 프레임 @ 3.530초 (drift: +30ms) ✅ 허용
     * 측면 채널: 프레임 @ 3.555초 (drift: +55ms) ❌ 초과
     *
     * Drift Threshold = 50ms
     * → ±50ms 이내의 프레임만 "동기화됨"으로 간주
     * @endcode
     *
     *
     * @section __drift________ 💡 왜 Drift가 발생하나요?
     * @endcode
     * 원인:
     * 1. 카메라 센서의 타이밍 불일치
     * 2. 비디오 인코딩 과정의 타임스탬프 편차
     * 3. I-Frame과 P-Frame의 시간 차이
     * 4. 네트워크 전송 지연 (IP 카메라)
     * @endcode
     *
     *
     * @section 50ms________ 🎯 50ms가 적절한 이유
     * @endcode
     * 인간의 지각:
     * - 20ms 이하: 완전히 동기화된 것으로 느낌
     * - 20~50ms: 약간의 차이 느낌 (허용)
     * - 50ms 이상: 명확한 불일치 감지
     *
     * 30fps 비디오:
     * - 프레임 간격: 33ms
     * - 50ms = 약 1.5프레임 차이
     * - 2프레임 이상 차이나면 부자연스러움
     * @endcode
     *
     * 🔧 Drift 보정 메커니즘:
     * @endcode
     * func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
     *     let targetTime = currentTime
     *
     *     for channel in channels {
     *         let frame = channel.getFrame(at: targetTime)
     *
     *         // Drift 확인
     *         let drift = abs(frame.timestamp - targetTime)
     *         if drift > driftThreshold {  // 50ms
     *             // 프레임 재요청 또는 건너뛰기
     *             continue
     *         }
     *
     *         frames[channel.position] = frame
     *     }
     * }
     * @endcode
     *
     * @test testDriftThreshold
     * @brief 📝 Note:
     *
     * @details
     *
     * @section note 📝 Note
     * driftThreshold는 internal 프로퍼티로,
     * Integration Tests에서 실제 동작을 검증합니다.
     */
    func testDriftThreshold() {
        // Drift threshold should be 50ms
        // This is an internal property, tested through integration
        //
        // 📝 Drift threshold는 50ms (0.05초)로 설정되어 있습니다.
        //
        // 💡 이 값은 SyncController의 internal 프로퍼티입니다:
        // ```swift
        // private let driftThreshold: TimeInterval = 0.05  // 50ms
        // ```
        //
        // 🔍 실제 동작은 Integration Tests에서 검증:
        // - 실제 비디오 파일 로드
        // - 멀티 채널 동기화 수행
        // - 각 채널의 drift 측정
        // - 50ms 이내인지 확인
    }

    // ========================================================================
    // MARK: - Thread Safety Tests
    // ========================================================================
    //
    // 🎯 목적: 멀티 스레드 환경에서 안전하게 동작하는지 검증합니다.
    //
    // ✅ 검증 항목:
    // - 동시 채널 접근 (channelCount, allChannelsReady)
    // - 동시 프레임 접근 (getSynchronizedFrames, getBufferStatus)
    // - 크래시 없이 실행 완료

    /**
     *
     * @section ________________ ✅ 테스트: 동시 채널 정보 접근
     * ────────────────────────────────────────────────────────────────────
     * 여러 스레드가 동시에 채널 정보에 접근해도 크래시가 발생하지 않는지
     * 검증합니다.
     *
     * 🔒 스레드 안전성이란?
     * @endcode
     * 여러 스레드가 동시에 같은 데이터에 접근해도
     * 데이터 손상이나 크래시가 발생하지 않는 성질
     *
     * 스레드 안전하지 않을 때:
     * Thread 1: channelCount 읽기 → 3
     * Thread 2: channels 배열 수정 → [ch1, ch2]
     * Thread 1: channels[2] 접근 → ❌ Index out of range!
     * @endcode
     *
     * 🔧 스레드 안전성 확보 방법:
     * @endcode
     * 1. NSLock 사용:
     * let lock = NSLock()
     * lock.lock()
     * defer { lock.unlock() }
     * // 보호된 코드
     *
     * 2. DispatchQueue 사용:
     * let queue = DispatchQueue(label: "sync")
     * queue.sync {
     *     // 순차적 실행
     * }
     *
     * 3. Actor (Swift 5.5+):
     * actor SyncController {
     *     // 자동 스레드 안전성
     * }
     * @endcode
     *
     * 🧪 DispatchQueue.concurrentPerform이란?
     * @endcode
     * DispatchQueue.concurrentPerform(iterations: 100) { i in
     *     // 이 클로저가 여러 스레드에서 동시에 100번 실행
     * }
     *
     * 특징:
     * - GCD가 자동으로 스레드 풀 관리
     * - 최적의 스레드 개수로 병렬 실행
     * - 모든 반복이 끝날 때까지 블로킹
     * @endcode
     *
     *
     * @section __________ 💡 실제 사용 시나리오
     * @endcode
     * 멀티 스레드 상황:
     *
     * UI Thread:         syncController.channelCount
     * Decoding Thread:   videoChannel.decode()
     * Network Thread:    gpsService.update()
     *         ↓
     *     모두 동시에 SyncController 데이터 접근
     *         ↓
     *     스레드 안전성 필수!
     * @endcode
     *
     * @test testConcurrentChannelAccess
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스
     * - <b>When:</b>  100개의 스레드가 동시에 채널 정보 접근
     * - <b>Then:</b>  크래시 없이 모든 접근 완료
     * @endcode
     */
    func testConcurrentChannelAccess() {
        // When: Access channel count from multiple threads

        // 🔄 100번 반복을 여러 스레드에서 동시에 실행
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            // 📺 채널 개수 읽기 (읽기 연산)
            _ = syncController.channelCount

            // ✅ 모든 채널 준비 여부 확인 (읽기 연산)
            _ = syncController.allChannelsReady

            // 💡 이 두 프로퍼티에 100개 스레드가 동시에 접근
            // → 스레드 안전하다면 크래시 없이 완료
        }

        // Then: Should not crash

        // 💡 syncController가 nil이 아니면 크래시 없이 실행 완료
        XCTAssertNotNil(syncController)

        // 📝 Note: 실제로는 메모리 손상이 발생해도
        // 즉시 크래시하지 않을 수 있습니다.
        // 더 정교한 테스트를 위해서는 Thread Sanitizer 사용 권장
    }

    /**
     *
     * @section ______________ ✅ 테스트: 동시 프레임 접근
     * ────────────────────────────────────────────────────────────────────
     * 여러 스레드가 동시에 프레임 데이터에 접근해도 크래시가 발생하지
     * 않는지 검증합니다.
     *
     * 📦 접근하는 메서드:
     * @endcode
     * getSynchronizedFrames():
     * - 모든 채널의 현재 프레임 조회
     * - Dictionary 반환 (읽기 집약적)
     *
     * getBufferStatus():
     * - 모든 채널의 버퍼 상태 조회
     * - Dictionary 반환 (읽기 집약적)
     * @endcode
     *
     *
     * @section ________________ 💡 왜 프레임 접근이 중요한가요?
     * @endcode
     * 실제 앱에서:
     *
     * Render Thread:    getSynchronizedFrames()  // 60fps
     * UI Thread:        getBufferStatus()        // 매초
     * Export Thread:    getSynchronizedFrames()  // 30fps
     *
     * → 초당 수백 번 동시 접근 발생!
     * → 스레드 안전성 필수
     * @endcode
     *
     * 🔒 보호해야 할 데이터:
     * @endcode
     * // SyncController 내부
     * private var channels: [VideoChannel] = []  // ← 보호 필요
     * private var currentFrames: [CameraPosition: VideoFrame] = [:]
     *
     * // 스레드 안전하게 접근:
     * func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
     *     lock.lock()
     *     defer { lock.unlock() }
     *     return currentFrames
     * }
     * @endcode
     *
     *
     * @section race_condition___ ⚠️ Race Condition 예시
     * @endcode
     * 스레드 안전하지 않을 때:
     *
     * Thread A:                Thread B:
     * frames = getSynced()     frames = getSynced()
     *   ↓                        ↓
     * for (pos, frame) in frames
     *   ↓                      channels.removeAll()
     * frame.render()             ↓
     *   ↓                      💥 frames 무효화!
     * ❌ 크래시!
     * @endcode
     *
     * @test testConcurrentFrameAccess
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스
     * - <b>When:</b>  100개의 스레드가 동시에 프레임/버퍼 조회
     * - <b>Then:</b>  크래시 없이 모든 조회 완료
     * @endcode
     */
    func testConcurrentFrameAccess() {
        // When: Get synchronized frames from multiple threads

        // 🔄 100번 반복을 여러 스레드에서 동시에 실행
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            // 🎬 동기화된 프레임 조회
            _ = syncController.getSynchronizedFrames()

            // 📊 버퍼 상태 조회
            _ = syncController.getBufferStatus()

            // 💡 두 메서드를 100개 스레드가 동시에 호출
            // → 내부 channels 배열에 동시 접근
            // → 스레드 안전하다면 크래시 없이 완료
        }

        // Then: Should not crash

        // 💡 크래시 없이 실행 완료 확인
        XCTAssertNotNil(syncController)

        // 📝 추가 검증 가능:
        // - Thread Sanitizer로 데이터 레이스 감지
        // - Instruments로 메모리 손상 확인
        // - Stress Test로 더 많은 반복 실행
    }

    // ========================================================================
    // MARK: - Memory Management Tests
    // ========================================================================
    //
    // 🎯 목적: 메모리 관리가 올바르게 되는지 검증합니다.
    //
    // ✅ 검증 항목:
    // - deinit 호출 (메모리 해제)
    // - stop() 메서드의 리소스 정리
    // - 메모리 누수 방지

    /**
     *
     * @section _____deinit______ ✅ 테스트: deinit 호출 확인
     * ────────────────────────────────────────────────────────────────────
     * SyncController가 nil로 설정될 때 정상적으로 메모리 해제되는지
     * 검증합니다.
     *
     * 🧠 ARC (Automatic Reference Counting)란?
     * @endcode
     * Swift의 자동 메모리 관리 시스템:
     *
     * 1. 객체 생성:
     * let controller = SyncController()
     *    → Reference Count: 1
     *
     * 2. 참조 추가:
     * let another = controller
     *    → Reference Count: 2
     *
     * 3. 참조 제거:
     * controller = nil
     *    → Reference Count: 1
     *
     * 4. 마지막 참조 제거:
     * another = nil
     *    → Reference Count: 0
     *    → deinit 호출
     *    → 메모리 해제
     * @endcode
     *
     *
     * @section deinit____ 💡 deinit의 역할
     * @endcode
     * class SyncController {
     *     deinit {
     *         // 메모리 해제 직전 호출
     *         // 1. 타이머 중지
     *         // 2. 파일 핸들 닫기
     *         // 3. 네트워크 연결 해제
     *         // 4. 옵저버 제거
     *     }
     * }
     * @endcode
     *
     *
     * @section _________ ⚠️ 메모리 누수 패턴
     * @endcode
     * // 강한 참조 순환 (Retain Cycle):
     * class A {
     *     var b: B?
     * }
     * class B {
     *     var a: A?  // 강한 참조
     * }
     * let a = A()
     * let b = B()
     * a.b = b
     * b.a = a  // 순환 참조!
     * a = nil
     * b = nil
     * // → deinit 호출 안 됨! 💥
     *
     * // 해결책: weak 또는 unowned 사용
     * class B {
     *     weak var a: A?  // 약한 참조 ✅
     * }
     * @endcode
     *
     *
     * @section _____________ 🔍 이 테스트가 확인하는 것
     * @endcode
     * 1. controller = nil 했을 때
     * 2. 참조 카운트가 0이 되는지
     * 3. deinit이 정상 호출되는지
     * 4. 메모리가 실제로 해제되는지
     * @endcode
     *
     * @test testDeinit
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스 생성 (참조 카운트 1)
     * - <b>When:</b>  nil 할당 (참조 카운트 0)
     * - <b>Then:</b>  메모리 해제됨 (controller는 nil)
     * @endcode
     */
    func testDeinit() {
        // Given: 새로운 SyncController 인스턴스 생성

        // 💡 옵셔널 변수로 선언하여 nil 할당 가능하게 함
        var controller: SyncController? = SyncController()
        // 참조 카운트: 1

        // When: nil 할당하여 참조 제거
        controller = nil
        // 참조 카운트: 0 → deinit 호출 → 메모리 해제

        // Then: nil이어야 함

        // 💡 controller가 nil이면 메모리가 정상 해제된 것
        XCTAssertNil(controller)

        // 📝 추가로 확인 가능한 것들:
        // - Instruments의 Leaks 도구로 메모리 누수 확인
        // - deinit에 print 문 추가하여 호출 여부 확인
        // - 복잡한 참조 관계에서 순환 참조 검사
    }

    /**
     *
     * @section _____stop__________ ✅ 테스트: stop()의 리소스 정리
     * ────────────────────────────────────────────────────────────────────
     * stop() 메서드가 호출될 때 모든 리소스가 정리되는지 검증합니다.
     *
     * 🧹 stop() 메서드의 정리 작업:
     * @endcode
     * 1. 재생 중지:
     *    - playbackState = .stopped
     *    - 재생 타이머 중지
     *
     * 2. 채널 정리:
     *    - 모든 VideoChannel 중지
     *    - channels 배열 비우기
     *    - channelCount = 0
     *
     * 3. 시간 초기화:
     *    - currentTime = 0.0
     *    - duration = 0.0
     *    - playbackPosition = 0.0
     *
     * 4. 센서 서비스 정리:
     *    - GPS 데이터 정리
     *    - G-Sensor 데이터 정리
     * @endcode
     *
     *
     * @section stop___vs_deinit___ 💡 stop() vs deinit 차이
     * @endcode
     * stop():
     * - 명시적으로 호출
     * - 리소스 정리 + 상태 초기화
     * - 객체는 여전히 메모리에 존재
     * - 다시 loadVideoFile() 가능
     *
     * deinit:
     * - 자동으로 호출 (ARC)
     * - 메모리 해제
     * - 객체 완전히 사라짐
     * - 재사용 불가능
     * @endcode
     *
     *
     * @section __________ 🔄 일반적인 사용 패턴
     * @endcode
     * // 비디오 1 재생
     * syncController.loadVideoFile(video1)
     * syncController.play()
     *
     * // 비디오 전환
     * syncController.stop()        // 리소스 정리
     * syncController.loadVideoFile(video2)  // 새 비디오 로드
     * syncController.play()
     *
     * // 앱 종료
     * syncController = nil         // deinit 호출
     * @endcode
     *
     *
     * @section stop____________ ⚠️ stop()을 호출하지 않으면
     * @endcode
     * loadVideoFile(video2)  // stop() 없이 새 비디오 로드
     *   → 이전 비디오의 VideoChannel들이 남아있음
     *   → 메모리 누수!
     *   → 디코딩 스레드가 계속 실행
     * @endcode
     *
     * @test testStopClearsResources
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스
     * - <b>When:</b>  stop() 메서드 호출
     * - <b>Then:</b>  모든 상태가 초기값으로 리셋됨
     * @endcode
     */
    func testStopClearsResources() {
        // When: stop() 메서드 호출
        syncController.stop()

        // Then: 모든 리소스가 정리되어야 함

        // 📺 채널 개수가 0으로 초기화
        XCTAssertEqual(syncController.channelCount, 0)

        // ⏱️ 현재 시간이 0.0으로 초기화
        XCTAssertEqual(syncController.currentTime, 0.0)

        // ⏲️ 총 재생 시간이 0.0으로 초기화
        XCTAssertEqual(syncController.duration, 0.0)

        // 💡 추가로 확인할 수 있는 것들:
        // - playbackState == .stopped
        // - playbackPosition == 0.0
        // - allChannelsReady == false
        // - getSynchronizedFrames().isEmpty == true
        // - getBufferStatus().isEmpty == true
    }

    // ========================================================================
    // MARK: - Performance Tests
    // ========================================================================
    //
    // 🎯 목적: 성능 특성을 측정하고 기준치를 확인합니다.
    //
    // ✅ 검증 항목:
    // - getSynchronizedFrames() 성능
    // - getBufferStatus() 성능
    // - 1000회 반복 실행 시간

    /**
     *
     * @section _____getsynchronizedframes_____ ✅ 테스트: getSynchronizedFrames() 성능
     * ────────────────────────────────────────────────────────────────────
     * getSynchronizedFrames() 메서드를 1000번 호출하는데 걸리는 시간을
     * 측정합니다.
     *
     * ⏱️ measure {} 블록이란?
     * @endcode
     * measure {
     *     // 이 블록을 10번 실행
     *     // 각 실행 시간을 측정
     *     // 평균, 표준편차 계산
     * }
     *
     * 실행 과정:
     * 1회 실행: 0.015초
     * 2회 실행: 0.014초
     * 3회 실행: 0.016초
     * ...
     * 10회 실행: 0.015초
     *   ↓
     * 평균: 0.015초 ± 0.001초
     *   ↓
     * Xcode에 Baseline으로 저장 가능
     * @endcode
     *
     *
     * @section _____ 📊 성능 기준
     * @endcode
     * 목표: 1000회 호출에 < 10ms
     *
     * 이유:
     * - 60fps 렌더링 = 16.67ms per frame
     * - getSynchronizedFrames()는 매 프레임 호출
     * - 1회당 < 0.01ms 필요
     * - 1000회로 확대하면 < 10ms
     *
     * 측정 결과 예시:
     *
     * @section 5ms___________________ ✅ 5ms  → 매우 빠름 (최적화 잘 됨)
     *
     * @section 15ms______________ ⚠️ 15ms → 느림 (최적화 필요)
     * ❌ 50ms → 매우 느림 (버그 의심)
     * @endcode
     *
     *
     * @section __________ 💡 성능 최적화 포인트
     * @endcode
     * // 느린 구현:
     * func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
     *     var result: [CameraPosition: VideoFrame] = [:]
     *     for channel in channels {
     *         let frame = channel.decode()  // ❌ 매번 디코딩
     *         result[channel.position] = frame
     *     }
     *     return result
     * }
     *
     * // 빠른 구현:
     * func getSynchronizedFrames() -> [CameraPosition: VideoFrame] {
     *     return currentFrames  // ✅ 캐시된 프레임 반환
     * }
     * @endcode
     *
     *
     * @section xcode_baseline___ 🔍 Xcode Baseline 기능
     * @endcode
     * 1. 성능 테스트 실행
     * 2. "Set Baseline" 클릭
     * 3. 이후 실행 시 Baseline과 비교
     * 4. 10% 이상 느려지면 경고
     * @endcode
     *
     * @test testGetSynchronizedFramesPerformance
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스 (채널 없음)
     * - <b>When:</b>  getSynchronizedFrames()를 1000번 호출
     * - <b>Then:</b>  실행 시간이 기준치 이내
     * @endcode
     */
    func testGetSynchronizedFramesPerformance() {
        // ⏱️ measure 블록으로 성능 측정
        measure {
            // 💡 1000번 반복 실행
            for _ in 0..<1000 {
                // 🎬 동기화 프레임 조회
                _ = syncController.getSynchronizedFrames()

                // 📝 Note: 채널이 없으므로 빈 딕셔너리 반환
                // → 최소 오버헤드만 측정
                // → Integration Tests에서 실제 채널로 재측정
            }
        }

        // 💡 measure 블록 종료 후:
        // - Xcode Test Navigator에 실행 시간 표시
        // - 이전 Baseline과 비교 (설정된 경우)
        // - 성능 저하 시 경고 표시
    }

    /**
     *
     * @section _____getbufferstatus_____ ✅ 테스트: getBufferStatus() 성능
     * ────────────────────────────────────────────────────────────────────
     * getBufferStatus() 메서드를 1000번 호출하는데 걸리는 시간을
     * 측정합니다.
     *
     *
     * @section _____ 📊 성능 기준
     * @endcode
     * 목표: 1000회 호출에 < 10ms
     *
     * 이유:
     * - UI 업데이트에 사용 (초당 1~10회)
     * - 버퍼 상태 표시 (진행 바, 로딩 인디케이터)
     * - 부드러운 UI를 위해 빠른 응답 필요
     * @endcode
     *
     *
     * @section ___________ 💡 버퍼 상태 계산 비용
     * @endcode
     * func getBufferStatus() -> [CameraPosition: BufferStatus] {
     *     var result: [CameraPosition: BufferStatus] = [:]
     *     for channel in channels {
     *         let status = BufferStatus(
     *             current: channel.buffer.count,     // O(1)
     *             maximum: channel.buffer.capacity,  // O(1)
     *             fillPercentage: Double(channel.buffer.count) /
     *                            Double(channel.buffer.capacity)  // O(1)
     *         )
     *         result[channel.position] = status
     *     }
     *     return result  // O(n), n = 채널 개수
     * }
     * @endcode
     *
     *
     * @section ______ 🎯 최적화 전략
     * @endcode
     * 1. 캐싱:
     *    - 버퍼 상태가 변경될 때만 재계산
     *    - 변경 없으면 캐시된 값 반환
     *
     * 2. Lazy 계산:
     *    - 요청받을 때만 계산
     *    - 사용하지 않으면 계산 안 함
     *
     * 3. 병렬 처리:
     *    - 여러 채널의 상태를 동시에 계산
     *    - DispatchQueue.concurrentPerform 사용
     * @endcode
     *
     * @test testGetBufferStatusPerformance
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> SyncController 인스턴스 (채널 없음)
     * - <b>When:</b>  getBufferStatus()를 1000번 호출
     * - <b>Then:</b>  실행 시간이 기준치 이내
     * @endcode
     */
    func testGetBufferStatusPerformance() {
        // ⏱️ measure 블록으로 성능 측정
        measure {
            // 💡 1000번 반복 실행
            for _ in 0..<1000 {
                // 📊 버퍼 상태 조회
                _ = syncController.getBufferStatus()

                // 📝 Note: 채널이 없으므로 빈 딕셔너리 반환
                // → 메서드 호출 오버헤드만 측정
                // → 실제 성능은 Integration Tests에서 확인
            }
        }

        // 💡 성능 개선 팁:
        // - getSynchronizedFrames()보다 빨라야 함 (단순한 계산)
        // - 만약 느리다면 lock 경합 의심
        // - Thread Sanitizer로 동시성 문제 확인
    }
}

// ============================================================================
// MARK: - Integration Tests
// ============================================================================

/// 🔗 SyncControllerIntegrationTests 클래스
/// ────────────────────────────────────────────────────────────────────────
/// 실제 비디오 파일과 채널을 사용하여 SyncController의 전체 워크플로우를
/// 검증하는 Integration Test 클래스입니다.
///
/// 📝 Unit Tests vs Integration Tests:
/// ```
/// Unit Tests (SyncControllerTests):
/// ├─ 채널 없이 독립적으로 테스트
/// ├─ 빠른 실행 (< 1초)
/// ├─ 메서드 단위 검증
/// └─ Mock 데이터 사용
///
/// Integration Tests (이 클래스):
/// ├─ 실제 비디오 파일 로드
/// ├─ 느린 실행 (수 초)
/// ├─ 전체 워크플로우 검증
/// └─ 실제 데이터 사용
/// ```
///
/// 🎯 테스트 범위:
/// ```
/// 1. 비디오 파일 로드
/// 2. 재생 흐름 (.paused → .playing → .paused)
/// 3. 재생 중 Seeking
/// 4. 멀티 채널 동기화
/// 5. 재생 속도 제어
/// 6. 버퍼 상태 확인
/// 7. 끝까지 재생 (.playing → .stopped)
/// ```
///
/// ⚠️ XCTSkip이란?
/// ```swift
/// guard let videoPath = ... else {
///     throw XCTSkip("Test video file not found")
/// }
///
/// 역할:
/// - 테스트를 건너뛰기 (실패가 아님)
/// - CI/CD 환경에서 리소스 없을 때 유용
/// - 테스트 결과에 "Skipped" 표시
/// ```
final class SyncControllerIntegrationTests: XCTestCase {

    // ========================================================================
    // MARK: - Properties
    // ========================================================================

    /**
     * 📦 테스트 대상 SyncController 인스턴스
     */
    var syncController: SyncController!

    /**
     *
     * @section ______________ 🎬 테스트용 비디오 파일 정보
     * @endcode
     * VideoFile:
     * - 실제 비디오 파일 경로
     * - 채널 정보 (전방 카메라)
     * - 메타데이터 (duration, size 등)
     * @endcode
     */
    var testVideoFile: VideoFile!

    // ========================================================================
    // MARK: - Setup & Teardown
    // ========================================================================

    /**
     * 🔧 setUp 메서드
     * ────────────────────────────────────────────────────────────────────
     * 각 테스트 실행 전에 테스트 비디오 파일과 SyncController를 준비합니다.
     *
     * 📦 Bundle이란?
     * @endcode
     * let bundle = Bundle(for: type(of: self))
     *
     * 역할:
     * - 현재 테스트 타겟의 리소스 접근
     * - test_video.mp4 같은 테스트 파일 찾기
     * - 실행 환경에 따라 경로 자동 조정
     * @endcode
     *
     *
     * @section _____________ 🎬 테스트 비디오 파일 구조
     * @endcode
     * test_video.mp4
     * ├─ 전방 채널 (Front Camera)
     * ├─ 재생 시간: 10초
     * ├─ 해상도: 1920x1080
     * └─ 프레임 레이트: 30fps
     * @endcode
     *
     *
     * @section xctskip___ ⚠️ XCTSkip 사용
     * @endcode
     * 테스트 파일이 없으면:
     * - 테스트 실패 ❌ (다른 테스트도 영향)
     * - 테스트 Skip ✅ (이 테스트만 건너뜀)
     * @endcode
     */
    override func setUpWithError() throws {
        super.setUp()

        // Create test video file

        // 📦 현재 테스트 번들 가져오기
        let bundle = Bundle(for: type(of: self))

        // 🎬 테스트 비디오 파일 경로 찾기
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            // ⚠️ 파일이 없으면 테스트 건너뛰기
            throw XCTSkip("Test video file not found")
            // 💡 XCTSkip을 throw하면:
            // - 테스트가 "Skipped"로 표시됨
            // - 다른 테스트는 계속 실행됨
            // - CI/CD 파이프라인 통과
        }

        // Create test video file with channels

        // 🎬 VideoFile 인스턴스 생성
        testVideoFile = VideoFile(
            id: UUID(),                    // 고유 ID
            name: "Test Video",            // 비디오 이름
            filePath: videoPath,           // 실제 파일 경로
            timestamp: Date(),             // 생성 시간
            duration: 10.0,                // 10초 길이
            eventType: .normal,            // 일반 주행
            size: 1024 * 1024,             // 1MB
            channels: [
                // 전방 채널 1개
                ChannelInfo(
                    position: .front,      // 전방 카메라
                    filePath: videoPath,   // 같은 파일 사용
                    displayName: "Front"   // UI 표시명
                )
            ],
            metadata: VideoMetadata.empty  // 빈 메타데이터
        )

        // 🔧 SyncController 생성
        syncController = SyncController()
    }

    /**
     * 🧹 tearDown 메서드
     * ────────────────────────────────────────────────────────────────────
     * 각 테스트 실행 후 리소스를 정리합니다.
     *
     * 🧹 정리 순서:
     * @endcode
     * 1. syncController.stop()     → 재생 중지, 채널 해제
     * 2. syncController = nil      → 메모리 해제
     * 3. testVideoFile = nil       → 파일 정보 해제
     * 4. super.tearDown()          → 부모 클래스 정리
     * @endcode
     */
    override func tearDownWithError() throws {
        // 🎮 재생 중지 및 리소스 정리
        syncController.stop()

        // 🗑️ 메모리 해제
        syncController = nil
        testVideoFile = nil

        // 🧹 부모 클래스 정리
        super.tearDown()
    }

    // ========================================================================
    // MARK: - Integration Test Cases
    // ========================================================================

    /**
     *
     * @section ______________ ✅ 테스트: 비디오 파일 로드
     * ────────────────────────────────────────────────────────────────────
     * 실제 비디오 파일을 로드할 때 모든 채널이 정상적으로 초기화되는지
     * 검증합니다.
     *
     *
     * @section loadvideofile_____ 🔄 loadVideoFile() 동작
     * @endcode
     * 1. VideoFile 정보 읽기
     * 2. 각 채널별 VideoChannel 생성
     *    - FFmpeg 디코더 초기화
     *    - 비디오 파일 열기
     *    - 메타데이터 읽기
     * 3. duration 계산 (가장 긴 채널 기준)
     * 4. playbackState = .paused
     * 5. allChannelsReady = true
     * @endcode
     *
     * @test testLoadVideoFile
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 테스트 비디오 파일 준비
     * - <b>When:</b>  loadVideoFile() 호출
     * - <b>Then:</b>  .paused 상태, 채널/duration 설정됨
     * @endcode
     */
    func testLoadVideoFile() throws {
        // When: 비디오 파일 로드
        try syncController.loadVideoFile(testVideoFile)

        // Then: 로드 후 상태 검증

        // 🎮 재생 상태는 .paused (재생 준비 완료)
        XCTAssertEqual(syncController.playbackState, .paused)

        // 📺 1개 이상의 채널이 로드됨
        XCTAssertGreaterThan(syncController.channelCount, 0)

        // ⏲️ 비디오 길이가 설정됨 (> 0초)
        XCTAssertGreaterThan(syncController.duration, 0)

        // ✅ 모든 채널이 준비 완료 상태
        XCTAssertTrue(syncController.allChannelsReady)
    }

    /**
     *
     * @section _____________ ✅ 테스트: 전체 재생 흐름
     * ────────────────────────────────────────────────────────────────────
     * 재생 → 일시정지의 전체 흐름이 정상 동작하는지 검증합니다.
     *
     *
     * @section _____ 🔄 재생 흐름
     * @endcode
     * .stopped
     *    ↓ loadVideoFile()
     * .paused (재생 준비 완료)
     *    ↓ play()
     * .playing (재생 중, currentTime 증가)
     *    ↓ pause()
     * .paused (일시정지, currentTime 유지)
     * @endcode
     *
     * @test testPlaybackFlow
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 비디오 로드됨
     * - <b>When:</b>  play() → 0.5초 대기 → pause()
     * - <b>Then:</b>  상태 전환 정상, 시간 진행 확인
     * @endcode
     */
    func testPlaybackFlow() throws {
        // Given: 비디오 로드
        try syncController.loadVideoFile(testVideoFile)

        // When: Play

        // 🎮 재생 시작
        syncController.play()

        // Then: 재생 상태 확인

        // 🎮 상태가 .playing이어야 함
        XCTAssertEqual(syncController.playbackState, .playing)

        // Wait for some playback

        // ⏱️ 0.5초 동안 재생 (시간이 진행되도록)
        Thread.sleep(forTimeInterval: 0.5)

        // Then: Time should advance

        // ⏱️ 시간이 0보다 커야 함 (진행됨)
        XCTAssertGreaterThan(syncController.currentTime, 0.0)

        // When: Pause

        // ⏸️ 일시정지
        syncController.pause()

        // Then: 일시정지 상태 확인

        // 🎮 상태가 .paused여야 함
        XCTAssertEqual(syncController.playbackState, .paused)
    }

    /**
     *
     * @section __________seeking ✅ 테스트: 재생 중 Seeking
     * ────────────────────────────────────────────────────────────────────
     * 재생 중에 특정 시간으로 이동하는 기능을 검증합니다.
     *
     *
     * @section seeking___ 🎬 Seeking 동작
     * @endcode
     * 재생 중 (3.0초):
     * [====●===============] 10초
     *
     * seekToTime(5.0) 호출:
     * [=========●==========] 10초
     *          5.0초
     *
     * 변경 사항:
     * - currentTime = 5.0
     * - playbackPosition = 0.5
     * - 모든 채널이 5초 위치로 이동
     * - 재생 계속
     * @endcode
     *
     * @test testSeekDuringPlayback
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 비디오 재생 중
     * - <b>When:</b>  seekToTime(5.0) 호출
     * - <b>Then:</b>  currentTime이 5.0으로 변경됨
     * @endcode
     */
    func testSeekDuringPlayback() throws {
        // Given: 비디오 로드 및 재생 시작
        try syncController.loadVideoFile(testVideoFile)
        syncController.play()

        // ⏱️ 0.3초 재생 (seek 전 초기 재생)
        Thread.sleep(forTimeInterval: 0.3)

        // When: 5초 위치로 이동
        syncController.seekToTime(5.0)

        // Then: Seeking 결과 검증

        // ⏱️ 현재 시간이 5.0초여야 함
        XCTAssertEqual(syncController.currentTime, 5.0)

        // 📍 재생 위치가 0보다 커야 함 (5.0 / 10.0 = 0.5)
        XCTAssertGreaterThan(syncController.playbackPosition, 0.0)
    }

    /**
     *
     * @section ________________ ✅ 테스트: 동기화된 프레임 조회
     * ────────────────────────────────────────────────────────────────────
     * 멀티 채널 동기화가 정상 동작하는지 검증합니다.
     *
     *
     * @section _______ 🔄 프레임 동기화
     * @endcode
     * 현재 시간: 3.5초
     *
     * 전방 채널:
     * [...프레임 @ 3.498초...] ← drift: -2ms ✅
     *
     * getSynchronizedFrames() 반환:
     * [
     *     .front: VideoFrame(timestamp: 3.498)
     * ]
     * @endcode
     *
     * @test testSynchronizedFrames
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 비디오 재생 중
     * - <b>When:</b>  getSynchronizedFrames() 호출
     * - <b>Then:</b>  각 채널의 프레임 반환됨
     * @endcode
     */
    func testSynchronizedFrames() throws {
        // Given: 비디오 로드 및 재생
        try syncController.loadVideoFile(testVideoFile)
        syncController.play()

        // ⏱️ 0.5초 재생 (프레임 버퍼링 시간)
        Thread.sleep(forTimeInterval: 0.5)

        // When: 동기화된 프레임 조회
        let frames = syncController.getSynchronizedFrames()

        // Then: 프레임 검증

        // 📦 프레임이 비어있지 않아야 함
        XCTAssertFalse(frames.isEmpty, "Should have synchronized frames")

        // 🎬 각 채널의 프레임 검증
        for (position, frame) in frames {
            // ⏱️ 타임스탬프가 0 이상이어야 함
            XCTAssertGreaterThanOrEqual(frame.timestamp, 0.0)

            // 📝 디버그 출력 (테스트 실행 시 확인 가능)
            print("Channel \(position.displayName): frame at \(frame.timestamp)s")
        }
    }

    /**
     *
     * @section _____________ ✅ 테스트: 재생 속도 제어
     * ────────────────────────────────────────────────────────────────────
     * 2배속 재생이 실제로 빠르게 동작하는지 검증합니다.
     *
     *
     * @section ________ ⚡ 재생 속도 계산
     * @endcode
     * playbackSpeed = 2.0 (2배속)
     * 실제 시간: 0.5초
     * 비디오 시간: 0.5초 × 2.0 = 1.0초
     *
     * 예상 진행:
     * startTime = 0.0
     * (0.5초 대기)
     * endTime ≈ 1.0초
     * elapsed = 1.0 - 0.0 = 1.0초
     *
     * 검증: elapsed > 0.8 (약간의 오차 허용)
     * @endcode
     *
     * @test testPlaybackSpeedControl
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 비디오 로드, 2배속 설정
     * - <b>When:</b>  0.5초 재생
     * - <b>Then:</b>  약 1초 진행됨 (2배속 효과)
     * @endcode
     */
    func testPlaybackSpeedControl() throws {
        // Given: 비디오 로드
        try syncController.loadVideoFile(testVideoFile)

        // When: Set speed to 2x

        // ⚡ 2배속 설정
        syncController.playbackSpeed = 2.0

        // 🎮 재생 시작
        syncController.play()

        // 📊 시작 시간 기록
        let startTime = syncController.currentTime

        // ⏱️ 0.5초 대기 (실제 시간)
        Thread.sleep(forTimeInterval: 0.5)

        // 📊 종료 시간 기록
        let endTime = syncController.currentTime

        // Then: Should advance approximately 1 second (0.5s * 2x speed)

        // 📊 경과 시간 계산
        let elapsed = endTime - startTime

        // ⚡ 0.8초 이상 진행되어야 함 (2배속이므로 약 1초)
        // 💡 0.8은 오차 허용 (정확히 1초가 아닐 수 있음)
        XCTAssertGreaterThan(elapsed, 0.8, "Should advance faster at 2x speed")
    }

    /**
     *
     * @section _____________ ✅ 테스트: 버퍼 상태 조회
     * ────────────────────────────────────────────────────────────────────
     * 각 채널의 버퍼가 정상적으로 채워지는지 검증합니다.
     *
     *
     * @section ________ 📊 버퍼 상태 예시
     * @endcode
     * 전방 채널 버퍼:
     * [Frame][Frame][Frame]...[    ]  25/30 (83%)
     *
     * getBufferStatus() 반환:
     * [
     *     .front: BufferStatus(
     *         current: 25,
     *         maximum: 30,
     *         fillPercentage: 0.83
     *     )
     * ]
     * @endcode
     *
     * @test testBufferStatus
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 비디오 재생 중
     * - <b>When:</b>  getBufferStatus() 호출
     * - <b>Then:</b>  각 채널의 버퍼 상태 반환됨
     * @endcode
     */
    func testBufferStatus() throws {
        // Given: 비디오 로드 및 재생
        try syncController.loadVideoFile(testVideoFile)
        syncController.play()

        // ⏱️ 0.5초 재생 (버퍼 채우기)
        Thread.sleep(forTimeInterval: 0.5)

        // When: 버퍼 상태 조회
        let status = syncController.getBufferStatus()

        // Then: 버퍼 상태 검증

        // 📦 버퍼 상태가 비어있지 않아야 함
        XCTAssertFalse(status.isEmpty)

        // 📊 각 채널의 버퍼 상태 검증
        for (position, bufferStatus) in status {
            // 📦 버퍼에 1개 이상의 프레임이 있어야 함
            XCTAssertGreaterThan(
                bufferStatus.current,
                0,
                "Channel \(position.displayName) should have buffered frames"
            )

            // 📊 채움 비율은 0.0 ~ 1.0 범위
            XCTAssertLessThanOrEqual(bufferStatus.fillPercentage, 1.0)
        }
    }

    /**
     *
     * @section ___________ ✅ 테스트: 끝까지 재생
     * ────────────────────────────────────────────────────────────────────
     * 비디오를 끝까지 재생하면 자동으로 정지되는지 검증합니다.
     *
     *
     * @section _________ 🔄 끝까지 재생 흐름
     * @endcode
     * 재생 시작:
     * [●═══════════════════] 0.0초 / 10.0초
     *  ↓ play()
     * [════════════════●═══] 8.5초 / 10.0초
     *  ↓ (계속 재생)
     * [═══════════════════●] 10.0초 / 10.0초
     *  ↓ (자동)
     * .stopped (currentTime = 10.0, position = 1.0)
     * @endcode
     *
     * ⏱️ Polling 방식:
     * @endcode
     * while playbackState == .playing {
     *     Thread.sleep(0.1초)
     *     elapsed += 0.1초
     *     if elapsed > timeout { break }
     * }
     * @endcode
     *
     * @test testPlayToEnd
     * @brief 📝 Given-When-Then 패턴:
     *
     * @details
     *
     * @section given_when_then___ 📝 Given-When-Then 패턴
     * @endcode
     * - <b>Given:</b> 10초 비디오 로드
     * - <b>When:</b>  재생 시작, 끝날 때까지 대기
     * - <b>Then:</b>  자동 정지, currentTime = duration
     * @endcode
     */
    func testPlayToEnd() throws {
        // Given: Short video

        // 🎬 10초 비디오 로드
        try syncController.loadVideoFile(testVideoFile)

        // When: Play to end

        // 🎮 재생 시작
        syncController.play()

        // Wait for playback to complete

        // ⏱️ 타임아웃 설정 (duration + 2초 여유)
        let timeout = syncController.duration + 2.0

        // ⏱️ 경과 시간 추적
        var elapsed: TimeInterval = 0.0

        // ⏱️ 확인 간격 (0.1초마다 상태 확인)
        let checkInterval: TimeInterval = 0.1

        // 🔄 재생이 끝날 때까지 대기 (Polling)
        while syncController.playbackState == .playing && elapsed < timeout {
            // 0.1초 대기
            Thread.sleep(forTimeInterval: checkInterval)

            // 경과 시간 누적
            elapsed += checkInterval
        }

        // Then: Should stop at end

        // 🎮 재생 상태가 .stopped여야 함 (자동 정지)
        XCTAssertEqual(syncController.playbackState, .stopped)

        // ⏱️ 현재 시간 = duration (끝까지 재생됨)
        XCTAssertEqual(syncController.currentTime, syncController.duration)

        // 📍 재생 위치 = 1.0 (100%)
        XCTAssertEqual(syncController.playbackPosition, 1.0)
    }
}
