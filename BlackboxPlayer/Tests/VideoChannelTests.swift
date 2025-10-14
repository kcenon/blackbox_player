/**
 * @file VideoChannelTests.swift
 * @brief 비디오 채널 단위 테스트
 * @author BlackboxPlayer Team
 *
 * @details
 * 개별 비디오 채널(VideoChannel)의 디코딩, 버퍼링, 상태 관리를 검증하는
 * 단위 테스트 모음입니다. 멀티채널 블랙박스 시스템에서 각 카메라 채널의
 * 독립적인 동작을 테스트합니다.
 *
 * @section video_channel_overview VideoChannel이란?
 *
 * VideoChannel은 하나의 카메라 비디오를 디코딩하고 프레임을 버퍼링하는
 * 컴포넌트입니다. 각 채널은 독립적으로 동작하며, 멀티스레드 환경에서
 * 안전하게 접근할 수 있습니다.
 *
 * **주요 기능:**
 *
 * 1. **디코딩 관리**
 *    - 백그라운드 스레드에서 비디오 디코딩
 *    - FFmpeg VideoDecoder 래핑
 *    - 비동기 프레임 생성
 *
 * 2. **프레임 버퍼링**
 *    - 최근 30개 프레임 저장 (LRU 캐시)
 *    - 빠른 프레임 조회 (O(1) 접근)
 *    - 메모리 효율적 관리
 *
 * 3. **상태 관리**
 *    - Idle → Ready → Decoding → Completed/Error
 *    - Combine Publisher로 상태 변경 전파
 *    - 상태 전환 이벤트 구독 가능
 *
 * 4. **스레드 안전성**
 *    - 여러 스레드에서 동시 접근 가능
 *    - 내부 락으로 데이터 보호
 *    - 경쟁 조건 방지
 *
 * @section multichannel_structure 블랙박스 멀티채널 구조
 *
 * ```
 * BlackboxPlayer
 * ├── VideoChannel (전방)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30개]
 * ├── VideoChannel (후방)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30개]
 * ├── VideoChannel (좌측)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30개]
 * ├── VideoChannel (우측)
 * │   ├── VideoDecoder (FFmpeg)
 * │   └── Frame Buffer [30개]
 * └── VideoChannel (실내)
 *     ├── VideoDecoder (FFmpeg)
 *     └── Frame Buffer [30개]
 * ```
 *
 * @section test_scope 테스트 범위
 *
 * 1. **초기화 테스트**
 *    - 채널 ID 할당
 *    - 초기 상태 확인 (Idle)
 *    - 버퍼 초기화
 *
 * 2. **디코딩 테스트**
 *    - 비디오 파일 로드
 *    - 프레임 디코딩
 *    - 상태 전환 (Idle → Ready → Decoding)
 *
 * 3. **버퍼링 테스트**
 *    - 프레임 저장
 *    - 프레임 조회
 *    - LRU 캐시 동작
 *    - 버퍼 오버플로 처리
 *
 * 4. **상태 관리 테스트**
 *    - 상태 전환 검증
 *    - Combine Publisher 이벤트
 *    - 에러 상태 처리
 *
 * 5. **스레드 안전성 테스트**
 *    - 동시 접근 검증
 *    - 경쟁 조건 테스트
 *    - 데이터 레이스 감지
 *
 * 6. **성능 테스트**
 *    - 프레임 조회 속도
 *    - 버퍼 업데이트 성능
 *    - 메모리 사용량
 *
 * @section combine_overview Combine 프레임워크
 *
 * Combine은 Apple의 reactive 프로그래밍 프레임워크로, 데이터의 변화를
 * 자동으로 감지하고 반응하는 패턴을 제공합니다.
 *
 * **주요 개념:**
 * - **Publisher**: 값을 발행하는 객체
 * - **Subscriber**: 값을 구독하는 객체
 * - **AnyCancellable**: 구독 취소를 위한 토큰
 *
 * **사용 예시:**
 * ```swift
 * channel.$state  // Publisher
 *     .sink { state in  // Subscriber
 *         print("State changed: \(state)")
 *     }
 *     .store(in: &cancellables)  // 구독 관리
 * ```
 *
 * @section test_strategy 테스트 전략
 *
 * - Mock 데이터 사용으로 외부 의존성 제거
 * - 비동기 테스트에 async/await 활용
 * - XCTestExpectation으로 상태 변경 대기
 * - Combine sink로 이벤트 스트림 검증
 *
 * @note 이 테스트는 실제 비디오 파일 없이 Mock 데이터로 실행됩니다.
 * 통합 테스트에서 실제 파일 디코딩을 검증합니다.
 */

//
//  ═══════════════════════════════════════════════════════════════════════════
//  VideoChannelTests.swift
//  BlackboxPlayerTests
//
//  📋 프로젝트: BlackboxPlayer
//  🎯 목적: VideoChannel 유닛 테스트
//  📝 설명: 비디오 채널의 디코딩, 버퍼링, 상태 관리를 검증합니다
//
//  ═══════════════════════════════════════════════════════════════════════════
//
//  🎬 VideoChannel이란?
//  ────────────────────────────────────────────────────────────────────────
//  하나의 카메라 비디오를 디코딩하고 프레임을 버퍼링하는 컴포넌트입니다.
//
//  📦 주요 기능:
//  ```
//  1. 디코딩 관리
//     - 백그라운드 스레드에서 비디오 디코딩
//     - FFmpeg VideoDecoder 래핑
//
//  2. 프레임 버퍼링
//     - 최근 30개 프레임 저장
//     - 빠른 프레임 조회
//
//  3. 상태 관리
//     - Idle → Ready → Decoding → Completed/Error
//     - Combine Publisher로 상태 변경 전파
//
//  4. 스레드 안전성
//     - 여러 스레드에서 동시 접근 가능
//     - 내부 락으로 데이터 보호
//  ```
//
//  🔄 블랙박스 멀티 채널 구조:
//  ```
//  BlackboxPlayer
//  ├── VideoChannel (전방)
//  │   ├── VideoDecoder
//  │   └── Frame Buffer [30개]
//  ├── VideoChannel (후방)
//  │   ├── VideoDecoder
//  │   └── Frame Buffer [30개]
//  └── VideoChannel (측면)
//      ├── VideoDecoder
//      └── Frame Buffer [30개]
//  ```
//  ────────────────────────────────────────────────────────────────────────
//

/// XCTest 프레임워크
///
/// Apple의 공식 유닛 테스트 프레임워크입니다.
import XCTest

/// Combine 프레임워크
///
/// Apple의 reactive 프로그래밍 프레임워크입니다.
///
/// 🔄 Reactive Programming이란?
/// ```
/// 데이터의 변화를 자동으로 감지하고 반응하는 프로그래밍 패러다임
///
/// 전통적 방식:
/// if (state == .ready) {
///     // 상태 변경 수동 확인
/// }
///
/// Reactive 방식:
/// channel.$state.sink { newState in
///     // 상태 변경 시 자동 실행
/// }
/// ```
///
/// 💡 Combine의 주요 개념:
/// - Publisher: 값을 발행하는 객체
/// - Subscriber: 값을 구독하는 객체
/// - AnyCancellable: 구독 취소를 위한 토큰
///
/// 📚 사용 예시:
/// ```swift
/// channel.$state  // Publisher
///     .sink { state in  // Subscriber
///         print("State changed: \(state)")
///     }
///     .store(in: &cancellables)  // 구독 관리
/// ```
import Combine

/// @testable import
///
/// 테스트 대상 모듈의 internal 멤버에 접근할 수 있게 합니다.
@testable import BlackboxPlayer

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - 비디오 채널 테스트 (Unit Tests)
// ═══════════════════════════════════════════════════════════════════════════

