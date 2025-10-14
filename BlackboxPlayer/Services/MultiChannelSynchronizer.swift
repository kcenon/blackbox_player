/// @file MultiChannelSynchronizer.swift
/// @brief Multi-channel video synchronization coordinator
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 블랙박스의 여러 카메라 채널을 동기화하는 클래스를 정의합니다.
/// 블랙박스는 보통 전면/후면/좌측/우측 카메라를 동시에 녹화하므로,
/// 재생 시 모든 채널이 같은 시간을 표시해야 합니다.

import Foundation

/// @enum SyncError
/// @brief 동기화 관련 에러
enum SyncError: Error {
    case channelNotFound(String)
    case decoderNotInitialized(String)
    case seekFailed(String)
    case unknown(String)
}

/// @class MultiChannelSynchronizer
/// @brief 여러 비디오 채널을 동기화하는 클래스입니다.
///
/// @details
/// ## 주요 기능:
/// - 여러 VideoDecoder 인스턴스 관리
/// - 마스터 타임라인 유지
/// - 모든 채널을 동일한 타임스탬프로 동기화
/// - 재생/일시정지/seek를 모든 채널에 동시 적용
///
/// ## 사용 예:
/// ```swift
/// let sync = MultiChannelSynchronizer()
/// sync.addChannel(id: "front", decoder: frontDecoder)
/// sync.addChannel(id: "rear", decoder: rearDecoder)
///
/// // 모든 채널을 30초로 이동
/// try sync.seekAll(to: 30.0)
///
/// // 모든 채널의 다음 프레임 가져오기
/// let frames = try sync.stepForwardAll()
/// ```
class MultiChannelSynchronizer {

    // MARK: - Properties

    /// @var channels
    /// @brief 채널별 VideoDecoder 딕셔너리
    /// @details
    /// - Key: 채널 ID (예: "front", "rear", "left", "right", "interior")
    /// - Value: VideoDecoder 인스턴스
    private var channels: [String: VideoDecoder] = [:]

    /// @var masterTimestamp
    /// @brief 마스터 타임라인의 현재 타임스탬프
    /// @details
    /// - 모든 채널이 이 시간에 맞춰 동기화됨
    /// - 재생/seek 시 이 값을 기준으로 동작
    private(set) var masterTimestamp: TimeInterval = 0

    /// @var isPlaying
    /// @brief 재생 중 여부
    private(set) var isPlaying: Bool = false

    /// @var tolerance
    /// @brief 동기화 허용 오차 (초 단위)
    /// @details
    /// - 채널 간 타임스탬프 차이가 이 값 이하면 동기화된 것으로 간주
    /// - 기본값: 0.033초 (약 1프레임, 30fps 기준)
    private let tolerance: TimeInterval = 0.033

    /// @var autoCorrectionThreshold
    /// @brief 자동 수정 임계값 (초 단위)
    /// @details
    /// - 드리프트가 이 값을 초과하면 자동으로 수정
    /// - 기본값: 0.050초 (50ms, 약 1.5프레임)
    private let autoCorrectionThreshold: TimeInterval = 0.050

    /// @var monitoringEnabled
    /// @brief 드리프트 모니터링 활성화 여부
    private var monitoringEnabled: Bool = false

    /// @var monitoringTimer
    /// @brief 드리프트 모니터링 타이머
    private var monitoringTimer: Timer?

    /// @var driftHistory
    /// @brief 드리프트 히스토리 (통계용)
    /// @details
    /// - 최근 100개의 드리프트 값 저장
    /// - 평균, 최대값 계산에 사용
    private var driftHistory: [TimeInterval] = []

    /// @var maxDriftHistorySize
    /// @brief 드리프트 히스토리 최대 크기
    private let maxDriftHistorySize = 100

    // MARK: - Initialization

    /// @brief 동기화 객체를 생성합니다.
    init() {
        // 초기화 로직 없음
    }

    // MARK: - Channel Management

    /// @brief 채널을 추가합니다.
    ///
    /// @param id 채널 ID (예: "front", "rear")
    /// @param decoder VideoDecoder 인스턴스
    ///
    /// @details
    /// 동일한 ID로 여러 번 호출하면 기존 채널을 덮어씁니다.
    func addChannel(id: String, decoder: VideoDecoder) {
        channels[id] = decoder
    }

