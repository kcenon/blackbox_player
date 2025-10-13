/// @file VideoChannel.swift
/// @brief Video channel for multi-channel synchronized playback
/// @author BlackboxPlayer Development Team
/// @details
/// 멀티 채널 동기화 재생을 위한 독립적인 비디오 채널 클래스입니다.
///
/// ## 채널(Channel)이란?
/// - 블랙박스에는 보통 여러 개의 카메라가 있습니다 (전방, 후방, 좌측, 우측, 실내)
/// - 각 카메라의 영상을 독립적으로 디코딩하고 관리하는 단위가 "채널"입니다
/// - 예: 4채널 블랙박스 = 전방 채널 + 후방 채널 + 좌측 채널 + 우측 채널
///
/// ## 주요 기능:
/// 1. **독립적인 디코딩**: 각 채널이 자신의 VideoDecoder를 가짐
/// 2. **프레임 버퍼링**: 디코딩된 프레임을 버퍼에 저장하여 부드러운 재생 보장
/// 3. **동기화 지원**: 다른 채널들과 시간을 맞춰 재생할 수 있도록 지원
/// 4. **백그라운드 디코딩**: 별도의 스레드에서 디코딩하여 UI가 멈추지 않음
///
/// ## 버퍼(Buffer)란?
/// - 미리 디코딩해둔 프레임들을 저장하는 임시 저장소
/// - 마치 유튜브가 동영상을 미리 다운로드해두는 것과 같은 원리
/// - 네트워크나 디코딩 속도가 느려도 끊김 없이 재생 가능
///
/// ## 동기화(Synchronization)란?
/// - 여러 채널의 영상을 같은 시점에서 재생하는 것
/// - 예: 0.5초 시점의 전방 영상과 0.5초 시점의 후방 영상을 동시에 표시
/// - GPS나 G-센서 데이터도 같은 시점의 것을 표시
///
/// ## 사용 예제:
/// ```swift
/// // 1. 채널 생성
/// let channelInfo = ChannelInfo(
///     position: .front,
///     filePath: "/path/to/front_camera.mp4",
///     displayName: "전방 카메라"
/// )
/// let channel = VideoChannel(channelInfo: channelInfo)
///
/// // 2. 초기화
/// try channel.initialize()
///
/// // 3. 디코딩 시작
/// channel.startDecoding()
///
/// // 4. 특정 시점의 프레임 가져오기
/// if let frame = channel.getFrame(at: 5.0) {
///     print("5초 시점의 프레임: \(frame.frameNumber)")
/// }
///
/// // 5. 버퍼 상태 확인
/// let status = channel.getBufferStatus()
/// print("버퍼: \(status.current)/\(status.max) (\(status.fillPercentage * 100)%)")
///
/// // 6. 정리
/// channel.stop()
/// ```
///
/// ## 스레드 안전성(Thread Safety):
/// - 여러 스레드에서 동시에 접근해도 안전하도록 설계됨
/// - NSLock을 사용하여 프레임 버퍼 보호
/// - 백그라운드 스레드에서 디코딩, 메인 스레드에서 UI 업데이트

import Foundation
import Combine

/// @class VideoChannel
/// @brief 멀티 채널 동기화 재생을 위한 독립적인 비디오 채널
/// @details 각 비디오 채널을 독립적으로 디코딩하고 버퍼링하며, 다른 채널들과 동기화하여 재생합니다.
class VideoChannel {
    // MARK: - Properties (속성)

    /*
     MARK란?
     - Xcode에서 코드를 구역별로 구분하는 주석
     - // MARK: - 제목 형태로 작성
     - Xcode의 파일 구조 메뉴에서 빠르게 찾을 수 있음
     */

    /// @var channelID
    /// @brief 채널 식별자 (Channel Identifier)
    /// @details
    /// UUID란?
    /// - Universally Unique Identifier (범용 고유 식별자)
    /// - 전 세계에서 유일한 ID 값 (중복될 확률이 거의 0)
    /// - 형태: "550e8400-e29b-41d4-a716-446655440000"
    ///
    /// 왜 필요한가?
    /// - 여러 채널을 구분하기 위해 필요
    /// - 파일 경로나 이름은 변경될 수 있지만 UUID는 고유함
    let channelID: UUID

    /// @var channelInfo
    /// @brief 채널 정보 (Channel Information)
    /// @details
    /// ChannelInfo 구조체 내용:
    /// - position: 카메라 위치 (전방, 후방, 좌측, 우측, 실내)
    /// - filePath: 비디오 파일 경로 (예: "/videos/front_20250112.mp4")
    /// - displayName: 화면에 표시할 이름 (예: "전방 카메라")
    ///
    /// let vs var:
    /// - let: 상수, 한 번 설정하면 변경 불가
    /// - var: 변수, 나중에 변경 가능
    /// - channelInfo는 let이므로 채널 생성 후 변경 불가
    let channelInfo: ChannelInfo

    /// @var state
    /// @brief 채널 상태 (Channel State)
    /// @details
    /// @Published란?
    /// - Combine 프레임워크의 프로퍼티 래퍼
    /// - 값이 변경되면 자동으로 구독자들에게 알림
    /// - SwiftUI에서 UI가 자동으로 업데이트됨
    ///
    /// 예:
    /// ```swift
    /// channel.$state
    ///     .sink { newState in
    ///         print("상태 변경: \(newState)")
    ///     }
    /// ```
    ///
    /// private(set)이란?
    /// - 읽기는 public (외부에서 읽을 수 있음)
    /// - 쓰기는 private (이 클래스 내부에서만 변경 가능)
    /// - 외부에서 state = .idle 같은 직접 수정 불가
    ///
    /// 채널 상태 종류:
    /// - .idle: 유휴 상태 (아무것도 안 하는 상태)
    /// - .ready: 준비 완료 (디코더 초기화 완료, 디코딩 시작 가능)
    /// - .decoding: 디코딩 중 (백그라운드에서 프레임 디코딩 중)
    /// - .completed: 완료 (파일 끝까지 디코딩 완료)
    /// - .error: 오류 (디코딩 중 에러 발생)
    @Published private(set) var state: ChannelState = .idle

    /// @var currentFrame
    /// @brief 현재 프레임 (Current Frame)
    /// @details
    /// VideoFrame이란?
    /// - 디코딩된 한 장의 영상 프레임
    /// - 내용: 픽셀 데이터, 타임스탬프, 프레임 번호, 크기 등
    ///
    /// Optional(?)이란?
    /// - 값이 있을 수도 있고(VideoFrame), 없을 수도 있음(nil)
    /// - 처음에는 nil (아직 디코딩된 프레임이 없음)
    /// - 디코딩 시작 후에는 VideoFrame 값이 들어감
    ///
    /// 사용 예:
    /// ```swift
    /// if let frame = channel.currentFrame {
    ///     print("현재 프레임: \(frame.frameNumber)")
    /// } else {
    ///     print("프레임 없음")
    /// }
    /// ```
    @Published private(set) var currentFrame: VideoFrame?

    /// @var decoder
    /// @brief 비디오 디코더 (Video Decoder)
    /// @details
    /// private란?
    /// - 이 클래스 내부에서만 접근 가능
    /// - 외부에서 channel.decoder로 접근 불가
    /// - 캡슐화(Encapsulation): 내부 구현을 숨기고 필요한 것만 공개
    ///
    /// 왜 Optional인가?
    /// - 처음에는 nil (초기화 전)
    /// - initialize() 호출 시 VideoDecoder 생성
    /// - stop() 호출 시 다시 nil로 설정 (메모리 해제)
    private var decoder: VideoDecoder?