/// VideoChannel 유닛 테스트 클래스
///
/// 비디오 채널의 기본 기능을 검증합니다.
///
/// 🎯 테스트 범위:
/// ```
/// 1. 초기화
///    - 채널 생성
///    - Identifiable (고유 ID)
///    - Equatable (비교 가능)
///
/// 2. 상태 관리
///    - 상태 전환
///    - 상태 이름
///    - Combine Publisher
///
/// 3. 버퍼 관리
///    - 버퍼 상태 조회
///    - 버퍼 초기화
///    - 프레임 조회
///
/// 4. 에러 처리
///    - 잘못된 파일
///    - 미초기화 상태
///    - 중복 초기화
///
/// 5. 스레드 안전성
///    - 동시 버퍼 접근
///    - 동시 프레임 조회
///
/// 6. 메모리 관리
///    - deinit 정리
///    - stop() 정리
///
/// 7. 성능
///    - 버퍼 상태 조회
///    - 프레임 조회
/// ```
final class VideoChannelTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 비디오 채널 인스턴스
     */
    /**
     * 각 테스트에서 새로 생성됩니다.
     */
    var channel: VideoChannel!

    /**
     * 테스트 채널 정보
     */
    /**
     * 채널 위치, 파일 경로, 표시 이름을 포함합니다.
     */
    /**
     *
     * @section channelinfo___ 📝 ChannelInfo 구조
     * @endcode
     * struct ChannelInfo {
     *     let position: CameraPosition  // .front, .rear, etc.
     *     let filePath: String          // 비디오 파일 경로
     *     let displayName: String       // UI에 표시할 이름
     * }
     * @endcode
     */
    var testChannelInfo: ChannelInfo!

    /**
     * Combine 구독 저장소
     */
    /**
     * Combine의 구독을 저장하여 메모리 누수를 방지합니다.
     */
    /**
     *
     * @section anycancellable___ 💡 AnyCancellable이란?
     * @endcode
     * Combine 구독의 수명을 관리하는 토큰
     */
    /**
     * 역할:
     * 1. 구독 취소 가능
     * 2. 자동 메모리 관리
     * 3. Set으로 여러 구독 관리
     * @endcode
     */
    /**
     *
     * @section _____ 📝 사용 패턴
     * @endcode
     * publisher
     *     .sink { value in ... }
     *     .store(in: &cancellables)  // Set에 저장
     */
    /**
     * // cancellables = nil 시 모든 구독 자동 취소
     * @endcode
     */
    /**
     *
     * @section set__________ ⚠️ Set으로 관리하는 이유
     * - 여러 구독을 한 번에 관리
     * - tearDown에서 일괄 취소
     * - 메모리 누수 방지
     */
    var cancellables: Set<AnyCancellable>!

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
     * @section ______ 🎯 초기화 내용
     * 1. 부모 클래스의 setUp 호출
     * 2. continueAfterFailure 플래그 설정
     * 3. cancellables 빈 Set 생성
     * 4. 테스트 채널 정보 생성
     */
    /**
     *
     * @section continueafterfailure___false 💡 continueAfterFailure = false
     * 첫 번째 assertion 실패 시 테스트를 즉시 중단합니다.
     * (안전성 확보: nil 접근 방지)
     */
    override func setUpWithError() throws {
        /**
         * 부모 클래스의 setUp 호출
         */
        super.setUp()

        /**
         * 실패 시 즉시 중단 설정
         */
        /**
         *
         * @section __ 💡 이유
         * 첫 번째 실패 후 계속 실행하면
         * nil 접근으로 크래시 발생 가능
         */
        continueAfterFailure = false

        /**
         * Combine 구독 저장소 초기화
         */
        /**
         * 빈 Set으로 시작
         * 테스트에서 .store(in: &cancellables)로 구독 추가
         */
        cancellables = []

        /**
         * 테스트 채널 정보 생성
         */
        /**
         *
         * @section _______ 💡 테스트용 설정
         * - position: .front (전방 카메라)
         * - filePath: "/path/to/test/video.mp4" (존재하지 않는 경로)
         * - displayName: "Test Channel"
         */
        /**
         *
         * @section ________________ ⚠️ 파일 경로는 의도적으로 잘못됨
         * 에러 처리를 테스트하기 위함
         */
        testChannelInfo = ChannelInfo(
            position: .front,
            filePath: "/path/to/test/video.mp4",
            displayName: "Test Channel"
        )
    }

    /**
     * 각 테스트 실행 후 정리
     */
    /**
     * XCTest가 각 테스트 메서드 실행 후에 자동으로 호출합니다.
     */
    /**
     * 🧹 정리 내용:
     * 1. 채널 중지 (디코딩 스레드 종료)
     * 2. 채널 해제
     * 3. 채널 정보 해제
     * 4. Combine 구독 해제
     * 5. 부모 클래스의 tearDown 호출
     */
    /**
     *
     * @section _____________ 💡 정리 순서가 중요한 이유
     * @endcode
     * 1. channel?.stop()
     *    - 백그라운드 디코딩 스레드 먼저 중지
     *    - 안전하게 종료
     */
    /**
     * 2. channel = nil
     *    - 채널 메모리 해제
     *    - 디코더 정리
     */
    /**
     * 3. cancellables = nil
     *    - 모든 Combine 구독 취소
     *    - 순환 참조 방지
     * @endcode
     */
    override func tearDownWithError() throws {
        /**
         * 채널 중지
         */
        /**
         * ?: 옵셔널 체이닝
         * channel이 nil이면 호출하지 않음
         */
        /**
         * stop()의 역할:
         * - 디코딩 스레드 중지
         * - 버퍼 초기화
         * - 상태를 idle로 변경
         */
        channel?.stop()

        /**
         * 채널 해제
         */
        /**
         * nil 할당으로 ARC가 메모리 해제
         */
        channel = nil

        /**
         * 채널 정보 해제
         */
        testChannelInfo = nil

        /**
         * Combine 구독 해제
         */
        /**
         * Set을 nil로 설정하면
         * 모든 AnyCancellable이 deinit되어
         * 자동으로 구독이 취소됩니다.
         */
        /**
         *
         * @section _________ 💡 메모리 누수 방지
         * Combine 구독은 강한 참조를 생성하므로
         * 반드시 해제해야 합니다.
         */
        cancellables = nil

        /**
         * 부모 클래스의 tearDown 호출
         */
        super.tearDown()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Initialization Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 채널 초기화 테스트
     */
    /**
     * VideoChannel의 기본 초기화가 올바르게 수행되는지 검증합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 사항
     * @endcode
     * 1. 채널 객체 생성 성공
     * 2. 초기 상태 = .idle
     * 3. 현재 프레임 = nil
     * 4. 채널 정보 저장 확인
     * @endcode
     */
    /**
     *
     * @section ______ 💡 초기화 단계
     * @endcode
     * VideoChannel(channelInfo:)
     * ├── 1. channelInfo 저장
     * ├── 2. 고유 ID 생성 (UUID)
     * ├── 3. 상태를 .idle로 설정
     * ├── 4. 프레임 버퍼 초기화 (빈 버퍼)
     * └── 5. currentFrame = nil
     * @endcode
     */
    /**
     * @test testChannelInitialization
     * @brief ⚠️ 초기화 vs initialize():
     *
     * @details
     *
     * @section ____vs_initialize__ ⚠️ 초기화 vs initialize()
     * - init: 객체 생성만 (메모리 할당)
     * - initialize(): 디코더 준비 (파일 열기)
     */
    func testChannelInitialization() {
        /**
         * Given/When: 채널 생성
         */
        /**
         * testChannelInfo로 새 채널을 생성합니다.
         */
        /**
         *
         * @section ______ 💡 이 시점에는
         * - 객체만 생성됨
         * - 디코더는 아직 초기화 안 됨
         * - 파일은 아직 열지 않음
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 초기화 검증
         */
        /**
         * 4가지 조건을 확인합니다.
         *
         * 1. 채널 객체 생성 성공
         */
        /**
         * XCTAssertNotNil: 객체가 nil이 아닌지 확인
         */
        XCTAssertNotNil(channel, "Channel should be initialized")

        /**
         * 2. 초기 상태가 .idle인지 확인
         */
        /**
         *
         * @section channelstate_idle 💡 ChannelState.idle
         * - 아직 초기화되지 않은 상태
         * - 디코더 미생성
         * - 디코딩 불가능
         */
        XCTAssertEqual(channel.state, .idle, "Initial state should be idle")

        /**
         * 3. 현재 프레임이 nil인지 확인
         */
        /**
         *
         * @section __ 💡 이유
         * - 아직 디코딩하지 않음
         * - 버퍼가 비어있음
         */
        XCTAssertNil(channel.currentFrame, "Current frame should be nil initially")

        /**
         * 4. 채널 정보가 올바르게 저장되었는지 확인
         */
        /**
         * position이 .front인지 검증
         */
        XCTAssertEqual(channel.channelInfo.position, .front, "Channel position should match")
    }

    /**
     * Identifiable 프로토콜 테스트
     */
    /**
     * 각 채널이 고유한 ID를 가지는지 검증합니다.
     */
    /**
     * 🆔 Identifiable 프로토콜이란?
     * @endcode
     * protocol Identifiable {
     *     var id: ID { get }  // 고유 식별자
     * }
     */
    /**
     * SwiftUI의 List, ForEach 등에서 항목을 구분하는 데 사용
     * @endcode
     */
    /**
     *
     * @section videochannel__id 💡 VideoChannel의 ID
     * @endcode
     * class VideoChannel: Identifiable {
     *     let id: UUID = UUID()  // 생성 시 랜덤 UUID
     * }
     * @endcode
     */
    /**
     *
     * @section _____id_______ 🎯 왜 고유 ID가 필요한가?
     * @endcode
     * 멀티 채널 플레이어에서 각 채널을 구분하기 위해
     */
    /**
     * 예시:
     * - 전방 카메라 (ID: 1234-5678)
     * - 후방 카메라 (ID: 9abc-def0)
     * - 측면 카메라 (ID: 1111-2222)
     */
    /**
     * @test testChannelIdentifiable
     * @brief SwiftUI에서 사용:
     *
     * @details
     * SwiftUI에서 사용:
     * ForEach(channels) { channel in
     *     VideoView(channel: channel)
     * }
     * @endcode
     */
    func testChannelIdentifiable() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 같은 정보로 두 채널 생성
         */
        /**
         *
         * @section ___ 💡 포인트
         * - testChannelInfo는 동일
         * - 하지만 각 채널은 독립적인 인스턴스
         */
        let channel1 = VideoChannel(channelInfo: testChannelInfo)
        let channel2 = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> ID가 서로 다른지 확인
         */
        /**
         *
         * @section _____ 💡 예상 동작
         * @endcode
         * channel1.id = UUID("1234-5678-...")
         * channel2.id = UUID("9abc-def0-...")  ← 다름!
         * @endcode
         */
        /**
         * UUID는 초기화 시마다 랜덤 생성되므로
         * 두 채널의 ID는 항상 달라야 합니다.
         */
        XCTAssertNotEqual(channel1.id, channel2.id, "Each channel should have unique ID")
    }

    /**
     * Equatable 프로토콜 테스트
     */
    /**
     * ID 기반 동등성 비교가 올바르게 작동하는지 검증합니다.
     */
    /**
     * ⚖️ Equatable 프로토콜이란?
     * @endcode
     * protocol Equatable {
     *     static func == (lhs: Self, rhs: Self) -> Bool
     * }
     */
    /**
     * == 연산자로 두 객체를 비교 가능하게 만듦
     * @endcode
     */
    /**
     *
     * @section videochannel_____ 💡 VideoChannel의 동등성
     * @endcode
     * extension VideoChannel: Equatable {
     *     static func == (lhs: VideoChannel, rhs: VideoChannel) -> Bool {
     *         return lhs.id == rhs.id  // ID만 비교
     *     }
     * }
     */
    /**
     * 즉, ID가 같으면 같은 채널로 간주
     * @endcode
     */
    /**
     * @test testChannelEquatable
     * @brief 🎯 테스트 시나리오:
     *
     * @details
     *
     * @section ________ 🎯 테스트 시나리오
     * @endcode
     * 1. 같은 ID → 같은 채널 (==)
     * 2. 다른 ID → 다른 채널 (!=)
     * @endcode
     */
    func testChannelEquatable() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 특정 UUID 생성
         */
        /**
         *
         * @section uuid__ 💡 UUID()
         * 랜덤 UUID 생성
         * 예: "550E8400-E29B-41D4-A716-446655440000"
         */
        let channelID = UUID()

        /**
         * 같은 ID로 두 채널 생성
         */
        /**
         * VideoChannel(channelID:channelInfo:) 생성자 사용
         * (ID를 직접 지정 가능)
         */
        /**
         *
         * @section channel1__channel2_ 💡 channel1과 channel2는
         * - 동일한 ID를 공유
         * - 다른 인스턴스
         */
        let channel1 = VideoChannel(channelID: channelID, channelInfo: testChannelInfo)
        let channel2 = VideoChannel(channelID: channelID, channelInfo: testChannelInfo)

        /**
         * 다른 ID로 세 번째 채널 생성
         */
        /**
         * channelID 지정 없이 생성
         * → 자동으로 새 UUID 생성
         */
        let channel3 = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 동등성 검증
         *
         * 1. 같은 ID → 같은 채널
         */
        /**
         * XCTAssertEqual: == 연산자로 비교
         */
        /**
         *
         * @section __ 💡 예상
         * @endcode
         * channel1.id = channelID
         * channel2.id = channelID
         * → channel1 == channel2  ✅
         * @endcode
         */
        XCTAssertEqual(channel1, channel2, "Channels with same ID should be equal")

        /**
         * 2. 다른 ID → 다른 채널
         */
        /**
         *
         * @section __ 💡 예상
         * @endcode
         * channel1.id = channelID
         * channel3.id = 새로운 UUID (다름)
         * → channel1 != channel3  ✅
         * @endcode
         */
        XCTAssertNotEqual(channel1, channel3, "Channels with different IDs should not be equal")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - State Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 상태 전환 테스트
     */
    /**
     * 채널의 초기 상태와 표시 이름을 검증합니다.
     */
    /**
     *
     * @section channelstate_enum 🔄 ChannelState Enum
     * @endcode
     * enum ChannelState: Equatable {
     *     case idle         // 유휴: 초기 상태
     *     case ready        // 준비: 디코더 초기화 완료
     *     case decoding     // 디코딩 중: 프레임 생성 중
     *     case completed    // 완료: 비디오 끝
     *     case error(String) // 에러: 실패 (메시지 포함)
     * }
     * @endcode
     */
    /**
     *
     * @section ________ 💡 상태 전환 흐름
     * @endcode
     * Idle
     *  ↓ initialize()
     * Ready
     *  ↓ startDecoding()
     * Decoding
     *  ↓ 비디오 끝 or stop()
     * Completed
     */
    /**
     * 어느 상태에서든:
     *  ↓ 에러 발생
     * Error
     * @endcode
     */
    /**
     * @test testStateTransitions
     * @brief 🎯 displayName 속성:
     *
     * @details
     *
     * @section displayname___ 🎯 displayName 속성
     * UI에 표시할 사용자 친화적인 문자열
     */
    func testStateTransitions() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 생성 직후의 상태를 확인합니다.
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 초기 상태 검증
         *
         * 1. 상태가 .idle인지 확인
         */
        /**
         *
         * @section ___________idle 💡 초기 상태는 항상 .idle
         * - 디코더 미초기화
         * - 디코딩 불가능
         * - initialize() 대기 중
         */
        XCTAssertEqual(channel.state, .idle, "Initial state should be idle")

        /**
         * 2. 표시 이름 확인
         */
        /**
         *
         * @section displayname______ 💡 displayName 계산 속성
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
     * 상태 표시 이름 테스트
     */
    /**
     * 모든 ChannelState 케이스의 displayName을 검증합니다.
     */
    /**
     * 🏷️ 테스트 대상:
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
     * @section _____________ 💡 이 테스트가 중요한 이유
     * - UI에 상태를 표시할 때 사용
     * - 로그 메시지에 사용
     * - 디버깅 시 가독성 향상
     */
    /**
     * @test testStateDisplayNames
     * @brief 📱 UI 사용 예시:
     *
     * @details
     * 📱 UI 사용 예시:
     * @endcode
     * Text("Status: \(channel.state.displayName)")
     * // "Status: Decoding" 표시
     * @endcode
     */
    func testStateDisplayNames() {
        /**
         * 모든 상태의 표시 이름 테스트
         */
        /**
         *
         * @section _________________ 💡 각 케이스를 직접 생성하여 검증
         *
         * 1. Idle 상태
         */
        /**
         * 초기 상태, 아직 초기화 안 됨
         */
        XCTAssertEqual(ChannelState.idle.displayName, "Idle")

        /**
         * 2. Ready 상태
         */
        /**
         * initialize() 완료, 디코딩 준비 완료
         */
        XCTAssertEqual(ChannelState.ready.displayName, "Ready")

        /**
         * 3. Decoding 상태
         */
        /**
         * startDecoding() 후, 프레임 생성 중
         */
        XCTAssertEqual(ChannelState.decoding.displayName, "Decoding")

        /**
         * 4. Completed 상태
         */
        /**
         * 비디오 끝까지 디코딩 완료
         */
        XCTAssertEqual(ChannelState.completed.displayName, "Completed")

        /**
         * 5. Error 상태
         */
        /**
         * 에러 발생, associated value로 메시지 전달
         */
        /**
         *
         * @section enum_with_associated_values 💡 Enum with Associated Values
         * @endcode
         * case error(String)  // String을 저장
         * @endcode
         */
        /**
         *
         * @section displayname___ 💡 displayName 구현
         * @endcode
         * case .error(let message):
         *     return "Error: \(message)"
         * @endcode
         */
        XCTAssertEqual(ChannelState.error("test").displayName, "Error: test")
    }

    /**
     * 상태 발행 테스트
     */
    /**
     * Combine의 @Published를 통한 상태 변경 알림을 검증합니다.
     */
    /**
     * 📡 @Published 속성:
     * @endcode
     * class VideoChannel {
     *     @Published var state: ChannelState = .idle
     * }
     * @endcode
     */
    /**
     *
     * @section _published____ 💡 @Published의 동작
     * - 값이 변경되면 자동으로 Publisher가 새 값을 발행
     * - $state로 Publisher에 접근
     * - Subscriber들이 변경을 감지
     */
    /**
     *
     * @section reactive___ 🔄 Reactive 패턴
     * @endcode
     * VideoChannel (Publisher)
     *       ↓ state 변경
     *   Combine Framework
     *       ↓ 이벤트 전달
     *    UI / Logic (Subscriber)
     * @endcode
     */
    /**
     * @test testStatePublishing
     * @brief 🎯 비동기 테스트 패턴:
     *
     * @details
     *
     * @section __________ 🎯 비동기 테스트 패턴
     * XCTestExpectation을 사용하여 비동기 이벤트를 검증합니다.
     */
    func testStatePublishing() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널과 비동기 기대값 설정
         */
        /**
         * 채널 생성
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * XCTestExpectation 생성
         */
        /**
         *
         * @section xctestexpectation 💡 XCTestExpectation
         * 비동기 작업의 완료를 기다리는 객체
         */
        /**
         * @endcode
         * let exp = expectation(description: "작업 설명")
         * // ... 비동기 작업 ...
         * exp.fulfill()  // 완료 신호
         * waitForExpectations(timeout: 1.0)  // 대기
         * @endcode
         */
        let expectation = expectation(description: "State change published")

        /**
         * 수신한 상태들을 저장할 배열
         */
        /**
         *
         * @section __ 💡 이유
         * - 상태 변경 횟수 추적
         * - 상태 변경 순서 확인 가능
         */
        var receivedStates: [ChannelState] = []

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 상태 변경 구독
         */
        /**
         *
         * @section _____ 💡 구독 체인
         * @endcode
         * channel.$state      // Publisher<ChannelState, Never>
         *   .sink { state in  // Subscriber
         *       // state: 새로운 상태 값
         *   }
         *   .store(in: &cancellables)  // 구독 저장
         * @endcode
         *
         * $state: Publisher에 접근
         */
        /**
         *
         * @section __prefix 💡 $ prefix
         * @Published 속성의 Publisher를 가져옴
         * @endcode
         * @Published var state: ChannelState  // 값
         * $state                              // Publisher
         * @endcode
         */
        channel.$state
            /**
             * .sink: Subscriber 생성
             */
            ///
            /**
             * 클로저가 값을 받을 때마다 실행됨
             */
            ///
            /**
             *
             * @section ____ 💡 파라미터
             * - state: 새로 발행된 상태 값
             */
            ///
            /**
             *
             * @section __ 💡 반환
             * - AnyCancellable: 구독 취소 토큰
             */
            .sink { state in
                /**
                 * 받은 상태를 배열에 추가
                 */
                receivedStates.append(state)

                /**
                 * 2개 이상 받으면 완료
                 */
                ///
                /**
                 *
                 * @section __2__ 💡 왜 2개?
                 * 1. 초기 값 (.idle)
                 * 2. 첫 번째 변경
                 */
                ///
                /**
                 *
                 * @section ____ 💡 실제로는
                 * 이 테스트에서는 상태 변경이 없어
                 * 초기 값만 받음 (1개)
                 */
                if receivedStates.count >= 2 {
                    /**
                     * fulfill(): 기대값 충족
                     */
                    ///
                    /**
                     * 비동기 작업 완료 신호
                     */
                    expectation.fulfill()
                }
            }
            /**
             * .store(in:): 구독 저장
             */
            ///
            /**
             * cancellables Set에 추가
             * tearDown에서 자동 취소됨
             */
            ///
            /**
             *
             * @section ___inout_____ 💡 &: inout 파라미터
             * Set을 직접 수정
             */
            .store(in: &cancellables)

        /**
         * 상태 변경 시뮬레이션 생략
         */
        /**
         *
         * @section __ ⚠️ 주의
         * 이 테스트는 구독 패턴을 보여주는 예시입니다.
         * 실제 상태 변경은 실제 디코더가 필요합니다.
         */
        /**
         *
         * @section _______ 💡 실제 사용 예
         * @endcode
         * channel.initialize()  // .idle → .ready
         * channel.startDecoding()  // .ready → .decoding
         * @endcode
         *
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 비동기 대기
         */
        /**
         * waitForExpectations: 기대값 충족까지 대기
         */
        /**
         *
         * @section ____ 💡 파라미터
         * - timeout: 최대 대기 시간 (초)
         */
        /**
         *
         * @section __ 💡 동작
         * - expectation.fulfill() 호출되면 성공
         * - timeout 초과하면 실패
         */
        /**
         *
         * @section ______ ⚠️ 이 테스트는
         * 실제 상태 변경이 없어서
         * timeout으로 종료될 수 있음
         * (패턴 시연용 테스트)
         */
        waitForExpectations(timeout: 1.0)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Buffer Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 초기 버퍼 상태 테스트
     */
    /**
     * 채널 생성 직후 버퍼 상태를 검증합니다.
     */
    /**
     * 📦 프레임 버퍼란?
     * @endcode
     * 디코딩된 비디오 프레임을 저장하는 메모리 구조
     */
    /**
     * 구조:
     * [Frame 1] [Frame 2] [Frame 3] ... [Frame 30]
     *  ↑ 가장 오래된           ↑ 가장 최신
     */
    /**
     * 특징:
     * - 최대 30개 프레임 저장
     * - 오래된 프레임 자동 제거 (FIFO)
     * - 빠른 타임스탬프 기반 조회
     * @endcode
     */
    /**
     *
     * @section bufferstatus___ 💡 BufferStatus 구조
     * @endcode
     * struct BufferStatus {
     *     let current: Int           // 현재 프레임 개수
     *     let max: Int              // 최대 용량
     *     let fillPercentage: Double // 채워진 비율 (0.0~1.0)
     * }
     * @endcode
     */
    /**
     * @test testInitialBufferStatus
     * @brief 🎯 왜 버퍼가 필요한가?
     *
     * @details
     *
     * @section ___________ 🎯 왜 버퍼가 필요한가?
     * - 부드러운 재생을 위한 프레임 미리 준비
     * - 빠른 탐색 (이미 디코딩된 프레임 재사용)
     * - 디코딩과 렌더링의 비동기 처리
     */
    func testInitialBufferStatus() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 아직 디코딩 시작 전
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 버퍼 상태 조회
         */
        /**
         * getBufferStatus(): BufferStatus 반환
         */
        /**
         *
         * @section __ 💡 동작
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
         * - <b>Then:</b> 초기 버퍼 상태 검증
         *
         * 1. 현재 프레임 개수 = 0
         */
        /**
         *
         * @section _____ 💡 초기 상태
         * 아직 디코딩하지 않아서 비어있음
         */
        XCTAssertEqual(status.current, 0, "Buffer should be empty initially")

        /**
         * 2. 최대 크기 = 30
         */
        /**
         *
         * @section 30_______ 💡 30개 제한 이유
         * - 메모리 사용량 제한
         * - 30 fps * 1초 = 약 1초분량
         * - 충분한 버퍼링 + 메모리 효율
         */
        XCTAssertEqual(status.max, 30, "Max buffer size should be 30")

        /**
         * 3. 채움 비율 = 0%
         */
        /**
         *
         * @section __ 💡 계산
         * fillPercentage = current / max
         *                = 0 / 30
         *                = 0.0
         */
        XCTAssertEqual(status.fillPercentage, 0.0, "Fill percentage should be 0%")
    }

    /**
     * 버퍼 초기화 테스트
     */
    /**
     * flushBuffer() 메서드가 버퍼를 올바르게 비우는지 검증합니다.
     */
    /**
     * 🚽 flushBuffer()의 역할:
     * @endcode
     * 버퍼에 저장된 모든 프레임을 제거
     */
    /**
     * 사용 시점:
     * 1. stop() 호출 시
     * 2. seek() 호출 시 (새 위치로 이동)
     * 3. 에러 발생 시
     * @endcode
     */
    /**
     *
     * @section __ 💡 구현
     * @endcode
     * func flushBuffer() {
     *     lock.lock()
     *     defer { lock.unlock() }
     *     buffer.removeAll()  // 모든 프레임 제거
     *     currentFrame = nil
     * }
     * @endcode
     */
    /**
     * @test testFlushBuffer
     * @brief 🎯 왜 Flush가 필요한가?
     *
     * @details
     *
     * @section __flush_______ 🎯 왜 Flush가 필요한가?
     * - Seek 시 오래된 프레임 제거
     * - 메모리 절약
     * - 상태 초기화
     */
    func testFlushBuffer() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * (실제로는 버퍼에 프레임이 있어야 의미있지만,
         *  여기서는 빈 버퍼에서도 정상 작동 확인)
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 버퍼 초기화 + 상태 조회
         */
        /**
         * 순서:
         * 1. flushBuffer() 호출
         * 2. getBufferStatus() 호출
         */
        channel.flushBuffer()
        let status = channel.getBufferStatus()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 버퍼가 비었는지 확인
         */
        /**
         *
         * @section __ 💡 예상
         * current = 0 (모든 프레임 제거됨)
         */
        /**
         *
         * @section _______ 💡 실제 사용 예
         * @endcode
         * // 50프레임이 버퍼에 있음
         * channel.seek(to: 10.0)  // 10초로 이동
         * // flushBuffer() 자동 호출
         * // → 이전 프레임 모두 제거
         * // → 10초부터 새로 디코딩
         * @endcode
         */
        XCTAssertEqual(status.current, 0, "Buffer should be empty after flush")
    }

    /**
     * 빈 버퍼에서 프레임 가져오기 테스트
     */
    /**
     * 버퍼가 비어있을 때 getFrame(at:) 동작을 검증합니다.
     */
    /**
     *
     * @section getframe_at______ 🔍 getFrame(at:) 메서드
     * @endcode
     * func getFrame(at timestamp: TimeInterval) -> VideoFrame?
     * @endcode
     */
    /**
     *
     * @section __ 💡 동작
     * @endcode
     * 1. 버퍼에서 timestamp에 가장 가까운 프레임 찾기
     * 2. 프레임 반환
     * 3. 없으면 nil 반환
     */
    /**
     * 검색 알고리즘:
     * - 이진 검색 사용 (O(log n))
     * - timestamp 기준 정렬된 버퍼
     * @endcode
     */
    /**
     *
     * @section timeinterval 📝 TimeInterval
     * @endcode
     * typealias TimeInterval = Double
     * // 초 단위 시간 (예: 1.5 = 1.5초)
     * @endcode
     */
    /**
     * @test testGetFrameFromEmptyBuffer
     * @brief 🎯 사용 예시:
     *
     * @details
     *
     * @section _____ 🎯 사용 예시
     * @endcode
     * // 1.0초 시점의 프레임 가져오기
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
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 버퍼가 비어있는 상태
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 프레임 조회
         */
        /**
         * 1.0초 시점의 프레임 요청
         */
        /**
         *
         * @section _____ 💡 버퍼 상태
         * @endcode
         * Buffer: []  ← 비어있음
         * 요청: 1.0초 프레임
         * @endcode
         */
        let frame = channel.getFrame(at: 1.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> nil 반환 확인
         */
        /**
         * XCTAssertNil: 값이 nil인지 확인
         */
        /**
         *
         * @section _____ 💡 예상 동작
         * - 버퍼가 비어있음
         * - 검색 불가
         * - nil 반환
         */
        /**
         *
         * @section nil________ ⚠️ nil은 에러가 아님
         * 버퍼에 프레임이 없는 정상 상태
         */
        XCTAssertNil(frame, "Should return nil when buffer is empty")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Error Handling Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 존재하지 않는 파일로 초기화 테스트
     */
    /**
     * 잘못된 파일 경로로 initialize() 호출 시 에러 처리를 검증합니다.
     */
    /**
     *
     * @section ______ 🎯 테스트 목적
     * - 파일 오류 감지
     * - 적절한 에러 발생
     * - 안전한 실패 처리
     */
    /**
     *
     * @section initialize______ 💡 initialize() 메서드
     * @endcode
     * func initialize() throws {
     *     // 1. 파일 존재 확인
     *     // 2. VideoDecoder 생성
     *     // 3. 파일 열기
     *     // 4. 상태를 .ready로 변경
     * }
     * @endcode
     */
    /**
     * ❌ 실패 시나리오:
     * @endcode
     * 파일 경로: "/path/to/test/video.mp4"
     *         ↓ 파일 없음
     * VideoDecoder.open() 실패
     *         ↓
     * DecoderError.fileNotFound 또는
     * DecoderError.openFailed 발생
     * @endcode
     */
    /**
     * @test testInitializeWithNonExistentFile
     * @brief 🔍 XCTAssertThrowsError:
     *
     * @details
     *
     * @section xctassertthrowserror 🔍 XCTAssertThrowsError
     * throwing 함수가 에러를 발생시키는지 검증
     */
    func testInitializeWithNonExistentFile() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 잘못된 경로로 채널 생성
         */
        /**
         * testChannelInfo의 filePath는
         * "/path/to/test/video.mp4" (존재하지 않음)
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: 초기화 시도 및 에러 확인
         */
        /**
         * XCTAssertThrowsError의 동작:
         * @endcode
         * XCTAssertThrowsError(
         *     try 테스트할코드(),    // 에러 발생 예상
         *     "실패 메시지"
         * ) { error in
         *     // 발생한 에러 검사
         * }
         * @endcode
         */
        /**
         *
         * @section _____ 💡 예상 동작
         * 1. channel.initialize() 호출
         * 2. VideoDecoder가 파일 열기 시도
         * 3. 파일 없음 → Error throw
         * 4. 테스트 성공
         */
        /**
         *
         * @section __________ ⚠️ 에러 발생 안 하면
         * 테스트 실패 (파일 검증 누락)
         */
        XCTAssertThrowsError(try channel.initialize()) { error in
            /**
             * 발생한 에러 타입 확인
             */
            ///
            /**
             *
             * @section _____ 💡 예상 에러
             * - DecoderError.fileNotFound
             * - DecoderError.openFailed
             * - 기타 파일 관련 에러
             */
            ///
            /**
             *
             * @section ___________ 📝 에러 타입 확인 예시
             * @endcode
             * if case DecoderError.fileNotFound = error {
             *     // 예상된 에러
             * } else {
             *     XCTFail("Unexpected error: \(error)")
             * }
             * @endcode
             */
            // Should throw decoder error for non-existent file
        }
    }

    /**
     * 초기화 없이 seek 테스트
     */
    /**
     * initialize()를 호출하지 않고 seek()를 호출했을 때
     * 적절한 에러 처리를 검증합니다.
     */
    /**
     * 🚫 잘못된 사용 패턴:
     * @endcode
     * let channel = VideoChannel(...)
     * try channel.seek(to: 5.0)  // ❌ initialize() 먼저 필요!
     * @endcode
     */
    /**
     *
     * @section _________ ✅ 올바른 사용 패턴
     * @endcode
     * let channel = VideoChannel(...)
     * try channel.initialize()   // 1. 먼저 초기화
     * try channel.seek(to: 5.0)  // 2. 그 다음 seek
     * @endcode
     */
    /**
     *
     * @section channelerror_notinitialized 💡 ChannelError.notInitialized
     * @endcode
     * enum ChannelError: Error {
     *     case notInitialized  // 초기화되지 않음
     *     case invalidState    // 잘못된 상태
     *     case decoderError    // 디코더 에러
     * }
     * @endcode
     */
    /**
     * @test testSeekWithoutInitialization
     * @brief 🔍 if case 패턴 매칭:
     *
     * @details
     *
     * @section if_case______ 🔍 if case 패턴 매칭
     * enum 케이스를 매칭하는 Swift 문법
     */
    func testSeekWithoutInitialization() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화하지 않은 채널
         */
        /**
         * 채널 생성만 하고 initialize() 호출 안 함
         */
        /**
         *
         * @section __ 💡 상태
         * - state = .idle
         * - decoder = nil
         * - seek 불가능
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: seek 시도 및 에러 확인
         */
        /**
         * 5.0초 위치로 이동 시도
         */
        /**
         *
         * @section _____ 💡 예상 동작
         * @endcode
         * channel.seek(to: 5.0)
         *     ↓ state가 .idle?
         *     ↓ decoder가 nil?
         * throw ChannelError.notInitialized
         * @endcode
         */
        XCTAssertThrowsError(try channel.seek(to: 5.0)) { error in
            /**
             * 에러 타입 확인
             */
            ///
            /**
             * if case: enum 패턴 매칭
             */
            ///
            /**
             *
             * @section __ 💡 문법
             * @endcode
             * if case PatternType.case = value {
             *     // 매칭 성공
             * }
             * @endcode
             */
            ///
            /**
             *
             * @section __ 💡 예시
             * @endcode
             * let error: Error = ChannelError.notInitialized
             * if case ChannelError.notInitialized = error {
             *     print("예상된 에러")  // ✅
             * }
             * @endcode
             */
            if case ChannelError.notInitialized = error {
                /**
                 * 예상된 에러 발생
                 */
                ///
                /**
                 * notInitialized 에러가 맞음
                 * 테스트 통과
                 */
                // Expected error
            } else {
                /**
                 * 예상치 못한 에러
                 */
                ///
                /**
                 * XCTFail: 테스트 강제 실패
                 */
                ///
                /**
                 *
                 * @section __ 💡 이유
                 * notInitialized가 아닌 다른 에러 발생
                 * → 에러 처리 로직 문제
                 */
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    /**
     * 중복 초기화 테스트
     */
    /**
     * initialize()를 두 번 호출했을 때의 에러 처리를 검증합니다.
     */
    /**
     * 🚫 잘못된 사용 패턴:
     * @endcode
     * try channel.initialize()  // 1차 초기화
     * try channel.initialize()  // ❌ 중복 초기화!
     * @endcode
     */
    /**
     *
     * @section _____ 💡 예상 동작
     * @endcode
     * 1차 initialize()
     *     ↓
     * state = .ready
     *     ↓
     * 2차 initialize() 시도
     *     ↓
     * state가 .idle이 아님
     *     ↓
     * throw ChannelError.invalidState
     * @endcode
     */
    /**
     *
     * @section ____ ⚠️ 주의사항
     * - 이 테스트는 실제 비디오 파일 필요
     * - 유효한 파일로 initialize() 성공해야 함
     * - 현재는 stub (구현 예정)
     */
    /**
     *
     * @section _________ 🎯 구현 시 확인사항
     * @endcode
     * // Given: 유효한 파일로 채널 생성
     * let bundle = Bundle(for: type(of: self))
     * let videoPath = bundle.path(forResource: "test", ofType: "mp4")!
     * let info = ChannelInfo(position: .front, filePath: videoPath, ...)
     * channel = VideoChannel(channelInfo: info)
     */
    /**
     * // When: 첫 번째 초기화 성공
     * try channel.initialize()  // ✅
     * XCTAssertEqual(channel.state, .ready)
     */
    /**
     * @test testDoubleInitialization
     * @brief // Then: 두 번째 초기화 실패
     *
     * @details
     * // Then: 두 번째 초기화 실패
     * XCTAssertThrowsError(try channel.initialize()) { error in
     *     if case ChannelError.invalidState = error {
     *         // 예상된 에러
     *     } else {
     *         XCTFail("Expected invalidState error")
     *     }
     * }
     * @endcode
     */
    func testDoubleInitialization() {
        /**
         *
         * @section ________________________ ⚠️ 이 테스트는 실제 비디오 파일이 필요합니다.
         */
        /**
         *
         * @section _____ 💡 구현 방법
         * 1. 테스트 번들에 test_video.mp4 추가
         * 2. Bundle에서 파일 경로 가져오기
         * 3. 첫 번째 initialize() 호출
         * 4. 두 번째 initialize() 호출 시 에러 확인
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
     * 동시 버퍼 접근 테스트
     */
    /**
     * 여러 스레드에서 동시에 버퍼에 접근할 때
     * 스레드 안전성을 검증합니다.
     */
    /**
     * 🔒 스레드 안전성(Thread Safety)이란?
     * @endcode
     * 여러 스레드가 동시에 같은 데이터에 접근해도
     * 데이터 손상이나 크래시가 발생하지 않는 성질
     */
    /**
     * 문제 상황 (스레드 안전하지 않을 때):
     * Thread 1: buffer.count 읽기 → 5
     * Thread 2: buffer.removeAll() → 버퍼 비움
     * Thread 1: buffer[5] 접근 → ❌ 크래시!
     * @endcode
     */
    /**
     * 🛡️ 보호 메커니즘:
     * @endcode
     * class VideoChannel {
     *     private let lock = NSLock()
     */
    /**
     *     func getBufferStatus() -> BufferStatus {
     *         lock.lock()          // 1. 잠금
     *         defer { lock.unlock() }  // 2. 종료 시 해제
     */
    /**
     *         // 3. 안전한 데이터 접근
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
     * 여러 스레드에서 동시에 작업 수행
     */
    func testConcurrentBufferAccess() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성 및 반복 횟수 설정
         */
        /**
         * 빈 채널 준비
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * 100번 반복
         */
        /**
         *
         * @section __ 💡 이유
         * - 충분한 동시성 테스트
         * - 경쟁 조건(race condition) 발견 가능
         */
        let iterations = 100

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 여러 스레드에서 동시 접근
         */
        /**
         * concurrentPerform: 동시 실행
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * Thread 1: 반복 0, 1, 2, ...
         * Thread 2: 반복 10, 11, 12, ...
         * Thread 3: 반복 20, 21, 22, ...
         * ...
         * 모든 반복이 동시에 실행됨
         * @endcode
         */
        /**
         *
         * @section ____ 📝 파라미터
         * - iterations: 총 반복 횟수
         * - _ in: 각 반복의 인덱스 (사용 안 함)
         */
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            /**
             * 버퍼 상태 조회
             */
            ///
            /**
             *
             * @section ______________ 💡 스레드 안전성 검증 포인트
             * - buffer.count 읽기
             * - 동시에 다른 스레드가 버퍼 수정
             */
            _ = channel.getBufferStatus()

            /**
             * 버퍼 초기화
             */
            ///
            /**
             *
             * @section ______________ 💡 스레드 안전성 검증 포인트
             * - buffer.removeAll() 호출
             * - 동시에 다른 스레드가 버퍼 읽기
             */
            channel.flushBuffer()
        }

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 크래시 없이 완료 확인
         */
        /**
         *
         * @section _________ 💡 테스트 통과 조건
         * - 크래시 발생 안 함
         * - 데이터 손상 없음
         * - 최종 버퍼 상태 일관성 유지
         */
        /**
         * 최종 상태 확인
         */
        let finalStatus = channel.getBufferStatus()

        /**
         * 버퍼가 비어있어야 함
         */
        /**
         *
         * @section __ 💡 이유
         * 모든 flushBuffer() 호출이 완료됨
         * → 버퍼는 비어있어야 정상
         */
        XCTAssertEqual(finalStatus.current, 0)
    }

    /**
     * 동시 프레임 조회 테스트
     */
    /**
     * 여러 스레드에서 동시에 getFrame()을 호출할 때
     * 스레드 안전성을 검증합니다.
     */
    /**
     *
     * @section ________ 🔍 테스트 시나리오
     * @endcode
     * Thread 1: getFrame(at: 0.0)
     * Thread 2: getFrame(at: 1.0)
     * Thread 3: getFrame(at: 2.0)
     * ...
     * Thread 100: getFrame(at: 99.0)
     */
    /**
     * 모두 동시 실행
     * @endcode
     */
    /**
     *
     * @section getframe___________ 💡 getFrame()의 스레드 안전성
     * @endcode
     * func getFrame(at timestamp: TimeInterval) -> VideoFrame? {
     *     lock.lock()
     *     defer { lock.unlock() }
     */
    /**
     *     // 버퍼 검색 (이진 탐색)
     *     return buffer.first { ... }
     * }
     * @endcode
     */
    /**
     * @test testConcurrentGetFrame
     * @brief 🎯 검증 포인트:
     *
     * @details
     *
     * @section ______ 🎯 검증 포인트
     * - 동시 읽기 작업의 안전성
     * - 버퍼 접근 중 크래시 방지
     * - 일관된 검색 결과
     */
    func testConcurrentGetFrame() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 빈 버퍼 상태
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 여러 스레드에서 동시에 프레임 조회
         */
        /**
         * 100개 스레드에서 동시 실행
         */
        /**
         *
         * @section __________timestamp___ 💡 각 스레드가 다른 timestamp 조회
         * @endcode
         * Thread 0: getFrame(at: 0.0)
         * Thread 1: getFrame(at: 1.0)
         * Thread 2: getFrame(at: 2.0)
         * ...
         * @endcode
         */
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            /**
             * index를 Double로 변환
             */
            ///
            /**
             * 예: index=5 → timestamp=5.0
             */
            _ = channel.getFrame(at: Double(index))
        }

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 크래시 없이 완료
         */
        /**
         * XCTAssertNotNil: 채널 객체가 유효한지 확인
         */
        /**
         *
         * @section _________ 💡 테스트 통과 의미
         * - 100번의 동시 조회에서 크래시 없음
         * - 데이터 경쟁 조건 없음
         * - 스레드 안전성 확보
         */
        /**
         *
         * @section __ ⚠️ 주의
         * 버퍼가 비어있으므로 모든 getFrame()은 nil 반환
         * (정상 동작)
         */
        XCTAssertNotNil(channel)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Memory Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 채널 deinit 테스트
     */
    /**
     * VideoChannel이 메모리에서 해제될 때
     * 올바르게 정리되는지 검증합니다.
     */
    /**
     *
     * @section arc__automatic_reference_counting_ 💾 ARC (Automatic Reference Counting)
     * @endcode
     * Swift의 자동 메모리 관리 시스템
     */
    /**
     * 객체 생성:
     * let channel = VideoChannel(...)  // 참조 횟수 = 1
     */
    /**
     * 참조 증가:
     * let ref2 = channel  // 참조 횟수 = 2
     */
    /**
     * 참조 감소:
     * ref2 = nil  // 참조 횟수 = 1
     * channel = nil  // 참조 횟수 = 0 → deinit 호출
     * @endcode
     */
    /**
     * 🧹 deinit의 역할:
     * @endcode
     * class VideoChannel {
     *     deinit {
     *         // 1. 디코딩 스레드 중지
     *         stop()
     */
    /**
     *         // 2. 버퍼 정리
     *         buffer.removeAll()
     */
    /**
     *         // 3. Combine 구독 취소
     *         cancellables.removeAll()
     */
    /**
     *         // 4. 디코더 해제
     *         decoder = nil
     *     }
     * }
     * @endcode
     */
    /**
     * @test testChannelDeinit
     * @brief 🔍 메모리 누수 검증 도구:
     *
     * @details
     *
     * @section ____________ 🔍 메모리 누수 검증 도구
     * - Instruments (Leaks, Allocations)
     * - Memory Graph Debugger
     */
    func testChannelDeinit() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 로컬 변수로 채널 생성
         */
        /**
         * var: 변경 가능한 변수
         * ?: 옵셔널 타입
         */
        /**
         *
         * @section __ 💡 이유
         * - nil 할당 가능
         * - 참조 횟수 제어 가능
         */
        var testChannel: VideoChannel? = VideoChannel(channelInfo: testChannelInfo)

        /**
         * 채널이 생성되었는지 확인
         */
        /**
         *
         * @section ____ 💡 이 시점
         * - testChannel 참조 횟수 = 1
         * - 메모리 할당됨
         */
        XCTAssertNotNil(testChannel)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 채널 해제
         */
        /**
         * nil 할당으로 참조 해제
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * testChannel = nil
         *     ↓
         * 참조 횟수 = 0
         *     ↓
         * ARC가 deinit 호출
         *     ↓
         * 메모리 해제
         * @endcode
         */
        testChannel = nil

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> nil 확인
         */
        /**
         *
         * @section _____ 💡 검증 사항
         * - 변수가 nil로 설정됨
         * - deinit이 정상 호출됨 (크래시 없음)
         * - 리소스가 정리됨
         */
        /**
         *
         * @section __________ ⚠️ 실제 메모리 누수는
         * Instruments 도구로 확인해야 함
         * (이 테스트는 기본 동작만 확인)
         */
        XCTAssertNil(testChannel)
    }

    /**
     * stop() 리소스 정리 테스트
     */
    /**
     * stop() 메서드가 모든 리소스를 올바르게 정리하는지 검증합니다.
     */
    /**
     * 🛑 stop() 메서드의 역할:
     * @endcode
     * func stop() {
     *     // 1. 디코딩 스레드 중지
     *     decodingQueue.async {
     *         self.shouldStop = true
     *     }
     */
    /**
     *     // 2. 버퍼 초기화
     *     flushBuffer()
     */
    /**
     *     // 3. 현재 프레임 제거
     *     currentFrame = nil
     */
    /**
     *     // 4. 상태를 idle로 변경
     *     state = .idle
     * }
     * @endcode
     */
    /**
     *
     * @section _____ 🎯 사용 시점
     * - 비디오 재생 중지
     * - 새 비디오 로드 전
     * - 앱 종료 전
     * - 에러 발생 시
     */
    /**
     * @test testStopCleansResources
     * @brief 💡 stop() vs deinit:
     *
     * @details
     *
     * @section stop___vs_deinit 💡 stop() vs deinit
     * - stop(): 수동 호출, 재사용 가능
     * - deinit: 자동 호출, 객체 소멸
     */
    func testStopCleansResources() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 초기 상태로 채널 준비
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> stop() 호출
         */
        /**
         * 리소스 정리 실행
         */
        /**
         *
         * @section _____ 💡 내부 동작
         * @endcode
         * stop()
         *   ↓ 디코딩 중지
         *   ↓ 버퍼 비우기
         *   ↓ 상태 초기화
         * 완료
         * @endcode
         */
        channel.stop()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 정리 상태 검증
         *
         * 1. 상태가 .idle인지 확인
         */
        /**
         *
         * @section stop_______ 💡 stop() 후 상태
         * 항상 .idle로 돌아감
         */
        XCTAssertEqual(channel.state, .idle)

        /**
         * 2. 현재 프레임이 nil인지 확인
         */
        /**
         *
         * @section __ 💡 이유
         * stop()에서 currentFrame = nil 설정
         */
        XCTAssertNil(channel.currentFrame)

        /**
         * 3. 버퍼가 비었는지 확인
         */
        /**
         * getBufferStatus() 호출하여 상태 확인
         */
        let status = channel.getBufferStatus()

        /**
         * 버퍼 카운트 = 0
         */
        /**
         *
         * @section __ 💡 이유
         * stop()이 flushBuffer() 호출함
         */
        XCTAssertEqual(status.current, 0, "Buffer should be empty after stop")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Performance Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 버퍼 상태 조회 성능 테스트
     */
    /**
     * getBufferStatus() 메서드의 성능을 측정합니다.
     */
    /**
     * ⏱️ measure { } 블록:
     * @endcode
     * XCTest의 성능 측정 도구
     */
    /**
     * 동작:
     * 1. 블록을 10회 실행
     * 2. 각 실행 시간 측정
     * 3. 평균, 표준편차 계산
     * 4. 기준치와 비교
     * @endcode
     */
    /**
     *
     * @section _____ 💡 성능 기준
     * @endcode
     * getBufferStatus()는 매 프레임마다 호출 가능
     * → 매우 빠르게 실행되어야 함
     * → 목표: 1000회 호출에 < 10ms
     * @endcode
     */
    /**
     *
     * @section ________ 📊 측정 결과 예시
     * @endcode
     * Average: 5.234 ms
     * Relative standard deviation: 3.2%
     * Baseline: 5.0 ms
     * @endcode
     */
    /**
     * @test testBufferStatusPerformance
     * @brief 🎯 성능 최적화 포인트:
     *
     * @details
     *
     * @section __________ 🎯 성능 최적화 포인트
     * - NSLock 사용 (빠른 잠금)
     * - 간단한 계산만 수행
     * - 메모리 할당 최소화
     */
    func testBufferStatusPerformance() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 빈 버퍼 상태
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: 성능 측정
         */
        /**
         * measure: 성능 측정 블록
         */
        /**
         *
         * @section __ 💡 동작
         * 이 블록이 10회 반복 실행되고
         * 각 실행 시간이 측정됩니다
         */
        measure {
            /**
             * 1000회 버퍼 상태 조회
             */
            ///
            /**
             *
             * @section 1000____ 💡 1000회 이유
             * - 통계적으로 의미있는 측정
             * - 실제 사용 패턴 시뮬레이션
             * - 성능 병목 지점 발견
             */
            for _ in 0..<1000 {
                /**
                 * 버퍼 상태 조회
                 */
                ///
                /**
                 * _: 결과 무시 (사용 안 함)
                 */
                ///
                /**
                 *
                 * @section _____ 💡 측정 대상
                 * - lock/unlock 오버헤드
                 * - buffer.count 접근
                 * - BufferStatus 생성
                 * - fillPercentage 계산
                 */
                _ = channel.getBufferStatus()
            }
        }

        /**
         *
         * @section _____ 💡 결과 확인
         * Xcode 테스트 레포트에서 확인
         * - Average: 평균 실행 시간
         * - Std Dev: 표준 편차
         * - Set Baseline: 기준치 설정 가능
         */
    }

    /**
     * 프레임 조회 성능 테스트
     */
    /**
     * getFrame(at:) 메서드의 성능을 측정합니다.
     */
    /**
     *
     * @section getframe________ 🔍 getFrame() 성능 특성
     * @endcode
     * 빈 버퍼: O(1) - 즉시 nil 반환
     * 가득 찬 버퍼: O(log n) - 이진 탐색
     */
    /**
     * 최악의 경우:
     * - 버퍼 30개
     * - 이진 탐색: log₂(30) ≈ 5 단계
     * @endcode
     */
    /**
     *
     * @section 0_033____ 💡 0.033초 간격
     * @endcode
     * 30 fps 비디오의 프레임 간격
     * 1초 / 30 프레임 = 0.033초
     */
    /**
     * 테스트 패턴:
     * frame 0: 0.000초
     * frame 1: 0.033초
     * frame 2: 0.066초
     * ...
     * @endcode
     */
    /**
     * @test testGetFramePerformance
     * @brief 🎯 성능 목표:
     *
     * @details
     *
     * @section _____ 🎯 성능 목표
     * - 1000회 조회에 < 20ms
     * - 실시간 재생에 충분
     */
    func testGetFramePerformance() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 생성
         */
        /**
         * 빈 버퍼 상태
         * (실제로는 프레임이 있어야 의미있지만,
         *  이 테스트는 기본 성능 측정)
         */
        channel = VideoChannel(channelInfo: testChannelInfo)

        /**
         * When/Then: 성능 측정
         */
        /**
         * measure 블록 안에서 1000회 프레임 조회
         */
        measure {
            /**
             * 1000회 프레임 조회
             */
            ///
            /**
             *
             * @section ____ 💡 각 반복
             * i=0: getFrame(at: 0.0)
             * i=1: getFrame(at: 0.033)
             * i=2: getFrame(at: 0.066)
             * ...
             */
            for i in 0..<1000 {
                /**
                 * timestamp 계산
                 */
                ///
                /**
                 * Double(i) * 0.033
                 * = i번째 프레임의 예상 timestamp
                 */
                ///
                /**
                 *
                 * @section 0_033___30_fps___ 💡 0.033 = 30 fps 간격
                 */
                _ = channel.getFrame(at: Double(i) * 0.033)
            }
        }

        /**
         *
         * @section __________ 💡 성능 개선 아이디어
         * - 버퍼를 정렬된 배열로 유지
         * - 이진 탐색 알고리즘 최적화
         * - 최근 조회 결과 캐싱
         * - 시간 범위 인덱싱
         */
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Integration Tests (통합 테스트)
// ═══════════════════════════════════════════════════════════════════════════