    /// @brief 채널을 제거합니다.
    ///
    /// @param id 제거할 채널 ID
    func removeChannel(id: String) {
        channels.removeValue(forKey: id)
    }

    /// @brief 모든 채널을 제거합니다.
    func removeAllChannels() {
        channels.removeAll()
    }

    /// @brief 등록된 채널 ID 목록을 반환합니다.
    ///
    /// @return 채널 ID 배열
    func getChannelIDs() -> [String] {
        return Array(channels.keys)
    }

    /// @brief 특정 채널의 디코더를 가져옵니다.
    ///
    /// @param id 채널 ID
    /// @return VideoDecoder 인스턴스, 없으면 nil
    func getDecoder(for id: String) -> VideoDecoder? {
        return channels[id]
    }

    // MARK: - Synchronization

    /// @brief 모든 채널을 특정 시간으로 이동합니다.
    ///
    /// @param timestamp 이동할 시간 (초 단위)
    ///
    /// @throws SyncError
    ///
    /// @details
    /// 모든 채널을 동시에 같은 타임스탬프로 seek합니다.
    /// 하나라도 실패하면 에러를 throw합니다.
    func seekAll(to timestamp: TimeInterval) throws {
        // 모든 채널을 지정된 시간으로 seek
        for (channelID, decoder) in channels {
            do {
                try decoder.seek(to: timestamp)
            } catch {
                throw SyncError.seekFailed("Failed to seek channel '\(channelID)': \(error)")
            }
        }

        // 마스터 타임스탬프 업데이트
        masterTimestamp = timestamp
    }

    /// @brief 모든 채널을 특정 프레임 번호로 이동합니다.
    ///
    /// @param frameNumber 이동할 프레임 번호
    ///
    /// @throws SyncError
    ///
    /// @details
    /// 각 채널의 프레임레이트가 다를 수 있으므로,
    /// 프레임 번호를 타임스탬프로 변환하여 동기화합니다.
    func seekAllToFrame(_ frameNumber: Int) throws {
        // 첫 번째 채널의 프레임레이트를 기준으로 타임스탬프 계산
        guard let firstDecoder = channels.values.first,
              let videoInfo = firstDecoder.videoInfo else {
            throw SyncError.decoderNotInitialized("No initialized decoder found")
        }

        let timestamp = Double(frameNumber) / videoInfo.frameRate
        try seekAll(to: timestamp)
    }

    /// @brief 모든 채널의 다음 프레임으로 이동합니다.
    ///
    /// @return 채널별 비디오 프레임 딕셔너리
    ///
    /// @throws SyncError
    ///
    /// @details
    /// 각 채널에서 다음 비디오 프레임을 디코딩하여 반환합니다.
    /// 마스터 타임스탬프는 가장 빠른 채널 기준으로 업데이트됩니다.
    func stepForwardAll() throws -> [String: VideoFrame] {
        var frames: [String: VideoFrame] = [:]
        var maxTimestamp: TimeInterval = masterTimestamp

        // 각 채널에서 다음 프레임 가져오기
        for (channelID, decoder) in channels {
            if let frame = try decoder.stepForward() {
                frames[channelID] = frame
                maxTimestamp = max(maxTimestamp, frame.timestamp)
            }
        }

        // 마스터 타임스탬프 업데이트
        masterTimestamp = maxTimestamp

        return frames
    }

    /// @brief 모든 채널의 이전 프레임으로 이동합니다.
    ///
    /// @throws SyncError
    ///
    /// @details
    /// 각 채널을 이전 프레임으로 이동시킵니다.
    /// seek 기반이므로 정확히 1프레임 뒤로 가지 않을 수 있습니다.
    func stepBackwardAll() throws {
        // 모든 채널을 이전 프레임으로 이동
        for (channelID, decoder) in channels {
            do {
                try decoder.stepBackward()
            } catch {
                throw SyncError.seekFailed("Failed to step backward on channel '\(channelID)': \(error)")
            }
        }

        // 마스터 타임스탬프 업데이트 (첫 번째 채널 기준)
        if let firstDecoder = channels.values.first {
            masterTimestamp = firstDecoder.getCurrentTimestamp()
        }
    }

