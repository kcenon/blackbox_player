/// @file VideoBuffer.swift
/// @brief Frame buffer for video playback
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 비디오 프레임을 버퍼링하는 클래스를 정의합니다.
/// 메모리 사용량을 제한하고 부드러운 재생을 보장합니다.

import Foundation

/// @class VideoBuffer
/// @brief 비디오 프레임을 버퍼링하는 스레드 안전한 클래스입니다.
///
/// @details
/// ## 주요 기능:
/// - 순환 버퍼 구조 (FIFO)
/// - 최대 크기 제한 (메모리 절약)
/// - 스레드 안전성 (DispatchQueue 사용)
/// - 자동 오래된 프레임 삭제
///
/// ## 버퍼링 전략:
/// - 채널당 최대 30 프레임 버퍼 (약 1초분, 30fps 기준)
/// - 버퍼 가득 차면 가장 오래된 프레임 자동 삭제
/// - 디코딩 스레드와 렌더링 스레드 사이의 동기화
///
/// ## 사용 예:
/// ```swift
/// let buffer = VideoBuffer(maxSize: 30)
///
/// // 디코딩 스레드에서
/// buffer.append(frame)
///
/// // 렌더링 스레드에서
/// if let frame = buffer.next() {
///     render(frame)
/// }
/// ```
class VideoBuffer {

    // MARK: - Properties

    /// @var frames
    /// @brief 저장된 비디오 프레임 배열
    /// @details
    /// - FIFO 순서로 관리 (First In, First Out)
    /// - private: 외부에서 직접 접근 불가
    private var frames: [VideoFrame] = []

    /// @var maxSize
    /// @brief 버퍼의 최대 크기 (프레임 개수)
    /// @details
    /// - 기본값: 30 프레임 (30fps 기준 1초)
    /// - 메모리 사용량 제한을 위해 설정
    private let maxSize: Int

    /// @var queue
    /// @brief 스레드 안전성을 위한 직렬 큐
    /// @details
    /// - 여러 스레드에서 동시 접근 시 데이터 경쟁 방지
    /// - 직렬 큐(serial queue): 한 번에 하나의 작업만 실행
    private let queue = DispatchQueue(label: "com.blackboxplayer.videobuffer", qos: .userInitiated)

    /// @var currentIndex
    /// @brief 현재 읽기 위치 인덱스
    /// @details
    /// - next() 호출 시 반환할 프레임의 인덱스
    /// - 순차적으로 증가
    private var currentIndex: Int = 0

    /// @var isEmpty
    /// @brief 버퍼가 비어있는지 여부
    var isEmpty: Bool {
        return queue.sync { frames.isEmpty }
    }

    /// @var count
    /// @brief 현재 버퍼에 저장된 프레임 개수
    var count: Int {
        return queue.sync { frames.count }
    }

    /// @var isFull
    /// @brief 버퍼가 가득 찼는지 여부
    var isFull: Bool {
        return queue.sync { frames.count >= maxSize }
    }

    // MARK: - Initialization

    /// @brief 비디오 버퍼를 생성합니다.
    ///
    /// @param maxSize 버퍼의 최대 크기 (프레임 개수), 기본값 30
    ///
    /// @details
    /// 적절한 버퍼 크기 선택:
    /// - 30fps 영상: 30 프레임 = 1초
    /// - 60fps 영상: 60 프레임 = 1초
    /// - 너무 크면 메모리 낭비, 너무 작으면 버퍼 언더런 발생
    init(maxSize: Int = 30) {
        self.maxSize = maxSize
    }

    // MARK: - Public Methods

    /// @brief 버퍼에 새 프레임을 추가합니다.
    ///
    /// @param frame 추가할 비디오 프레임
    ///
    /// @details
    /// 동작 방식:
    /// 1. 버퍼가 가득 차 있으면 가장 오래된 프레임 삭제
    /// 2. 새 프레임을 버퍼 끝에 추가
    /// 3. 스레드 안전하게 처리
    func append(_ frame: VideoFrame) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 버퍼가 가득 차면 가장 오래된 프레임 삭제
            if self.frames.count >= self.maxSize {
                self.frames.removeFirst()
                // 인덱스 조정 (삭제로 인해 모든 인덱스가 -1)
                if self.currentIndex > 0 {
                    self.currentIndex -= 1
                }
            }