    /// @var frameBuffer
    /// @brief 프레임 버퍼 (Frame Buffer)
    /// @details
    /// 배열(Array)이란?
    /// - 여러 개의 값을 순서대로 저장하는 컬렉션
    /// - [VideoFrame]: VideoFrame 타입의 배열
    /// - 예: [frame1, frame2, frame3, ...]
    ///
    /// 원형 버퍼(Circular Buffer)란?
    /// - 고정된 크기의 버퍼에 새 데이터가 들어오면 오래된 데이터 제거
    /// - 마치 회전목마처럼 계속 순환하며 사용
    /// - 메모리를 절약하면서도 최신 프레임들을 유지
    ///
    /// 버퍼 동작 방식:
    /// ```
    /// 최대 크기 3인 경우:
    /// [Frame1]
    /// [Frame1, Frame2]
    /// [Frame1, Frame2, Frame3]
    /// [Frame2, Frame3, Frame4]  <- Frame1 제거, Frame4 추가
    /// [Frame3, Frame4, Frame5]  <- Frame2 제거, Frame5 추가
    /// ```
    private var frameBuffer: [VideoFrame] = []

    /// @var maxBufferSize
    /// @brief 최대 버퍼 크기 (Maximum Buffer Size)
    /// @details
    /// 30개 = 약 1초분의 프레임 (30fps 기준)
    ///
    /// 왜 30개인가?
    /// - 너무 작으면: 디코딩이 늦어질 때 끊김 발생
    /// - 너무 크면: 메모리 과다 사용, 시크 시 응답 느림
    /// - 30개 = 1초: 적당한 균형점
    ///
    /// 4채널 × 30프레임 = 120프레임 동시 버퍼링
    /// - 1프레임 ≈ 2MB (1920×1080 BGRA)
    /// - 120프레임 ≈ 240MB (충분히 감당 가능)
    private let maxBufferSize = 30

    /// @var decodingQueue
    /// @brief 디코딩 큐 (Decoding Queue)
    /// @details
    /// DispatchQueue란?
    /// - Swift의 멀티스레딩(다중 작업) 시스템
    /// - 작업을 백그라운드에서 실행할 수 있게 해줌
    ///
    /// 왜 필요한가?
    /// - 비디오 디코딩은 시간이 오래 걸리는 작업
    /// - 메인 스레드에서 하면 UI가 멈춤 (버벅임, 클릭 안됨)
    /// - 별도 스레드에서 디코딩하면 UI는 부드럽게 유지
    ///
    /// 스레드 개념:
    /// ```
    /// 메인 스레드:     [UI 그리기] [버튼 클릭] [애니메이션] ...
    /// 디코딩 스레드:   [프레임1 디코딩] [프레임2 디코딩] ...
    /// ```
    ///
    /// label: 디버깅 시 구분하기 위한 이름
    /// qos (Quality of Service): 작업 우선순위
    /// - userInitiated: 사용자가 시작한 작업, 높은 우선순위
    private let decodingQueue: DispatchQueue

    /// @var bufferLock
    /// @brief 버퍼 잠금 (Buffer Lock)
    /// @details
    /// NSLock이란?
    /// - 여러 스레드가 동시에 같은 데이터에 접근하는 것을 막는 도구
    /// - 마치 화장실 문 잠그는 것과 같은 원리
    ///
    /// 왜 필요한가?
    /// - 디코딩 스레드: frameBuffer에 프레임 추가
    /// - 메인 스레드: frameBuffer에서 프레임 읽기
    /// - 동시 접근 시 데이터 깨짐 (Race Condition)
    ///
    /// Race Condition(경쟁 상태) 예:
    /// ```
    /// 스레드 A: frameBuffer.append(frame1)  <- 배열 크기 증가 중
    /// 스레드 B: let frame = frameBuffer[0]  <- 동시에 읽으려 함
    /// 결과: 크래시! (잘못된 메모리 접근)
    /// ```
    ///
    /// Lock 사용:
    /// ```swift
    /// bufferLock.lock()      // 문 잠그기
    /// frameBuffer.append(frame)  // 혼자만 사용
    /// bufferLock.unlock()    // 문 열기
    /// ```
    ///
    /// defer 패턴:
    /// ```swift
    /// bufferLock.lock()
    /// defer { bufferLock.unlock() }  // 함수 끝날 때 자동으로 unlock
    /// // ... 작업 ...
    /// // return이나 throw가 있어도 반드시 unlock됨
    /// ```
    private let bufferLock = NSLock()

    /// @var isDecoding
    /// @brief 디코딩 중 여부 (Is Decoding)
    /// @details
    /// Bool (Boolean): true 또는 false
    ///
    /// 역할:
    /// - 디코딩 루프를 제어하는 플래그
    /// - true: 계속 디코딩
    /// - false: 디코딩 중단
    ///
    /// 사용 예:
    /// ```swift
    /// while isDecoding {  // isDecoding이 true인 동안 반복
    ///     // 프레임 디코딩...
    /// }
    /// ```
    ///
    /// 상태(state)와의 차이:
    /// - state: 외부에 공개되는 상태 (UI에 표시 가능)
    /// - isDecoding: 내부 제어용 플래그 (private)
    private var isDecoding = false

    /// @var targetFrameTime
    /// @brief 목표 프레임 시간 (Target Frame Time)
    /// @details
    /// TimeInterval = Double (초 단위 시간)
    ///
    /// 역할:
    /// - 현재 재생 중인 시간 위치
    /// - seek() 호출 시 업데이트됨
    /// - 이 시간에 가장 가까운 프레임을 찾아서 표시
    ///
    /// 예:
    /// ```
    /// targetFrameTime = 5.0
    /// -> 5.0초에 가장 가까운 프레임을 버퍼에서 찾음
    /// -> 4.97초 프레임이 가장 가까움
    /// -> 해당 프레임을 currentFrame으로 설정
    /// ```
    private var targetFrameTime: TimeInterval = 0.0

    // MARK: - Initialization (초기화)

    /// @brief 채널을 생성합니다
    /// @param channelID 채널 고유 식별자 (기본값: 새 UUID 자동 생성)
    /// @param channelInfo 채널 정보 (카메라 위치, 파일 경로 등)
    /// @details
    /// 이니셜라이저(Initializer)란?
    /// - 클래스의 인스턴스를 생성할 때 호출되는 특별한 함수
    /// - init으로 시작
    /// - 모든 속성(property)을 초기화해야 함
    ///
    /// 파라미터:
    /// - channelID: 채널 고유 식별자 (기본값: 새 UUID 자동 생성)
    /// - channelInfo: 채널 정보 (카메라 위치, 파일 경로 등)
    ///
    /// 기본값(Default Value):
    /// - channelID: UUID = UUID()
    /// - "= UUID()"가 기본값
    /// - 호출 시 생략 가능: VideoChannel(channelInfo: info)
    /// - 명시 가능: VideoChannel(channelID: myUUID, channelInfo: info)
    ///
    /// 사용 예:
    /// ```swift
    /// // 방법 1: channelID 자동 생성
    /// let channel1 = VideoChannel(channelInfo: frontInfo)
    ///
    /// // 방법 2: 특정 channelID 사용
    /// let id = UUID()
    /// let channel2 = VideoChannel(channelID: id, channelInfo: rearInfo)
    /// ```
    init(channelID: UUID = UUID(), channelInfo: ChannelInfo) {
        // self란?
        // - 현재 클래스의 인스턴스 자신을 가리킴
        // - 파라미터 이름과 속성 이름이 같을 때 구분하기 위해 사용

        // self.channelID: 클래스의 속성
        // channelID: 파라미터
        self.channelID = channelID
        self.channelInfo = channelInfo

        // 디코딩 큐 생성
        // label에 UUID를 포함하여 각 채널마다 고유한 큐 이름 생성
        // 예: "com.blackboxplayer.channel.550e8400-e29b-41d4-a716-446655440000"
        self.decodingQueue = DispatchQueue(
            label: "com.blackboxplayer.channel.\(channelID.uuidString)",
            // \(변수): 문자열 보간(String Interpolation)
            // - 문자열 안에 변수 값을 삽입

            qos: .userInitiated
            // Quality of Service: 작업 우선순위
            // - background: 낮은 우선순위
            // - utility: 중간 우선순위
            // - userInitiated: 높은 우선순위 (사용자 대기 중)
            // - userInteractive: 최고 우선순위 (UI 직접 관련)
        )

        // 다른 속성들은 선언 시 기본값이 있어서 여기서 초기화 불필요:
        // - state = .idle
        // - currentFrame = nil (Optional의 기본값)
        // - frameBuffer = []
        // - isDecoding = false
        // - targetFrameTime = 0.0
    }