    /// @brief 현재 마스터 타임스탬프를 반환합니다.
    ///
    /// @return 현재 타임스탬프 (초 단위)
    func getCurrentTimestamp() -> TimeInterval {
        return masterTimestamp
    }

    /// @brief 모든 채널이 동기화되어 있는지 확인합니다.
    ///
    /// @return 모든 채널의 타임스탬프 차이가 허용 오차 이내면 true
    ///
    /// @details
    /// 각 채널의 currentTimestamp를 비교하여
    /// 최대 차이가 tolerance 이내인지 확인합니다.
    func isSynchronized() -> Bool {
        guard !channels.isEmpty else { return true }

        let timestamps = channels.values.map { $0.getCurrentTimestamp() }
        guard let minTimestamp = timestamps.min(),
              let maxTimestamp = timestamps.max() else {
            return false
        }

        let difference = maxTimestamp - minTimestamp
        return difference <= tolerance
    }

    // MARK: - Playback Control

    /// @brief 재생을 시작합니다.
    ///
    /// @details
    /// 실제 프레임 디코딩은 외부 타이머나 루프에서 수행해야 합니다.
    /// 이 메서드는 재생 상태만 변경합니다.
    func play() {
        isPlaying = true
    }

    /// @brief 재생을 일시정지합니다.
    func pause() {
        isPlaying = false
    }

    /// @brief 재생을 중지하고 처음으로 돌아갑니다.
    ///
    /// @throws SyncError
    func stop() throws {
        isPlaying = false
        try seekAll(to: 0)
    }

    // MARK: - Information

    /// @brief 모든 채널의 상태를 문자열로 반환합니다.
    ///
    /// @return 채널별 타임스탬프 정보
    ///
    /// @details
    /// 디버깅 용도로 각 채널의 현재 타임스탬프를 출력합니다.
    func getStatusString() -> String {
        var status = "Master: \(String(format: "%.3f", masterTimestamp))s\n"
        status += "Channels:\n"

        for (channelID, decoder) in channels.sorted(by: { $0.key < $1.key }) {
            let timestamp = decoder.getCurrentTimestamp()
            let diff = abs(timestamp - masterTimestamp)
            status += "  \(channelID): \(String(format: "%.3f", timestamp))s (diff: \(String(format: "%.3f", diff))s)\n"
        }

        status += "Synchronized: \(isSynchronized())"

        // 드리프트 통계 추가
        if !driftHistory.isEmpty {
            let avgDrift = driftHistory.reduce(0, +) / Double(driftHistory.count)
            let maxDrift = driftHistory.max() ?? 0
            status += "\nDrift Stats: Avg=\(String(format: "%.3f", avgDrift * 1000))ms, Max=\(String(format: "%.3f", maxDrift * 1000))ms"
        }

        return status
    }

    // MARK: - Drift Monitoring