            // 새 프레임 추가
            self.frames.append(frame)
        }
    }

    /// @brief 다음 프레임을 가져옵니다.
    ///
    /// @return 다음 비디오 프레임, 없으면 nil
    ///
    /// @details
    /// 순차적 읽기:
    /// - currentIndex 위치의 프레임 반환
    /// - currentIndex 증가
    /// - 버퍼 끝에 도달하면 nil 반환
    ///
    /// 주의:
    /// - 프레임을 버퍼에서 삭제하지 않음
    /// - 여러 번 호출 가능
    func next() -> VideoFrame? {
        return queue.sync { [weak self] in
            guard let self = self else { return nil }

            // 인덱스 범위 확인
            guard self.currentIndex < self.frames.count else {
                return nil
            }

            let frame = self.frames[self.currentIndex]
            self.currentIndex += 1
            return frame
        }
    }

    /// @brief 특정 타임스탬프에 가장 가까운 프레임을 가져옵니다.
    ///
    /// @param timestamp 찾을 타임스탬프 (초 단위)
    ///
    /// @return 가장 가까운 비디오 프레임, 없으면 nil
    ///
    /// @details
    /// 탐색 방법:
    /// 1. 버퍼의 모든 프레임 순회
    /// 2. 각 프레임과 목표 타임스탬프의 차이 계산
    /// 3. 차이가 가장 작은 프레임 반환
    func frame(at timestamp: TimeInterval) -> VideoFrame? {
        return queue.sync { [weak self] in
            guard let self = self, !self.frames.isEmpty else {
                return nil
            }

            // 가장 가까운 프레임 찾기
            var closestFrame: VideoFrame?
            var minDifference = Double.infinity

            for frame in self.frames {
                let difference = abs(frame.timestamp - timestamp)
                if difference < minDifference {
                    minDifference = difference
                    closestFrame = frame
                }
            }

            return closestFrame
        }
    }

    /// @brief 현재 버퍼에서 가장 최근 프레임을 가져옵니다.
    ///
    /// @return 가장 최근 프레임, 없으면 nil
    ///
    /// @details
    /// 버퍼의 마지막 프레임을 반환합니다.
    /// 실시간 미리보기나 썸네일 생성에 유용합니다.
    func latest() -> VideoFrame? {
        return queue.sync { [weak self] in
            guard let self = self else { return nil }
            return self.frames.last
        }
    }

    /// @brief 버퍼를 비웁니다.
    ///
    /// @details
    /// 모든 프레임을 삭제하고 인덱스를 초기화합니다.
    /// seek 또는 파일 전환 시 호출합니다.
    func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.frames.removeAll()
            self.currentIndex = 0
        }
    }

    /// @brief 읽기 위치를 처음으로 되돌립니다.
    ///
    /// @details
    /// currentIndex를 0으로 재설정합니다.
    /// 프레임은 삭제하지 않고 다시 읽을 수 있게 합니다.
    func reset() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.currentIndex = 0
        }
    }

    /// @brief 특정 타임스탬프 이전의 모든 프레임을 삭제합니다.
    ///
    /// @param timestamp 기준 타임스탬프 (초 단위)
    ///
    /// @details
    /// 메모리 최적화:
    /// - 이미 재생된 오래된 프레임 삭제
    /// - 메모리 사용량 감소
    /// - 버퍼 공간 확보
    func removeFrames(before timestamp: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }

            // 타임스탬프 이전의 프레임 개수 계산
            let removeCount = self.frames.prefix(while: { $0.timestamp < timestamp }).count

            // 프레임 삭제
            if removeCount > 0 {
                self.frames.removeFirst(removeCount)
                // 인덱스 조정
                self.currentIndex = max(0, self.currentIndex - removeCount)
            }
        }
    }

    /// @brief 버퍼의 상태 정보를 문자열로 반환합니다.
    ///
    /// @return 버퍼 상태 문자열
    ///
    /// @details
    /// 디버깅 용도로 버퍼 상태를 출력합니다.
    func getStatusString() -> String {
        return queue.sync { [weak self] in
            guard let self = self else { return "Buffer: disposed" }

            let usage = self.frames.count
            let capacity = self.maxSize
            let percentage = capacity > 0 ? Int(Double(usage) / Double(capacity) * 100) : 0

            var status = "Buffer: \(usage)/\(capacity) (\(percentage)%)"

            if let first = self.frames.first, let last = self.frames.last {
                let range = last.timestamp - first.timestamp
                status += " | Range: \(String(format: "%.2f", range))s"
            }

            return status
        }
    }
}