    /// @brief 디이니셜라이저 (deinit)
    /// @details
    /// deinit이란?
    /// - 인스턴스가 메모리에서 해제될 때 자동으로 호출
    /// - 정리 작업(cleanup)을 수행
    /// - init의 반대 개념
    ///
    /// ARC (Automatic Reference Counting):
    /// - Swift의 메모리 관리 시스템
    /// - 인스턴스를 참조하는 곳이 없으면 자동으로 메모리 해제
    ///
    /// 예:
    /// ```swift
    /// var channel: VideoChannel? = VideoChannel(channelInfo: info)
    /// // 메모리에 VideoChannel 인스턴스 생성, 참조 카운트 = 1
    ///
    /// channel = nil
    /// // 참조 카운트 = 0
    /// // -> deinit 자동 호출
    /// // -> stop() 실행하여 디코딩 중단, 리소스 해제
    /// // -> 메모리에서 제거
    /// ```
    ///
    /// 왜 stop()을 호출하나?
    /// - 디코딩 스레드가 실행 중일 수 있음
    /// - 디코더가 파일을 열어둔 상태일 수 있음
    /// - 메모리 해제 전에 깔끔하게 정리
    deinit {
        stop()
    }

    // MARK: - Public Methods (공개 메서드)

    /*
     Public vs Private:
     - Public: 클래스 외부에서 호출 가능
     - Private: 클래스 내부에서만 호출 가능

     Public 메서드: initialize, startDecoding, stop, seek, getFrame, getBufferStatus, flushBuffer
     Private 메서드: decodingLoop, addFrameToBuffer
     */

    /// @brief 채널과 디코더를 초기화합니다
    /// @throws ChannelError 또는 DecoderError
    /// @details
    /// 초기화 과정:
    /// 1. 상태 확인 (이미 초기화되었는지)
    /// 2. VideoDecoder 생성
    /// 3. 디코더 초기화 (FFmpeg으로 파일 열기)
    /// 4. 상태를 .ready로 변경
    ///
    /// throws란?
    /// - 이 함수가 에러를 던질(throw) 수 있음을 의미
    /// - 호출 시 try 키워드 필요
    /// - do-catch로 에러 처리 필요
    ///
    /// 사용 예:
    /// ```swift
    /// do {
    ///     try channel.initialize()
    ///     print("초기화 성공!")
    ///     channel.startDecoding()
    /// } catch {
    ///     print("초기화 실패: \(error)")
    /// }
    /// ```
    ///
    /// 발생 가능한 에러:
    /// - ChannelError.invalidState: 이미 초기화된 상태
    /// - DecoderError.cannotOpenFile: 파일을 열 수 없음
    /// - DecoderError.noVideoStream: 비디오 스트림 없음
    /// - DecoderError.codecNotFound: 코덱을 찾을 수 없음
    func initialize() throws {
        // 1. 상태 확인
        // guard-else: 조건이 false면 else 블록 실행 후 함수 종료
        // guard는 "이 조건이 반드시 참이어야 함"을 의미
        guard state == .idle else {
            // 이미 초기화된 경우 에러 던지기
            throw ChannelError.invalidState("Channel already initialized")
        }

        // 2. VideoDecoder 생성
        // let decoder: 로컬 변수 (이 함수 안에서만 사용)
        // self.decoder: 클래스 속성 (클래스 전체에서 사용)
        let decoder = VideoDecoder(filePath: channelInfo.filePath)

        // 3. 디코더 초기화
        // try: 에러가 발생하면 이 함수를 호출한 곳으로 에러 전달
        // decoder.initialize()가 throw하면 아래 코드는 실행 안 됨
        try decoder.initialize()

        // 4. 클래스 속성에 저장
        // 여기까지 왔다 = 초기화 성공
        // Optional을 nil에서 실제 값으로 변경
        self.decoder = decoder

        // 5. 상태 변경
        // @Published 속성이므로 이 변경이 자동으로 구독자들에게 알림
        // SwiftUI에서 UI가 자동으로 업데이트됨
        state = .ready

        // 성공적으로 초기화 완료, 에러 없이 함수 종료
        // 이제 startDecoding() 호출 가능
    }

    /// @brief 백그라운드에서 프레임 디코딩을 시작합니다
    /// @details
    /// 백그라운드(Background)란?
    /// - 사용자가 보지 못하는 뒤에서 실행되는 작업
    /// - UI를 방해하지 않음
    ///
    /// 동작 방식:
    /// 1. 상태 확인 (.ready 상태여야 함)
    /// 2. isDecoding 플래그를 true로 설정
    /// 3. 별도 스레드에서 decodingLoop() 실행
    /// 4. 즉시 return (함수는 바로 끝나지만 디코딩은 계속 진행)
    ///
    /// 비동기(Asynchronous) 작업:
    /// - 이 함수는 즉시 반환됨
    /// - 디코딩은 백그라운드에서 계속 진행
    /// - 완료를 기다리지 않음
    ///
    /// ```
    /// startDecoding() 호출
    ///     ↓
    /// 함수 즉시 종료 (0.001초)
    ///     ↓
    /// 호출자는 다음 코드 실행
    ///
    /// 동시에:
    /// 백그라운드 스레드에서
    /// decodingLoop() 실행 (수 초~수 분)
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// try channel.initialize()  // 1. 먼저 초기화
    /// channel.startDecoding()   // 2. 디코딩 시작 (즉시 반환)
    /// print("디코딩 시작!")     // 3. 바로 실행됨 (디코딩 완료 대기 안 함)
    ///
    /// // 백그라운드에서 계속 프레임 디코딩 중...
    /// ```
    ///
    /// 주의사항:
    /// - initialize()를 먼저 호출해야 함
    /// - .ready 상태가 아니면 무시됨
    /// - 이미 디코딩 중이면 무시됨 (중복 시작 방지)
    func startDecoding() {
        // 1. 상태 확인
        // guard: 여러 조건을 동시에 확인
        // state == .ready: 초기화 완료 상태여야 함
        // !isDecoding: 디코딩 중이 아니어야 함 (!는 not, 부정)
        // 둘 중 하나라도 false면 return (함수 종료)
        guard state == .ready, !isDecoding else {
            return  // 조용히 종료, 에러 안 던짐
        }

        // 2. 디코딩 시작 플래그 설정
        isDecoding = true
        state = .decoding
        // @Published이므로 UI에 "디코딩 중" 표시 가능

        // 3. 백그라운드에서 디코딩 시작
        // decodingQueue: init에서 만든 별도 스레드
        // .async: 비동기 실행 (기다리지 않고 즉시 return)
        decodingQueue.async { [weak self] in
            // [weak self]란?
            // - self를 약한 참조(weak reference)로 캡처
            // - 순환 참조(Retain Cycle) 방지
            //
            // 순환 참조란?
            // - A가 B를 참조, B가 A를 참조
            // - 서로 참조하여 메모리 해제 안 됨
            // - 메모리 누수(Memory Leak)
            //
            // weak를 사용하는 이유:
            // - 클로저가 self를 강하게 참조하면
            // - self도 클로저를 강하게 참조하면 (decodingQueue가 클로저 보관)
            // - 순환 참조 발생
            // - weak로 참조하면 순환 끊김
            //
            // self?란?
            // - weak self는 Optional
            // - 인스턴스가 이미 해제되었을 수 있음
            // - self? = nil이면 아무것도 안 함

            self?.decodingLoop()
            // 디코딩 루프 시작
            // while isDecoding 루프가 계속 실행됨
        }

        // 4. 함수 즉시 종료
        // decodingLoop()는 백그라운드에서 계속 실행 중
    }

