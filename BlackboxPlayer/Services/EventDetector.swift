/// @file EventDetector.swift
/// @brief 비디오 이벤트 자동 감지 서비스
/// @author BlackboxPlayer Development Team
/// @details
/// GPS 데이터를 분석하여 급가속, 급감속, 급회전 등의 이벤트를 자동으로 감지하는 서비스입니다.
/// 속도 변화율과 방향 변화를 분석하여 이벤트 마커를 생성합니다.

import Foundation

/// @class EventDetector
/// @brief 이벤트 자동 감지 서비스
///
/// @details
/// GPS 데이터를 분석하여 운전 이벤트를 자동으로 감지합니다.
///
/// ## 감지 알고리즘
///
/// ### 1. 급감속 (Hard Braking)
/// ```
/// 조건:
/// - 속도 감소량 ≥ 20 km/h
/// - 시간 간격 ≤ 0.5초
/// - 현재 속도 > 10 km/h (정지 상태 아님)
///
/// 강도 계산:
/// magnitude = min(1.0, 속도감소량 / 50.0)
/// ```
///
/// ### 2. 급가속 (Rapid Acceleration)
/// ```
/// 조건:
/// - 속도 증가량 ≥ 20 km/h
/// - 시간 간격 ≤ 0.5초
/// - 이전 속도 < 100 km/h (이미 고속이 아님)
///
/// 강도 계산:
/// magnitude = min(1.0, 속도증가량 / 60.0)
/// ```
///
/// ### 3. 급회전 (Sharp Turn)
/// ```
/// 조건:
/// - 방향 변화 ≥ 45도
/// - 속도 > 20 km/h (일정 속도 이상)
/// - 속도 변화 < 10 km/h (급감속이 아님)
///
/// 강도 계산:
/// magnitude = min(1.0, 방향변화량 / 90.0)
/// ```
///
/// ## 사용 예제
/// ```swift
/// let detector = EventDetector()
/// let gpsPoints = loadGPSData()
///
/// // 이벤트 감지
/// let events = detector.detectEvents(from: gpsPoints)
///
/// // 결과 출력
/// for event in events {
///     print(event.description)
/// }
/// ```
class EventDetector {
    // MARK: - Constants

    /// 급감속 감지 임계값 (km/h)
    private let hardBrakingThreshold: Double = 20.0

    /// 급가속 감지 임계값 (km/h)
    private let rapidAccelerationThreshold: Double = 20.0

    /// 급회전 감지 임계값 (도)
    private let sharpTurnThreshold: Double = 45.0

    /// 이벤트 감지를 위한 최대 시간 간격 (초)
    private let maxTimeInterval: TimeInterval = 0.5

    /// 급회전 감지를 위한 최소 속도 (km/h)
    private let minSpeedForTurn: Double = 20.0

    // MARK: - Public Methods

    /// @brief GPS 데이터로부터 이벤트 감지
    /// @param gpsPoints GPS 포인트 배열 (시간 순 정렬)
    /// @return 감지된 이벤트 마커 배열
    ///
    /// @details
    /// GPS 데이터를 분석하여 급가속, 급감속, 급회전 이벤트를 감지합니다.
    ///
    /// **전제 조건:**
    /// - gpsPoints는 timestamp 기준으로 정렬되어 있어야 함
    /// - 최소 2개 이상의 GPS 포인트 필요
    ///
    /// **반환값:**
    /// - 감지된 모든 이벤트 마커 배열 (timestamp 순 정렬)
    /// - GPS 데이터가 부족하면 빈 배열 반환
    func detectEvents(from gpsPoints: [GPSPoint]) -> [EventMarker] {
        // 최소 2개의 GPS 포인트 필요
        guard gpsPoints.count >= 2 else {
            return []
        }

        var events: [EventMarker] = []

        // 연속된 GPS 포인트 쌍을 분석
        for i in 1..<gpsPoints.count {
            let previousPoint = gpsPoints[i - 1]
            let currentPoint = gpsPoints[i]

            // 시간 간격 계산
            let timeInterval = currentPoint.timestamp.timeIntervalSince(previousPoint.timestamp)

            // 시간 간격이 너무 크면 스킵 (데이터 누락)
            guard timeInterval > 0 && timeInterval <= maxTimeInterval else {
                continue
            }

            // 속도 변화 분석
            if let eventMarker = detectSpeedChangeEvent(
                previous: previousPoint,
                current: currentPoint,
                timeInterval: timeInterval
            ) {
                events.append(eventMarker)
            }

            // 방향 변화 분석 (급회전)
            if let eventMarker = detectTurnEvent(
                previous: previousPoint,
                current: currentPoint,
                timeInterval: timeInterval
            ) {
                events.append(eventMarker)
            }
        }

        // 타임스탬프 순으로 정렬
        return events.sorted()
    }

