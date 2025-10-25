/**
 * @file VideoDecoderTests.swift
 * @brief FFmpeg 기반 비디오 디코더 단위 테스트
 * @author BlackboxPlayer Team
 *
 * @details
 * FFmpeg 기반 비디오 디코더(VideoDecoder)의 기능을 검증하는 단위 테스트 모음입니다.
 * 초기화, 프레임 디코딩, 시간 탐색, 에러 처리, 메모리 관리, 성능을 테스트합니다.
 *
 * @section video_decoder_overview 비디오 디코더란?
 *
 * VideoDecoder는 압축된 비디오 파일을 읽어서 화면에 표시할 수 있는
 * 원본 이미지 프레임으로 변환하는 컴포넌트입니다.
 *
 * **디코딩 과정:**
 * ```
 * 압축된 비디오 파일 (.mp4, .avi, .mov 등)
 *         ↓
 * VideoDecoder (FFmpeg)
 *         ↓
 * 원본 프레임 (CVPixelBuffer 배열)
 *         ↓
 * Metal 렌더링 → 화면 표시
 * ```
 *
 * @section ffmpeg_overview FFmpeg 프레임워크
 *
 * FFmpeg은 세계에서 가장 널리 사용되는 오픈소스 멀티미디어 프레임워크입니다.
 *
 * **주요 특징:**
 * - **범용성**: 거의 모든 비디오/오디오 포맷 지원
 * - **코덱 지원**: H.264, H.265 (HEVC), VP9, AV1 등
 * - **플랫폼**: Linux, macOS, Windows, iOS, Android 모두 지원
 * - **성능**: 하드웨어 가속 지원 (VideoToolbox, VAAPI, NVDEC)
 * - **오픈소스**: LGPL/GPL 라이선스
 *
 * **FFmpeg 아키텍처:**
 * ```
 * libavformat  - 컨테이너 포맷 (MP4, AVI, MKV 등)
 * libavcodec   - 코덱 (H.264, H.265, AAC 등)
 * libavutil    - 유틸리티 함수
 * libswscale   - 이미지 변환 (YUV → RGB)
 * libswresample - 오디오 리샘플링
 * ```
 *
 * @section test_scope 테스트 범위
 *
 * 1. **디코더 초기화**
 *    - 파일 열기 및 스트림 정보 읽기
 *    - 비디오/오디오 스트림 감지
 *    - 코덱 초기화
 *    - 에러 처리 (파일 없음, 손상된 파일 등)
 *
 * 2. **프레임 디코딩**
 *    - 비디오 프레임 디코딩
 *    - 오디오 프레임 디코딩
 *    - Pixel format 변환 (YUV420p → BGRA)
 *    - CVPixelBuffer 생성
 *
 * 3. **시간 탐색 (Seeking)**
 *    - 특정 시간으로 점프
 *    - 프레임 단위 탐색
 *    - I-frame (키프레임) 탐색
 *    - Seek 정확도 검증
 *
 * 4. **재생 시간 조회**
 *    - Duration 읽기
 *    - Frame rate 조회
 *    - 비트레이트 확인
 *
 * 5. **에러 처리**
 *    - 존재하지 않는 파일
 *    - 손상된 비디오 파일
 *    - 지원하지 않는 코덱
 *    - 디코딩 에러 복구
 *
 * 6. **메모리 관리**
 *    - AVFrame 해제
 *    - AVPacket 해제
 *    - Context 정리
 *    - 메모리 누수 방지
 *
 * 7. **성능**
 *    - 디코딩 속도 측정
 *    - Seek 성능
 *    - 메모리 사용량
 *
 * @section codec_support 지원 코덱
 *
 * **비디오 코덱:**
 * - H.264 (AVC) - 가장 널리 사용
 * - H.265 (HEVC) - 더 높은 압축률
 * - VP9 - Google의 오픈소스 코덱
 * - MJPEG - 모션 JPEG
 *
 * **오디오 코덱:**
 * - AAC - Advanced Audio Coding
 * - MP3 - MPEG-1/2 Audio Layer 3
 * - PCM - 무손실 오디오
 *
 * @section test_limitations 테스트 제한사항
 *
 * **단위 테스트 (이 파일):**
 * - Mock 데이터 사용
 * - 실제 파일 불필요
 * - 빠른 실행 (밀리초 단위)
 * - 에러 경로 검증
 * - 상태 관리 테스트
 *
 * **통합 테스트 (별도 파일):**
 * - 실제 비디오 파일 필요
 * - 실제 디코딩 검증
 * - 느린 실행 (초 단위)
 * - 정상 경로 검증
 * - 엔드투엔드 시나리오
 *
 * @section test_strategy 테스트 전략
 *
 * 실제 비디오 파일 없이도 디코더의 상태 관리와 에러 처리가 올바른지 검증합니다.
 * 이를 통해 CI/CD에서 빠르게 실행 가능한 테스트를 제공합니다.
 *
 * @note FFmpeg은 C 라이브러리이므로, Swift 래퍼 클래스(VideoDecoder)를 통해
 * 안전하게 사용됩니다. 메모리 관리에 특히 주의가 필요합니다.
 */

//
//  ═══════════════════════════════════════════════════════════════════════════
//  VideoDecoderTests.swift
//  BlackboxPlayerTests
//
//  📋 프로젝트: BlackboxPlayer
//  🎯 목적: VideoDecoder 유닛 테스트
//  📝 설명: FFmpeg 기반 비디오 디코더의 기능을 검증합니다
//
//  ═══════════════════════════════════════════════════════════════════════════
//
//  🎬 비디오 디코더란?
//  ────────────────────────────────────────────────────────────────────────
//  압축된 비디오 파일을 읽어서 화면에 표시할 수 있는
//  이미지 프레임으로 변환하는 컴포넌트입니다.
//
//  📦 디코딩 과정:
//  ```
//  압축된 비디오 파일 (.mp4, .avi 등)
//         ↓
//  디코더 (VideoDecoder)
//         ↓
//  원본 프레임 (이미지 배열)
//         ↓
//  화면 렌더링
//  ```
//
//  🔧 FFmpeg란?
//  세계에서 가장 널리 사용되는 오픈소스 멀티미디어 프레임워크입니다.
//  - 거의 모든 비디오/오디오 포맷 지원
//  - H.264, H.265, VP9 등 다양한 코덱 지원
//  - 리눅스, macOS, Windows, iOS, Android 모두 지원
//
//  🎯 이 테스트가 검증하는 것:
//  1. 디코더 초기화
//  2. 프레임 디코딩 (비디오/오디오)
//  3. 시간 탐색 (Seeking)
//  4. 재생 시간 조회
//  5. 에러 처리
//  6. 메모리 관리
//  7. 성능
//  ────────────────────────────────────────────────────────────────────────
//

/// XCTest 프레임워크
///
/// Apple의 공식 유닛 테스트 프레임워크입니다.
import XCTest

/// @testable import
///
/// 테스트 대상 모듈의 internal 멤버에 접근할 수 있게 합니다.
@testable import BlackboxPlayer

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - 비디오 디코더 테스트 (Unit Tests)
// ═══════════════════════════════════════════════════════════════════════════