    /// @brief 디코딩을 중단하고 리소스를 정리합니다
    /// @details
    /// 정리(Cleanup) 작업:
    /// 1. 디코딩 루프 중단 (isDecoding = false)
    /// 2. 상태를 .idle로 초기화
    /// 3. 프레임 버퍼 비우기
    /// 4. 디코더 해제 (메모리 반환)
    /// 5. 현재 프레임 제거
    ///
    /// 리소스(Resource)란?
    /// - 메모리, 파일 핸들, 스레드 등 시스템 자원
    /// - 사용 후 반드시 해제해야 함
    /// - 해제하지 않으면 메모리 누수
    ///
    /// 사용 시점:
    /// - 영상 재생 종료 시
    /// - 다른 영상으로 전환 시
    /// - 앱 종료 시
    /// - deinit에서 자동 호출
    ///
    /// 사용 예:
    /// ```swift
    /// channel.startDecoding()  // 디코딩 시작
    /// // ... 재생 중 ...
    /// channel.stop()           // 정리
    ///
    /// // 리소스가 모두 해제됨
    /// // 다시 initialize() + startDecoding() 가능
    /// ```
    func stop() {
        // 1. 디코딩 중단 플래그
        isDecoding = false
        // -> decodingLoop()의 while isDecoding 루프가 종료됨
        // -> 백그라운드 스레드가 자연스럽게 종료

        // 2. 상태 초기화
        state = .idle
        // 초기 상태로 되돌림
        // @Published이므로 UI에 "유휴" 표시

        // 3. 프레임 버퍼 비우기 (스레드 안전하게)
        bufferLock.lock()
        // 다른 스레드가 버퍼에 접근 못하도록 잠금

        frameBuffer.removeAll()
        // 배열의 모든 요소 제거
        // 메모리 해제됨

        bufferLock.unlock()
        // 잠금 해제, 다른 스레드가 다시 접근 가능

        // 4. 디코더 해제
        decoder = nil
        // Optional을 nil로 설정
        // VideoDecoder 인스턴스의 참조 카운트 감소
        // 참조 카운트가 0이 되면 자동으로 메모리 해제
        // VideoDecoder의 deinit 호출됨
        // -> FFmpeg 리소스 정리

        // 5. 현재 프레임 제거
        currentFrame = nil
        // Optional을 nil로 설정
        // @Published이므로 UI에서 프레임 표시 사라짐

        // 모든 정리 완료
        // 메모리 사용량 최소화
        // 다시 initialize() 호출 가능
    }

    /// @brief 특정 시간 위치로 이동합니다
    /// @param time 이동할 시간 위치 (초 단위)
    /// @throws ChannelError 또는 DecoderError
    /// @details
    /// 시크(Seek)란?
    /// - 영상의 특정 위치로 점프하는 것
    /// - 유튜브에서 진행 바를 드래그하는 것과 같음
    /// - 예: 10분짜리 영상의 5분 지점으로 이동
    ///
    /// 시크 과정:
    /// 1. 디코딩 일시 중단
    /// 2. 버퍼의 모든 프레임 제거 (이전 시간대의 프레임들)
    /// 3. 디코더에게 새 위치로 이동 요청
    /// 4. 목표 시간 업데이트
    /// 5. 디코딩 재개
    ///
    /// 왜 버퍼를 비우나?
    /// - 버퍼에 있는 프레임들은 이전 시간대의 것
    /// - 예: 5초 지점에서 20초로 시크
    /// - 버퍼에 5초~6초 프레임들이 있음
    /// - 20초 지점에서는 필요 없음
    /// - 버퍼를 비우고 20초부터 다시 디코딩
    ///
    /// 사용 예:
    /// ```swift
    /// // 10초 지점으로 이동
    /// try channel.seek(to: 10.0)
    ///
    /// // 처음으로 이동
    /// try channel.seek(to: 0.0)
    ///
    /// // 5분 30초로 이동
    /// try channel.seek(to: 330.0)  // 5*60 + 30 = 330
    /// ```
    ///
    /// 주의사항:
    /// - initialize()를 먼저 호출해야 함
    /// - 디코더가 없으면 에러 발생
    /// - 음수 시간은 0으로 처리됨
    /// - 영상 길이를 넘는 시간은 끝으로 이동
    func seek(to time: TimeInterval) throws {
        // 1. 디코더 존재 확인
        // guard let: Optional 바인딩
        // - decoder가 nil이 아니면 언래핑하여 decoder 변수에 저장
        // - nil이면 else 블록 실행
        guard let decoder = decoder else {
            // 디코더가 초기화되지 않음
            throw ChannelError.notInitialized
        }

        // 2. 디코딩 상태 저장 및 중단
        let wasDecoding = isDecoding
        // 현재 디코딩 중이었는지 기억
        // 나중에 다시 시작할지 결정하기 위해

        isDecoding = false
        // 디코딩 루프 중단
        // decodingLoop()의 while isDecoding이 종료됨
        // 백그라운드 스레드가 멈춤을 기다림

        // 3. 버퍼 비우기 (스레드 안전)
        bufferLock.lock()
        frameBuffer.removeAll()
        bufferLock.unlock()
        // 이전 시간대의 프레임들 모두 제거

        // 4. 디코더 시크
        try decoder.seek(to: time)
        // VideoDecoder에게 새 위치로 이동 요청
        // FFmpeg이 파일에서 해당 위치 찾기
        // 키프레임(I-frame)으로 이동
        // 에러 발생 시 throw (호출자에게 전달)

        // 5. 목표 시간 업데이트
        targetFrameTime = time
        // 이 시간에 가장 가까운 프레임을 찾기 위해 저장

        // 6. 디코딩 재개 (필요한 경우)
        if wasDecoding {
            // 원래 디코딩 중이었다면
            startDecoding()
            // 다시 디코딩 시작
            // 새 위치부터 프레임 디코딩 시작
        }

        // 7. 상태 업데이트
        state = .ready
        // 시크 완료, 재생 가능 상태

        // 성공적으로 시크 완료
        // getFrame(at: time)으로 새 위치의 프레임 얻을 수 있음
    }

