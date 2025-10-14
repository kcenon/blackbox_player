/**
 * @file DataModelsTests.swift
 * @brief 데이터 모델 단위 테스트
 * @author BlackboxPlayer Team
 *
 * @details
 * BlackboxPlayer의 모든 데이터 모델을 체계적으로 테스트하는 단위 테스트 모음입니다.
 * 비즈니스 로직, 데이터 무결성, 직렬화/역직렬화, 계산 프로퍼티의 정확성을 검증합니다.
 *
 * @section test_targets 테스트 대상 모델
 *
 * 1. **EventType** - 이벤트 유형
 *    - 일반/충격/주차/수동/긴급 구분
 *    - 파일 경로 기반 자동 감지
 *    - 우선순위 비교
 *
 * 2. **CameraPosition** - 카메라 위치
 *    - 전방/후방/좌측/우측/실내
 *    - 파일명 접미사 기반 감지 (_F, _R, _L, _Ri, _I)
 *    - 채널 인덱스 매핑
 *
 * 3. **GPSPoint** - GPS 위치 데이터
 *    - 위도/경도 유효성 검증
 *    - Haversine 공식 기반 거리 계산
 *    - 신호 강도 판단
 *
 * 4. **AccelerationData** - 가속도 센서 데이터
 *    - 3축 (X, Y, Z) 벡터 크기 계산
 *    - 충격 감지 (2.5G 임계값)
 *    - 충격 심각도 분류
 *
 * 5. **ChannelInfo** - 비디오 채널 정보
 *    - 해상도 및 화면 비율
 *    - 채널 유효성 검증
 *
 * 6. **VideoMetadata** - 비디오 메타데이터
 *    - GPS 데이터 통계 (총 거리, 평균/최대 속도)
 *    - 가속도 데이터 통계 (최대 G-force)
 *    - 충격 이벤트 감지
 *
 * 7. **VideoFile** - 비디오 파일 모델
 *    - 멀티채널 접근
 *    - 파일 속성 (duration, size, timestamp)
 *    - 즐겨찾기/메모 기능
 *
 * @section test_importance 데이터 모델 테스트의 중요성
 *
 * - **비즈니스 로직 정확성**: 도메인 규칙이 올바르게 구현되었는지 확인
 * - **데이터 무결성**: 잘못된 데이터가 시스템에 유입되지 않도록 검증
 * - **Codable 직렬화**: JSON 인코딩/디코딩이 데이터 손실 없이 동작하는지 확인
 * - **계산 프로퍼티**: 파생 데이터가 정확히 계산되는지 검증
 * - **성능**: 대량 데이터 처리 성능 측정 및 최적화
 *
 * @section test_strategy 테스트 전략
 *
 * **단위 테스트 특징:**
 * - UI가 없어 밀리초 단위의 빠른 실행
 * - Mock 데이터 사용으로 외부 의존성 제거
 * - 독립적 실행 가능 (순서 무관)
 * - 높은 커버리지 목표 (90%+)
 *
 * **Given-When-Then 패턴 사용:**
 * ```swift
 * func testEventTypeDetection() {
 *     // Given: 파일 경로 준비
 *     let normalPath = "normal/video.mp4"
 *
 *     // When: 이벤트 유형 감지
 *     let eventType = EventType.detect(from: normalPath)
 *
 *     // Then: .normal 타입 검증
 *     XCTAssertEqual(eventType, .normal)
 * }
 * ```
 *
 * @section performance_tests 성능 테스트
 *
 * - GPS 거리 계산 (Haversine 공식)
 * - 비디오 메타데이터 요약 생성
 * - measure { } 블록으로 10회 반복 측정
 * - Baseline 설정으로 성능 퇴화 감지
 *
 * @note 이 테스트는 실제 파일 시스템이나 네트워크에 의존하지 않으므로
 * 언제든지 빠르게 실행할 수 있습니다.
 */

// ============================================================================
// DataModelsTests.swift
// BlackboxPlayerTests
//
// 데이터 모델 단위 테스트
// ============================================================================
//
// 📖 이 파일의 목적:
//    BlackboxPlayer의 모든 데이터 모델을 체계적으로 테스트합니다.
//
// 🎯 테스트 대상 모델:
//    1. EventType        - 이벤트 유형 (일반/충격/주차/수동/긴급)
//    2. CameraPosition   - 카메라 위치 (전방/후방/좌측/우측/실내)
//    3. GPSPoint         - GPS 위치 데이터
//    4. AccelerationData - 가속도 센서 데이터
//    5. ChannelInfo      - 비디오 채널 정보
//    6. VideoMetadata    - 비디오 메타데이터
//    7. VideoFile        - 비디오 파일 모델
//
// 💡 데이터 모델 테스트의 중요성:
//    - 비즈니스 로직의 정확성 보장
//    - 데이터 무결성 검증
//    - Codable 직렬화/역직렬화 확인
//    - 계산 프로퍼티 정확성 검증
//
// ============================================================================

import XCTest
@testable import BlackboxPlayer

// ═════════════════════════════════════════════════════════════════════════
// MARK: - DataModelsTests (데이터 모델 테스트 클래스)
// ═════════════════════════════════════════════════════════════════════════