    // MARK: - Private Methods

    /// @brief 속도 변화 이벤트 감지 (급가속/급감속)
    /// @param previous 이전 GPS 포인트
    /// @param current 현재 GPS 포인트
    /// @param timeInterval 시간 간격 (초)
    /// @return EventMarker 또는 nil
    private func detectSpeedChangeEvent(
        previous: GPSPoint,
        current: GPSPoint,
        timeInterval: TimeInterval
    ) -> EventMarker? {
        // 속도 정보가 없으면 스킵
        guard let previousSpeed = previous.speed,
              let currentSpeed = current.speed else {
            return nil
        }

        // 속도 변화량 계산 (km/h)
        let speedChange = currentSpeed - previousSpeed

        // 급감속 감지
        if speedChange <= -hardBrakingThreshold && currentSpeed > 10.0 {
            // 강도 계산: 속도 감소량에 비례 (최대 50km/h 기준)
            let magnitude = min(1.0, abs(speedChange) / 50.0)

            return EventMarker(
                timestamp: current.timestamp.timeIntervalSince1970,
                type: .hardBraking,
                magnitude: magnitude,
                metadata: [
                    "speed_before": previousSpeed,
                    "speed_after": currentSpeed,
                    "speed_change": speedChange,
                    "time_interval": timeInterval,
                    "gps_lat": current.latitude,
                    "gps_lon": current.longitude
                ]
            )
        }

        // 급가속 감지
        if speedChange >= rapidAccelerationThreshold && previousSpeed < 100.0 {
            // 강도 계산: 속도 증가량에 비례 (최대 60km/h 기준)
            let magnitude = min(1.0, speedChange / 60.0)

            return EventMarker(
                timestamp: current.timestamp.timeIntervalSince1970,
                type: .rapidAcceleration,
                magnitude: magnitude,
                metadata: [
                    "speed_before": previousSpeed,
                    "speed_after": currentSpeed,
                    "speed_change": speedChange,
                    "time_interval": timeInterval,
                    "gps_lat": current.latitude,
                    "gps_lon": current.longitude
                ]
            )
        }

        return nil
    }