    /// @brief 목표 시간에 맞는 프레임을 반환합니다
    /// @param time 원하는 시간 위치 (초 단위)
    /// @param strategy 프레임 선택 전략 (기본값: .nearest)
    /// @return 선택된 VideoFrame, 없으면 nil
    /// @details
    /// ## 프레임 선택 전략:
    /// - `.nearest`: 가장 가까운 프레임 (기본)
    /// - `.before`: 목표 시간 이전의 가장 가까운 프레임
    /// - `.after`: 목표 시간 이후의 가장 가까운 프레임
    /// - `.exact(tolerance)`: 허용 오차 내에서 정확히 일치하는 프레임
    ///
    /// ## 개선 사항:
    /// - 이진 탐색으로 성능 향상 (O(n) → O(log n))
    /// - 프레임 선택 전략 지원
    /// - 프레임레이트 기반 tolerance
    /// - 더 정확한 시간 매칭
    ///
    /// 프레임 찾기 알고리즘:
    /// 1. 버퍼에서 이진 탐색으로 목표 시간 위치 찾기
    /// 2. 선택 전략에 따라 적절한 프레임 선택
    /// 3. 오래된 프레임들 정리
    ///
    /// 예시:
    /// ```swift
    /// // 가장 가까운 프레임
    /// let frame1 = channel.getFrame(at: 5.0)
    ///
    /// // 5.0초 이전의 프레임 (되감기에 유용)
    /// let frame2 = channel.getFrame(at: 5.0, strategy: .before)
    ///
    /// // 5.0초 이후의 프레임 (빨리감기에 유용)
    /// let frame3 = channel.getFrame(at: 5.0, strategy: .after)
    ///
    /// // 정확히 5.0초±0.01초 이내의 프레임만
    /// let frame4 = channel.getFrame(at: 5.0, strategy: .exact(tolerance: 0.01))
    /// ```
    ///
    /// 버퍼 정리:
    /// - 현재 시간 - 0.5초 이전의 프레임 제거 (1초 → 0.5초로 개선)
    /// - 더 빠른 응답성과 메모리 효율성
    ///
    /// nil을 반환하는 경우:
    /// - 버퍼가 비어있음
    /// - 선택 전략에 맞는 프레임이 없음
    /// - exact 전략에서 tolerance 내의 프레임이 없음
    func getFrame(at time: TimeInterval, strategy: FrameSelectionStrategy = .nearest) -> VideoFrame? {
        // 1. 버퍼 잠금
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // 2. 버퍼 비어있는지 확인
        guard !frameBuffer.isEmpty else {
            return nil
        }

        // 3. 선택 전략에 따라 프레임 선택
        let selectedFrame: VideoFrame?

        switch strategy {
        case .nearest:
            // 가장 가까운 프레임 (기본 동작)
            selectedFrame = findNearestFrame(to: time)

        case .before:
            // 목표 시간 이전의 가장 가까운 프레임
            selectedFrame = findFrameBefore(time: time)

        case .after:
            // 목표 시간 이후의 가장 가까운 프레임
            selectedFrame = findFrameAfter(time: time)

        case .exact(let tolerance):
            // 허용 오차 내에서 정확히 일치하는 프레임
            selectedFrame = findExactFrame(at: time, tolerance: tolerance)
        }

        // 4. 오래된 프레임 정리 (0.5초로 개선)
        let cleanupThreshold = time - 0.5
        frameBuffer.removeAll { frame in
            frame.timestamp < cleanupThreshold
        }

        // 5. 결과 반환
        return selectedFrame
    }

    /// @brief 현재 버퍼 상태를 반환합니다
    /// @return (현재 크기, 최대 크기, 채움 비율)
    /// @details
    /// 버퍼 상태 정보:
    /// - current: 현재 버퍼에 있는 프레임 수
    /// - max: 최대 버퍼 크기 (30)
    /// - fillPercentage: 채워진 비율 (0.0 ~ 1.0)
    ///
    /// Tuple(튜플)이란?
    /// - 여러 값을 하나로 묶은 것
    /// - (Int, Int, Double) 형태
    /// - 이름을 붙일 수 있음: (current: Int, max: Int, fillPercentage: Double)
    ///
    /// 사용 예:
    /// ```swift
    /// let status = channel.getBufferStatus()
    /// print("버퍼: \(status.current)/\(status.max)")
    /// print("채움율: \(status.fillPercentage * 100)%")
    ///
    /// // 버퍼가 거의 비었는지 확인
    /// if status.fillPercentage < 0.2 {
    /// print("버퍼가 부족합니다!")
    /// }
    ///
    /// // 버퍼가 거의 찼는지 확인
    /// if status.fillPercentage > 0.9 {
    ///     print("버퍼가 거의 찼습니다")
    /// }
    /// ```
    ///
    /// 활용:
    /// - UI에 버퍼 상태 표시 (로딩 바)
    /// - 버퍼가 낮으면 "로딩 중" 표시
    /// - 디버깅: 버퍼가 제대로 채워지는지 확인
    func getBufferStatus() -> (current: Int, max: Int, fillPercentage: Double) {
        // 1. 버퍼 잠금 (스레드 안전)
        bufferLock.lock()
        defer { bufferLock.unlock() }
        // 다른 스레드가 동시에 버퍼를 수정하지 못하도록

        // 2. 현재 버퍼 크기
        let current = frameBuffer.count
        // count: 배열의 요소 개수
        // 0 ~ 30 사이의 값

        // 3. 채움 비율 계산
        let percentage = Double(current) / Double(maxBufferSize)
        // Double(): Int를 Double로 변환
        // - 필요한 이유: Int끼리 나누면 소수점 버림
        // - 15 / 30 = 0 (Int 나눗셈)
        // - 15.0 / 30.0 = 0.5 (Double 나눗셈)
        //
        // percentage: 0.0 ~ 1.0
        // - 0.0 = 비어있음 (0%)
        // - 0.5 = 절반 (50%)
        // - 1.0 = 가득 참 (100%)

        // 4. 튜플로 반환
        return (current, maxBufferSize, percentage)
        // (current: 15, max: 30, fillPercentage: 0.5)

        // defer에 의해 자동으로 unlock 실행
    }

    /// @brief 프레임 버퍼를 비웁니다
    /// @details
    /// 버퍼 플러시(Flush)란?
    /// - 버퍼의 모든 내용을 제거하는 것
    /// - 마치 물탱크의 물을 다 빼는 것
    /// - 메모리를 즉시 반환
    ///
    /// 사용 시점:
    /// - 시크 시 (seek 함수에서 자동 호출)
    /// - 메모리 절약이 필요할 때
    /// - 새로운 영상으로 전환할 때
    ///
    /// 주의:
    /// - 버퍼를 비우면 프레임이 없어짐
    /// - getFrame()이 nil 반환
    /// - 디코딩이 다시 채울 때까지 대기 필요
    ///
    /// 사용 예:
    /// ```swift
    /// // 메모리 절약을 위해 버퍼 비우기
    /// channel.flushBuffer()
    ///
    /// // 버퍼 확인
    /// let status = channel.getBufferStatus()
    /// print(status.current)  // 0
    /// ```
    func flushBuffer() {
        // 스레드 안전하게 버퍼 비우기
        bufferLock.lock()
        defer { bufferLock.unlock() }

        frameBuffer.removeAll()
        // 배열의 모든 요소 제거
        // 메모리 즉시 해제
        // count = 0이 됨
    }

    // MARK: - Private Methods (비공개 메서드)

    /*
     Private 메서드:
     - 클래스 내부에서만 사용
     - 외부에서 직접 호출 불가
     - 내부 구현 세부사항

     이 섹션의 메서드들:
     - decodingLoop(): 디코딩 루프 (백그라운드 스레드에서 실행)
     - addFrameToBuffer(): 프레임을 버퍼에 추가
     - findNearestFrame(): 가장 가까운 프레임 찾기
     - findFrameBefore(): 이전 프레임 찾기
     - findFrameAfter(): 이후 프레임 찾기
     - findExactFrame(): 정확한 프레임 찾기
     */