/// 데이터 모델 단위 테스트 클래스
///
/// 모든 데이터 모델의 기능을 검증합니다.
///
/// 🎯 테스트 범위:
/// - 초기화 및 기본값
/// - 계산 프로퍼티
/// - 메서드 동작
/// - 데이터 변환
/// - 직렬화/역직렬화
/// - 성능
///
/// 💡 모델 테스트의 특징:
/// - UI가 없어 빠른 실행 (밀리초 단위)
/// - Mock 데이터 사용
/// - 독립적 실행 가능
/// - 높은 커버리지 목표 (90%+)
final class DataModelsTests: XCTestCase {

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - EventType Tests (이벤트 유형 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 이벤트 유형 감지 테스트
     */
    /**
     * 파일 경로에서 이벤트 유형을 올바르게 감지하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - "normal" 경로 → .normal
     * - "event" 경로 → .impact
     * - "parking" 경로 → .parking
     * - "manual" 경로 → .manual
     * - "emergency" 경로 → .emergency
     * - 알 수 없는 경로 → .unknown
     */
    /**
     *
     * @section ________ 💡 파일 경로 패턴
     * @endcode
     * 블랙박스 SD 카드 구조:
     * /DCIM/
     *   normal/    ← 일반 주행 영상
     *   event/     ← 충격 감지 영상
     *   parking/   ← 주차 모드 영상
     *   manual/    ← 수동 녹화 영상
     *   emergency/ ← 긴급 녹화 영상
     * @endcode
     */
    /**
     * @test testEventTypeDetection
     * @brief 🔍 감지 알고리즘:
     *
     * @details
     *
     * @section _______ 🔍 감지 알고리즘
     * @endcode
     * extension EventType {
     *     static func detect(from path: String) -> EventType {
     *         if path.contains("normal") { return .normal }
     *         if path.contains("event") { return .impact }
     *         // ...
     *         return .unknown
     *     }
     * }
     * @endcode
     */
    func testEventTypeDetection() {
        /**
         * 일반 주행 영상 감지
         */
        /**
         *
         * @section _normal____ 💡 .normal의 의미
         * - 평소 운전 중 자동 녹화
         * - 충격 감지 없음
         * - 순환 녹화 대상 (오래된 파일 자동 삭제)
         */
        XCTAssertEqual(EventType.detect(from: "normal/video.mp4"), .normal)

        /**
         * 충격 감지 영상 감지
         */
        /**
         *
         * @section _impact____ 💡 .impact의 의미
         * - 충격 센서가 일정 G-force 이상 감지
         * - 보호 녹화 (자동 삭제 안 됨)
         * - 사고 증거로 중요
         */
        XCTAssertEqual(EventType.detect(from: "event/video.mp4"), .impact)

        /**
         * 주차 모드 영상 감지
         */
        /**
         *
         * @section _parking____ 💡 .parking의 의미
         * - 차량 정차 중 녹화
         * - 움직임 감지 시 녹화 시작
         * - 배터리 보호를 위한 타임아웃
         */
        XCTAssertEqual(EventType.detect(from: "parking/video.mp4"), .parking)

        /**
         * 수동 녹화 영상 감지
         */
        /**
         *
         * @section _manual____ 💡 .manual의 의미
         * - 사용자가 버튼을 눌러 수동 녹화
         * - 특별한 순간 기록
         * - 보호 녹화 (자동 삭제 안 됨)
         */
        XCTAssertEqual(EventType.detect(from: "manual/video.mp4"), .manual)

        /**
         * 긴급 녹화 영상 감지
         */
        /**
         *
         * @section _emergency____ 💡 .emergency의 의미
         * - 긴급 버튼 (SOS) 눌렀을 때
         * - 최고 우선순위 보호
         * - 자동 알림 전송 가능
         */
        XCTAssertEqual(EventType.detect(from: "emergency/video.mp4"), .emergency)

        /**
         * 알 수 없는 유형 감지
         */
        /**
         *
         * @section _unknown____ 💡 .unknown의 의미
         * - 표준 경로 패턴이 아닌 경우
         * - 사용자 정의 폴더
         * - 수동으로 분류 필요
         */
        XCTAssertEqual(EventType.detect(from: "unknown/video.mp4"), .unknown)
    }

    /**
     * 이벤트 유형 우선순위 테스트
     */
    /**
     * 이벤트 유형 간 중요도 비교가 올바른지 확인합니다.
     */
    /**
     *
     * @section _______ 🎯 우선순위 순서
     * @endcode
     * emergency > impact > manual > parking > normal > unknown
     *    (가장 중요)                           (가장 낮음)
     * @endcode
     */
    /**
     *
     * @section ________ 💡 우선순위의 용도
     * - 저장 공간 부족 시 삭제 순서 결정
     * - UI에서 목록 정렬 순서
     * - 알림 중요도 결정
     */
    /**
     *
     * @section _____ 📊 사용 예시
     * @endcode
     * // 저장 공간이 부족할 때
     * let videosToDelete = allVideos
     *     .sorted { $0.eventType < $1.eventType }  // 우선순위 낮은 것부터
     *     .prefix(10)  // 10개 선택
     */
    /**
     * @test testEventTypePriority
     * @brief // emergency와 impact는 마지막에 삭제됨
     *
     * @details
     * // emergency와 impact는 마지막에 삭제됨
     * @endcode
     */
    func testEventTypePriority() {
        /**
         * 긴급 > 충격
         */
        /**
         *
         * @section _________ 💡 비교 연산자 구현
         * @endcode
         * extension EventType: Comparable {
         *     static func < (lhs: EventType, rhs: EventType) -> Bool {
         *         return lhs.priority < rhs.priority
         *     }
         * }
         * @endcode
         */
        XCTAssertTrue(EventType.emergency > EventType.impact)

        /**
         * 충격 > 일반
         */
        /**
         * 충격 감지 영상이 일반 주행 영상보다 중요합니다.
         * - 충격 영상: 보호 필요
         * - 일반 영상: 순환 녹화 대상
         */
        XCTAssertTrue(EventType.impact > EventType.normal)

        /**
         * 일반 > 알 수 없음
         */
        /**
         * 일반 주행 영상도 unknown보다는 중요합니다.
         * - 일반: 정상적인 녹화
         * - unknown: 분류 안 된 파일
         */
        XCTAssertTrue(EventType.normal > EventType.unknown)
    }

    /**
     * 이벤트 유형 표시 이름 테스트
     */
    /**
     * UI에 표시할 이름이 올바른지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - .normal → "Normal"
     * - .impact → "Impact"
     * - .parking → "Parking"
     */
    /**
     *
     * @section _________ 💡 표시 이름의 용도
     * @endcode
     * // UI에서 사용
     * List(videos) { video in
     *     HStack {
     *         Text(video.eventType.displayName)  // "Impact", "Normal" 등
     *         Image(systemName: video.eventType.iconName)
     *     }
     * }
     */
    /**
     * // 필터링 UI
     * Picker("Event Type", selection: $selectedType) {
     *     ForEach(EventType.allCases) { type in
     *         Text(type.displayName).tag(type)
     *     }
     * }
     * @endcode
     */
    /**
     * @test testEventTypeDisplayNames
     * @brief 🌍 다국어 지원:
     *
     * @details
     * 🌍 다국어 지원:
     * @endcode
     * extension EventType {
     *     var displayName: String {
     *         switch self {
     *         case .normal:
     *             return NSLocalizedString("event.normal", comment: "Normal")
     *         case .impact:
     *             return NSLocalizedString("event.impact", comment: "Impact")
     *         // ...
     *         }
     *     }
     * }
     * @endcode
     */
    func testEventTypeDisplayNames() {
        /**
         * Normal 표시 이름 확인
         */
        XCTAssertEqual(EventType.normal.displayName, "Normal")

        /**
         * Impact 표시 이름 확인
         */
        /**
         *
         * @section ______ 💡 대안 이름들
         * @endcode
         * "Impact"    ✅ 선택됨 (간결하고 명확)
         * "Shock"        (충격이지만 덜 구체적)
         * "Accident"     (사고를 암시하여 부적절)
         * "Event"        (너무 일반적)
         * @endcode
         */
        XCTAssertEqual(EventType.impact.displayName, "Impact")

        /**
         * Parking 표시 이름 확인
         */
        XCTAssertEqual(EventType.parking.displayName, "Parking")
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - CameraPosition Tests (카메라 위치 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 카메라 위치 감지 테스트
     */
    /**
     * 파일명에서 카메라 위치를 올바르게 감지하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - "_F" 접미사 → .front
     * - "_R" 접미사 → .rear
     * - "_L" 접미사 → .left
     * - "_Ri" 접미사 → .right
     * - "_I" 접미사 → .interior
     */
    /**
     *
     * @section ___________ 💡 블랙박스 파일명 규칙
     * @endcode
     * 형식: YYYY_MM_DD_HH_MM_SS_[위치].mp4
     * 예시: 2025_01_10_09_00_00_F.mp4
     *       └─────┬─────┘└──┬──┘ └┬┘
     *           날짜       시간    위치
     */
    /**
     * F  = Front    (전방)
     * R  = Rear     (후방)
     * L  = Left     (좌측)
     * Ri = Right    (우측)
     * I  = Interior (실내)
     * @endcode
     */
    /**
     * 🚗 카메라 배치:
     * @endcode
     *        F (전방)
     *          ↑
     *    L ←  🚗  → Ri
     *          ↓
     *        R (후방)
     */
    /**
     * @test testCameraPositionDetection
     * @brief I (실내): 운전석을 향함
     *
     * @details
     * I (실내): 운전석을 향함
     * @endcode
     */
    func testCameraPositionDetection() {
        /**
         * 전방 카메라 감지
         */
        /**
         *
         * @section __f________ 💡 "_F" 접미사 패턴
         * - Front의 약자
         * - 가장 중요한 카메라
         * - 대부분의 블랙박스에 필수
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_F.mp4"), .front)

        /**
         * 후방 카메라 감지
         */
        /**
         *
         * @section __r________ 💡 "_R" 접미사 패턴
         * - Rear의 약자
         * - 후방 추돌 확인
         * - 2채널 블랙박스의 두 번째 카메라
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_R.mp4"), .rear)

        /**
         * 좌측 카메라 감지
         */
        /**
         *
         * @section __l________ 💡 "_L" 접미사 패턴
         * - Left의 약자
         * - 사각지대 확인
         * - 4채널 블랙박스에서 사용
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_L.mp4"), .left)

        /**
         * 우측 카메라 감지
         */
        /**
         *
         * @section __ri________ 💡 "_Ri" 접미사 패턴
         * - Right의 약자
         * - "R"은 Rear와 구분하기 위해 "Ri" 사용
         * - 우측 사각지대 확인
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_Ri.mp4"), .right)

        /**
         * 실내 카메라 감지
         */
        /**
         *
         * @section __i________ 💡 "_I" 접미사 패턴
         * - Interior의 약자
         * - 택시, 우버 등에서 사용
         * - 승객 및 운전자 확인
         */
        XCTAssertEqual(CameraPosition.detect(from: "2025_01_10_09_00_00_I.mp4"), .interior)
    }

    /**
     * 카메라 위치의 채널 인덱스 테스트
     */
    /**
     * 각 카메라 위치가 올바른 채널 번호를 가지는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - .front → 0
     * - .rear → 1
     * - .left → 2
     * - .right → 3
     * - .interior → 4
     */
    /**
     *
     * @section __________ 💡 채널 인덱스의 용도
     * @endcode
     * // FFmpeg에서 비디오 스트림 선택
     * let streamIndex = cameraPosition.channelIndex
     * avformat_find_stream_info(formatContext, nil)
     * let stream = formatContext.streams[streamIndex]
     */
    /**
     * // 렌더링 시 텍스처 배열 인덱스
     * textures[position.channelIndex] = newTexture
     */
    /**
     * // UI에서 채널 선택
     * let channel = channels[selectedPosition.channelIndex]
     * @endcode
     */
    /**
     * @test testCameraPositionChannelIndex
     * @brief 📊 채널 순서의 중요성:
     *
     * @details
     *
     * @section __________ 📊 채널 순서의 중요성
     * - 고정된 순서로 일관성 보장
     * - 배열 인덱스로 빠른 접근
     * - FFmpeg 스트림 순서와 매칭
     */
    func testCameraPositionChannelIndex() {
        /**
         * 전방 카메라 = 채널 0
         */
        /**
         *
         * @section 0_________ 💡 0번이 전방인 이유
         * - 가장 중요한 카메라
         * - 항상 존재하는 기본 채널
         * - 배열의 첫 번째 요소
         */
        XCTAssertEqual(CameraPosition.front.channelIndex, 0)

        /**
         * 후방 카메라 = 채널 1
         */
        /**
         * 두 번째로 중요한 카메라
         * 2채널 블랙박스의 표준
         */
        XCTAssertEqual(CameraPosition.rear.channelIndex, 1)

        /**
         * 좌측 카메라 = 채널 2
         */
        /**
         * 4채널 블랙박스의 세 번째
         */
        XCTAssertEqual(CameraPosition.left.channelIndex, 2)

        /**
         * 우측 카메라 = 채널 3
         */
        /**
         * 4채널 블랙박스의 네 번째
         */
        XCTAssertEqual(CameraPosition.right.channelIndex, 3)

        /**
         * 실내 카메라 = 채널 4
         */
        /**
         *
         * @section 5______________ 💡 5채널 블랙박스의 추가 채널
         * - 선택적 기능
         * - 택시/우버용
         * - 마지막 인덱스
         */
        XCTAssertEqual(CameraPosition.interior.channelIndex, 4)
    }

    /**
     * 채널 인덱스에서 카메라 위치 변환 테스트
     */
    /**
     * 채널 번호로부터 카메라 위치를 올바르게 찾는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 0 → .front
     * - 1 → .rear
     * - 4 → .interior
     * - 99 (잘못된 값) → nil
     */
    /**
     *
     * @section _____ 💡 사용 사례
     * @endcode
     * // FFmpeg 스트림에서 위치 추출
     * for i in 0..<streamCount {
     *     if let position = CameraPosition.from(channelIndex: i) {
     *         channels[position] = decodeStream(at: i)
     *     }
     * }
     */
    /**
     * // UI 인덱스에서 위치 매핑
     * @State var selectedIndex = 0
     * var selectedPosition: CameraPosition? {
     *     CameraPosition.from(channelIndex: selectedIndex)
     * }
     * @endcode
     */
    /**
     * @test testCameraPositionFromChannelIndex
     * @brief 🔄 양방향 변환:
     *
     * @details
     *
     * @section ______ 🔄 양방향 변환
     * @endcode
     * let position: CameraPosition = .front
     * let index = position.channelIndex      // → 0
     * let restored = CameraPosition.from(channelIndex: index)  // → .front
     * assert(restored == position)  // ✅
     * @endcode
     */
    func testCameraPositionFromChannelIndex() {
        /**
         * 채널 0 → 전방 카메라
         */
        XCTAssertEqual(CameraPosition.from(channelIndex: 0), .front)

        /**
         * 채널 1 → 후방 카메라
         */
        XCTAssertEqual(CameraPosition.from(channelIndex: 1), .rear)

        /**
         * 채널 4 → 실내 카메라
         */
        XCTAssertEqual(CameraPosition.from(channelIndex: 4), .interior)

        /**
         * 잘못된 채널 번호 → nil
         */
        /**
         *
         * @section nil_______ 💡 nil 반환의 이유
         * - 유효하지 않은 인덱스
         * - 지원하지 않는 채널
         * - Optional로 안전한 실패 처리
         */
        /**
         *
         * @section _____ 🔍 사용 예시
         * @endcode
         * guard let position = CameraPosition.from(channelIndex: 99) else {
         *     print("Invalid channel index")
         *     return
         * }
         * @endcode
         */
        XCTAssertNil(CameraPosition.from(channelIndex: 99))
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - GPSPoint Tests (GPS 위치 데이터 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * GPS 포인트 유효성 검증 테스트
     */
    /**
     * 위도/경도 값이 유효한 범위 내에 있는지 확인합니다.
     */
    /**
     * @test testGPSPointValidation
     * @brief 🌍 유효한 범위:
     *
     * @details
     * 🌍 유효한 범위:
     * - 위도: -90° ~ 90° (북위/남위)
     * - 경도: -180° ~ 180° (동경/서경)
     */
    func testGPSPointValidation() {
        /**
         * 유효한 GPS 포인트
         */
        /**
         * 서울 시청 좌표: 37.5665°N, 126.9780°E
         */
        let valid = GPSPoint.sample
        XCTAssertTrue(valid.isValid)

        /**
         * 잘못된 GPS 포인트
         */
        /**
         *
         * @section latitude___91_0_________ 💡 latitude = 91.0은 유효하지 않음
         * - 최대 위도는 90° (북극)
         * - 91°는 지구상에 존재하지 않음
         */
        let invalid = GPSPoint(
            timestamp: Date(),
            latitude: 91.0,  // Invalid (> 90)
            longitude: 0.0
        )
        XCTAssertFalse(invalid.isValid)
    }

    /**
     * GPS 포인트 간 거리 계산 테스트
     */
    /**
     * Haversine 공식을 사용한 두 GPS 좌표 간 거리를 검증합니다.
     */
    /**
     * @test testGPSPointDistance
     * @brief 🌐 Haversine 공식:
     *
     * @details
     *
     * @section haversine___ 🌐 Haversine 공식
     * 구면 삼각법을 사용하여 지구 표면의 두 점 사이 최단 거리를 계산합니다.
     */
    func testGPSPointDistance() {
        /**
         * 서울 광화문 근처의 두 지점
         */
        /**
         * point1: 37.5665°N, 126.9780°E
         * point2: 37.5667°N, 126.9782°E
         */
        /**
         * 약 25-30미터 거리
         */
        let point1 = GPSPoint(timestamp: Date(), latitude: 37.5665, longitude: 126.9780)
        let point2 = GPSPoint(timestamp: Date(), latitude: 37.5667, longitude: 126.9782)

        let distance = point1.distance(to: point2)

        /**
         * 거리가 양수인지 확인
         */
        XCTAssertGreaterThan(distance, 0)

        /**
         * 50미터 이내인지 확인
         */
        /**
         *
         * @section 0_0002_______22__ 💡 0.0002도 차이 ≈ 22미터
         */
        XCTAssertLessThan(distance, 50)
    }

    /**
     * GPS 신호 강도 테스트
     */
    /**
     * @test testGPSPointSignalStrength
     * @brief 정확도와 위성 수를 기반으로 신호 강도를 판단합니다.
     *
     * @details
     * 정확도와 위성 수를 기반으로 신호 강도를 판단합니다.
     */
    func testGPSPointSignalStrength() {
        /**
         * 강한 GPS 신호
         */
        /**
         *
         * @section _________ 💡 강한 신호의 조건
         * - horizontalAccuracy < 10m
         * - satelliteCount >= 7
         */
        let strongSignal = GPSPoint(
            timestamp: Date(),
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracy: 5.0,      // 5미터 오차
            satelliteCount: 8             // 8개 위성
        )
        XCTAssertTrue(strongSignal.hasStrongSignal)

        /**
         * 약한 GPS 신호
         */
        /**
         *
         * @section _________ 💡 약한 신호의 조건
         * - horizontalAccuracy >= 10m
         * - satelliteCount < 7
         */
        let weakSignal = GPSPoint(
            timestamp: Date(),
            latitude: 37.5665,
            longitude: 126.9780,
            horizontalAccuracy: 100.0,    // 100미터 오차
            satelliteCount: 3             // 3개 위성만
        )
        XCTAssertFalse(weakSignal.hasStrongSignal)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - AccelerationData Tests (가속도 센서 데이터 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 가속도 크기 계산 테스트
     */
    /**
     * 3축 가속도의 벡터 크기를 계산합니다.
     */
    /**
     * @test testAccelerationMagnitude
     * @brief 📐 벡터 크기 공식:
     *
     * @details
     * 📐 벡터 크기 공식:
     * magnitude = √(x² + y² + z²)
     */
    func testAccelerationMagnitude() {
        /**
         * 피타고라스 정리 검증: 3-4-5 삼각형
         */
        /**
         * x=3, y=4, z=0 → magnitude = 5
         * √(3² + 4² + 0²) = √(9 + 16) = √25 = 5
         */
        let data = AccelerationData(timestamp: Date(), x: 3.0, y: 4.0, z: 0.0)
        XCTAssertEqual(data.magnitude, 5.0, accuracy: 0.01)
    }

    /**
     * 충격 감지 테스트
     */
    /**
     * 가속도 크기에 따라 충격 여부를 판단합니다.
     */
    /**
     * @test testAccelerationImpactDetection
     * @brief 📊 충격 기준 (G-force):
     *
     * @details
     *
     * @section _______g_force_ 📊 충격 기준 (G-force)
     * - 일반: < 1.5G
     * - 급정거: 1.5G ~ 2.5G
     * - 충격: 2.5G ~ 5G
     * - 심각한 충격: > 5G
     */
    func testAccelerationImpactDetection() {
        /**
         * 일반 주행 (충격 아님)
         */
        XCTAssertFalse(AccelerationData.normal.isImpact)

        /**
         * 급정거 (충격 아님)
         */
        XCTAssertFalse(AccelerationData.braking.isImpact)

        /**
         * 충격 (충격 감지)
         */
        XCTAssertTrue(AccelerationData.impact.isImpact)

        /**
         * 심각한 충격 (심각한 충격 감지)
         */
        XCTAssertTrue(AccelerationData.severeImpact.isSevereImpact)
    }

    /**
     * 충격 심각도 분류 테스트
     */
    /**
     * @test testAccelerationSeverity
     * @brief 가속도 크기를 기반으로 4단계로 분류합니다.
     *
     * @details
     * 가속도 크기를 기반으로 4단계로 분류합니다.
     */
    func testAccelerationSeverity() {
        /**
         * 일반 → 심각도 없음
         */
        XCTAssertEqual(AccelerationData.normal.impactSeverity, .none)

        /**
         * 급정거 → 중간 심각도
         */
        XCTAssertEqual(AccelerationData.braking.impactSeverity, .moderate)

        /**
         * 충격 → 높은 심각도
         */
        XCTAssertEqual(AccelerationData.impact.impactSeverity, .high)

        /**
         * 심각한 충격 → 심각 수준
         */
        XCTAssertEqual(AccelerationData.severeImpact.impactSeverity, .severe)
    }

    /**
     * 가속도 방향 테스트
     */
    /**
     * @test testAccelerationDirection
     * @brief 가장 큰 가속도 축을 기반으로 주요 방향을 결정합니다.
     *
     * @details
     * 가장 큰 가속도 축을 기반으로 주요 방향을 결정합니다.
     */
    func testAccelerationDirection() {
        /**
         * 좌회전 (X축이 가장 큼)
         */
        /**
         * x=-2.0 (좌측으로 큰 가속도)
         */
        let leftTurn = AccelerationData(timestamp: Date(), x: -2.0, y: 0.5, z: 1.0)
        XCTAssertEqual(leftTurn.primaryDirection, .left)

        /**
         * 급정거 (Y축이 가장 큼)
         */
        /**
         * y=-3.0 (후방으로 큰 가속도)
         */
        let braking = AccelerationData(timestamp: Date(), x: 0.0, y: -3.0, z: 1.0)
        XCTAssertEqual(braking.primaryDirection, .backward)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - ChannelInfo Tests (채널 정보 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 채널 해상도 테스트
     */
    /**
     * @test testChannelInfoResolution
     * @brief 해상도 문자열과 이름을 올바르게 생성하는지 확인합니다.
     *
     * @details
     * 해상도 문자열과 이름을 올바르게 생성하는지 확인합니다.
     */
    func testChannelInfoResolution() {
        let hd = ChannelInfo.frontHD

        /**
         * 해상도 문자열: "1920x1080"
         */
        XCTAssertEqual(hd.resolutionString, "1920x1080")

        /**
         * 해상도 이름: "Full HD"
         */
        XCTAssertEqual(hd.resolutionName, "Full HD")

        /**
         * 고해상도 플래그
         */
        /**
         *
         * @section ____________1920x1080 💡 고해상도 기준: >= 1920x1080
         */
        XCTAssertTrue(hd.isHighResolution)
    }

    /**
     * 채널 화면 비율 테스트
     */
    /**
     * @test testChannelInfoAspectRatio
     * @brief 16:9, 4:3 등의 화면 비율을 계산합니다.
     *
     * @details
     * 16:9, 4:3 등의 화면 비율을 계산합니다.
     */
    func testChannelInfoAspectRatio() {
        let hd = ChannelInfo.frontHD

        /**
         * 화면 비율 문자열: "16:9"
         */
        XCTAssertEqual(hd.aspectRatioString, "16:9")

        /**
         * 화면 비율 소수: 1.777...
         */
        /**
         * 16 / 9 = 1.777...
         */
        XCTAssertEqual(hd.aspectRatio, 16.0/9.0, accuracy: 0.01)
    }

    /**
     * 채널 유효성 검증 테스트
     */
    /**
     * @test testChannelInfoValidation
     * @brief 필수 필드가 유효한 값을 가지는지 확인합니다.
     *
     * @details
     * 필수 필드가 유효한 값을 가지는지 확인합니다.
     */
    func testChannelInfoValidation() {
        /**
         * 유효한 채널
         */
        let valid = ChannelInfo.frontHD
        XCTAssertTrue(valid.isValid)

        /**
         * 잘못된 채널
         */
        /**
         *
         * @section ______ 💡 무효한 이유
         * - filePath가 비어있음
         * - width = 0
         * - height = 0
         * - frameRate = 0
         */
        let invalid = ChannelInfo(
            position: .front,
            filePath: "",  // Empty path
            width: 0,      // Invalid width
            height: 0,
            frameRate: 0
        )
        XCTAssertFalse(invalid.isValid)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - VideoMetadata Tests (비디오 메타데이터 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @test testVideoMetadataGPSData
     * @brief 비디오 메타데이터 GPS 데이터 테스트
     *
     * @details
     * 비디오 메타데이터 GPS 데이터 테스트
     */
    func testVideoMetadataGPSData() {
        let metadata = VideoMetadata.sample

        /**
         * GPS 데이터 존재 여부
         */
        XCTAssertTrue(metadata.hasGPSData)

        /**
         * 총 이동 거리 (미터)
         */
        XCTAssertGreaterThan(metadata.totalDistance, 0)

        /**
         * 평균 속도 (km/h)
         */
        XCTAssertNotNil(metadata.averageSpeed)

        /**
         * 최대 속도 (km/h)
         */
        XCTAssertNotNil(metadata.maximumSpeed)
    }

    /**
     * @test testVideoMetadataAccelerationData
     * @brief 비디오 메타데이터 가속도 데이터 테스트
     *
     * @details
     * 비디오 메타데이터 가속도 데이터 테스트
     */
    func testVideoMetadataAccelerationData() {
        let metadata = VideoMetadata.sample

        /**
         * 가속도 데이터 존재 여부
         */
        XCTAssertTrue(metadata.hasAccelerationData)

        /**
         * 최대 G-force
         */
        XCTAssertNotNil(metadata.maximumGForce)
    }

    /**
     * @test testVideoMetadataImpactDetection
     * @brief 비디오 메타데이터 충격 감지 테스트
     *
     * @details
     * 비디오 메타데이터 충격 감지 테스트
     */
    func testVideoMetadataImpactDetection() {
        /**
         * GPS만 있는 메타데이터 (충격 없음)
         */
        let noImpact = VideoMetadata.gpsOnly
        XCTAssertFalse(noImpact.hasImpactEvents)

        /**
         * 충격 이벤트가 있는 메타데이터
         */
        let withImpact = VideoMetadata.withImpact
        XCTAssertTrue(withImpact.hasImpactEvents)
        XCTAssertGreaterThan(withImpact.impactEvents.count, 0)
    }

    /**
     * @test testVideoMetadataPointRetrieval
     * @brief 비디오 메타데이터 포인트 검색 테스트
     *
     * @details
     * 비디오 메타데이터 포인트 검색 테스트
     */
    func testVideoMetadataPointRetrieval() {
        let metadata = VideoMetadata.sample

        /**
         * 특정 시간의 GPS 포인트 검색
         */
        /**
         *
         * @section 1_0______gps______ 💡 1.0초 시점의 GPS 좌표 조회
         */
        let gpsPoint = metadata.gpsPoint(at: 1.0)
        XCTAssertNotNil(gpsPoint)

        /**
         * 특정 시간의 가속도 데이터 검색
         */
        /**
         *
         * @section 1_0____________ 💡 1.0초 시점의 가속도 조회
         */
        let accelData = metadata.accelerationData(at: 1.0)
        XCTAssertNotNil(accelData)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - VideoFile Tests (비디오 파일 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @test testVideoFileChannelAccess
     * @brief 비디오 파일 채널 접근 테스트
     *
     * @details
     * 비디오 파일 채널 접근 테스트
     */
    func testVideoFileChannelAccess() {
        let video = VideoFile.normal5Channel

        /**
         * 총 채널 수
         */
        XCTAssertEqual(video.channelCount, 5)

        /**
         * 멀티 채널 여부 (2개 이상)
         */
        XCTAssertTrue(video.isMultiChannel)

        /**
         * 전방 채널 존재 확인
         */
        XCTAssertNotNil(video.frontChannel)

        /**
         * 후방 채널 존재 확인
         */
        XCTAssertNotNil(video.rearChannel)

        /**
         * 특정 채널 존재 여부
         */
        XCTAssertTrue(video.hasChannel(.front))
        XCTAssertTrue(video.hasChannel(.rear))
    }

    /**
     * @test testVideoFileProperties
     * @brief 비디오 파일 속성 테스트
     *
     * @details
     * 비디오 파일 속성 테스트
     */
    func testVideoFileProperties() {
        let video = VideoFile.normal5Channel

        /**
         * 이벤트 유형
         */
        XCTAssertEqual(video.eventType, .normal)

        /**
         * 재생 시간 (초)
         */
        XCTAssertEqual(video.duration, 60.0)

        /**
         * 총 파일 크기 (바이트)
         */
        XCTAssertGreaterThan(video.totalFileSize, 0)

        /**
         * 즐겨찾기 상태 (기본값: false)
         */
        XCTAssertFalse(video.isFavorite)
    }

    /**
     * @test testVideoFileValidation
     * @brief 비디오 파일 유효성 검증 테스트
     *
     * @details
     * 비디오 파일 유효성 검증 테스트
     */
    func testVideoFileValidation() {
        /**
         * 유효한 비디오 파일
         */
        let valid = VideoFile.normal5Channel
        XCTAssertTrue(valid.isValid)
        XCTAssertTrue(valid.isPlayable)

        /**
         * 손상된 비디오 파일
         */
        let corrupted = VideoFile.corruptedFile
        XCTAssertFalse(corrupted.isPlayable)
    }

    /**
     * 비디오 파일 변경 테스트
     */
    /**
     * @test testVideoFileMutations
     * @brief 💡 struct의 불변성:
     *
     * @details
     *
     * @section struct_____ 💡 struct의 불변성
     * - 원본은 변경되지 않음
     * - 새로운 인스턴스 반환
     */
    func testVideoFileMutations() {
        let original = VideoFile.normal5Channel
        XCTAssertFalse(original.isFavorite)

        /**
         * 즐겨찾기 추가
         */
        let favorited = original.withFavorite(true)
        XCTAssertTrue(favorited.isFavorite)
        XCTAssertEqual(favorited.id, original.id)  // ID는 유지

        /**
         * 메모 추가
         */
        let withNotes = original.withNotes("Test note")
        XCTAssertEqual(withNotes.notes, "Test note")
    }

    /**
     * @test testVideoFileMetadata
     * @brief 비디오 파일 메타데이터 테스트
     *
     * @details
     * 비디오 파일 메타데이터 테스트
     */
    func testVideoFileMetadata() {
        let video = VideoFile.normal5Channel
        XCTAssertTrue(video.hasGPSData)
        XCTAssertTrue(video.hasAccelerationData)

        let impactVideo = VideoFile.impact2Channel
        XCTAssertTrue(impactVideo.hasImpactEvents)
    }

    /**
     * @test testVideoFileFormatting
     * @brief 비디오 파일 포맷팅 테스트
     *
     * @details
     * 비디오 파일 포맷팅 테스트
     */
    func testVideoFileFormatting() {
        let video = VideoFile.normal5Channel

        /**
         * 재생 시간 문자열 (예: "01:00")
         */
        XCTAssertFalse(video.durationString.isEmpty)

        /**
         * 타임스탬프 문자열 (예: "2025-01-10 09:00:00")
         */
        XCTAssertFalse(video.timestampString.isEmpty)

        /**
         * 파일 크기 문자열 (예: "125.5 MB")
         */
        XCTAssertFalse(video.totalFileSizeString.isEmpty)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Codable Tests (직렬화/역직렬화 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * GPSPoint Codable 테스트
     */
    /**
     * @test testGPSPointCodable
     * @brief 💡 Codable 프로토콜:
     *
     * @details
     *
     * @section codable_____ 💡 Codable 프로토콜
     * - JSON으로 인코딩
     * - JSON에서 디코딩
     * - 데이터 영속화 및 전송용
     */
    func testGPSPointCodable() throws {
        let original = GPSPoint.sample

        /**
         * JSON 인코딩
         */
        let encoded = try JSONEncoder().encode(original)

        /**
         * JSON 디코딩
         */
        let decoded = try JSONDecoder().decode(GPSPoint.self, from: encoded)

        /**
         * 데이터 보존 검증
         */
        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
    }

    /**
     * @test testAccelerationDataCodable
     * @brief AccelerationData Codable 테스트
     *
     * @details
     * AccelerationData Codable 테스트
     */
    func testAccelerationDataCodable() throws {
        let original = AccelerationData.impact

        /**
         * JSON 인코딩
         */
        let encoded = try JSONEncoder().encode(original)

        /**
         * JSON 디코딩
         */
        let decoded = try JSONDecoder().decode(AccelerationData.self, from: encoded)

        /**
         * 3축 데이터 보존 검증
         */
        XCTAssertEqual(decoded.x, original.x)
        XCTAssertEqual(decoded.y, original.y)
        XCTAssertEqual(decoded.z, original.z)
    }

    /**
     * @test testVideoFileCodable
     * @brief VideoFile Codable 테스트
     *
     * @details
     * VideoFile Codable 테스트
     */
    func testVideoFileCodable() throws {
        let original = VideoFile.normal5Channel

        /**
         * JSON 인코딩
         */
        let encoded = try JSONEncoder().encode(original)

        /**
         * JSON 디코딩
         */
        let decoded = try JSONDecoder().decode(VideoFile.self, from: encoded)

        /**
         * 주요 속성 보존 검증
         */
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.eventType, original.eventType)
        XCTAssertEqual(decoded.duration, original.duration)
        XCTAssertEqual(decoded.channelCount, original.channelCount)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Performance Tests (성능 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * GPS 거리 계산 성능 테스트
     */
    /**
     * @test testGPSDistanceCalculationPerformance
     * @brief 💡 Haversine 공식의 성능:
     *
     * @details
     *
     * @section haversine_______ 💡 Haversine 공식의 성능
     * - 삼각함수 (sin, cos, asin) 사용
     * - 부동소수점 연산 집약적
     * - 많은 포인트 처리 시 최적화 필요
     */
    func testGPSDistanceCalculationPerformance() {
        let points = GPSPoint.sampleRoute

        /**
         * 10회 반복 측정
         */
        measure {
            /**
             * 모든 연속된 포인트 쌍의 거리 계산
             */
            for i in 0..<(points.count - 1) {
                _ = points[i].distance(to: points[i + 1])
            }
        }
    }

    /**
     * 비디오 메타데이터 요약 생성 성능 테스트
     */
    /**
     * @test testVideoMetadataSummaryPerformance
     * @brief 💡 요약 생성 과정:
     *
     * @details
     *
     * @section ________ 💡 요약 생성 과정
     * - 모든 GPS 포인트 처리
     * - 모든 가속도 데이터 처리
     * - 통계 계산 (평균, 최대, 최소)
     * - 이벤트 분석
     */
    func testVideoMetadataSummaryPerformance() {
        let metadata = VideoMetadata.sample

        /**
         * 10회 반복 측정
         */
        measure {
            /**
             * 요약 문자열 생성
             */
            _ = metadata.summary
        }
    }
}
