/// @file EventMarker.swift
/// @brief 비디오 이벤트 마커 모델
/// @author BlackboxPlayer Development Team
/// @details
/// 블랙박스 비디오에서 감지된 이벤트(급가속, 급감속, 급회전 등)를 표현하는 모델입니다.
/// GPS 데이터 분석을 통해 자동으로 이벤트를 감지하고 타임라인에 표시합니다.

import Foundation

/// @enum EventType
/// @brief 이벤트 유형
///
/// @details
/// GPS 데이터 분석으로 감지 가능한 이벤트 유형입니다.
///
/// ## 감지 기준
/// - **hardBraking**: 0.5초 내 20km/h 이상 감속 (충격 위험)
/// - **rapidAcceleration**: 0.5초 내 20km/h 이상 가속 (급발진)
/// - **sharpTurn**: 속도 유지 중 45도 이상 급격한 방향 전환 (전복 위험)
///
/// ## 색상 코딩
/// - hardBraking → 빨간색 (위험)
/// - rapidAcceleration → 주황색 (경고)
/// - sharpTurn → 노란색 (주의)
enum EventType: String, Codable {
    /// 급감속 (급정거)
    case hardBraking = "hard_braking"

    /// 급가속
    case rapidAcceleration = "rapid_acceleration"

    /// 급회전
    case sharpTurn = "sharp_turn"

    /// @brief 이벤트 표시 이름
    var displayName: String {
        switch self {
        case .hardBraking:
            return "급감속"
        case .rapidAcceleration:
            return "급가속"
        case .sharpTurn:
            return "급회전"
        }
    }

    /// @brief 이벤트 설명
    var description: String {
        switch self {
        case .hardBraking:
            return "급격한 속도 감소"
        case .rapidAcceleration:
            return "급격한 속도 증가"
        case .sharpTurn:
            return "급격한 방향 전환"
        }
    }

    /// @brief 이벤트 심각도 (0.0 ~ 1.0)
    ///
    /// @details
    /// 위험도 순위:
    /// 1. hardBraking: 1.0 (충격 사고 가능성)
    /// 2. sharpTurn: 0.7 (전복 사고 가능성)
    /// 3. rapidAcceleration: 0.5 (급발진)
    var severity: Double {
        switch self {
        case .hardBraking:
            return 1.0
        case .sharpTurn:
            return 0.7
        case .rapidAcceleration:
            return 0.5
        }
    }
}

/// @struct EventMarker
/// @brief 비디오 이벤트 마커
///
/// @details
/// 비디오 재생 중 특정 시점에 발생한 이벤트를 표시하는 마커입니다.
///
/// ## 사용 예제
/// ```swift
/// let marker = EventMarker(
///     timestamp: 15.5,
///     type: .hardBraking,
///     magnitude: 0.8,
///     metadata: ["speed_before": 80.0, "speed_after": 50.0]
/// )
///
/// print(marker.displayName)  // "급감속"
/// print(marker.description)  // "15.5초: 급격한 속도 감소 (강도: 80%)"
/// ```
struct EventMarker: Identifiable, Codable {
    // MARK: - Properties

    /// @var id
    /// @brief 고유 식별자
    let id: UUID

    /// @var timestamp
    /// @brief 이벤트 발생 시간 (초)
    ///
    /// @details
    /// 비디오 재생 시간 기준 (0초부터 시작)
    /// 타임라인에서의 위치를 결정합니다.
    let timestamp: TimeInterval

    /// @var type
    /// @brief 이벤트 유형
    let type: EventType

    /// @var magnitude
    /// @brief 이벤트 강도 (0.0 ~ 1.0)
    ///
    /// @details
    /// 이벤트의 심각도를 나타내는 0~1 범위의 값입니다.
    /// - 0.0 ~ 0.3: 경미
    /// - 0.3 ~ 0.7: 보통
    /// - 0.7 ~ 1.0: 심각
    ///
    /// **계산 예시 (급감속):**
    /// ```
    /// 속도 변화량 = |속도_이후 - 속도_이전|
    /// magnitude = min(1.0, 속도변화량 / 50.0)
    ///
    /// 예: 80km/h → 30km/h (50km/h 감소)
    /// magnitude = 50 / 50 = 1.0 (매우 심각)
    /// ```
    let magnitude: Double

    /// @var metadata
    /// @brief 추가 메타데이터
    ///
    /// @details
    /// 이벤트와 관련된 추가 정보를 저장합니다.
    ///
    /// **저장 가능한 정보:**
    /// - "speed_before": 이벤트 이전 속도 (km/h)
    /// - "speed_after": 이벤트 이후 속도 (km/h)
    /// - "heading_before": 이전 방향 (도)
    /// - "heading_after": 이후 방향 (도)
    /// - "gps_lat": GPS 위도
    /// - "gps_lon": GPS 경도
    let metadata: [String: Double]?

    // MARK: - Initialization

    /// @brief EventMarker 초기화
    /// @param timestamp 이벤트 발생 시간 (초)
    /// @param type 이벤트 유형
    /// @param magnitude 이벤트 강도 (0.0 ~ 1.0)
    /// @param metadata 추가 메타데이터 (선택사항)
    init(
        timestamp: TimeInterval,
        type: EventType,
        magnitude: Double,
        metadata: [String: Double]? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.type = type
        self.magnitude = min(1.0, max(0.0, magnitude))  // 0~1 범위로 제한
        self.metadata = metadata
    }

    // MARK: - Computed Properties

    /// @brief 이벤트 표시 이름
    var displayName: String {
        return type.displayName
    }

    /// @brief 이벤트 상세 설명
    var description: String {
        let magnitudePercent = Int(magnitude * 100)
        return "\(String(format: "%.1f", timestamp))초: \(type.description) (강도: \(magnitudePercent)%)"
    }

    /// @brief 시간 포맷 문자열 (MM:SS)
    var timeString: String {
        let totalSeconds = Int(timestamp)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Comparable

extension EventMarker: Comparable {
    /// @brief 타임스탬프 기준으로 정렬
    static func < (lhs: EventMarker, rhs: EventMarker) -> Bool {
        return lhs.timestamp < rhs.timestamp
    }
}

// MARK: - Sample Data

extension EventMarker {
    /// @brief 샘플 이벤트 마커 (급감속)
    static let sampleHardBraking = EventMarker(
        timestamp: 15.5,
        type: .hardBraking,
        magnitude: 0.8,
        metadata: [
            "speed_before": 80.0,
            "speed_after": 30.0,
            "gps_lat": 37.5665,
            "gps_lon": 126.9780
        ]
    )

    /// @brief 샘플 이벤트 마커 (급가속)
    static let sampleRapidAcceleration = EventMarker(
        timestamp: 32.0,
        type: .rapidAcceleration,
        magnitude: 0.6,
        metadata: [
            "speed_before": 20.0,
            "speed_after": 60.0
        ]
    )

    /// @brief 샘플 이벤트 마커 (급회전)
    static let sampleSharpTurn = EventMarker(
        timestamp: 48.5,
        type: .sharpTurn,
        magnitude: 0.7,
        metadata: [
            "heading_before": 45.0,
            "heading_after": 135.0
        ]
    )

    /// @brief 샘플 이벤트 마커 배열
    static let samples: [EventMarker] = [
        sampleHardBraking,
        sampleRapidAcceleration,
        sampleSharpTurn
    ]
}