    /// @brief 목표 시간에 가장 가까운 프레임을 찾습니다
    /// @param time 목표 시간
    /// @return 가장 가까운 프레임
    /// @details
    /// 이진 탐색으로 목표 시간에 가장 가까운 프레임을 찾습니다.
    /// 버퍼는 이미 타임스탬프 순으로 정렬되어 있으므로 O(log n) 성능.
    private func findNearestFrame(to time: TimeInterval) -> VideoFrame? {
        guard !frameBuffer.isEmpty else { return nil }

        // 이진 탐색으로 삽입 위치 찾기
        var left = 0
        var right = frameBuffer.count - 1

        // 특수 케이스: 목표 시간이 버퍼 범위 밖인 경우
        if time <= frameBuffer[0].timestamp {
            return frameBuffer[0]
        }
        if time >= frameBuffer[right].timestamp {
            return frameBuffer[right]
        }

        // 이진 탐색
        while left <= right {
            let mid = (left + right) / 2
            let frame = frameBuffer[mid]

            if frame.timestamp == time {
                // 정확히 일치하는 프레임 발견
                return frame
            } else if frame.timestamp < time {
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        // left와 right 사이에 목표 시간이 있음
        // left = 목표 시간 이후의 첫 프레임
        // right = 목표 시간 이전의 마지막 프레임
        if right >= 0 && left < frameBuffer.count {
            let beforeFrame = frameBuffer[right]
            let afterFrame = frameBuffer[left]

            let diffBefore = abs(beforeFrame.timestamp - time)
            let diffAfter = abs(afterFrame.timestamp - time)

            // 더 가까운 프레임 선택 (같으면 이전 프레임 선택)
            return diffBefore <= diffAfter ? beforeFrame : afterFrame
        }

        // 폴백: 배열 범위 확인
        if right >= 0 && right < frameBuffer.count {
            return frameBuffer[right]
        }
        if left >= 0 && left < frameBuffer.count {
            return frameBuffer[left]
        }

        return nil
    }

    /// @brief 목표 시간 이전의 가장 가까운 프레임을 찾습니다
    /// @param time 목표 시간
    /// @return 이전 프레임
    /// @details
    /// 되감기나 정확한 시간 이전의 프레임이 필요할 때 사용.
    private func findFrameBefore(time: TimeInterval) -> VideoFrame? {
        guard !frameBuffer.isEmpty else { return nil }

        // 이진 탐색으로 목표 시간 이전의 마지막 프레임 찾기
        var left = 0
        var right = frameBuffer.count - 1
        var result: VideoFrame?

        while left <= right {
            let mid = (left + right) / 2
            let frame = frameBuffer[mid]

            if frame.timestamp < time {
                // 이 프레임은 목표 시간 이전
                result = frame
                left = mid + 1  // 더 가까운 프레임이 있는지 오른쪽 탐색
            } else if frame.timestamp == time {
                // 정확히 일치하는 경우, 이전 프레임을 원함
                if mid > 0 {
                    return frameBuffer[mid - 1]
                } else {
                    return nil  // 이전 프레임 없음
                }
            } else {
                // 이 프레임은 목표 시간 이후
                right = mid - 1
            }
        }

        return result
    }

    /// @brief 목표 시간 이후의 가장 가까운 프레임을 찾습니다
    /// @param time 목표 시간
    /// @return 이후 프레임
    /// @details
    /// 빨리감기나 정확한 시간 이후의 프레임이 필요할 때 사용.
    private func findFrameAfter(time: TimeInterval) -> VideoFrame? {
        guard !frameBuffer.isEmpty else { return nil }

        // 이진 탐색으로 목표 시간 이후의 첫 프레임 찾기
        var left = 0
        var right = frameBuffer.count - 1
        var result: VideoFrame?

        while left <= right {
            let mid = (left + right) / 2
            let frame = frameBuffer[mid]

            if frame.timestamp > time {
                // 이 프레임은 목표 시간 이후
                result = frame
                right = mid - 1  // 더 가까운 프레임이 있는지 왼쪽 탐색
            } else if frame.timestamp == time {
                // 정확히 일치하는 경우, 이후 프레임을 원함
                if mid < frameBuffer.count - 1 {
                    return frameBuffer[mid + 1]
                } else {
                    return nil  // 이후 프레임 없음
                }
            } else {
                // 이 프레임은 목표 시간 이전
                left = mid + 1
            }
        }

        return result
    }

    /// @brief 허용 오차 내에서 정확히 일치하는 프레임을 찾습니다
    /// @param time 목표 시간
    /// @param tolerance 허용 오차 (초)
    /// @return 정확한 프레임
    /// @details
    /// 특정 tolerance 내의 프레임만 반환. 프레임레이트 기반 tolerance 권장.
    /// 예: 30fps → tolerance = 1/(30*2) = 0.0167초
    private func findExactFrame(at time: TimeInterval, tolerance: TimeInterval) -> VideoFrame? {
        // 먼저 가장 가까운 프레임 찾기
        guard let nearestFrame = findNearestFrame(to: time) else {
            return nil
        }

        // tolerance 내에 있는지 확인
        let diff = abs(nearestFrame.timestamp - time)
        if diff <= tolerance {
            return nearestFrame
        }

        return nil  // tolerance 밖이면 nil 반환
    }

    /// @brief 디코딩 루프 (백그라운드 스레드에서 실행)
    /// @details
    /// 무한 루프(Infinite Loop)란?
    /// - while isDecoding { ... } 형태
    /// - isDecoding이 true인 동안 계속 반복
    /// - isDecoding이 false가 되면 루프 종료
    ///
    /// 루프 동작:
    /// ```
    /// 시작
    ///   ↓
    /// ┌──────────────────┐
    /// │ isDecoding?      │ ← while 조건 확인
    /// └──────────────────┘
    ///   ↓ true         ↓ false
    /// ┌──────────────┐  종료
    /// │ 버퍼 확인     │
    /// │ 프레임 디코딩 │
    /// │ 버퍼에 추가   │
    /// └──────────────┘
    ///   ↓
    /// (다시 위로)
    /// ```
    ///
    /// autoreleasepool이란?
    /// - 루프 안에서 생성된 임시 객체를 즉시 해제
    /// - 메모리 사용량 최소화
    /// - 루프가 오래 실행되어도 메모리 누적 안 됨
    ///
    /// 로깅(Logging):
    /// - infoLog, debugLog, errorLog 사용
    /// - 디버깅과 모니터링을 위한 로그 출력
    /// - 프레임 수, 버퍼 상태 등 기록
    ///
    /// 에러 처리:
    /// - endOfFile: 파일 끝 도달, 정상 종료
    /// - readFrameError: 디코딩 에러 발생
    /// - 기타 에러: 에러 상태로 전환
    private func decodingLoop() {
        // 시작 로그
        infoLog("[VideoChannel:\(channelInfo.position.displayName)] Decoding loop started")
        // 예: "[VideoChannel:전방 카메라] Decoding loop started"

        // 통계 변수
        var frameCount = 0  // 디코딩한 총 프레임 수
        var lastLogTime = Date()  // 마지막 로그 시간

        // 메인 루프
        // isDecoding이 true인 동안 계속 실행
        // stop()이나 seek()가 호출되면 isDecoding = false
        while isDecoding {
            // autoreleasepool: 루프 한 번 돌 때마다 임시 메모리 해제
            autoreleasepool {
                // autoreleasepool이란?
                // - Objective-C와의 호환성을 위한 메모리 관리 도구
                // - 블록 안에서 생성된 임시 객체를 블록 끝에서 해제
                // - 루프 안에서 사용하면 메모리 누적 방지
                //
                // 예:
                // ```
                // for i in 1...1000000 {
                //     autoreleasepool {
                //         let data = hugeData()  // 큰 데이터 생성
                //         // 사용...
                //     }  // 여기서 data 즉시 해제
                // }
                // ```

                // 1. 버퍼 크기 확인 (스레드 안전)
                bufferLock.lock()
                let bufferSize = frameBuffer.count
                bufferLock.unlock()
                // 짧은 시간만 잠금, 즉시 해제

                // 2. 버퍼가 가득 찼는지 확인
                guard bufferSize < maxBufferSize else {
                    // 버퍼가 가득 참 (30개)
                    // 더 디코딩해도 추가할 공간 없음
                    // 잠시 대기

                    // 2초마다 로그 출력 (너무 많은 로그 방지)
                    if Date().timeIntervalSince(lastLogTime) > 2.0 {
                        debugLog("[VideoChannel:\(channelInfo.position.displayName)] Buffer full (\(bufferSize)/\(maxBufferSize)), waiting...")
                        lastLogTime = Date()
                    }

                    // 10밀리초 대기
                    Thread.sleep(forTimeInterval: 0.01)
                    // Thread.sleep: 현재 스레드를 지정된 시간만큼 멈춤
                    // 0.01초 = 10밀리초
                    // CPU 낭비 방지

                    return  // autoreleasepool 종료, while 루프 계속
                }

                // 3. 디코더 확인
                guard let decoder = decoder else {
                    // 디코더가 없음 (stop() 호출됨)
                    isDecoding = false
                    return  // 루프 종료
                }

                // 4. 다음 프레임 디코딩 시도
                do {
                    // try: 에러 발생 가능한 코드
                    // do-catch: 에러 처리

                    if let result = try decoder.decodeNextFrame() {
                        // decodeNextFrame(): 다음 패킷을 디코딩
                        // 반환: (video: VideoFrame?, audio: AudioFrame?)
                        // nil: EAGAIN (더 많은 패킷 필요)

                        if let videoFrame = result.video {
                            // 비디오 프레임이 디코딩됨
                            addFrameToBuffer(videoFrame)
                            frameCount += 1
                        }

                        // 오디오 프레임은 무시
                        // 멀티 채널 환경에서는 마스터 채널에서만 오디오 사용
                        // 각 채널마다 오디오를 재생하면 소리가 겹침
                    }
                    // result가 nil이면:
                    // - EAGAIN 에러 (더 많은 패킷 필요)
                    // - 다음 루프에서 다시 시도

                } catch {
                    // 에러 발생
                    errorLog("Channel \(channelInfo.position.displayName) decode error: \(error)")

                    // 에러 종류에 따라 처리
                    if case DecoderError.endOfFile = error {
                        // 파일 끝 도달 (정상 종료)
                        isDecoding = false
                        state = .completed
                        infoLog("Channel \(channelInfo.position.displayName) completed after \(frameCount) frames")

                    } else if case DecoderError.readFrameError(let code) = error, code == -541478725 {
                        // AVERROR_EOF from av_read_frame
                        // FFmpeg의 파일 끝 에러 코드
                        // -541478725 = AVERROR_EOF
                        isDecoding = false
                        state = .completed
                        infoLog("Channel \(channelInfo.position.displayName) completed (EOF) after \(frameCount) frames")

                    } else {
                        // 기타 에러 (실제 오류)
                        state = .error(error.localizedDescription)
                        isDecoding = false
                    }
                }
            }  // autoreleasepool 끝
            // 여기서 이번 루프에서 생성된 임시 객체들 해제
        }  // while 끝

        // 루프 종료 로그
        infoLog("[VideoChannel:\(channelInfo.position.displayName)] Decoding loop ended, total frames: \(frameCount)")
        // 예: "[VideoChannel:전방 카메라] Decoding loop ended, total frames: 450"
    }

    /// @brief 프레임을 버퍼에 추가합니다
    /// @param frame 추가할 VideoFrame
    /// @details
    /// 추가 과정:
    /// 1. 버퍼 잠금 (스레드 안전)
    /// 2. 버퍼에 프레임 추가
    /// 3. 타임스탬프 순서로 정렬
    /// 4. 버퍼 크기 제한 (오래된 프레임 제거)
    /// 5. 처음 몇 프레임 로그 출력
    /// 6. 현재 프레임 업데이트 (메인 스레드)
    ///
    /// 정렬(Sorting)이 필요한 이유:
    /// - 디코딩 순서와 표시 순서가 다를 수 있음
    /// - H.264는 B-프레임(양방향 예측 프레임)이 있음
    /// - 디코딩: I, P, B, P, B 순서
    /// - 표시: I, B, B, P, P 순서
    /// - 타임스탬프로 정렬하여 올바른 순서 유지
    private func addFrameToBuffer(_ frame: VideoFrame) {
        // 1. 버퍼 잠금
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // 2. 버퍼에 프레임 추가
        frameBuffer.append(frame)
        // append(): 배열 끝에 요소 추가
        // [Frame1, Frame2] + Frame3 = [Frame1, Frame2, Frame3]

        // 3. 타임스탬프 순서로 정렬
        frameBuffer.sort { frame1, frame2 in
            // sort(by:): 배열 정렬
            // 클로저가 true를 반환하면 frame1이 frame2보다 앞에 옴
            frame1.timestamp < frame2.timestamp
            // 타임스탬프가 작은 것부터 (오름차순)
        }
        // 정렬 후: [0.0초, 0.033초, 0.067초, 0.1초, ...]

        // 4. 버퍼 크기 제한
        if frameBuffer.count > maxBufferSize {
            // 버퍼가 최대 크기 초과
            // 오래된 프레임들 제거

            let removeCount = frameBuffer.count - maxBufferSize
            // 제거할 개수
            // 예: 32 - 30 = 2개 제거

            frameBuffer.removeFirst(removeCount)
            // removeFirst(n): 앞에서 n개 제거
            // 타임스탬프가 작은 (오래된) 프레임들 제거
        }

        // 5. 처음 몇 프레임 로그 (디버깅용)
        if frameBuffer.count <= 3 {
            // 처음 3개 프레임만 로그 출력
            // 너무 많은 로그 방지

            debugLog("[VideoChannel:\(channelInfo.position.displayName)] Buffered frame #\(frame.frameNumber) at \(String(format: "%.2f", frame.timestamp))s, buffer size: \(frameBuffer.count)")
            // String(format:): 형식화된 문자열 생성
            // "%.2f": 소수점 2자리
            // 예: "Buffered frame #5 at 0.17s, buffer size: 3"
        }

        // 6. 현재 프레임 업데이트 (메인 스레드에서)
        DispatchQueue.main.async { [weak self] in
            // DispatchQueue.main: 메인 스레드
            // .async: 비동기 실행 (기다리지 않음)
            //
            // 왜 메인 스레드인가?
            // - @Published 속성 업데이트는 메인 스레드에서
            // - SwiftUI UI 업데이트는 메인 스레드에서만
            // - 백그라운드 스레드에서 UI 업데이트하면 크래시
            //
            // [weak self]: 순환 참조 방지

            self?.currentFrame = frame
            // @Published이므로 UI 자동 업데이트
            // 화면에 최신 프레임 표시됨
        }
    }
}

// MARK: - Supporting Types (지원 타입)

/// @enum FrameSelectionStrategy
/// @brief 프레임 선택 전략을 나타내는 열거형
/// @details
/// getFrame(at:strategy:) 메서드에서 사용되는 프레임 선택 전략입니다.
///
/// ## 전략 종류:
///
/// **nearest (기본)**:
/// - 목표 시간에 가장 가까운 프레임 선택
/// - 앞뒤 프레임 모두 고려
/// - 일반적인 재생에 적합
///
/// **before**:
/// - 목표 시간 이전의 가장 가까운 프레임
/// - 되감기나 정확한 시간 이전이 필요할 때
/// - 예: 5.0초 요청 시 4.967초 프레임 반환
///
/// **after**:
/// - 목표 시간 이후의 가장 가까운 프레임
/// - 빨리감기나 정확한 시간 이후가 필요할 때
/// - 예: 5.0초 요청 시 5.033초 프레임 반환
///
/// **exact(tolerance)**:
/// - 허용 오차 내에서 정확히 일치하는 프레임만
/// - tolerance 밖이면 nil 반환
/// - 정밀한 동기화가 필요할 때
/// - 예: exact(tolerance: 0.01) → ±10ms 이내만 허용
///
/// ## 사용 예시:
/// ```swift
/// // 일반 재생 (기본)
/// let frame1 = channel.getFrame(at: 5.0)
///
/// // 프레임 단위 되감기
/// let frame2 = channel.getFrame(at: currentTime, strategy: .before)
///
/// // 프레임 단위 빨리감기
/// let frame3 = channel.getFrame(at: currentTime, strategy: .after)
///
/// // 정밀 동기화 (30fps 기준)
/// let tolerance = 1.0 / (30.0 * 2)  // 약 0.0167초
/// let frame4 = channel.getFrame(at: 5.0, strategy: .exact(tolerance: tolerance))
/// ```
enum FrameSelectionStrategy {
    /// @brief 가장 가까운 프레임 (기본)
    case nearest

    /// @brief 목표 시간 이전의 프레임
    case before

    /// @brief 목표 시간 이후의 프레임
    case after

    /// @brief 정확히 일치하는 프레임 (허용 오차 내)
    /// @param tolerance 허용 오차 (초 단위)
    case exact(tolerance: TimeInterval)
}

/// @enum ChannelState
/// @brief 채널 상태를 나타내는 열거형
/// @details
/// enum(열거형)이란?
/// - 관련된 값들을 하나로 묶은 타입
/// - 정해진 값들 중 하나만 가질 수 있음
/// - switch 문으로 모든 경우를 처리 가능
///
/// Equatable이란?
/// - ==, != 연산자로 비교 가능
/// - state1 == state2 가능
///
/// 연관 값(Associated Value):
/// - case error(String)처럼 추가 정보를 담을 수 있음
/// - 예: .error("File not found")
///
/// 상태 전이(State Transition):
/// ```
/// .idle (유휴)
///   ↓ initialize()
/// .ready (준비)
///   ↓ startDecoding()
/// .decoding (디코딩 중)
///   ↓ 파일 끝
/// .completed (완료)
///
/// 언제든지:
///   → .error (에러)
///   → .idle (stop())
/// ```
enum ChannelState: Equatable {
    /// @brief 유휴 상태 (초기 상태, 아무것도 안 함)
    case idle

    /// @brief 준비 완료 (디코더 초기화됨, 디코딩 시작 가능)
    case ready

    /// @brief 디코딩 중 (백그라운드에서 프레임 디코딩 중)
    case decoding

    /// @brief 완료 (파일 끝까지 디코딩 완료)
    case completed

    /// @brief 에러 (에러 메시지 포함)
    case error(String)

    /// @brief UI에 표시할 상태 이름
    /// @return 상태를 나타내는 문자열
    var displayName: String {
        // computed property (계산 속성)
        // 값을 저장하지 않고 계산하여 반환

        switch self {
        // self: 현재 enum 값
        // switch: 모든 경우를 나누어 처리

        case .idle:
            return "Idle"
        case .ready:
            return "Ready"
        case .decoding:
            return "Decoding"
        case .completed:
            return "Completed"
        case .error(let message):
            // let message: 연관 값 추출
            // .error("File not found") → message = "File not found"
            return "Error: \(message)"
        }
    }
}

/// @enum ChannelError
/// @brief 채널 관련 에러를 나타내는 열거형
/// @details
/// LocalizedError란?
/// - Swift의 표준 에러 프로토콜
/// - errorDescription으로 사용자 친화적인 메시지 제공
/// - Error 프로토콜보다 더 많은 정보 제공
enum ChannelError: LocalizedError {
    /// @brief 초기화되지 않음 (initialize() 먼저 호출 필요)
    case notInitialized

    /// @brief 잘못된 상태 (예: 이미 초기화됨)
    case invalidState(String)

    /// @brief 에러 설명 (사용자에게 표시할 메시지)
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Channel not initialized"
        case .invalidState(let message):
            return "Invalid channel state: \(message)"
        }
    }