/// VideoChannel 통합 테스트 클래스
///
/// 실제 비디오 파일을 사용한 전체 workflow 테스트를 수행합니다.
///
/// 🔗 통합 테스트 (Integration Tests)란?
/// ```
/// 여러 컴포넌트가 함께 작동하는 것을 검증하는 테스트
///
/// Unit Tests vs Integration Tests:
///
/// Unit Tests:
/// - 단일 클래스/메서드 테스트
/// - Mock 객체 사용
/// - 빠른 실행
///
/// Integration Tests:
/// - 실제 의존성 사용
/// - 전체 workflow 테스트
/// - 느린 실행
/// ```
///
/// 💡 이 테스트의 특징:
/// ```
/// 1. 실제 비디오 파일 필요
///    - test_video.mp4를 Bundle에서 로드
///    - XCTSkip으로 파일 없으면 건너뛰기
///
/// 2. 실제 디코딩 수행
///    - FFmpeg VideoDecoder 사용
///    - Thread.sleep으로 디코딩 대기
///    - 실제 프레임 생성 검증
///
/// 3. 전체 기능 검증
///    - initialize → startDecoding → getFrame
///    - seek → 새 위치 디코딩
///    - 버퍼 관리 및 프레임 순서
/// ```
///
/// ⚠️ 실행 주의사항:
/// - test_video.mp4 파일이 테스트 번들에 포함되어야 함
/// - 파일 없으면 모든 테스트가 XCTSkip으로 건너뛰어짐
/// - 실제 디코딩으로 인해 느리게 실행됨 (수 초 소요)
final class VideoChannelIntegrationTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 비디오 채널 인스턴스
     */
    /**
     * 실제 비디오 파일로 초기화됩니다.
     */
    var channel: VideoChannel!

    /**
     * 테스트 채널 정보
     */
    /**
     * 테스트 비디오 파일 경로를 포함합니다.
     */
    var testChannelInfo: ChannelInfo!

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Setup & Teardown
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 각 테스트 실행 전 초기화
     */
    /**
     * 테스트 비디오 파일을 찾아서 채널을 생성합니다.
     */
    /**
     * 📦 Bundle 파일 접근:
     * @endcode
     * let bundle = Bundle(for: type(of: self))
     * bundle.path(forResource: "파일명", ofType: "확장자")
     * @endcode
     */
    /**
     *
     * @section xctskip 💡 XCTSkip
     * @endcode
     * 테스트를 건너뛰는 특수 에러
     */
    /**
     * throw XCTSkip("이유")
     *     ↓
     * 테스트가 Skipped로 표시됨 (실패 아님)
     */
    /**
     * 사용 시기:
     * - 필수 리소스 없음
     * - 특정 환경에서만 실행
     * - 구현 대기 중
     * @endcode
     */
    override func setUpWithError() throws {
        /**
         * 부모 클래스의 setUp 호출
         */
        super.setUp()

        /**
         * 테스트 비디오 파일 찾기
         */
        /**
         * Bundle(for:): 이 테스트 클래스의 Bundle
         */
        /**
         *
         * @section bundle___ 💡 Bundle이란?
         * @endcode
         * 앱의 리소스를 담고 있는 디렉토리
         */
        /**
         * 구조:
         * MyApp.app/
         * ├── MyApp (실행 파일)
         * ├── Info.plist
         * └── Resources/
         *     ├── test_video.mp4  ← 여기서 찾음
         *     ├── icon.png
         *     └── ...
         * @endcode
         */
        let bundle = Bundle(for: type(of: self))

        /**
         * path(forResource:ofType:): 파일 경로 찾기
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * Bundle에서 "test_video.mp4" 파일 찾기
         *     ↓ 찾으면
         * 전체 경로 반환 ("/path/to/test_video.mp4")
         *     ↓ 못 찾으면
         * nil 반환
         * @endcode
         */
        /**
         * guard let: nil이면 else 실행
         */
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            /**
             * 파일 없으면 테스트 건너뛰기
             */
            ///
            /**
             * XCTSkip: 테스트 스킵 에러
             */
            ///
            /**
             *
             * @section __ 💡 이유
             * - 실패가 아닌 건너뛰기로 표시
             * - CI 환경에서 유용
             * - 선택적 테스트 가능
             */
            throw XCTSkip("Test video file not found")
        }

        /**
         * 채널 정보 생성
         */
        /**
         * 실제 비디오 파일 경로 사용
         */
        testChannelInfo = ChannelInfo(
            position: .front,
            filePath: videoPath,
            displayName: "Test Channel"
        )

        /**
         * 채널 생성
         */
        /**
         * 실제 파일로 초기화 가능한 상태
         */
        channel = VideoChannel(channelInfo: testChannelInfo)
    }

    /**
     * 각 테스트 실행 후 정리
     */
    /**
     * 채널을 중지하고 리소스를 해제합니다.
     */
    /**
     *
     * @section _____ 💡 정리 순서
     * 1. stop() - 디코딩 중지, 버퍼 정리
     * 2. channel = nil - 메모리 해제
     * 3. testChannelInfo = nil - 정보 해제
     */
    override func tearDownWithError() throws {
        /**
         * 채널 중지
         */
        /**
         * 디코딩 스레드 종료, 버퍼 비우기
         */
        channel.stop()

        /**
         * 채널 해제
         */
        channel = nil

        /**
         * 채널 정보 해제
         */
        testChannelInfo = nil

        /**
         * 부모 클래스의 tearDown 호출
         */
        super.tearDown()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Initialization Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 채널 초기화 통합 테스트
     */
    /**
     * 실제 비디오 파일로 initialize()를 호출하여
     * 디코더가 정상적으로 준비되는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 테스트 시나리오
     * @endcode
     * 1. 채널 생성 (setUp에서 완료)
     * 2. initialize() 호출
     * 3. 상태가 .ready로 변경되는지 확인
     * @endcode
     */
    /**
     * @test testInitializeChannel
     * @brief 💡 initialize()의 내부 동작:
     *
     * @details
     *
     * @section initialize_________ 💡 initialize()의 내부 동작
     * @endcode
     * initialize()
     *   ↓ 파일 경로 확인
     *   ↓ VideoDecoder 생성
     *   ↓ FFmpeg로 파일 열기
     *   ↓ 비디오 스트림 찾기
     *   ↓ 코덱 초기화
     * state = .ready
     * @endcode
     */
    func testInitializeChannel() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 채널 초기화
         */
        /**
         * try: 에러 발생 가능
         */
        /**
         *
         * @section _____ 💡 성공 조건
         * - test_video.mp4 파일 존재
         * - 유효한 비디오 포맷
         * - 지원되는 코덱
         */
        try channel.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 상태 확인
         */
        /**
         * XCTAssertEqual: 값 비교
         */
        /**
         *
         * @section __ 💡 예상
         * state = .ready (초기화 완료)
         */
        /**
         *
         * @section _idle__ ⚠️ .idle이면
         * 초기화 실패 (테스트 실패)
         */
        XCTAssertEqual(channel.state, .ready, "State should be ready after initialization")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Decoding Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 디코딩 시작 통합 테스트
     */
    /**
     * startDecoding()을 호출하여 백그라운드 디코딩이
     * 정상적으로 시작되는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 테스트 시나리오
     * @endcode
     * 1. initialize() - 디코더 준비
     * 2. startDecoding() - 디코딩 시작
     * 3. 0.5초 대기
     * 4. 상태 및 버퍼 확인
     * @endcode
     */
    /**
     * @test testStartDecoding
     * @brief 🔄 디코딩 프로세스:
     *
     * @details
     *
     * @section ________ 🔄 디코딩 프로세스
     * @endcode
     * startDecoding()
     *   ↓ 백그라운드 큐에서 실행
     *   ↓ loop:
     *   ↓   - AVPacket 읽기
     *   ↓   - AVFrame 디코딩
     *   ↓   - 버퍼에 추가
     *   ↓   - state = .decoding
     * 지속적으로 실행 중...
     * @endcode
     */
    func testStartDecoding() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 채널 초기화
         */
        /**
         * initialize()로 디코더 준비
         */
        try channel.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 디코딩 시작
         */
        /**
         * startDecoding(): 백그라운드 디코딩 시작
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * DispatchQueue.global().async {
         *     while !shouldStop {
         *         // 프레임 디코딩
         *         // 버퍼에 추가
         *     }
         * }
         * @endcode
         */
        channel.startDecoding()

        /**
         * 프레임 디코딩 대기
         */
        /**
         * Thread.sleep: 현재 스레드를 일시 중지
         */
        /**
         *
         * @section 0_5_______ 💡 0.5초 대기 이유
         * @endcode
         * 30 fps 비디오 기준:
         * 0.5초 = 15 프레임 디코딩 가능
         */
        /**
         * 충분한 프레임이 버퍼에 쌓임
         * @endcode
         */
        /**
         *
         * @section _______ ⚠️ 실제 앱에서는
         * sleep 대신 비동기 대기 사용
         */
        Thread.sleep(forTimeInterval: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 상태 및 버퍼 검증
         *
         * 1. 상태가 .decoding인지 확인
         */
        /**
         *
         * @section __ 💡 예상
         * startDecoding() 후 → state = .decoding
         */
        XCTAssertEqual(channel.state, .decoding, "State should be decoding")

        /**
         * 2. 버퍼에 프레임이 있는지 확인
         */
        /**
         * getBufferStatus(): 버퍼 상태 조회
         */
        let status = channel.getBufferStatus()

        /**
         * XCTAssertGreaterThan: 큰지 확인
         */
        /**
         *
         * @section __ 💡 예상
         * status.current > 0 (프레임이 디코딩됨)
         */
        /**
         *
         * @section 0__ ⚠️ 0이면
         * 디코딩이 동작하지 않음 (실패)
         */
        XCTAssertGreaterThan(status.current, 0, "Buffer should have frames")
    }

    /**
     * 디코딩 후 프레임 조회 통합 테스트
     */
    /**
     * 디코딩 후 getFrame()으로 특정 시점의 프레임을
     * 조회할 수 있는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 테스트 시나리오
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 0.5초 대기 (프레임 디코딩)
     * 3. getFrame(at: 0.5) 호출
     * 4. 프레임 반환 및 타임스탬프 확인
     * @endcode
     */
    /**
     * @test testGetFrameAfterDecoding
     * @brief 🔍 getFrame() 동작:
     *
     * @details
     *
     * @section getframe_____ 🔍 getFrame() 동작
     * @endcode
     * getFrame(at: 0.5)
     *   ↓ 버퍼에서 0.5초에 가장 가까운 프레임 찾기
     *   ↓ 이진 탐색
     *   ↓ 프레임 반환
     * @endcode
     */
    func testGetFrameAfterDecoding() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화 및 디코딩 시작
         */
        /**
         * 준비 단계 수행
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * 프레임 디코딩 대기
         */
        /**
         * 0.5초 동안 약 15개 프레임 디코딩
         */
        Thread.sleep(forTimeInterval: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 0.5초 시점 프레임 조회
         */
        /**
         * getFrame(at:): 특정 시점 프레임 가져오기
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * 버퍼: [0.0, 0.033, 0.066, ..., 0.5, ...]
         *          ↓ 0.5초에 가장 가까운 프레임 찾기
         * 반환: Frame(timestamp: 0.5)
         * @endcode
         */
        let frame = channel.getFrame(at: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 프레임 검증
         *
         * 1. 프레임이 반환되었는지 확인
         */
        /**
         * XCTAssertNotNil: nil이 아닌지 확인
         */
        /**
         *
         * @section __ 💡 예상
         * frame != nil (프레임 존재)
         */
        /**
         *
         * @section nil__ ⚠️ nil이면
         * 버퍼에 프레임 없음 (실패)
         */
        XCTAssertNotNil(frame, "Should get frame from buffer")

        /**
         * 2. 프레임 타임스탬프 확인
         */
        /**
         * if let: 옵셔널 바인딩
         */
        /**
         *
         * @section frame__nil_____ 💡 frame이 nil이 아니면
         * timestamp 확인
         */
        if let frame = frame {
            /**
             * XCTAssertGreaterThanOrEqual: ≥ 확인
             */
            ///
            /**
             *
             * @section __ 💡 예상
             * timestamp >= 0.0 (유효한 시간)
             */
            ///
            /**
             * 일반적으로:
             * timestamp ≈ 0.5 (요청한 시간 근처)
             */
            XCTAssertGreaterThanOrEqual(frame.timestamp, 0.0)
        }
    }

    /**
     * Seek 및 디코딩 통합 테스트
     */
    /**
     * seek()로 특정 위치로 이동 후
     * 새 위치에서 디코딩이 정상 동작하는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 테스트 시나리오
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 0.3초 대기 (초기 프레임 디코딩)
     * 3. seek(to: 5.0) - 5초 위치로 이동
     * 4. 0.5초 대기 (새 위치 디코딩)
     * 5. getFrame(at: 5.0) 확인
     * @endcode
     */
    /**
     * @test testSeekAndDecode
     * @brief 🎯 seek() 동작:
     *
     * @details
     *
     * @section seek_____ 🎯 seek() 동작
     * @endcode
     * seek(to: 5.0)
     *   ↓ 디코딩 일시 중지
     *   ↓ 버퍼 비우기 (flushBuffer)
     *   ↓ VideoDecoder.seek(to: 5.0)
     *   ↓ 5초 근처 I-Frame으로 이동
     *   ↓ 디코딩 재개
     * 5초부터 새로 디코딩...
     * @endcode
     */
    func testSeekAndDecode() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화 및 초기 디코딩
         */
        /**
         * 디코더 준비 및 시작
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * 초기 프레임 디코딩 대기
         */
        /**
         * 0.3초 = 약 9개 프레임
         */
        Thread.sleep(forTimeInterval: 0.3)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 5초로 seek
         */
        /**
         * seek(to:): 특정 시간으로 이동
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * 현재 위치: ~0.3초
         *     ↓ seek(to: 5.0)
         * 새 위치: 5.0초
         *     ↓ 버퍼 초기화
         *     ↓ 5초부터 디코딩
         * @endcode
         */
        try channel.seek(to: 5.0)

        /**
         * 새 위치에서 디코딩 대기
         */
        /**
         * 0.5초 동안 5초 근처 프레임 디코딩
         */
        Thread.sleep(forTimeInterval: 0.5)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 5초 근처 프레임 확인
         */
        /**
         * getFrame(at: 5.0): 5초 프레임 조회
         */
        let frame = channel.getFrame(at: 5.0)

        /**
         * 1. 프레임 존재 확인
         */
        /**
         *
         * @section __ 💡 예상
         * 5초 근처 프레임이 버퍼에 있음
         */
        XCTAssertNotNil(frame, "Should get frame after seeking")

        /**
         * 2. 프레임 타임스탬프 확인
         */
        /**
         * if let: 옵셔널 바인딩
         */
        if let frame = frame {
            /**
             * XCTAssertGreaterThanOrEqual: ≥ 확인
             */
            ///
            /**
             *
             * @section __ 💡 예상
             * timestamp >= 5.0
             */
            ///
            /**
             * 일반적으로:
             * timestamp ≈ 5.0 (seek 지점)
             */
            ///
            /**
             *
             * @section i_frame_______ ⚠️ I-Frame 위치에 따라
             * 정확히 5.0이 아닐 수 있음
             * (4.9 ~ 5.1 정도)
             */
            XCTAssertGreaterThanOrEqual(frame.timestamp, 5.0, "Frame should be at or after seek point")
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Buffer Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 버퍼 채우기 및 정리 통합 테스트
     */
    /**
     * 버퍼가 가득 찰 때까지 디코딩하여
     * 버퍼 크기 제한이 올바르게 동작하는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 테스트 시나리오
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 2.0초 대기 (충분한 디코딩 시간)
     * 3. 버퍼 상태 확인
     * 4. 최대 크기 및 채움 비율 검증
     * @endcode
     */
    /**
     *
     * @section ________ 💡 버퍼 크기 제한
     * @endcode
     * maxBufferSize = 30
     */
    /**
     * @test testBufferFillAndCleanup
     * @brief 동작:
     *
     * @details
     * 동작:
     * - 30개 프레임까지 저장
     * - 31번째 프레임 추가 시 가장 오래된 프레임 제거
     * - FIFO (First In First Out) 방식
     * @endcode
     */
    func testBufferFillAndCleanup() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화 및 디코딩 시작
         */
        /**
         * 디코더 준비 및 시작
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * 버퍼 채우기 대기
         */
        /**
         * 2.0초 = 약 60개 프레임 디코딩 시도
         */
        /**
         *
         * @section __ 💡 동작
         * @endcode
         * 0.0 ~ 0.5초: 버퍼 15개
         * 0.5 ~ 1.0초: 버퍼 30개 (가득 참)
         * 1.0 ~ 2.0초: 버퍼 30개 (최대 유지)
         *               → 오래된 프레임 제거됨
         * @endcode
         */
        Thread.sleep(forTimeInterval: 2.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 버퍼 상태 조회
         */
        /**
         * getBufferStatus(): 현재 버퍼 상태
         */
        let status = channel.getBufferStatus()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 버퍼 크기 제한 검증
         *
         * 1. 현재 크기 ≤ 최대 크기
         */
        /**
         * XCTAssertLessThanOrEqual: ≤ 확인
         */
        /**
         *
         * @section __ 💡 예상
         * status.current <= status.max
         * 예: current=30, max=30 ✅
         */
        /**
         *
         * @section current___max__ ⚠️ current > max이면
         * 버퍼 크기 제한 실패 (실패)
         */
        XCTAssertLessThanOrEqual(status.current, status.max, "Buffer should not exceed max size")

        /**
         * 2. 채움 비율 ≤ 100%
         */
        /**
         * fillPercentage: current / max
         */
        /**
         *
         * @section __ 💡 예상
         * fillPercentage <= 1.0 (100%)
         * 예: 30/30 = 1.0 ✅
         */
        /**
         *
         * @section __1_0__ ⚠️ > 1.0이면
         * 계산 오류 (실패)
         */
        XCTAssertLessThanOrEqual(status.fillPercentage, 1.0, "Fill percentage should not exceed 100%")
    }

    /**
     * 프레임 타임스탬프 순서 통합 테스트
     */
    /**
     * 버퍼에서 조회한 프레임들의 타임스탬프가
     * 올바른 순서로 정렬되어 있는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 테스트 시나리오
     * @endcode
     * 1. initialize() + startDecoding()
     * 2. 1.0초 대기 (충분한 프레임 디코딩)
     * 3. 0.0, 1.0, 2.0초 프레임 조회
     * 4. 타임스탬프 순서 확인
     * @endcode
     */
    /**
     *
     * @section _____________ 💡 타임스탬프 순서의 중요성
     * @endcode
     * 정렬된 버퍼:
     * [0.0, 0.033, 0.066, ..., 1.0, ..., 2.0]
     */
    /**
     * 이진 탐색 가능:
     * - O(log n) 성능
     * - 빠른 프레임 조회
     */
    /**
     * @test testFrameTimestampOrdering
     * @brief 순서 없으면:
     *
     * @details
     * 순서 없으면:
     * - 선형 탐색 필요 O(n)
     * - 느린 성능
     * @endcode
     */
    func testFrameTimestampOrdering() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화 및 디코딩
         */
        /**
         * 디코더 준비 및 시작
         */
        try channel.initialize()
        channel.startDecoding()

        /**
         * 프레임 디코딩 대기
         */
        /**
         * 1.0초 = 약 30개 프레임
         */
        Thread.sleep(forTimeInterval: 1.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 여러 시점의 프레임 조회
         */
        /**
         * 0.0, 1.0, 2.0초 프레임 가져오기
         */
        /**
         *
         * @section _____ 💡 조회 순서
         * 순차적이지 않아도 됨
         * 타임스탬프로 정렬된 버퍼에서 찾음
         */
        let frame1 = channel.getFrame(at: 0.0)
        let frame2 = channel.getFrame(at: 1.0)
        let frame3 = channel.getFrame(at: 2.0)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 타임스탬프 순서 확인
         */
        /**
         * if let: 옵셔널 바인딩 (3개 모두)
         */
        /**
         *
         * @section __ 💡 문법
         * @endcode
         * if let f1 = frame1, let f2 = frame2, let f3 = frame3 {
         *     // 모두 nil이 아닐 때만 실행
         * }
         * @endcode
         */
        if let f1 = frame1, let f2 = frame2, let f3 = frame3 {
            /**
             * 1. frame1 < frame2
             */
            ///
            /**
             * XCTAssertLessThan: < 확인
             */
            ///
            /**
             *
             * @section __ 💡 예상
             * f1.timestamp < f2.timestamp
             * 예: 0.0 < 1.0 ✅
             */
            XCTAssertLessThan(f1.timestamp, f2.timestamp, "Frames should be ordered by timestamp")

            /**
             * 2. frame2 < frame3
             */
            ///
            /**
             *
             * @section __ 💡 예상
             * f2.timestamp < f3.timestamp
             * 예: 1.0 < 2.0 ✅
             */
            ///
            /**
             *
             * @section _______ ⚠️ 순서가 틀리면
             * 버퍼 정렬 실패 (실패)
             */
            XCTAssertLessThan(f2.timestamp, f3.timestamp, "Frames should be ordered by timestamp")
        }
    }
}