/// VideoDecoder 유닛 테스트 클래스
///
/// 비디오 디코더의 기본 기능을 검증합니다.
///
/// ⚠️ 테스트 제한사항:
/// 이 테스트는 실제 비디오 파일 없이 실행됩니다.
/// 주로 에러 처리와 상태 관리를 검증합니다.
///
/// 💡 통합 테스트와의 차이:
/// ```
/// Unit Tests (VideoDecoderTests):
/// - Mock 데이터 사용
/// - 실제 파일 불필요
/// - 빠른 실행
/// - 에러 경로 검증
///
/// Integration Tests (VideoDecoderIntegrationTests):
/// - 실제 비디오 파일 필요
/// - 실제 디코딩 검증
/// - 느린 실행
/// - 정상 경로 검증
/// ```
///
/// 🎯 테스트 전략:
/// 실제 비디오 파일 없이도 디코더의 상태 관리와
/// 에러 처리가 올바른지 검증합니다.
final class VideoDecoderTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 테스트 비디오 파일 경로
     */
    /**
     * 실제로는 존재하지 않는 경로입니다.
     * 에러 처리 테스트에 사용됩니다.
     */
    /**
     *
     * @section ____implicitly_unwrapped_optional_ 📝 !  (Implicitly Unwrapped Optional)
     * setUp에서 반드시 초기화되므로 안전합니다.
     */
    var testVideoPath: String!

    /**
     * 비디오 디코더 인스턴스
     */
    /**
     * 각 테스트에서 새로 생성됩니다.
     */
    /**
     *
     * @section nil_____ 💡 nil로 초기화
     * 각 테스트 메서드에서 필요에 따라 생성합니다.
     */
    var decoder: VideoDecoder!

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
     * 3. 테스트 비디오 경로 생성
     */
    /**
     *
     * @section continueafterfailure___false 💡 continueAfterFailure = false
     * 첫 번째 assertion 실패 시 테스트를 즉시 중단합니다.
     */
    /**
     *
     * @section __________ 📝 왜 중단해야 할까?
     * @endcode
     * // continueAfterFailure = true (기본값)
     * XCTAssertNotNil(decoder)  // 실패!
     * XCTAssertTrue(decoder.isInitialized)  // decoder가 nil이라 크래시!
     */
    /**
     * // continueAfterFailure = false
     * XCTAssertNotNil(decoder)  // 실패! → 테스트 즉시 중단
     * // 이후 코드는 실행되지 않음 → 크래시 방지
     * @endcode
     */
    /**
     *
     * @section __________ 🎬 테스트 비디오 경로
     * "/path/to/test/video.mp4"는 존재하지 않는 경로입니다.
     * 에러 처리를 테스트하기 위한 의도적인 잘못된 경로입니다.
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
         * @section _________ 💡 이 플래그의 효과
         * - true: 실패해도 테스트 계속 실행 (위험)
         * - false: 실패하면 즉시 중단 (안전)
         */
        continueAfterFailure = false

        /**
         * 테스트 비디오 경로 생성
         */
        /**
         *
         * @section ________________________ ⚠️ 주의: 이 경로는 실제로 존재하지 않습니다!
         * 실제 테스트에서는 번들에 있는 진짜 비디오 파일을 사용해야 합니다.
         */
        /**
         *
         * @section _____________ 📝 이 경로를 사용하는 이유
         * - 파일이 없을 때의 에러 처리를 테스트하기 위함
         * - 초기화 실패 시나리오 검증
         */
        testVideoPath = "/path/to/test/video.mp4"
    }

    /**
     * 각 테스트 실행 후 정리
     */
    /**
     * XCTest가 각 테스트 메서드 실행 후에 자동으로 호출합니다.
     */
    /**
     * 🧹 정리 내용:
     * 1. decoder를 nil로 설정 (메모리 해제)
     * 2. testVideoPath를 nil로 설정
     * 3. 부모 클래스의 tearDown 호출
     */
    /**
     *
     * @section ______ 💾 메모리 관리
     * @endcode
     * decoder = nil  // VideoDecoder의 deinit이 호출됨
     *                // FFmpeg 리소스도 함께 해제됨
     * @endcode
     */
    /**
     *
     * @section __________ 🎯 정리가 중요한 이유
     * - FFmpeg은 네이티브 C 라이브러리
     * - 메모리 누수 방지
     * - 파일 핸들 정리
     * - 다음 테스트를 위한 깨끗한 상태 유지
     */
    override func tearDownWithError() throws {
        /**
         * decoder 해제
         */
        /**
         * VideoDecoder의 deinit이 호출되어
         * FFmpeg 리소스가 정리됩니다.
         */
        decoder = nil

        /**
         * 테스트 경로 해제
         */
        testVideoPath = nil

        /**
         * 부모 클래스의 tearDown 호출
         */
        super.tearDown()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Initialization Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 디코더 초기화 테스트
     */
    /**
     * VideoDecoder 객체 생성 시 초기 상태를 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. VideoDecoder 객체 생성
     * 2. 객체가 nil이 아닌지 확인
     * 3. 초기화 상태 플래그 확인
     * 4. 비디오/오디오 정보 확인
     */
    /**
     *
     * @section given_when_then___ 💡 Given-When-Then 패턴
     * @endcode
     * Given (준비): 테스트할 조건 설정
     * When (실행): 테스트할 동작 수행
     * Then (검증): 결과 확인
     * @endcode
     */
    /**
     *
     * @section 2______ 📝 2단계 초기화
     * VideoDecoder는 2단계로 초기화됩니다:
     * @endcode
     * // 1단계: 객체 생성
     * let decoder = VideoDecoder(filePath: path)
     * // 이 시점에는 파일을 열지 않음
     */
    /**
     * // 2단계: 실제 초기화
     * try decoder.initialize()
     * // 이 시점에 파일을 열고 코덱 정보 읽음
     * @endcode
     */
    /**
     * @test testDecoderInitialization
     * @brief 🎯 2단계 초기화의 장점:
     *
     * @details
     *
     * @section 2__________ 🎯 2단계 초기화의 장점
     * - 객체 생성 시 예외 처리 불필요
     * - 초기화 실패 시 명확한 에러 처리
     * - 지연 초기화 가능 (필요할 때만 초기화)
     */
    func testDecoderInitialization() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 디코더 생성
         */
        /**
         * VideoDecoder 객체를 생성합니다.
         * 이 시점에는 파일을 열지 않고 경로만 저장합니다.
         */
        /**
         *
         * @section testvideopath 💡 testVideoPath
         * setUp에서 설정한 "/path/to/test/video.mp4"
         * (실제로는 존재하지 않는 경로)
         */
        decoder = VideoDecoder(filePath: testVideoPath)

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 초기 상태 검증
         *
         * 1. 디코더 객체 생성 확인
         */
        /**
         * XCTAssertNotNil: 값이 nil이 아닌지 검증
         * 두 번째 매개변수는 실패 시 출력될 메시지
         */
        XCTAssertNotNil(decoder, "Decoder should be initialized")

        /**
         * 2. 초기화 상태 플래그 확인
         */
        /**
         * isInitialized: 디코더가 초기화되었는지 나타내는 Boolean
         */
        /**
         *
         * @section ___________ 💡 초기화되지 않은 상태
         * - 객체는 생성됨
         * - 하지만 initialize()는 아직 호출 안됨
         * - 파일을 열지 않음
         * - 디코딩 불가능
         */
        XCTAssertFalse(decoder.isInitialized, "Decoder should not be initialized before calling initialize()")

        /**
         * 3. 비디오 정보 확인
         */
        /**
         * videoInfo: 비디오 스트림 정보 (해상도, 프레임레이트 등)
         */
        /**
         * XCTAssertNil: 값이 nil인지 검증
         */
        /**
         *
         * @section ________nil 💡 초기화 전에는 nil
         * 파일을 열어야만 비디오 정보를 읽을 수 있습니다.
         */
        XCTAssertNil(decoder.videoInfo, "Video info should be nil before initialization")

        /**
         * 4. 오디오 정보 확인
         */
        /**
         * audioInfo: 오디오 스트림 정보 (샘플레이트, 채널 수 등)
         */
        /**
         *
         * @section ________nil 💡 초기화 전에는 nil
         * 파일을 열어야만 오디오 정보를 읽을 수 있습니다.
         */
        XCTAssertNil(decoder.audioInfo, "Audio info should be nil before initialization")
    }

    /**
     * 존재하지 않는 파일로 초기화 테스트
     */
    /**
     * 존재하지 않는 파일 경로로 초기화 시도 시
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     * 🚫 파일을 열 수 없는 경우:
     * @endcode
     * 1. 파일이 존재하지 않음
     * 2. 권한이 없음
     * 3. 파일이 손상됨
     * 4. 지원하지 않는 포맷
     * @endcode
     */
    /**
     *
     * @section decodererror_cannotopenfile 📝 DecoderError.cannotOpenFile
     * FFmpeg이 파일을 열 수 없을 때 발생하는 에러입니다.
     */
    /**
     * @test testInitializeWithNonExistentFile
     * @brief 💡 guard case 패턴:
     *
     * @details
     *
     * @section guard_case___ 💡 guard case 패턴
     * Swift의 패턴 매칭으로 enum case를 검증합니다.
     * @endcode
     * if case DecoderError.cannotOpenFile = error {
     *     // error가 cannotOpenFile인 경우
     * } else {
     *     // 다른 에러인 경우 → 테스트 실패
     * }
     * @endcode
     */
    func testInitializeWithNonExistentFile() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 존재하지 않는 파일 경로로 디코더 생성
         */
        /**
         * "/nonexistent/file.mp4"는 의도적으로 존재하지 않는 경로입니다.
         */
        /**
         *
         * @section _________ 💡 객체 생성은 성공
         * 생성자는 경로만 저장하고 파일을 열지 않으므로 성공합니다.
         */
        decoder = VideoDecoder(filePath: "/nonexistent/file.mp4")

        /**
         * When/Then: 초기화 시도 및 에러 검증
         */
        /**
         * initialize()를 호출하면 실제로 파일을 열려고 시도합니다.
         * 파일이 없으므로 에러를 던져야 합니다.
         */
        XCTAssertThrowsError(try decoder.initialize()) { error in
            /**
             * 에러 타입 검증
             */
            ///
            /**
             * if case: 패턴 매칭으로 enum case 확인
             */
            ///
            /**
             *
             * @section _____ 🎯 검증 내용
             * error가 DecoderError.cannotOpenFile인지 확인
             */
            if case DecoderError.cannotOpenFile = error {
                /**
                 * 예상한 에러 → 테스트 성공
                 */
                ///
                /**
                 *
                 * @section ____________ 💡 주석만 있고 코드 없음
                 * Swift에서는 빈 블록도 허용됩니다.
                 * "예상한 에러이므로 아무것도 안함"을 의미합니다.
                 */
            } else {
                /**
                 * 다른 에러 → 테스트 실패
                 */
                ///
                /**
                 * XCTFail: 테스트를 명시적으로 실패시킴
                 */
                ///
                /**
                 *
                 * @section __error_ 💡 \(error)
                 * 문자열 보간법으로 실제 에러를 출력하여
                 * 디버깅을 쉽게 합니다.
                 */
                XCTFail("Expected cannotOpenFile error, got \(error)")
            }
        }
    }

    /**
     * 중복 초기화 테스트
     */
    /**
     * 이미 초기화된 디코더를 다시 초기화하려 할 때
     * 적절히 처리하는지 검증합니다.
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 이 테스트는 실제 비디오 파일이 필요하므로
     * 아직 구현되지 않았습니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()  // 첫 번째 초기화
     */
    /**
     * // When/Then
     * XCTAssertThrowsError(try decoder.initialize()) { error in
     *     // 에러를 던지거나, 조용히 무시하거나
     *     // 구현 정책에 따라 다름
     * }
     * @endcode
     */
    /**
     *
     * @section ____________ 💡 중복 초기화 처리 방법
     * @endcode
     * 방법 1: 에러 던지기
     * - 명확한 에러 메시지
     * - 프로그래밍 오류 감지 용이
     */
    /**
     * 방법 2: 무시하기
     * - 간단한 구현
     * - 멱등성 (여러 번 호출해도 같은 결과)
     */
    /**
     * @test testDoubleInitialization
     * @brief 방법 3: 재초기화
     *
     * @details
     * 방법 3: 재초기화
     * - 기존 리소스 해제 후 다시 초기화
     * - 유연하지만 복잡함
     * @endcode
     */
    func testDoubleInitialization() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 유효한 파일로 디코더 생성 (Mock 필요)
         */
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 현재는 에러 경로만 테스트합니다.
         *
         * When/Then: 이미 초기화된 디코더에 다시 initialize() 호출
         */
        /**
         *
         * @section _____ 💡 구현 예정
         * XCTAssertThrowsError(try decoder.initialize())
         */
        /**
         *
         * @section _________ 📝 주석 처리된 이유
         * 실제 비디오 파일 없이는 테스트할 수 없으므로
         * Integration Tests에서 구현 예정
         */
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Decoding Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 초기화 없이 프레임 디코딩 테스트
     */
    /**
     * 디코더를 초기화하지 않고 프레임을 디코딩하려 할 때
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎬 디코딩 프로세스
     * @endcode
     * 1. 파일 열기 (initialize)
     * 2. 코덱 정보 읽기
     * 3. 프레임 디코딩 시작 (decodeNextFrame)
     * 4. 순차적으로 프레임 읽기
     * 5. EOF (End of File) 도달
     * @endcode
     */
    /**
     *
     * @section ____________ ⚠️ 초기화 없이 디코딩하면
     * - 파일이 열리지 않음
     * - 코덱 정보 없음
     * - 디코더 상태 불명확
     * → 에러를 던져야 함
     */
    /**
     * @test testDecodeNextFrameWithoutInitialization
     * @brief 📝 DecoderError.notInitialized:
     *
     * @details
     *
     * @section decodererror_notinitialized 📝 DecoderError.notInitialized
     * 디코더가 초기화되지 않은 상태에서
     * 작업을 시도할 때 발생하는 에러입니다.
     */
    func testDecodeNextFrameWithoutInitialization() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화되지 않은 디코더
         */
        /**
         * 객체는 생성했지만 initialize()를 호출하지 않았습니다.
         */
        decoder = VideoDecoder(filePath: testVideoPath)

        /**
         * When/Then: 프레임 디코딩 시도 및 에러 검증
         */
        /**
         * decodeNextFrame()을 호출하면 에러를 던져야 합니다.
         */
        XCTAssertThrowsError(try decoder.decodeNextFrame()) { error in
            /**
             * 에러 타입 검증
             */
            ///
            /**
             * if case: 패턴 매칭으로 enum case 확인
             */
            if case DecoderError.notInitialized = error {
                /**
                 * 예상한 에러 → 테스트 성공
                 */
            } else {
                /**
                 * 다른 에러 → 테스트 실패
                 */
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    /**
     * 비디오 프레임 디코딩 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When
     * let frames = try decoder.decodeNextFrame()
     */
    /**
     * // Then
     * XCTAssertNotNil(frames.video, "Should decode video frame")
     * XCTAssertGreaterThan(frames.video.width, 0)
     * XCTAssertGreaterThan(frames.video.height, 0)
     * @endcode
     */
    /**
     * @test testDecodeVideoFrame
     * @brief 🎬 비디오 프레임 구조:
     *
     * @details
     *
     * @section __________ 🎬 비디오 프레임 구조
     * @endcode
     * VideoFrame {
     *   width: 1920     (픽셀)
     *   height: 1080    (픽셀)
     *   timestamp: 0.033  (초)
     *   data: [UInt8]   (픽셀 데이터)
     *   format: YUV420  (색상 포맷)
     * }
     * @endcode
     */
    func testDecodeVideoFrame() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 비디오 프레임을 성공적으로 디코딩해야 합니다
         */
        /**
         *
         * @section integration_tests______ 💡 Integration Tests에서 구현됨
         * VideoDecoderIntegrationTests.testDecodeMultipleFrames()
         */
    }

    /**
     * 오디오 프레임 디코딩 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일(오디오 포함)이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPathWithAudio)
     * try decoder.initialize()
     */
    /**
     * // When
     * let frames = try decoder.decodeNextFrame()
     */
    /**
     * // Then
     * XCTAssertNotNil(frames.audio, "Should decode audio frame")
     * XCTAssertGreaterThan(frames.audio.sampleCount, 0)
     * @endcode
     */
    /**
     * 🔊 오디오 프레임 구조:
     * @endcode
     * AudioFrame {
     *   sampleRate: 48000  (Hz)
     *   channels: 2        (스테레오)
     *   samples: [Float]   (PCM 데이터)
     *   timestamp: 0.033   (초)
     * }
     * @endcode
     */
    /**
     * @test testDecodeAudioFrame
     * @brief 💡 블랙박스 오디오:
     *
     * @details
     *
     * @section ________ 💡 블랙박스 오디오
     * 일부 블랙박스는 오디오 녹음 기능이 없거나
     * 프라이버시를 위해 오디오를 제거할 수 있습니다.
     */
    func testDecodeAudioFrame() {
        /**
         *
         * @section ___________________________________ ⚠️ 주의: 이 테스트는 오디오가 있는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 오디오 프레임을 성공적으로 디코딩해야 합니다
         */
        /**
         *
         * @section integration_tests______ 💡 Integration Tests에서 구현됨
         * VideoDecoderIntegrationTests.testDecodeMultipleFrames()
         */
    }

    /**
     * EOF까지 디코딩 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When: 모든 프레임 디코딩
     * var frameCount = 0
     * while let frames = try decoder.decodeNextFrame() {
     *     frameCount += 1
     * }
     */
    /**
     * // Then
     * XCTAssertGreaterThan(frameCount, 0, "Should decode at least one frame")
     * XCTAssertNil(try decoder.decodeNextFrame(), "Should return nil at EOF")
     * @endcode
     */
    /**
     * 📁 EOF (End of File):
     * 파일의 끝에 도달하여 더 이상 읽을 데이터가 없는 상태입니다.
     */
    /**
     * @test testDecodeUntilEOF
     * @brief 💡 EOF 처리:
     *
     * @details
     *
     * @section eof___ 💡 EOF 처리
     * - nil 반환: 더 이상 프레임이 없음을 나타냄
     * - 에러 던지기: 선택적 (구현에 따라 다름)
     * - 루프 종료: 재생이 끝났음을 의미
     */
    func testDecodeUntilEOF() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 파일 끝에서 nil을 반환해야 합니다
         */
        /**
         *
         * @section integration_tests______ 💡 Integration Tests에서 구현됨
         * VideoDecoderIntegrationTests.testDecodeMultipleFrames()
         */
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Seeking Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 초기화 없이 시간 탐색 테스트
     */
    /**
     * 디코더를 초기화하지 않고 seek을 시도할 때
     * 적절한 에러를 발생시키는지 검증합니다.
     */
    /**
     *
     * @section seeking___ 🎯 Seeking이란?
     * @endcode
     * 비디오의 특정 시간으로 이동하는 것
     */
    /**
     * 예시:
     * - 5초 지점으로 이동: seek(to: 5.0)
     * - 빨리감기: 현재 시간 + 10초
     * - 되감기: 현재 시간 - 10초
     * @endcode
     */
    /**
     *
     * @section seeking___ 📝 Seeking 과정
     * @endcode
     * 1. 목표 시간 계산
     * 2. 파일에서 가장 가까운 키프레임 찾기
     * 3. 해당 위치로 파일 포인터 이동
     * 4. 디코더 버퍼 초기화
     * 5. 목표 시간까지 디코딩
     * @endcode
     */
    /**
     * @test testSeekWithoutInitialization
     * @brief ⚠️ 초기화 없이 seek하면:
     *
     * @details
     *
     * @section _______seek__ ⚠️ 초기화 없이 seek하면
     * - 파일이 열리지 않음
     * - 시간 정보 없음
     * - 디코더 상태 불명확
     * → 에러를 던져야 함
     */
    func testSeekWithoutInitialization() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화되지 않은 디코더
         */
        decoder = VideoDecoder(filePath: testVideoPath)

        /**
         * When/Then: 시간 탐색 시도 및 에러 검증
         */
        /**
         * seek(to: 5.0): 5초 지점으로 이동 시도
         */
        XCTAssertThrowsError(try decoder.seek(to: 5.0)) { error in
            /**
             * 에러 타입 검증
             */
            if case DecoderError.notInitialized = error {
                /**
                 * 예상한 에러 → 테스트 성공
                 */
            } else {
                /**
                 * 다른 에러 → 테스트 실패
                 */
                XCTFail("Expected notInitialized error, got \(error)")
            }
        }
    }

    /**
     * 유효한 타임스탬프로 탐색 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When
     * try decoder.seek(to: 5.0)  // 5초로 이동
     * let frames = try decoder.decodeNextFrame()
     */
    /**
     * // Then
     * XCTAssertGreaterThanOrEqual(frames.video.timestamp, 5.0)
     * XCTAssertLessThan(frames.video.timestamp, 5.5)
     * @endcode
     */
    /**
     *
     * @section seeking____ 💡 Seeking 정확도
     * @endcode
     * 키프레임(I-Frame)으로만 이동 가능:
     * - 요청: 5.0초
     * - 실제: 4.8초 (가장 가까운 키프레임)
     */
    /**
     * @test testSeekToValidTimestamp
     * @brief 정확한 이동을 위해:
     *
     * @details
     * 정확한 이동을 위해:
     * - 키프레임으로 이동
     * - 목표 시간까지 디코딩 (느림)
     * @endcode
     */
    func testSeekToValidTimestamp() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 유효한 타임스탬프로 이동해야 합니다
         */
        /**
         *
         * @section integration_tests______ 💡 Integration Tests에서 구현됨
         * VideoDecoderIntegrationTests.testSeekAndDecode()
         */
    }

    /**
     * 음수 타임스탬프로 탐색 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When
     * try decoder.seek(to: -5.0)  // 음수 시간
     */
    /**
     * // Then: 여러 처리 방법 가능
     * // 방법 1: 0초로 이동 (가장 일반적)
     * // 방법 2: 에러 던지기
     * // 방법 3: 무시하기
     * @endcode
     */
    /**
     *
     * @section ________ 💡 음수 시간 처리
     * @endcode
     * 방법 1: 0으로 클램핑 (Clamping)
     * seek(to: -5.0) → seek(to: 0.0)
     * 가장 안전하고 직관적
     */
    /**
     * 방법 2: 에러 던지기
     * throw DecoderError.invalidTimestamp
     * 명확한 에러 처리
     */
    /**
     * @test testSeekToNegativeTimestamp
     * @brief 방법 3: 상대 시간으로 해석
     *
     * @details
     * 방법 3: 상대 시간으로 해석
     * 끝에서부터 역산: duration - 5.0
     * 복잡하지만 유연함
     * @endcode
     */
    func testSeekToNegativeTimestamp() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 음수 타임스탬프를 적절히 처리해야 합니다
         */
    }

    /**
     * 재생 시간을 초과하는 탐색 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     * let duration = decoder.getDuration()!
     */
    /**
     * // When
     * try decoder.seek(to: duration + 10.0)  // 재생 시간 초과
     */
    /**
     * // Then: 여러 처리 방법 가능
     * // 방법 1: 마지막 프레임으로 이동
     * // 방법 2: EOF 상태로 설정
     * // 방법 3: 에러 던지기
     * @endcode
     */
    /**
     *
     * @section ________ 💡 초과 시간 처리
     * @endcode
     * 방법 1: duration으로 클램핑
     * seek(to: 100.0) → seek(to: duration)
     * 가장 일반적
     */
    /**
     * 방법 2: EOF 설정
     * 다음 디코딩 시 nil 반환
     * 재생 종료 의미
     */
    /**
     * @test testSeekBeyondDuration
     * @brief 방법 3: 에러 던지기
     *
     * @details
     * 방법 3: 에러 던지기
     * throw DecoderError.seekOutOfRange
     * 명확하지만 불편할 수 있음
     * @endcode
     */
    func testSeekBeyondDuration() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 재생 시간을 초과하는 seek을 적절히 처리해야 합니다
         */
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Duration Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 초기화 없이 재생 시간 조회 테스트
     */
    /**
     * 디코더를 초기화하지 않고 재생 시간을 조회할 때
     * nil을 반환하는지 검증합니다.
     */
    /**
     * 🕐 Duration (재생 시간)이란?
     * @endcode
     * 비디오의 전체 재생 시간 (초 단위)
     */
    /**
     * 예시:
     * - 짧은 클립: 10.5초
     * - 블랙박스 1분 영상: 60.0초
     * - 장편 영화: 7200.0초 (2시간)
     * @endcode
     */
    /**
     *
     * @section ________ 📝 재생 시간 계산
     * @endcode
     * Duration = 전체 프레임 수 / 프레임레이트
     */
    /**
     * 예시:
     * 1800 프레임 / 30 fps = 60초
     * @endcode
     */
    /**
     * @test testGetDurationWithoutInitialization
     * @brief 💡 초기화 전에는 nil:
     *
     * @details
     *
     * @section ________nil 💡 초기화 전에는 nil
     * 파일을 열어야만 메타데이터에서 재생 시간을 읽을 수 있습니다.
     */
    func testGetDurationWithoutInitialization() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 초기화되지 않은 디코더
         */
        decoder = VideoDecoder(filePath: testVideoPath)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 재생 시간 조회
         */
        /**
         * getDuration(): 재생 시간을 반환하는 함수
         * 반환 타입: Double? (Optional)
         */
        let duration = decoder.getDuration()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> nil 반환 확인
         */
        /**
         * XCTAssertNil: 값이 nil인지 검증
         */
        /**
         *
         * @section ___________ 💡 초기화되지 않았으므로
         * - 파일이 열리지 않음
         * - 메타데이터 없음
         * - 재생 시간을 알 수 없음
         * → nil 반환
         */
        XCTAssertNil(duration, "Duration should be nil when decoder is not initialized")
    }

    /**
     * 유효한 파일의 재생 시간 조회 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When
     * let duration = decoder.getDuration()
     */
    /**
     * // Then
     * let unwrappedDuration = try XCTUnwrap(duration)
     * XCTAssertGreaterThan(unwrappedDuration, 0.0)
     * XCTAssertLessThan(unwrappedDuration, 3600.0)  // 1시간 미만
     * @endcode
     */
    /**
     *
     * @section ________ 💡 재생 시간 검증
     * @endcode
     * 일반적인 블랙박스 영상:
     * - 최소: 1초 이상
     * - 일반: 60초 (1분)
     * - 최대: 300초 (5분)
     */
    /**
     * @test testGetDurationWithValidFile
     * @brief 비정상적인 값:
     *
     * @details
     * 비정상적인 값:
     * - 0.0초: 빈 파일
     * - 음수: 잘못된 메타데이터
     * - 매우 큰 값: 손상된 파일
     * @endcode
     */
    func testGetDurationWithValidFile() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 유효한 재생 시간을 반환해야 합니다
         */
        /**
         *
         * @section integration_tests______ 💡 Integration Tests에서 구현됨
         * VideoDecoderIntegrationTests.testGetDuration()
         */
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Error Handling Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 손상된 파일 처리 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 손상된 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given: 손상된 비디오 파일
     * let decoder = VideoDecoder(filePath: corruptedPath)
     */
    /**
     * // When/Then
     * XCTAssertThrowsError(try decoder.initialize()) { error in
     *     // 적절한 에러 타입 확인
     *     if case DecoderError.corruptedFile = error {
     *         // 예상한 에러
     *     }
     * }
     * @endcode
     */
    /**
     * 🚫 파일 손상의 원인:
     * @endcode
     * 1. 불완전한 다운로드
     *    - 네트워크 중단으로 파일 일부만 전송됨
     */
    /**
     * 2. 저장 매체 오류
     *    - SD 카드 불량 섹터
     *    - 갑작스러운 전원 차단
     */
    /**
     * 3. 파일 시스템 손상
     *    - 메타데이터 손실
     *    - inode 테이블 파괴
     */
    /**
     * 4. 인코딩 오류
     *    - 비디오 생성 중 크래시
     * @endcode
     */
    /**
     *
     * @section ________ 💡 손상 감지 방법
     * @endcode
     * FFmpeg이 파일을 읽으면서 감지:
     * - 잘못된 헤더
     * - 불완전한 프레임
     * - 잘못된 체크섬
     * - 예상하지 못한 EOF
     * @endcode
     */
    /**
     * 🔧 에러 복구 전략:
     * @endcode
     * 1. 부분 재생
     *    - 손상되지 않은 부분만 재생
     */
    /**
     * 2. 에러 무시
     *    - 손상된 프레임 건너뛰기
     */
    /**
     * 3. 파일 재다운로드
     *    - 클라우드에서 다시 가져오기
     */
    /**
     * @test testHandleCorruptedFile
     * @brief 4. 사용자에게 알림
     *
     * @details
     * 4. 사용자에게 알림
     *    - 명확한 에러 메시지 표시
     * @endcode
     */
    func testHandleCorruptedFile() {
        /**
         *
         * @section ____________________________ ⚠️ 주의: 이 테스트는 손상된 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 손상된 파일에 대해 적절한 에러를 던져야 합니다
         */
    }

    /**
     * 지원하지 않는 코덱 처리 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 지원하지 않는 코덱의 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given: 지원하지 않는 코덱의 비디오 파일
     * let decoder = VideoDecoder(filePath: unsupportedCodecPath)
     */
    /**
     * // When/Then
     * XCTAssertThrowsError(try decoder.initialize()) { error in
     *     if case DecoderError.codecNotFound = error {
     *         // 예상한 에러
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section _________ 🎬 비디오 코덱이란?
     * @endcode
     * 비디오를 압축/해제하는 알고리즘
     */
    /**
     * 일반적인 코덱:
     * - H.264 (AVC): 가장 널리 사용
     * - H.265 (HEVC): 더 높은 압축률
     * - VP9: Google의 오픈소스 코덱
     * - AV1: 차세대 오픈소스 코덱
     */
    /**
     * 지원하지 않는 코덱:
     * - 독점 코덱 (라이선스 필요)
     * - 매우 오래된 코덱
     * - 실험적인 코덱
     * @endcode
     */
    /**
     *
     * @section ________ 💡 코덱 지원 확인
     * @endcode
     * FFmpeg은 수백 개의 코덱을 지원하지만,
     * 라이센스나 플랫폼 제약으로 일부는 사용 불가
     */
    /**
     * 예시:
     * - iOS: H.264, H.265 하드웨어 가속
     * - Android: 기기마다 다름
     * - Desktop: 대부분 지원
     * @endcode
     */
    /**
     * 🔧 해결 방법:
     * @endcode
     * 1. 코덱 변환 (Transcoding)
     *    - H.264 등 지원되는 코덱으로 변환
     */
    /**
     * 2. 소프트웨어 디코딩
     *    - 느리지만 호환성 높음
     */
    /**
     * @test testHandleInvalidCodec
     * @brief 3. 사용자에게 알림
     *
     * @details
     * 3. 사용자에게 알림
     *    - "지원하지 않는 형식입니다"
     * @endcode
     */
    func testHandleInvalidCodec() {
        /**
         *
         * @section ____________________________________ ⚠️ 주의: 이 테스트는 지원하지 않는 코덱의 비디오 파일이 필요합니다
         * 통합 테스트: 디코더가 codecNotFound 에러를 던져야 합니다
         */
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Memory Management Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * deinit 시 정리 테스트
     */
    /**
     * VideoDecoder가 메모리에서 해제될 때
     * FFmpeg 리소스를 적절히 정리하는지 검증합니다.
     */
    /**
     *
     * @section ffmpeg____ 💾 FFmpeg 리소스
     * @endcode
     * VideoDecoder가 할당하는 네이티브 메모리:
     */
    /**
     * 1. AVFormatContext
     *    - 파일 컨테이너 정보
     */
    /**
     * 2. AVCodecContext
     *    - 코덱 상태 정보
     */
    /**
     * 3. AVFrame
     *    - 디코딩된 프레임 버퍼
     */
    /**
     * 4. AVPacket
     *    - 압축된 데이터 버퍼
     */
    /**
     * 5. SwsContext
     *    - 이미지 변환 컨텍스트
     * @endcode
     */
    /**
     *
     * @section ______________ 🎯 리소스 정리가 중요한 이유
     * @endcode
     * FFmpeg은 C 라이브러리:
     * - Swift ARC가 관리하지 않음
     * - 수동으로 해제해야 함
     * - 누수 시 메모리 계속 증가
     */
    /**
     * 예시:
     * 10MB 비디오를 100번 열고 닫으면
     * → 제대로 정리 안하면 1GB 메모리 누수!
     * @endcode
     */
    /**
     *
     * @section ____________ 🔍 메모리 누수 확인 방법
     * @endcode
     * 1. Xcode Instruments
     *    - Leaks 도구 사용
     *    - Allocations 패턴 분석
     */
    /**
     * 2. 자동화 테스트
     *    - measure { } 블록에서 메모리 측정
     *    - 반복 실행 후 증가 여부 확인
     */
    /**
     * 3. 수동 테스트
     *    - 많은 파일 열고 닫기
     *    - 메모리 사용량 모니터링
     * @endcode
     */
    /**
     *
     * @section _____ 💡 정리 순서
     * @endcode
     * deinit {
     *     // 1. SwsContext 해제
     *     if swsContext != nil {
     *         sws_freeContext(swsContext)
     *     }
     */
    /**
     *     // 2. AVFrame 해제
     *     if frame != nil {
     *         av_frame_free(&frame)
     *     }
     */
    /**
     *     // 3. AVCodecContext 해제
     *     if codecContext != nil {
     *         avcodec_free_context(&codecContext)
     *     }
     */
    /**
     * @test testCleanupOnDeinit
     * @brief // 4. AVFormatContext 해제
     *
     * @details
     *     // 4. AVFormatContext 해제
     *     if formatContext != nil {
     *         avformat_close_input(&formatContext)
     *     }
     * }
     * @endcode
     */
    func testCleanupOnDeinit() {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 디코더 생성
         */
        decoder = VideoDecoder(filePath: testVideoPath)

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> nil 할당으로 메모리 해제
         */
        /**
         * Swift ARC가 자동으로 deinit을 호출합니다.
         */
        /**
         *
         * @section ______ 💡 참조 카운트
         * @endcode
         * decoder = VideoDecoder(...)  // RefCount = 1
         * decoder = nil                // RefCount = 0 → deinit 호출
         * @endcode
         */
        decoder = nil

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 디코더가 리소스를 적절히 정리해야 함
         */
        /**
         *
         * @section __ ⚠️ 주의
         * 이 테스트는 자동으로 검증되지 않습니다.
         * Xcode Instruments를 사용하여 메모리 누수를 확인해야 합니다.
         */
        /**
         *
         * @section _____ 📝 검증 방법
         * 1. Product → Profile (Cmd+I)
         * 2. Leaks 도구 선택
         * 3. 이 테스트 실행
         * 4. 누수 없는지 확인
         */
    }

    /**
     * 여러 디코더 동시 사용 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 통합 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given: 여러 디코더 생성
     * let decoder1 = VideoDecoder(filePath: path1)
     * let decoder2 = VideoDecoder(filePath: path2)
     * let decoder3 = VideoDecoder(filePath: path3)
     */
    /**
     * // When: 모두 초기화
     * try decoder1.initialize()
     * try decoder2.initialize()
     * try decoder3.initialize()
     */
    /**
     * // Then: 독립적으로 작동
     * let frame1 = try decoder1.decodeNextFrame()
     * let frame2 = try decoder2.decodeNextFrame()
     * let frame3 = try decoder3.decodeNextFrame()
     */
    /**
     * XCTAssertNotEqual(frame1.timestamp, frame2.timestamp)
     * @endcode
     */
    /**
     *
     * @section __________ 🎯 동시 사용 시나리오
     * @endcode
     * 블랙박스 플레이어에서:
     * - 전방 카메라 디코더
     * - 후방 카메라 디코더
     * - 측면 카메라 디코더
     * → 3개 디코더 동시 실행
     * @endcode
     */
    /**
     *
     * @section ______ 💡 독립성 보장
     * @endcode
     * 각 디코더는 독립적인 상태 유지:
     * - 별도의 파일 핸들
     * - 별도의 디코더 컨텍스트
     * - 별도의 프레임 버퍼
     */
    /**
     * 상호 간섭 없어야 함:
     * - decoder1의 seek이 decoder2에 영향 없음
     * - decoder2의 프레임이 decoder3과 섞이지 않음
     * @endcode
     */
    /**
     *
     * @section ________ ⚠️ 리소스 고려사항
     * @endcode
     * 여러 디코더 동시 사용 시:
     * - 메모리 사용량 증가 (각각 10-50MB)
     * - CPU 부하 증가 (디코딩은 CPU 집약적)
     * - 배터리 소모 증가
     */
    /**
     * @test testMultipleDecodersSimultaneously
     * @brief 해결책:
     *
     * @details
     * 해결책:
     * - 하드웨어 가속 사용
     * - 필요 시만 디코딩
     * - 백그라운드 스레드 활용
     * @endcode
     */
    func testMultipleDecodersSimultaneously() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 통합 테스트: 여러 디코더가 독립적으로 작동해야 합니다
         */
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Performance Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 디코딩 성능 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 성능 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When/Then: 100 프레임 디코딩 시간 측정
     * measure {
     *     for _ in 0..<100 {
     *         _ = try? decoder.decodeNextFrame()
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section _____ 📊 성능 기준
     * @endcode
     * 실시간 재생을 위한 목표:
     * - 30 fps 비디오: 프레임당 33ms 이하
     * - 60 fps 비디오: 프레임당 16ms 이하
     */
    /**
     * 예시:
     * 1920x1080 H.264 비디오
     * - 소프트웨어 디코딩: 10-20ms/프레임
     * - 하드웨어 가속: 2-5ms/프레임
     * @endcode
     */
    /**
     * 🚀 성능 최적화 방법:
     * @endcode
     * 1. 하드웨어 가속 활용
     *    - VideoToolbox (iOS/macOS)
     *    - MediaCodec (Android)
     *    - 10배 이상 빠름
     */
    /**
     * 2. 멀티스레딩
     *    - FFmpeg 스레드 설정
     *    - 코어 수만큼 병렬 디코딩
     */
    /**
     * 3. 프레임 건너뛰기
     *    - 빨리감기 시 I-Frame만 디코딩
     *    - 10배 빠른 탐색
     */
    /**
     * 4. 버퍼링
     *    - 미리 여러 프레임 디코딩
     *    - 부드러운 재생
     * @endcode
     */
    /**
     * @test testDecodingPerformance
     * @brief 💡 measure { } 블록:
     *
     * @details
     *
     * @section measure_______ 💡 measure { } 블록
     * XCTest가 10번 실행하여 평균 시간을 측정합니다.
     */
    func testDecodingPerformance() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 성능 테스트: 프레임 디코딩 시간을 측정합니다
         */
        measure {
            /**
             * 100개 프레임을 디코딩하고 성능 측정
             */
            ///
            /**
             *
             * @section _____ 💡 실제 구현
             * @endcode
             * let decoder = VideoDecoder(filePath: validPath)
             * try decoder.initialize()
             * for _ in 0..<100 {
             *     _ = try decoder.decodeNextFrame()
             * }
             * @endcode
             */
        }
    }

    /**
     * 시간 탐색 성능 테스트
     */
    /**
     *
     * @section _______ ⚠️ 미구현 테스트
     * 실제 비디오 파일이 필요한 성능 테스트입니다.
     */
    /**
     *
     * @section ___________ 📝 구현 시 검증할 내용
     * @endcode
     * // Given
     * let decoder = VideoDecoder(filePath: validPath)
     * try decoder.initialize()
     */
    /**
     * // When/Then: 여러 번 seek 시간 측정
     * measure {
     *     for i in 0..<10 {
     *         try? decoder.seek(to: Double(i * 5))
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section _____ 📊 성능 기준
     * @endcode
     * 사용자 경험을 위한 목표:
     * - 일반 seek: 100-200ms 이하
     * - 빠른 seek: 50ms 이하
     */
    /**
     * 영향 요소:
     * - 비디오 길이 (긴 비디오는 느림)
     * - 키프레임 간격 (GOP size)
     * - 저장 매체 속도 (SSD vs HDD)
     * @endcode
     */
    /**
     *
     * @section seeking_______ 🎯 Seeking이 느린 이유
     * @endcode
     * 1. 키프레임 찾기
     *    - 파일을 순차적으로 스캔
     *    - 긴 비디오는 시간 소요
     */
    /**
     * 2. 파일 I/O
     *    - 디스크에서 데이터 읽기
     *    - SD 카드는 특히 느림
     */
    /**
     * 3. 버퍼 초기화
     *    - 디코더 상태 리셋
     *    - 새 위치에서 다시 시작
     */
    /**
     * 4. 정확한 탐색
     *    - 키프레임에서 목표까지 디코딩
     *    - 정확도 vs 속도 트레이드오프
     * @endcode
     */
    /**
     * 🚀 Seeking 최적화:
     * @endcode
     * 1. 키프레임 인덱스
     *    - 미리 키프레임 위치 저장
     *    - 빠른 탐색 가능
     */
    /**
     * 2. 대략적 탐색
     *    - 가장 가까운 키프레임으로만 이동
     *    - 정확도 포기하고 속도 확보
     */
    /**
     * 3. 프리로드
     *    - 여러 키프레임 미리 로드
     *    - 메모리는 더 사용하지만 빠름
     */
    /**
     * @test testSeekingPerformance
     * @brief 4. 하드웨어 가속
     *
     * @details
     * 4. 하드웨어 가속
     *    - GPU로 빠른 디코딩
     * @endcode
     */
    func testSeekingPerformance() {
        /**
         *
         * @section ___________________________ ⚠️ 주의: 이 테스트는 실제 비디오 파일이 필요합니다
         * 성능 테스트: 시간 탐색 시간을 측정합니다
         */
        measure {
            /**
             * 여러 번 seek을 수행하고 성능 측정
             */
            ///
            /**
             *
             * @section _____ 💡 실제 구현
             * @endcode
             * let decoder = VideoDecoder(filePath: validPath)
             * try decoder.initialize()
             * for i in 0..<10 {
             *     try decoder.seek(to: Double(i * 5))
             * }
             * @endcode
             */
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// MARK: - Integration Tests
// ═══════════════════════════════════════════════════════════════════════════

/// 비디오 디코더 통합 테스트 클래스
///
/// 실제 비디오 파일을 사용하여 디코더의 전체 기능을 검증합니다.
///
/// 🎯 Unit Tests vs Integration Tests:
/// ```
/// Unit Tests (VideoDecoderTests):
/// - Mock 데이터 사용
/// - 빠른 실행 (초 단위)
/// - 에러 경로 검증
/// - 실제 파일 불필요
/// - CI/CD에서 항상 실행
///
/// Integration Tests (이 클래스):
/// - 실제 비디오 파일 사용
/// - 느린 실행 (분 단위)
/// - 정상 경로 검증
/// - 테스트 파일 필요
/// - 수동으로 실행
/// ```
///
/// ⚠️ 테스트 리소스 요구사항:
/// 이 테스트는 test_video.mp4 파일이 테스트 번들에 있어야 합니다.
/// 파일이 없으면 XCTSkip으로 건너뜁니다.
///
/// 📦 테스트 번들에 파일 추가하기:
/// ```
/// 1. Xcode에서 테스트 타겟 선택
/// 2. Build Phases → Copy Bundle Resources
/// 3. test_video.mp4 추가
/// ```
///
/// 💡 테스트 파일 조건:
/// - 포맷: MP4 (H.264 코덱)
/// - 길이: 10-60초 권장
/// - 해상도: 1920x1080 또는 1280x720
/// - 프레임레이트: 30 fps
/// - 오디오: 선택 사항
final class VideoDecoderIntegrationTests: XCTestCase {

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Properties
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 비디오 디코더 인스턴스
     */
    var decoder: VideoDecoder!

    /**
     * 테스트 비디오 파일 경로
     */
    /**
     * setUp에서 테스트 번들에서 실제 파일 경로를 찾습니다.
     */
    var testVideoPath: String!

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Setup & Teardown
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 각 테스트 실행 전 초기화
     */
    /**
     * 테스트 번들에서 실제 비디오 파일을 찾아 경로를 설정합니다.
     */
    /**
     * 📦 Bundle이란?
     * @endcode
     * 앱이나 테스트에 포함된 리소스(이미지, 비디오 등)를 담는 컨테이너
     */
    /**
     * 번들 구조:
     * TestBundle.xctest/
     * ├── Info.plist
     * ├── TestExecutable
     * └── Resources/
     *     └── test_video.mp4  ← 여기에 있어야 함
     * @endcode
     */
    /**
     *
     * @section bundle_for__type_of__self__ 💡 Bundle(for: type(of: self))
     * 현재 테스트 클래스가 속한 번들을 가져옵니다.
     */
    /**
     *
     * @section path_forresource_oftype__ 🔍 path(forResource:ofType:)
     * @endcode
     * bundle.path(forResource: "test_video", ofType: "mp4")
     * // 반환: Optional<String>
     * // 성공: "/path/to/bundle/test_video.mp4"
     * // 실패: nil (파일이 없으면)
     * @endcode
     */
    /**
     *
     * @section xctskip ⚠️ XCTSkip
     * @endcode
     * throw XCTSkip("message")
     * // 테스트를 건너뛰고 실패로 표시하지 않음
     * // CI/CD에서 파일이 없을 때 유용
     * @endcode
     */
    override func setUpWithError() throws {
        /**
         * 부모 클래스의 setUp 호출
         */
        super.setUp()

        /**
         * 테스트 비디오 파일 경로 설정
         */
        /**
         *
         * @section _____ 💡 동작 과정
         * 1. 현재 테스트 클래스의 번들 가져오기
         * 2. 번들에서 "test_video.mp4" 파일 찾기
         * 3. 파일이 없으면 XCTSkip 던지기
         *
         * 테스트 번들 가져오기
         */
        /**
         * Bundle(for:)는 클래스가 속한 번들을 반환합니다.
         */
        let bundle = Bundle(for: type(of: self))

        /**
         * 비디오 파일 경로 찾기
         */
        /**
         * guard let: Optional을 안전하게 언래핑
         * 실패하면 else 블록 실행
         */
        guard let videoPath = bundle.path(forResource: "test_video", ofType: "mp4") else {
            /**
             * 파일을 찾을 수 없으면 테스트 건너뛰기
             */
            ///
            /**
             * XCTSkip: 테스트를 실패로 표시하지 않고 건너뜀
             */
            ///
            /**
             *
             * @section _____ 💡 사용 이유
             * - 테스트 리소스가 없을 때 유용
             * - CI/CD에서 선택적으로 실행 가능
             * - 개발자에게 명확한 메시지 제공
             */
            throw XCTSkip("Test video file not found. Add test_video.mp4 to test bundle.")
        }

        /**
         * 경로 저장 및 디코더 생성
         */
        testVideoPath = videoPath
        decoder = VideoDecoder(filePath: testVideoPath)
    }

    /**
     * 각 테스트 실행 후 정리
     */
    /**
     * 디코더와 경로를 nil로 설정하여 메모리를 해제합니다.
     */
    override func tearDownWithError() throws {
        /**
         * decoder 해제
         */
        decoder = nil

        /**
         * 경로 해제
         */
        testVideoPath = nil

        /**
         * 부모 클래스의 tearDown 호출
         */
        super.tearDown()
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Integration Tests
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * 유효한 파일로 초기화 테스트
     */
    /**
     * 실제 비디오 파일을 사용하여 디코더를 초기화하고
     * 비디오 정보를 올바르게 읽는지 검증합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * 1. 초기화 성공
     * 2. isInitialized 플래그 true
     * 3. videoInfo 존재
     * 4. 해상도 정보 유효 (width, height > 0)
     * 5. 프레임레이트 정보 유효 (frameRate > 0)
     */
    /**
     * @test testInitializeWithValidFile
     * @brief 📊 일반적인 비디오 정보:
     *
     * @details
     *
     * @section ___________ 📊 일반적인 비디오 정보
     * @endcode
     * width: 1920 (Full HD)
     * height: 1080
     * frameRate: 30.0 (fps)
     * codec: "h264"
     * bitrate: 5000000 (5 Mbps)
     * @endcode
     */
    func testInitializeWithValidFile() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 디코더 초기화
         */
        /**
         * initialize()는 파일을 열고 메타데이터를 읽습니다.
         */
        try decoder.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 초기화 상태 검증
         *
         * 1. 초기화 플래그 확인
         */
        XCTAssertTrue(decoder.isInitialized, "Decoder should be initialized")

        /**
         * 2. 비디오 정보 존재 확인
         */
        XCTAssertNotNil(decoder.videoInfo, "Video info should be available")

        /**
         * 3. 비디오 정보 상세 검증
         */
        /**
         * XCTUnwrap: Optional을 안전하게 언래핑
         * nil이면 테스트 실패
         */
        let videoInfo = try XCTUnwrap(decoder.videoInfo)

        /**
         * 4. 해상도 검증
         */
        /**
         * width와 height는 양수여야 합니다.
         * 0이면 잘못된 비디오 파일입니다.
         */
        XCTAssertGreaterThan(videoInfo.width, 0, "Video width should be positive")
        XCTAssertGreaterThan(videoInfo.height, 0, "Video height should be positive")

        /**
         * 5. 프레임레이트 검증
         */
        /**
         * frameRate는 양수여야 합니다.
         * 일반적으로 24, 30, 60 fps입니다.
         */
        XCTAssertGreaterThan(videoInfo.frameRate, 0, "Frame rate should be positive")
    }

    /**
     * 여러 프레임 디코딩 테스트
     */
    /**
     * 실제 비디오 파일에서 여러 프레임을 디코딩하여
     * 디코더가 정상적으로 작동하는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 디코더 초기화
     * 2. 100개 프레임 디코딩
     * 3. 비디오/오디오 프레임 수 집계
     * 4. 최소 1개 이상의 비디오 프레임 확인
     */
    /**
     *
     * @section while_let___ 💡 while let 패턴
     * @endcode
     * while let frames = try decoder.decodeNextFrame() {
     *     // frames가 nil이 아닌 동안 반복
     *     // EOF에 도달하면 nil 반환 → 루프 종료
     * }
     * @endcode
     */
    /**
     * @test testDecodeMultipleFrames
     * @brief 📊 예상 결과:
     *
     * @details
     *
     * @section _____ 📊 예상 결과
     * @endcode
     * 30 fps 비디오, 100 프레임:
     * - videoFrameCount: 100
     * - audioFrameCount: 약 100 (오디오 샘플링에 따라 다름)
     * - 총 재생 시간: 3.33초
     * @endcode
     */
    func testDecodeMultipleFrames() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 디코더 초기화
         */
        try decoder.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 여러 프레임 디코딩
         */
        /**
         * 프레임 카운터 초기화
         */
        var frameCount = 0          // 전체 프레임 수
        var videoFrameCount = 0     // 비디오 프레임 수
        var audioFrameCount = 0     // 오디오 프레임 수

        /**
         * 프레임 디코딩 루프
         */
        /**
         * while let: Optional 언래핑과 조건 검사를 동시에
         * decodeNextFrame()이 nil을 반환하면 루프 종료
         */
        while let frames = try decoder.decodeNextFrame() {
            /**
             * 비디오 프레임 확인
             */
            ///
            /**
             * frames.video가 nil이 아니면 비디오 프레임이 있음
             */
            if frames.video != nil {
                videoFrameCount += 1
            }

            /**
             * 오디오 프레임 확인
             */
            ///
            /**
             * frames.audio가 nil이 아니면 오디오 프레임이 있음
             * 모든 비디오에 오디오가 있는 것은 아닙니다.
             */
            if frames.audio != nil {
                audioFrameCount += 1
            }

            /**
             * 전체 프레임 수 증가
             */
            frameCount += 1

            /**
             * 테스트를 위해 100개만 디코딩
             */
            ///
            /**
             *
             * @section _________ 💡 제한을 두는 이유
             * - 긴 비디오는 시간이 오래 걸림
             * - 테스트는 빠르게 실행되어야 함
             * - 100개 프레임이면 기능 검증에 충분
             */
            if frameCount >= 100 {
                break
            }
        }

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 결과 검증
         */
        /**
         * 최소 1개 이상의 비디오 프레임이 디코딩되어야 합니다.
         */
        XCTAssertGreaterThan(videoFrameCount, 0, "Should decode at least one video frame")

        /**
         * 디버깅 정보 출력
         */
        /**
         * print: 콘솔에 출력
         * 테스트 로그에서 확인 가능합니다.
         */
        /**
         *
         * @section ______ 💡 유용한 정보
         * - 비디오 프레임 수
         * - 오디오 프레임 수
         * - 오디오 유무 확인
         */
        print("Decoded \(videoFrameCount) video frames and \(audioFrameCount) audio frames")
    }

    /**
     * 시간 탐색 후 디코딩 테스트
     */
    /**
     * 특정 시간으로 seek한 후 프레임을 디코딩하여
     * seek 기능이 정상적으로 작동하는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 디코더 초기화
     * 2. 5초 지점으로 이동
     * 3. 프레임 디코딩
     * 4. 타임스탬프가 5초 이상인지 확인
     */
    /**
     *
     * @section seeking____ 💡 Seeking 정확도
     * @endcode
     * 요청: 5.0초
     * 실제: 4.8초 ~ 5.2초
     */
    /**
     * @test testSeekAndDecode
     * @brief 이유:
     *
     * @details
     * 이유:
     * - 키프레임(I-Frame)으로만 이동 가능
     * - 가장 가까운 키프레임으로 이동
     * - 정확한 위치까지 디코딩 필요
     * @endcode
     */
    func testSeekAndDecode() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 디코더 초기화
         */
        try decoder.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 5초 지점으로 이동
         */
        /**
         * seek(to:): 지정된 시간(초)으로 이동
         */
        try decoder.seek(to: 5.0)

        /**
         * 프레임 디코딩
         */
        /**
         * seek 후 다음 프레임을 디코딩합니다.
         */
        let frames = try decoder.decodeNextFrame()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 결과 검증
         *
         * 1. 프레임이 디코딩되었는지 확인
         */
        /**
         * seek 후에도 정상적으로 디코딩되어야 합니다.
         */
        XCTAssertNotNil(frames, "Should be able to decode after seeking")

        /**
         * 2. 타임스탬프 확인
         */
        /**
         * if let: Optional 언래핑
         * videoFrame이 nil이 아니면 블록 실행
         */
        if let videoFrame = frames?.video {
            /**
             * 타임스탬프가 seek 지점 이상인지 확인
             */
            ///
            /**
             * XCTAssertGreaterThanOrEqual: 첫 번째 값 >= 두 번째 값
             */
            ///
            /**
             *
             * @section _________ 💡 왜 "이상"인가?
             * - 키프레임으로만 이동하므로 정확히 5.0초가 아닐 수 있음
             * - 4.8초 키프레임에서 5.0초까지 디코딩했을 수 있음
             * - 5.2초 키프레임으로 이동했을 수 있음
             */
            XCTAssertGreaterThanOrEqual(videoFrame.timestamp, 5.0, "Frame timestamp should be at or after seek point")
        }
    }

    /**
     * 재생 시간 조회 테스트
     */
    /**
     * 실제 비디오 파일의 재생 시간을 조회하여
     * duration 기능이 정상적으로 작동하는지 검증합니다.
     */
    /**
     *
     * @section ________ 🎯 테스트 시나리오
     * 1. 디코더 초기화
     * 2. 재생 시간 조회
     * 3. 양수인지 확인
     * 4. 콘솔에 출력
     */
    /**
     *
     * @section __________ 📊 일반적인 재생 시간
     * @endcode
     * 블랙박스 비디오:
     * - 1분 클립: 60.0초
     * - 5분 클립: 300.0초
     */
    /**
     * @test testGetDuration
     * @brief 테스트 비디오:
     *
     * @details
     * 테스트 비디오:
     * - 짧은 클립: 10-30초 권장
     * - 테스트가 빠르게 실행됨
     * @endcode
     */
    func testGetDuration() throws {
        /**
         *
         * @par Given-When-Then:
         * - <b>Given:</b> 디코더 초기화
         */
        try decoder.initialize()

        /**
         *
         * @par Given-When-Then:
         * - <b>When:</b> 재생 시간 조회
         */
        /**
         * getDuration(): 비디오의 전체 재생 시간 반환 (초)
         * 반환 타입: Double?
         */
        let duration = decoder.getDuration()

        /**
         *
         * @par Given-When-Then:
         * - <b>Then:</b> 결과 검증
         *
         * 1. 재생 시간이 존재하는지 확인
         */
        /**
         * XCTUnwrap: Optional을 안전하게 언래핑
         * nil이면 테스트 실패
         */
        let unwrappedDuration = try XCTUnwrap(duration)

        /**
         * 2. 양수인지 확인
         */
        /**
         * 재생 시간은 0보다 커야 합니다.
         * 0이면 빈 파일이거나 잘못된 파일입니다.
         */
        XCTAssertGreaterThan(unwrappedDuration, 0, "Duration should be positive")

        /**
         * 3. 재생 시간 출력
         */
        /**
         * print: 디버깅 정보 출력
         * 테스트 로그에서 확인할 수 있습니다.
         */
        /**
         * 💡 유용한 정보
         * - 테스트 비디오의 길이 파악
         * - 다른 테스트에서 참고 가능
         */
        print("Video duration: \(unwrappedDuration) seconds")
    }
}