    // 사용 예:
    // ```swift
    // do {
    //     try channel.seek(to: 5.0)
    // } catch let error as ChannelError {
    //     print(error.errorDescription)
    //     // "Channel not initialized"
    // }
    // ```
}

// MARK: - Equatable (동등성 비교)

/// @brief VideoChannel을 비교 가능하게 만듦
/// @details
/// extension이란?
/// - 기존 타입에 새 기능 추가
/// - 클래스 정의를 수정하지 않고 확장
///
/// Equatable 프로토콜:
/// - ==, != 연산자 사용 가능
/// - 배열에서 contains(), firstIndex(of:) 사용 가능
///
/// 채널 비교:
/// - channelID가 같으면 같은 채널
/// - 다른 속성(state, currentFrame)은 무시
extension VideoChannel: Equatable {
    /// @brief 두 VideoChannel이 같은지 비교
    /// @param lhs 왼쪽 피연산자
    /// @param rhs 오른쪽 피연산자
    /// @return channelID가 같으면 true
    static func == (lhs: VideoChannel, rhs: VideoChannel) -> Bool {
        // static func: 타입 메서드 (인스턴스 아닌 타입에 속함)
        // ==: 연산자 오버로딩
        // lhs: left-hand side (왼쪽)
        // rhs: right-hand side (오른쪽)

        return lhs.channelID == rhs.channelID
        // UUID가 같으면 같은 채널
    }
}