    /// @brief 방향 변화 이벤트 감지 (급회전)
    /// @param previous 이전 GPS 포인트
    /// @param current 현재 GPS 포인트
    /// @param timeInterval 시간 간격 (초)
    /// @return EventMarker 또는 nil
    private func detectTurnEvent(
        previous: GPSPoint,
        current: GPSPoint,
        timeInterval: TimeInterval
    ) -> EventMarker? {
        // 방향과 속도 정보가 없으면 스킵
        guard let previousHeading = previous.heading,
              let currentHeading = current.heading,
              let previousSpeed = previous.speed,
              let currentSpeed = current.speed else {
            return nil
        }

        // 속도가 너무 낮으면 스킵 (정지 또는 저속)
        guard previousSpeed > minSpeedForTurn && currentSpeed > minSpeedForTurn else {
            return nil
        }

        // 방향 변화량 계산 (0 ~ 180도 범위)
        let headingChange = calculateHeadingChange(from: previousHeading, to: currentHeading)

        // 급회전 감지
        if headingChange >= sharpTurnThreshold {
            // 속도 변화량 (급감속과 동시에 일어나면 급회전으로 분류 안 함)
            let speedChange = abs(currentSpeed - previousSpeed)

            // 급감속이 아닌 경우만 급회전으로 분류
            guard speedChange < 10.0 else {
                return nil
            }

            // 강도 계산: 방향 변화량에 비례 (최대 90도 기준)
            let magnitude = min(1.0, headingChange / 90.0)

            return EventMarker(
                timestamp: current.timestamp.timeIntervalSince1970,
                type: .sharpTurn,
                magnitude: magnitude,
                metadata: [
                    "heading_before": previousHeading,
                    "heading_after": currentHeading,
                    "heading_change": headingChange,
                    "speed": currentSpeed,
                    "time_interval": timeInterval,
                    "gps_lat": current.latitude,
                    "gps_lon": current.longitude
                ]
            )
        }

        return nil
    }

    /// @brief 방향 변화량 계산 (0 ~ 180도 범위)
    /// @param fromHeading 시작 방향 (0 ~ 360도)
    /// @param toHeading 끝 방향 (0 ~ 360도)
    /// @return 방향 변화량 (0 ~ 180도)
    ///
    /// @details
    /// 두 방향 사이의 최소 각도를 계산합니다.
    ///
    /// **예시:**
    /// ```
    /// from: 10도, to: 350도 → 20도 (시계 반대방향)
    /// from: 350도, to: 10도 → 20도 (시계방향)
    /// from: 0도, to: 180도 → 180도
    /// from: 0도, to: 90도 → 90도
    /// ```
    private func calculateHeadingChange(from fromHeading: Double, to toHeading: Double) -> Double {
        // 방향 차이 계산
        var diff = abs(toHeading - fromHeading)

        // 180도 이상이면 반대 방향으로 계산 (최소 각도)
        if diff > 180 {
            diff = 360 - diff
        }

        return diff
    }

    /// @brief 이벤트 필터링 (중복 제거)
    /// @param events 원본 이벤트 배열
    /// @param minInterval 최소 간격 (초)
    /// @return 필터링된 이벤트 배열
    ///
    /// @details
    /// 같은 종류의 이벤트가 짧은 시간 내에 여러 번 감지되면
    /// 가장 강한 이벤트만 남기고 나머지는 제거합니다.
    ///
    /// **사용 예:**
    /// ```swift
    /// let filtered = detector.filterDuplicateEvents(events, minInterval: 2.0)
    /// ```
    func filterDuplicateEvents(_ events: [EventMarker], minInterval: TimeInterval = 2.0) -> [EventMarker] {
        guard !events.isEmpty else {
            return []
        }

        var filteredEvents: [EventMarker] = []
        var lastEventByType: [DrivingEventType: EventMarker] = [:]

        for event in events.sorted() {
            // 같은 종류의 이전 이벤트 확인
            if let lastEvent = lastEventByType[event.type] {
                // 시간 간격 확인
                let interval = event.timestamp - lastEvent.timestamp

                if interval < minInterval {
                    // 간격이 짧으면 더 강한 이벤트만 유지
                    if event.magnitude > lastEvent.magnitude {
                        // 현재 이벤트가 더 강함
                        if let index = filteredEvents.firstIndex(where: { $0.id == lastEvent.id }) {
                            filteredEvents.remove(at: index)
                        }
                        filteredEvents.append(event)
                        lastEventByType[event.type] = event
                    }
                    // 이전 이벤트가 더 강하면 현재 이벤트 무시
                    continue
                }
            }

            // 새 이벤트 추가
            filteredEvents.append(event)
            lastEventByType[event.type] = event
        }

        return filteredEvents.sorted()
    }
}