    /// @brief 드리프트 모니터링을 시작합니다.
    ///
    /// @param interval 모니터링 간격 (초 단위), 기본값 0.1초 (100ms)
    ///
    /// @details
    /// 주기적으로 채널 간 동기화 상태를 확인하고,
    /// 드리프트가 임계값을 초과하면 자동으로 수정합니다.
    ///
    /// 동작 방식:
    /// 1. 지정된 간격마다 타이머 실행
    /// 2. 모든 채널의 타임스탬프 확인
    /// 3. 최대 드리프트 계산
    /// 4. 임계값 초과 시 자동 수정
    /// 5. 드리프트 히스토리에 기록
    func startMonitoring(interval: TimeInterval = 0.1) {
        guard !monitoringEnabled else { return }

        monitoringEnabled = true

        // 메인 스레드에서 타이머 실행 (UI 업데이트 가능)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.monitorSync()
        }
    }

    /// @brief 드리프트 모니터링을 중지합니다.
    func stopMonitoring() {
        monitoringEnabled = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    /// @brief 동기화 상태를 모니터링하고 필요 시 수정합니다.
    ///
    /// @details
    /// 모니터링 프로세스:
    /// 1. 각 채널의 현재 타임스탬프 수집
    /// 2. 마스터 타임스탬프와의 차이 계산
    /// 3. 최대 드리프트 확인
    /// 4. 임계값 초과 시 correctDrift() 호출
    /// 5. 드리프트 히스토리에 기록
    func monitorSync() {
        guard !channels.isEmpty else { return }

        // 모든 채널의 타임스탬프 수집
        let timestamps = channels.values.map { $0.getCurrentTimestamp() }
        guard let minTimestamp = timestamps.min(),
              let maxTimestamp = timestamps.max() else {
            return
        }

        // 최대 드리프트 계산
        let maxDrift = maxTimestamp - minTimestamp

        // 드리프트 히스토리에 기록
        driftHistory.append(maxDrift)
        if driftHistory.count > maxDriftHistorySize {
            driftHistory.removeFirst()
        }

        // 임계값 초과 시 자동 수정
        if maxDrift > autoCorrectionThreshold {
            do {
                try correctDrift(maxDrift: maxDrift)
            } catch {
                print("Drift correction failed: \(error)")
            }
        }
    }

    /// @brief 드리프트를 자동으로 수정합니다.
    ///
    /// @param maxDrift 현재 최대 드리프트
    ///
    /// @throws SyncError
    ///
    /// @details
    /// 수정 전략:
    /// 1. 가장 느린 채널 찾기 (타임스탬프가 가장 작은 채널)
    /// 2. 가장 빠른 채널 찾기 (타임스탬프가 가장 큰 채널)
    /// 3. 중간값을 목표 타임스탬프로 설정
    /// 4. 모든 채널을 목표 타임스탬프로 seek
    ///
    /// 중간값 사용 이유:
    /// - 모든 채널을 같은 양만큼 이동
    /// - seek 횟수 최소화
    /// - 재생 끊김 최소화
    func correctDrift(maxDrift: TimeInterval) throws {
        guard !channels.isEmpty else { return }

        // 모든 채널의 타임스탬프 수집
        var channelTimestamps: [(id: String, timestamp: TimeInterval)] = []
        for (id, decoder) in channels {
            let timestamp = decoder.getCurrentTimestamp()
            channelTimestamps.append((id: id, timestamp: timestamp))
        }

        // 정렬
        channelTimestamps.sort { $0.timestamp < $1.timestamp }

        guard let slowest = channelTimestamps.first,
              let fastest = channelTimestamps.last else {
            return
        }

        // 중간값 계산
        let targetTimestamp = (slowest.timestamp + fastest.timestamp) / 2.0

        print("Correcting drift: \(String(format: "%.3f", maxDrift * 1000))ms -> Seeking to \(String(format: "%.3f", targetTimestamp))s")

        // 모든 채널을 목표 타임스탬프로 이동
        for (id, decoder) in channels {
            let currentTimestamp = decoder.getCurrentTimestamp()
            let diff = abs(currentTimestamp - targetTimestamp)

            // 드리프트가 큰 채널만 수정 (작은 드리프트는 무시)
            if diff > tolerance {
                do {
                    try decoder.seek(to: targetTimestamp)
                } catch {
                    throw SyncError.seekFailed("Failed to correct drift for channel '\(id)': \(error)")
                }
            }
        }

        // 마스터 타임스탬프 업데이트
        masterTimestamp = targetTimestamp
    }

    /// @brief 드리프트 통계를 반환합니다.
    ///
    /// @return (평균 드리프트, 최대 드리프트, 히스토리 개수)
    ///
    /// @details
    /// 통계 정보:
    /// - average: 평균 드리프트 (초 단위)
    /// - maximum: 최대 드리프트 (초 단위)
    /// - count: 히스토리에 기록된 샘플 개수
    func getDriftStatistics() -> (average: TimeInterval, maximum: TimeInterval, count: Int) {
        guard !driftHistory.isEmpty else {
            return (0, 0, 0)
        }

        let average = driftHistory.reduce(0, +) / Double(driftHistory.count)
        let maximum = driftHistory.max() ?? 0

        return (average, maximum, driftHistory.count)
    }

    /// @brief 드리프트 히스토리를 초기화합니다.
    func clearDriftHistory() {
        driftHistory.removeAll()
    }
}