// 사용 예:
// ```swift
// let channel1 = VideoChannel(channelInfo: info1)
// let channel2 = VideoChannel(channelInfo: info2)
//
// if channel1 == channel2 {
//     print("같은 채널")
// } else {
//     print("다른 채널")
// }
//
// let channels = [channel1, channel2, channel3]
// if channels.contains(channel1) {
//     print("channel1이 배열에 있음")
// }
// ```

// MARK: - Identifiable (식별 가능)

/// @brief VideoChannel을 SwiftUI에서 식별 가능하게 만듦
/// @details
/// Identifiable 프로토콜:
/// - SwiftUI의 List, ForEach에서 사용
/// - id 속성 필요 (고유 식별자)
/// - 각 항목을 구분하는 데 사용
///
/// ForEach 사용 예:
/// ```swift
/// ForEach(channels) { channel in
///     // channel.id를 자동으로 사용하여 각 항목 구분
///     Text(channel.channelInfo.displayName)
/// }
/// ```
///
/// id가 없으면:
/// ```swift
/// ForEach(channels, id: \.channelID) { channel in
///     // id를 명시해야 함
/// }
/// ```
///
/// id가 있으면:
/// ```swift
/// ForEach(channels) { channel in
///     // id 자동 사용
/// }
/// ```
extension VideoChannel: Identifiable {
    /// @brief 고유 식별자
    /// @return channelID
    var id: UUID {
        // computed property
        // channelID를 id로 반환
        channelID
        // return channelID와 같음 (Swift 단축 문법)
    }
}
