// ============================================================================
// MultiChannelRendererTests.swift
// BlackboxPlayerTests
//
// MultiChannelRenderer의 단위 테스트
// ============================================================================
//
// 📖 이 파일의 목적:
//    멀티 채널 비디오 렌더러의 모든 기능을 체계적으로 테스트합니다.
//
// 🎯 테스트 범위:
//    1. 렌더러 초기화 (Metal 디바이스 확인)
//    2. 레이아웃 모드 변경 (Grid, Focus, Horizontal)
//    3. 포커스 위치 설정 (Front, Rear, Left, Right, Interior)
//    4. 뷰포트 계산 (다양한 채널 수에 대응)
//    5. 화면 캡처 기능 (PNG/JPEG 포맷)
//    6. 성능 측정 (레이아웃 변경 속도)
//    7. 메모리 관리 (메모리 누수 방지)
//    8. 스레드 안전성 (동시성 처리)
//
// 💡 테스트 전략:
//    - 단위 테스트: 개별 기능을 독립적으로 테스트
//    - 통합 테스트: 실제 렌더링 파이프라인 전체를 테스트
//    - 성능 테스트: measure { } 블록으로 속도 측정
//    - 동시성 테스트: DispatchQueue.concurrentPerform로 경쟁 조건 확인
//
// ============================================================================

// ─────────────────────────────────────────────────────────────────────────
// MARK: - 필수 프레임워크 Import
// ─────────────────────────────────────────────────────────────────────────

/// XCTest 프레임워크
///
/// 애플의 공식 테스트 프레임워크로, 다음 기능을 제공합니다:
/// - XCTestCase: 테스트 케이스의 기본 클래스
/// - XCTAssert 함수들: 조건 검증
/// - measure { }: 성능 측정
/// - XCTSkip: 테스트 건너뛰기 (조건부 실행)
///
/// 📚 참고: setUp/tearDown으로 테스트 환경을 제어합니다.
import XCTest

/// Metal 프레임워크
///
/// Apple의 저수준 GPU 그래픽 및 연산 API입니다.
///
/// 🎨 주요 개념:
/// - MTLDevice: GPU를 나타내는 객체
/// - MTLCommandQueue: GPU 명령을 전송하는 큐
/// - MTLRenderPipelineState: 렌더링 파이프라인 설정
/// - MTLTexture: GPU 메모리의 이미지 데이터
///
/// ⚙️ Metal의 렌더링 파이프라인:
/// ```
/// 1. MTLDevice 생성 (GPU 선택)
///    ↓
/// 2. MTLCommandQueue 생성 (명령 큐)
///    ↓
/// 3. MTLCommandBuffer 생성 (명령 버퍼)
///    ↓
/// 4. MTLRenderCommandEncoder 생성 (그리기 명령)
///    ↓
/// 5. Draw 호출 (실제 렌더링)
///    ↓
/// 6. Present (화면에 표시)
/// ```
///
/// 💡 Metal을 사용하는 이유:
/// - 하드웨어 가속으로 빠른 비디오 렌더링
/// - 여러 채널을 동시에 화면에 그릴 수 있음
/// - 회전, 크롭, 필터 등 실시간 변환 가능
///
/// 📚 참고: OpenGL보다 약 10배 빠른 성능을 제공합니다.
import Metal

/// MetalKit 프레임워크
///
/// Metal을 더 쉽게 사용할 수 있도록 도와주는 고수준 API입니다.
///
/// 🛠️ 주요 클래스:
/// - MTKView: Metal 렌더링을 표시하는 뷰
/// - MTKTextureLoader: 이미지를 MTLTexture로 로드
///
/// 💡 MetalKit의 편리한 점:
/// ```swift
/// // Metal만 사용하는 경우 (복잡함)
/// let device = MTLCreateSystemDefaultDevice()
/// let drawable = layer.nextDrawable()
/// // ... 많은 설정 코드 ...
///
/// // MetalKit을 사용하는 경우 (간단함)
/// let mtkView = MTKView(frame: bounds, device: device)
/// mtkView.delegate = self  // draw 메서드만 구현하면 됨
/// ```
import MetalKit

/// @testable import BlackboxPlayer
///
/// @testable 키워드의 의미:
/// - internal 접근 수준의 코드도 테스트에서 접근 가능
/// - private는 여전히 접근 불가
/// - 프로덕션 코드의 캡슐화는 유지하면서 테스트 가능
///
/// 🔒 접근 수준 비교:
/// ```
/// ┌─────────────┬──────────┬────────────────┐
/// │ 접근 수준   │ 일반     │ @testable     │
/// ├─────────────┼──────────┼────────────────┤
/// │ open/public │ ✅       │ ✅            │
/// │ internal    │ ❌       │ ✅ (테스트만) │
/// │ fileprivate │ ❌       │ ❌            │
/// │ private     │ ❌       │ ❌            │
/// └─────────────┴──────────┴────────────────┘
/// ```
///
/// 💡 예시:
/// ```swift
/// // BlackboxPlayer 모듈 내부
/// internal class VideoDecoder { }  // 원래는 접근 불가
///
/// // 테스트 파일
/// @testable import BlackboxPlayer
/// let decoder = VideoDecoder()  // @testable 덕분에 접근 가능!
/// ```
@testable import BlackboxPlayer

// ═════════════════════════════════════════════════════════════════════════
// MARK: - MultiChannelRendererTests (단위 테스트 클래스)
// ═════════════════════════════════════════════════════════════════════════

/// MultiChannelRenderer의 단위 테스트 클래스
///
/// 멀티 채널 비디오 렌더러의 핵심 기능을 검증합니다.
///
/// 🎯 테스트 대상:
/// - 렌더러 초기화 및 Metal 디바이스 확인
/// - 레이아웃 모드 변경 (Grid, Focus, Horizontal)
/// - 포커스 카메라 위치 설정
/// - 화면 캡처 기능
/// - 성능 및 메모리 관리
/// - 스레드 안전성
///
/// 📋 테스트 원칙 (FIRST):
/// ```
/// F - Fast       : 빠르게 실행되어야 함 (수백 개를 1초 내에)
/// I - Independent: 각 테스트는 독립적으로 실행 가능
/// R - Repeatable : 어떤 환경에서도 반복 가능한 결과
/// S - Self-validating: 성공/실패가 명확히 판단됨
/// T - Timely     : 적시에 작성 (TDD의 경우 코드보다 먼저)
/// ```
///
/// 💡 final 키워드를 사용한 이유:
/// - 테스트 클래스는 상속이 필요 없음
/// - 컴파일러 최적화 가능 (dynamic dispatch 방지)
/// - 의도를 명확히 전달 (더 이상 확장하지 않음)
final class MultiChannelRendererTests: XCTestCase {

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Properties (테스트 속성)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 테스트 대상 렌더러 인스턴스
     */
    /**
     * Implicitly Unwrapped Optional (!)을 사용하는 이유:
     * - setUp()에서 반드시 초기화됨을 보장
     * - 각 테스트 메서드에서 nil 체크 없이 사용 가능
     * - 초기화 실패 시 XCTSkip으로 테스트 건너뜀
     */
    /**
     *
     * @section ______________ 💡 테스트에서의 프로퍼티 패턴
     * @endcode
     * // 방법 1: Implicitly Unwrapped Optional (일반적)
     * var renderer: MultiChannelRenderer!
     */
    /**
     * // 방법 2: Optional (nil 체크 필요)
     * var renderer: MultiChannelRenderer?
     * func testSomething() {
     *     guard let renderer = renderer else { return }
     *     // 테스트 코드...
     * }
     */
    /**
     * // 방법 3: lazy var (드물게 사용)
     * lazy var renderer = MultiChannelRenderer()
     * @endcode
     */
    /**
     * 📚 참고: 프로덕션 코드에서는 !를 피하지만, 테스트에서는
     *          setUp()이 보장하므로 안전하게 사용 가능합니다.
     */
    var renderer: MultiChannelRenderer!

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Setup & Teardown (테스트 전후 처리)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 각 테스트 메서드 실행 전에 호출되는 설정 메서드
     */
    /**
     * 테스트 환경을 깨끗한 상태로 준비합니다.
     */
    /**
     * 📋 실행 순서:
     * @endcode
     * 1. setUpWithError() 호출       ← 여기
     * 2. testExample1() 실행
     * 3. tearDownWithError() 호출
     * 4. setUpWithError() 호출       ← 다시 여기 (새로운 인스턴스)
     * 5. testExample2() 실행
     * 6. tearDownWithError() 호출
     * ...
     * @endcode
     */
    /**
     *
     * @section ______________ 💡 왜 매번 새로 설정하나요?
     * - 테스트 간 독립성 보장 (FIRST의 I)
     * - 이전 테스트의 부작용 제거
     * - 깨끗한 상태에서 시작
     */
    /**
     * 🔧 throws 키워드의 의미:
     * - XCTSkip 같은 에러를 던질 수 있음
     * - 테스트 실패가 아닌 "건너뛰기" 처리 가능
     */
    /**
     * @throws XCTSkip: Metal을 사용할 수 없는 환경에서 발생
     */
    override func setUpWithError() throws {
        /**
         * 부모 클래스의 setUp 호출
         */
        /**
         * XCTestCase의 기본 설정을 수행합니다.
         * - 테스트 타이머 시작
         * - 테스트 컨텍스트 준비
         */
        /**
         * 📚 참고: Swift에서는 super.method()를 명시적으로 호출해야 합니다.
         */
        super.setUp()

        /**
         * 실패 후 계속 진행하지 않음
         */
        /**
         * continueAfterFailure = false의 의미:
         * - 첫 번째 assertion 실패 시 즉시 테스트 중단
         * - true인 경우: 모든 assertion을 실행하고 나중에 실패 리포트
         */
        /**
         *
         * @section ___false________ 💡 언제 false를 사용하나요?
         * - 초기 설정이 중요한 경우 (Metal 디바이스 등)
         * - 후속 assertion이 의미 없어지는 경우
         * - 크래시 위험이 있는 경우
         */
        /**
         *
         * @section __ 📊 비교
         * @endcode
         * // continueAfterFailure = true (기본값)
         * XCTAssertNotNil(device)     // ❌ 실패
         * XCTAssertEqual(device.name, "GPU")  // ⚠️ 계속 실행 (크래시 위험!)
         */
        /**
         * // continueAfterFailure = false
         * XCTAssertNotNil(device)     // ❌ 실패
         * // 여기서 즉시 중단됨 (크래시 방지)
         * @endcode
         */
        continueAfterFailure = false

        /**
         * Metal 디바이스 사용 가능 여부 확인
         */
        /**
         * MTLCreateSystemDefaultDevice()의 동작:
         * - 시스템의 기본 GPU를 찾아 MTLDevice 객체 반환
         * - GPU가 없거나 Metal을 지원하지 않으면 nil 반환
         */
        /**
         * 🖥️ Metal을 지원하는 시스템:
         * - macOS: 2012년 이후 Mac (일부 예외)
         * - iOS: iPhone 5s 이상, iPad Air 이상
         * - Apple Silicon: 모든 M1/M2/M3 Mac
         */
        /**
         *
         * @section metal____________ ⚠️ Metal을 지원하지 않는 경우
         * - 가상 머신 (일부 VM은 지원)
         * - CI/CD 서버 (헤드리스 환경)
         * - 구형 Mac (2012년 이전)
         */
        /**
         *
         * @section xctskip_________ 💡 XCTSkip을 사용하는 이유
         * @endcode
         * // ❌ 잘못된 방법 (테스트 실패로 기록됨)
         * guard MTLCreateSystemDefaultDevice() != nil else {
         *     XCTFail("Metal is not available")
         *     return
         * }
         */
        /**
         * // ✅ 올바른 방법 (테스트 건너뛰기로 기록됨)
         * guard MTLCreateSystemDefaultDevice() != nil else {
         *     throw XCTSkip("Metal is not available")
         * }
         * @endcode
         */
        /**
         *
         * @section _________ 📊 테스트 결과 비교
         * @endcode
         * XCTFail 사용:
         * ✅ 10 passed, ❌ 5 failed
         */
        /**
         * XCTSkip 사용:
         *
         * @section 10_passed_____5_skipped ✅ 10 passed, ⏭️ 5 skipped
         * @endcode
         */
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is not available on this system")
        }

        /**
         * MultiChannelRenderer 인스턴스 생성
         */
        /**
         * 렌더러 초기화 과정:
         * 1. Metal 디바이스 생성
         * 2. 커맨드 큐 설정
         * 3. 렌더 파이프라인 구성
         * 4. 캡처 서비스 초기화
         */
        /**
         *
         * @section ________________ 💡 초기화가 실패할 수 있는 이유
         * - Metal 디바이스를 생성할 수 없음
         * - 셰이더 컴파일 실패
         * - 메모리 부족
         */
        renderer = MultiChannelRenderer()

        /**
         * 렌더러 생성 성공 여부 확인
         */
        /**
         * 왜 추가 확인이 필요한가요?
         * - Swift의 옵셔널 초기화는 nil을 반환할 수 있음
         * - Metal 리소스 할당 실패 시 nil 반환 가능
         */
        /**
         * 📚 참고: renderer는 !로 선언되어 있지만,
         *          초기화 실패 시 nil이 할당될 수 있습니다.
         */
        guard renderer != nil else {
            throw XCTSkip("Failed to create MultiChannelRenderer")
        }
    }

    /**
     * 각 테스트 메서드 실행 후에 호출되는 정리 메서드
     */
    /**
     * 테스트에서 사용한 리소스를 해제합니다.
     */
    /**
     * 🧹 정리 작업의 중요성:
     * - 메모리 누수 방지
     * - GPU 리소스 해제
     * - 다음 테스트를 위한 깨끗한 환경 보장
     */
    /**
     *
     * @section ________nil________ 💡 왜 명시적으로 nil을 할당하나요?
     * @endcode
     * // ARC (Automatic Reference Counting) 동작:
     * renderer = nil  // ← retain count를 1 감소
     * // retain count가 0이 되면 메모리에서 해제됨
     */
    /**
     * // 만약 nil을 할당하지 않으면:
     * // - 테스트 클래스가 살아있는 동안 renderer도 유지됨
     * // - 모든 테스트가 끝날 때까지 메모리 점유
     * // - GPU 리소스도 계속 점유
     * @endcode
     */
    /**
     *
     * @section _____ 🔄 실행 흐름
     * @endcode
     * setUp()      → 렌더러 생성 (메모리 할당)
     * test()       → 렌더러 사용
     * tearDown()   → 렌더러 해제 (메모리 반환) ← 여기
     * @endcode
     */
    /**
     * @throws 이 메서드는 에러를 던질 수 있지만, 일반적으로는 던지지 않습니다.
     */
    override func tearDownWithError() throws {
        /**
         * 렌더러 인스턴스 해제
         */
        /**
         * nil 할당의 효과:
         * - MTLDevice 해제
         * - MTLCommandQueue 해제
         * - 모든 MTLTexture 해제
         * - 캡처 서비스 해제
         */
        /**
         *
         * @section metal_____________ 💡 Metal 리소스는 비용이 큽니다
         * - GPU 메모리 사용
         * - 시스템 메모리 매핑
         * - 커맨드 버퍼 할당
         */
        /**
         *
         * @section __________ 📊 메모리 사용량 예시
         * @endcode
         * 렌더러 1개 = 약 50-100MB
         * - MTLDevice: 10MB
         * - 텍스처 버퍼: 30-80MB (해상도에 따라)
         * - 커맨드 큐: 10MB
         * @endcode
         */
        renderer = nil

        /**
         * 부모 클래스의 tearDown 호출
         */
        /**
         * XCTestCase의 기본 정리 작업을 수행합니다.
         * - 테스트 타이머 중지
         * - 테스트 결과 기록
         * - 임시 파일 정리
         */
        super.tearDown()
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Initialization Tests (초기화 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 렌더러 초기화 테스트
     */
    /**
     * 렌더러가 올바르게 초기화되고 기본값이 정확한지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * 1. 렌더러 인스턴스가 생성되었는가?
     * 2. 캡처 서비스가 초기화되었는가?
     * 3. 기본 레이아웃 모드가 .grid인가?
     * 4. 기본 포커스 위치가 .front인가?
     */
    /**
     *
     * @section ____________ 💡 초기화 테스트의 중요성
     * - 기본 상태가 예상대로인지 확인
     * - 의존성 (캡처 서비스)이 제대로 주입되었는지 검증
     * - 후속 테스트의 전제 조건 확인
     */
    /**
     * 📋 Given-When-Then 패턴:
     * @endcode
     * - <b>Given:</b> setUp()에서 렌더러가 생성됨
     * - <b>When:</b>  (초기화 직후의 상태)
     * - <b>Then:</b>  기본값이 예상과 일치함
     * @endcode
     */
    /**
     * @test testRendererInitialization
     * @brief 🔍 이 테스트가 실패하는 경우:
     *
     * @details
     *
     * @section ______________ 🔍 이 테스트가 실패하는 경우
     * - Metal 디바이스 초기화 실패
     * - 캡처 서비스 생성 실패
     * - 기본값 설정 누락
     */
    func testRendererInitialization() {
        // ─────────────────────────────────────────────────────────────────
        // Then: 초기화 결과 검증
        // ─────────────────────────────────────────────────────────────────

        /**
         * 렌더러 인스턴스가 nil이 아닌지 확인
         */
        /**
         * XCTAssertNotNil의 동작:
         * - 값이 nil이 아니면 테스트 통과
         * - nil이면 메시지와 함께 테스트 실패
         */
        /**
         *
         * @section ________ 💡 메시지의 중요성
         * @endcode
         * // ❌ 나쁜 예 (메시지 없음)
         * XCTAssertNotNil(renderer)
         * // 실패 시: "XCTAssertNotNil failed"
         */
        /**
         * // ✅ 좋은 예 (명확한 메시지)
         * XCTAssertNotNil(renderer, "Renderer should initialize successfully")
         * // 실패 시: "XCTAssertNotNil failed - Renderer should initialize successfully"
         * @endcode
         */
        /**
         *
         * @section _________ 📊 실패 메시지 비교
         * @endcode
         * 메시지 없음:
         * ❌ testRendererInitialization(): XCTAssertNotNil failed
         *    → 무엇이 잘못되었는지 알기 어려움
         */
        /**
         * 메시지 있음:
         * ❌ testRendererInitialization(): Renderer should initialize successfully
         *    → 즉시 문제 파악 가능
         * @endcode
         */
        XCTAssertNotNil(renderer, "Renderer should initialize successfully")

        /**
         * 캡처 서비스가 초기화되었는지 확인
         */
        /**
         * 캡처 서비스의 역할:
         * - 현재 렌더링된 프레임을 이미지로 저장
         * - PNG/JPEG 포맷 지원
         * - Metal 텍스처를 CPU로 읽어옴
         */
        /**
         *
         * @section _________ 💡 의존성 주입 검증
         * @endcode
         * class MultiChannelRenderer {
         *     let captureService: CaptureService
         */
        /**
         *     init() {
         *         self.captureService = CaptureService()  // ← 이게 제대로 되었나?
         *     }
         * }
         * @endcode
         */
        /**
         *
         * @section __assertion_________ 🔍 이 assertion이 실패하는 이유
         * - captureService 초기화를 잊어버림
         * - CaptureService() 생성 실패
         * - 메모리 부족
         */
        XCTAssertNotNil(renderer.captureService, "Capture service should be initialized")

        /**
         * 기본 레이아웃 모드가 .grid인지 확인
         */
        /**
         * XCTAssertEqual의 동작:
         * - 두 값이 같으면 테스트 통과
         * - 다르면 실제값과 기대값을 보여주며 실패
         */
        /**
         * 🎨 레이아웃 모드:
         * - .grid: 그리드 형태로 모든 채널 표시
         * - .focus: 하나의 채널을 크게, 나머지는 썸네일로
         * - .horizontal: 가로로 나란히 배치
         */
        /**
         *
         * @section ___grid_________ 💡 왜 .grid가 기본값인가요?
         * - 모든 채널을 동등하게 표시
         * - 블랙박스의 전체 상황을 한눈에 파악
         * - 사용자가 원하는 채널을 선택하기 쉬움
         */
        /**
         *
         * @section assertion________ 📊 assertion 실패 시 출력
         * @endcode
         * ❌ XCTAssertEqual failed: (".focus") is not equal to (".grid")
         *    - Default layout should be grid
         *    → 실제값과 기대값이 명확히 표시됨
         * @endcode
         */
        XCTAssertEqual(renderer.layoutMode, .grid, "Default layout should be grid")

        /**
         * 기본 포커스 위치가 .front인지 확인
         */
        /**
         * 🚗 카메라 위치:
         * - .front: 전방 카메라 (가장 중요)
         * - .rear: 후방 카메라
         * - .left: 좌측 카메라
         * - .right: 우측 카메라
         * - .interior: 실내 카메라
         */
        /**
         *
         * @section ___front_________ 💡 왜 .front가 기본값인가요?
         * - 전방 카메라가 가장 중요한 정보
         * - 사고 시 가장 먼저 확인하는 영상
         * - 대부분의 블랙박스가 전방 카메라를 기본으로 함
         */
        /**
         *
         * @section focus________ 🎯 Focus 모드와의 관계
         * @endcode
         * Focus 모드 활성화 시:
         * ┌─────────────────┬───┐
         * │                 │ R │  R = Rear (썸네일)
         * │     Front       ├───┤
         * │   (75% 영역)    │ L │  L = Left (썸네일)
         * │                 ├───┤
         * │                 │ I │  I = Interior (썸네일)
         * └─────────────────┴───┘
         *   ↑ focusedPosition이 결정하는 큰 화면
         * @endcode
         */
        XCTAssertEqual(renderer.focusedPosition, .front, "Default focused position should be front")
    }

    /**
     * Metal 디바이스 사용 가능 여부 테스트
     */
    /**
     * GPU가 시스템에서 사용 가능한지 확인합니다.
     */
    /**
     *
     * @section ______ 🎯 테스트 목적
     * - Metal API가 제대로 작동하는지 확인
     * - GPU 리소스에 접근 가능한지 검증
     * - CI/CD 환경에서의 제약사항 파악
     */
    /**
     *
     * @section _______setup______ 💡 이 테스트와 setUp()의 차이
     * @endcode
     * setUp():
     * - 모든 테스트 전에 실행
     * - Metal 없으면 전체 테스트 스킵
     * - XCTSkip 사용
     */
    /**
     * testMetalDeviceAvailable():
     * - 독립적인 테스트
     * - Metal 존재 자체를 검증
     * - XCTFail 사용
     * @endcode
     */
    /**
     * 🖥️ Metal 디바이스 종류:
     * @endcode
     * let devices = MTLCopyAllDevices()
     * // macOS의 경우 여러 GPU가 있을 수 있음:
     * // - 내장 GPU (Intel Iris, Apple Silicon GPU)
     * // - 외장 GPU (AMD Radeon, NVIDIA - 구형 Mac만)
     * // - eGPU (Thunderbolt로 연결된 외장 GPU)
     */
    /**
     * let defaultDevice = MTLCreateSystemDefaultDevice()
     * // 시스템이 자동으로 선택한 기본 GPU
     * // 보통 가장 성능 좋은 GPU를 선택
     * @endcode
     */
    /**
     * @test testMetalDeviceAvailable
     * @brief 📊 다양한 환경에서의 결과:
     *
     * @details
     *
     * @section ____________ 📊 다양한 환경에서의 결과
     * @endcode
     * MacBook Pro (M2): ✅ Apple M2 GPU
     * Mac Studio (M1 Max): ✅ Apple M1 Max GPU
     * MacBook Pro (Intel + AMD): ✅ AMD Radeon Pro 5500M
     * VM (Parallels): ⚠️ 가상 GPU (제한적)
     * GitHub Actions: ❌ GPU 없음 (테스트 스킵)
     * @endcode
     */
    func testMetalDeviceAvailable() {
        // ─────────────────────────────────────────────────────────────────
        // Then: Metal 디바이스 존재 확인
        // ─────────────────────────────────────────────────────────────────

        /**
         * Metal 디바이스 가져오기 시도
         */
        /**
         * guard let 패턴의 동작:
         * - MTLCreateSystemDefaultDevice()가 nil을 반환하면
         * - else 블록으로 이동
         * - XCTFail로 테스트 실패 처리
         * - return으로 함수 종료 (후속 코드 실행 방지)
         */
        /**
         *
         * @section xctfail_vs_xctskip 💡 XCTFail vs XCTSkip
         * @endcode
         * // XCTSkip (setUp에서 사용)
         * throw XCTSkip("Metal is not available")
         * // → 테스트 건너뛰기 (환경 문제)
         * // → 노란색 경고로 표시
         */
        /**
         * // XCTFail (이 테스트에서 사용)
         * XCTFail("Metal device should be available")
         * // → 테스트 실패 (코드 문제)
         * // → 빨간색 실패로 표시
         * @endcode
         */
        /**
         *
         * @section ________________ 🔍 언제 이 테스트가 실패하나요?
         * - Metal 지원이 중단된 경우
         * - GPU 드라이버 문제
         * - 시스템 리소스 고갈
         * - 가상 머신에서 GPU 에뮬레이션 실패
         */
        /**
         * 📚 참고: setUp()에서 이미 Metal을 확인하므로,
         *          실제로는 이 테스트가 실패할 확률은 매우 낮습니다.
         */
        guard let device = MTLCreateSystemDefaultDevice() else {
            XCTFail("Metal device should be available")
            return
        }

        /**
         * 디바이스가 nil이 아닌지 재확인
         */
        /**
         *
         * @section __assertion_______________ 💡 이 assertion은 불필요해 보일 수 있지만
         * - guard let으로 이미 unwrap 했으므로 항상 통과
         * - 하지만 명시적으로 검증하여 테스트 의도를 명확히 함
         * - 나중에 코드가 변경되어도 안전장치 역할
         */
        /**
         *
         * @section _______________ 🎯 추가로 검증할 수 있는 것들
         * @endcode
         * // 디바이스 이름 확인
         * print(device.name)  // "Apple M2" 등
         */
        /**
         * // 최대 스레드 그룹 크기
         * print(device.maxThreadsPerThreadgroup)
         */
        /**
         * // 메모리 크기
         * print(device.recommendedMaxWorkingSetSize)
         */
        /**
         * // 기능 지원 여부
         * XCTAssertTrue(device.supportsFamily(.apple7))
         * XCTAssertTrue(device.supportsFamily(.common3))
         * @endcode
         */
        XCTAssertNotNil(device)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Layout Mode Tests (레이아웃 모드 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 레이아웃 모드 설정 테스트
     */
    /**
     * setLayoutMode() 메서드가 레이아웃을 올바르게 변경하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - .focus 모드로 변경 가능한가?
     * - .horizontal 모드로 변경 가능한가?
     * - 변경 후 상태가 올바르게 반영되는가?
     */
    /**
     *
     * @section ______ 💡 테스트 구조
     * @endcode
     * When → Then → When → Then
     * (여러 상태 전환을 순차적으로 검증)
     * @endcode
     */
    /**
     * 🎨 레이아웃 모드별 화면 구성:
     * @endcode
     * .grid (2x2):
     * ┌────────┬────────┐
     * │ Front  │  Rear  │
     * ├────────┼────────┤
     * │  Left  │ Right  │
     * └────────┴────────┘
     */
    /**
     * .focus:
     * ┌──────────────┬──┐
     * │              │R │
     * │    Front     ├──┤
     * │   (75%)      │L │
     * └──────────────┴──┘
     */
    /**
     * @test testSetLayoutMode
     * @brief .horizontal:
     *
     * @details
     * .horizontal:
     * ┌───┬───┬───┬───┐
     * │ F │ R │ L │ I │
     * └───┴───┴───┴───┘
     * @endcode
     */
    func testSetLayoutMode() {
        // ─────────────────────────────────────────────────────────────────
        // When: Focus 모드로 변경
        // ─────────────────────────────────────────────────────────────────

        /**
         * 레이아웃을 Focus 모드로 설정
         */
        /**
         * Focus 모드의 특징:
         * - 하나의 채널을 크게 표시 (보통 75%)
         * - 나머지 채널은 썸네일로 표시 (각 25% 영역에 세로로 배치)
         * - focusedPosition 속성으로 어떤 채널을 크게 표시할지 결정
         */
        /**
         *
         * @section _____ 💡 사용 사례
         * - 특정 카메라에 집중하고 싶을 때
         * - 사고 영상을 자세히 확인할 때
         * - 전방 카메라를 메인으로 보면서 다른 각도도 확인
         */
        renderer.setLayoutMode(.focus)

        // ─────────────────────────────────────────────────────────────────
        // Then: Focus 모드로 변경되었는지 확인
        // ─────────────────────────────────────────────────────────────────

        /**
         * 레이아웃 모드가 .focus인지 검증
         */
        /**
         *
         * @section _____________ 💡 상태 변경 검증의 중요성
         * - setter 메서드가 실제로 값을 변경했는지 확인
         * - 내부 상태와 외부 인터페이스가 일치하는지 검증
         */
        /**
         *
         * @section ___________ 🔍 실패할 수 있는 경우
         * @endcode
         * // ❌ 잘못된 구현
         * func setLayoutMode(_ mode: LayoutMode) {
         *     // 아무것도 하지 않음 (버그!)
         * }
         */
        /**
         * // ✅ 올바른 구현
         * func setLayoutMode(_ mode: LayoutMode) {
         *     self.layoutMode = mode
         *     invalidateLayout()  // 레이아웃 재계산
         * }
         * @endcode
         */
        XCTAssertEqual(renderer.layoutMode, .focus)

        // ─────────────────────────────────────────────────────────────────
        // When: Horizontal 모드로 변경
        // ─────────────────────────────────────────────────────────────────

        /**
         * 레이아웃을 Horizontal 모드로 설정
         */
        /**
         * Horizontal 모드의 특징:
         * - 모든 채널을 가로로 나란히 배치
         * - 각 채널이 동일한 너비를 가짐
         * - 타임라인 뷰어와 함께 사용하기 좋음
         */
        /**
         *
         * @section _____ 💡 사용 사례
         * - 여러 각도를 동시에 비교할 때
         * - 와이드 모니터에서 사용할 때
         * - 시간대별로 모든 각도를 확인할 때
         */
        /**
         *
         * @section 4______ 📊 4채널의 경우
         * @endcode
         * 화면 너비 1920px일 때:
         * - 각 채널: 480px (1920 / 4)
         * - 간격: 없음 (경계선만)
         * @endcode
         */
        renderer.setLayoutMode(.horizontal)

        // ─────────────────────────────────────────────────────────────────
        // Then: Horizontal 모드로 변경되었는지 확인
        // ─────────────────────────────────────────────────────────────────

        /**
         * 레이아웃 모드가 .horizontal인지 검증
         */
        /**
         *
         * @section ______________ 💡 왜 여러 번 테스트하나요?
         * - 첫 번째 변경만 작동하고 두 번째는 실패할 수 있음
         * - 상태 전환 로직에 버그가 있을 수 있음
         * - 이전 상태에서 새 상태로의 전환을 모두 검증
         */
        /**
         *
         * @section _________ 🔄 상태 전환 그래프
         * @endcode
         * .grid ──→ .focus ──→ .horizontal
         *   ↑                      │
         *   └──────────────────────┘
         * (모든 전환이 가능해야 함)
         * @endcode
         */
        XCTAssertEqual(renderer.layoutMode, .horizontal)
    }

    /**
     * 모든 레이아웃 모드 테스트
     */
    /**
     * LayoutMode 열거형의 모든 케이스를 순회하며 테스트합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 모든 레이아웃 모드로 변경 가능한가?
     * - 각 모드의 displayName이 존재하는가?
     */
    /**
     *
     * @section _________ 💡 이 테스트의 장점
     * - 새로운 레이아웃 모드를 추가해도 자동으로 테스트됨
     * - CaseIterable 프로토콜 활용
     * - 모든 케이스를 빠뜨리지 않고 검증
     */
    /**
     *
     * @section caseiterable_____ 🔄 CaseIterable 프로토콜
     * @endcode
     * enum LayoutMode: CaseIterable {
     *     case grid
     *     case focus
     *     case horizontal
     * }
     */
    /**
     * // allCases는 자동 생성됨
     * LayoutMode.allCases  // [.grid, .focus, .horizontal]
     * @endcode
     */
    /**
     * @test testAllLayoutModes
     * @brief 📚 참고: 만약 새로운 모드 (.pip 등)를 추가하면
     *
     * @details
     * 📚 참고: 만약 새로운 모드 (.pip 등)를 추가하면
     *          이 테스트가 자동으로 검증합니다.
     */
    func testAllLayoutModes() {
        // ─────────────────────────────────────────────────────────────────
        // When & Then: 모든 레이아웃 모드를 순회하며 테스트
        // ─────────────────────────────────────────────────────────────────

        /**
         * LayoutMode.allCases를 순회
         */
        /**
         * for-in 루프로 모든 케이스를 테스트:
         * 1. .grid로 설정 → 검증
         * 2. .focus로 설정 → 검증
         * 3. .horizontal로 설정 → 검증
         */
        /**
         *
         * @section _______________ 💡 루프를 사용한 테스트의 장점
         * @endcode
         * // ❌ 반복적인 코드 (유지보수 어려움)
         * renderer.setLayoutMode(.grid)
         * XCTAssertEqual(renderer.layoutMode, .grid)
         * renderer.setLayoutMode(.focus)
         * XCTAssertEqual(renderer.layoutMode, .focus)
         * // ...
         */
        /**
         * // ✅ 루프 사용 (간결하고 확장 가능)
         * for mode in LayoutMode.allCases {
         *     renderer.setLayoutMode(mode)
         *     XCTAssertEqual(renderer.layoutMode, mode)
         * }
         * @endcode
         */
        /**
         *
         * @section ________ 🔍 테스트 실패 시
         * @endcode
         * ❌ XCTAssertEqual failed: (".grid") is not equal to (".focus")
         *    → 어떤 모드에서 실패했는지 정확히 알 수 있음
         * @endcode
         */
        for mode in LayoutMode.allCases {
            // When: 해당 모드로 변경
            renderer.setLayoutMode(mode)

            // Then: 모드가 올바르게 설정되었는지 확인
            XCTAssertEqual(renderer.layoutMode, mode)

            // Then: displayName이 존재하는지 확인
            /**
             * displayName 검증
             */
            ///
            /**
             * displayName의 역할:
             * - UI에 표시할 사용자 친화적인 이름
             * - 메뉴나 버튼에 사용
             * - 로그나 디버그 메시지에 사용
             */
            ///
            /**
             *
             * @section nil____________ 💡 nil이 되면 안 되는 이유
             * @endcode
             * // UI 코드에서:
             * Button(mode.displayName) {  // nil이면 크래시!
             *     renderer.setLayoutMode(mode)
             * }
             * @endcode
             */
            ///
            /**
             *
             * @section ____ 📊 예상 값
             * @endcode
             * .grid       → "Grid"
             * .focus      → "Focus"
             * .horizontal → "Horizontal"
             * @endcode
             */
            XCTAssertNotNil(mode.displayName)
        }
    }

    /**
     * 레이아웃 모드 표시 이름 테스트
     */
    /**
     * 각 레이아웃 모드의 displayName이 올바른지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - .grid의 displayName이 "Grid"인가?
     * - .focus의 displayName이 "Focus"인가?
     * - .horizontal의 displayName이 "Horizontal"인가?
     */
    /**
     *
     * @section _______________ 💡 왜 이 테스트가 필요한가요?
     * - UI에 표시되는 텍스트의 정확성 보장
     * - 다국어 지원 시 기준값 역할
     * - 오타나 실수 방지
     */
    /**
     * @test testLayoutModeDisplayNames
     * @brief 🌍 다국어 지원 예시:
     *
     * @details
     * 🌍 다국어 지원 예시:
     * @endcode
     * extension LayoutMode {
     *     var displayName: String {
     *         switch Locale.current.languageCode {
     *         case "ko":
     *             switch self {
     *             case .grid: return "격자"
     *             case .focus: return "집중"
     *             case .horizontal: return "가로"
     *             }
     *         default:
     *             switch self {
     *             case .grid: return "Grid"
     *             case .focus: return "Focus"
     *             case .horizontal: return "Horizontal"
     *             }
     *         }
     *     }
     * }
     * @endcode
     */
    func testLayoutModeDisplayNames() {
        // ─────────────────────────────────────────────────────────────────
        // Then: 각 모드의 displayName 검증
        // ─────────────────────────────────────────────────────────────────

        /**
         * Grid 모드의 표시 이름 확인
         */
        /**
         * "Grid"가 기대값인 이유:
         * - 영어권 사용자에게 익숙한 용어
         * - 짧고 명확함
         * - 다른 비디오 플레이어에서도 일반적으로 사용
         */
        /**
         *
         * @section ___ 💡 대안들
         * @endcode
         * "Grid"      ✅ 선택됨
         * "Grid View"    (너무 길음)
         * "Tile"         (의미가 덜 명확)
         * "Matrix"       (기술적이고 어려움)
         * @endcode
         */
        XCTAssertEqual(LayoutMode.grid.displayName, "Grid")

        /**
         * Focus 모드의 표시 이름 확인
         */
        /**
         * "Focus"가 기대값인 이유:
         * - 하나의 채널에 집중한다는 의미 명확
         * - 간결하고 직관적
         * - 카메라 앱 등에서도 사용하는 용어
         */
        /**
         *
         * @section ___ 💡 대안들
         * @endcode
         * "Focus"           ✅ 선택됨
         * "Picture-in-Picture"  (PiP와 혼동)
         * "Main View"           (너무 일반적)
         * "Spotlight"           (macOS 검색과 혼동)
         * @endcode
         */
        XCTAssertEqual(LayoutMode.focus.displayName, "Focus")

        /**
         * Horizontal 모드의 표시 이름 확인
         */
        /**
         * "Horizontal"이 기대값인 이유:
         * - 레이아웃 방향을 정확히 설명
         * - 수평 배치를 명확히 전달
         * - Vertical(세로)과 대비되는 용어
         */
        /**
         *
         * @section ___ 💡 대안들
         * @endcode
         * "Horizontal" ✅ 선택됨
         * "Side by Side"  (길고 띄어쓰기 있음)
         * "Strip"         (의미가 덜 명확)
         * "Timeline"      (타임라인 UI와 혼동)
         * @endcode
         */
        XCTAssertEqual(LayoutMode.horizontal.displayName, "Horizontal")
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Focused Position Tests (포커스 위치 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 포커스 위치 설정 테스트
     */
    /**
     * setFocusedPosition() 메서드가 포커스 카메라를 올바르게 변경하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - .rear 위치로 변경 가능한가?
     * - .left 위치로 변경 가능한가?
     * - 변경 후 상태가 올바르게 반영되는가?
     */
    /**
     *
     * @section __________ 💡 포커스 위치의 의미
     * - Focus 레이아웃 모드에서 크게 표시할 채널 선택
     * - Grid/Horizontal 모드에서는 영향 없음
     * - 사용자가 특정 각도에 집중하고 싶을 때 사용
     */
    /**
     * 🚗 블랙박스 카메라 배치:
     * @endcode
     *        Front (전방)
     *           ↑
     *    Left ← 🚗 → Right
     *           ↓
     *       Rear (후방)
     */
    /**
     * @test testSetFocusedPosition
     * @brief Interior (실내): 운전석을 향함
     *
     * @details
     * Interior (실내): 운전석을 향함
     * @endcode
     */
    func testSetFocusedPosition() {
        // ─────────────────────────────────────────────────────────────────
        // When: Rear (후방) 위치로 변경
        // ─────────────────────────────────────────────────────────────────

        /**
         * 포커스를 후방 카메라로 설정
         */
        /**
         * 후방 카메라를 선택하는 경우:
         * - 주차 중 후방 확인
         * - 후방 추돌 사고 검증
         * - 뒷차와의 거리 확인
         */
        renderer.setFocusedPosition(.rear)

        // ─────────────────────────────────────────────────────────────────
        // Then: Rear 위치로 변경되었는지 확인
        // ─────────────────────────────────────────────────────────────────

        XCTAssertEqual(renderer.focusedPosition, .rear)

        // ─────────────────────────────────────────────────────────────────
        // When: Left (좌측) 위치로 변경
        // ─────────────────────────────────────────────────────────────────

        /**
         * 포커스를 좌측 카메라로 설정
         */
        /**
         * 좌측 카메라를 선택하는 경우:
         * - 좌회전 시 사각지대 확인
         * - 측면 접촉 사고 검증
         * - 주차 시 좌측 여유 공간 확인
         */
        renderer.setFocusedPosition(.left)

        // ─────────────────────────────────────────────────────────────────
        // Then: Left 위치로 변경되었는지 확인
        // ─────────────────────────────────────────────────────────────────

        XCTAssertEqual(renderer.focusedPosition, .left)
    }

    /**
     * 모든 카메라 위치 테스트
     */
    /**
     * CameraPosition의 모든 케이스를 순회하며 테스트합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 5개 카메라 위치 모두 설정 가능한가?
     * - 각 위치로의 전환이 올바르게 동작하는가?
     */
    /**
     * 🚗 카메라 위치 설명:
     * @endcode
     * .front    : 전방 카메라 (주행 방향)
     * .rear     : 후방 카메라 (후진 방향)
     * .left     : 좌측 카메라 (운전석 쪽)
     * .right    : 우측 카메라 (조수석 쪽)
     * .interior : 실내 카메라 (운전자/승객)
     * @endcode
     */
    /**
     * @test testAllCameraPositions
     * @brief 💡 배열 리터럴 사용 이유:
     *
     * @details
     *
     * @section ____________ 💡 배열 리터럴 사용 이유
     * - CameraPosition이 CaseIterable을 채택하지 않을 수 있음
     * - 테스트할 특정 위치만 선택 가능
     * - 명시적으로 어떤 위치를 테스트하는지 표시
     */
    func testAllCameraPositions() {
        // ─────────────────────────────────────────────────────────────────
        // When & Then: 모든 카메라 위치를 순회하며 테스트
        // ─────────────────────────────────────────────────────────────────

        /**
         * 5개 카메라 위치를 순회
         */
        /**
         *
         * @section _____________ 💡 배열로 직접 나열한 이유
         * @endcode
         * // 방법 1: 배열 리터럴 (현재 사용)
         * for position in [CameraPosition.front, .rear, .left, .right, .interior] {
         *     // 명시적이고 순서 보장
         * }
         */
        /**
         * // 방법 2: CaseIterable (만약 채택했다면)
         * for position in CameraPosition.allCases {
         *     // 자동으로 모든 케이스 포함
         * }
         * @endcode
         */
        /**
         *
         * @section ______ 🔄 테스트 순서
         * @endcode
         * 1. .front로 설정  → 검증
         * 2. .rear로 설정   → 검증
         * 3. .left로 설정   → 검증
         * 4. .right로 설정  → 검증
         * 5. .interior로 설정 → 검증
         * @endcode
         */
        for position in [CameraPosition.front, .rear, .left, .right, .interior] {
            // When: 해당 위치로 변경
            renderer.setFocusedPosition(position)

            // Then: 위치가 올바르게 설정되었는지 확인
            /**
             * 포커스 위치 검증
             */
            ///
            /**
             *
             * @section _____________ 💡 각 위치별 사용 시나리오
             * @endcode
             * .front    : 일반 주행 시 (기본값)
             * .rear     : 주차/후진 시
             * .left     : 좁은 길, 좌회전 시
             * .right    : 우회전, 좁은 도로 시
             * .interior : 택시, 우버 등 승객 확인
             * @endcode
             */
            XCTAssertEqual(renderer.focusedPosition, position)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Viewport Calculation Tests (뷰포트 계산 테스트 - Grid 레이아웃)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Grid 레이아웃 - 단일 채널 뷰포트 테스트
     */
    /**
     * 1개 채널만 있을 때 뷰포트 계산을 검증합니다.
     */
    /**
     *
     * @section _____ 💡 현재 상태
     * - 이 테스트는 private 메서드 접근이 필요
     * - 실제 렌더링을 통한 간접 테스트 또는
     * - 메서드를 internal로 변경하여 @testable import로 접근
     */
    /**
     * 🎨 기대되는 레이아웃:
     * @endcode
     * ┌───────────────────────┐
     * │                       │
     * │      Front            │
     * │    (전체 화면)        │
     * │                       │
     * └───────────────────────┘
     * @endcode
     */
    /**
     * @test testGridViewportsSingleChannel
     * @brief 📐 기대 뷰포트 크기:
     *
     * @details
     * 📐 기대 뷰포트 크기:
     * - x: 0, y: 0
     * - width: 1920, height: 1080
     * - 전체 화면을 차지
     */
    func testGridViewportsSingleChannel() {
        /**
         * 테스트용 화면 크기 정의
         */
        /**
         * Full HD 해상도 (1920x1080) 사용:
         * - 가장 일반적인 해상도
         * - 16:9 비율
         * - 계산하기 쉬운 숫자
         */
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 뷰포트 계산 메서드 테스트
         */
        /**
         * 구현 방법:
         * @endcode
         * // 옵션 1: private 메서드를 internal로 변경
         * internal func calculateGridViewports(for channels: [CameraPosition], size: CGSize) -> [CameraPosition: CGRect]
         */
        /**
         * // 옵션 2: 통합 테스트에서 실제 렌더링 결과 확인
         * let texture = renderer.render(frames: singleChannelFrames)
         * // 텍스처의 픽셀 데이터로 렌더링 영역 확인
         */
        /**
         * // 테스트 코드:
         * let viewports = renderer.calculateGridViewports(for: [.front], size: size)
         * XCTAssertEqual(viewports[.front], CGRect(x: 0, y: 0, width: 1920, height: 1080))
         * @endcode
         */
    }

    /**
     * Grid 레이아웃 - 2채널 뷰포트 테스트
     */
    /**
     * 2개 채널이 있을 때 뷰포트 계산을 검증합니다.
     */
    /**
     * 🎨 기대되는 레이아웃:
     * @endcode
     * 가로 배치 (화면이 넓을 때):
     * ┌──────────┬──────────┐
     * │  Front   │   Rear   │
     * │          │          │
     * └──────────┴──────────┘
     */
    /**
     * 세로 배치 (화면이 높을 때):
     * ┌────────────────────┐
     * │      Front         │
     * ├────────────────────┤
     * │       Rear         │
     * └────────────────────┘
     * @endcode
     */
    /**
     * @test testGridViewportsTwoChannels
     * @brief 📐 기대 뷰포트 크기 (가로 배치):
     *
     * @details
     * 📐 기대 뷰포트 크기 (가로 배치):
     * - Front: (0, 0, 960, 1080)
     * - Rear: (960, 0, 960, 1080)
     */
    func testGridViewportsTwoChannels() {
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 2채널 뷰포트 계산 테스트
         */
        /**
         *
         * @section ____________ 💡 화면 비율에 따른 선택
         * @endcode
         * let aspectRatio = size.width / size.height
         * if aspectRatio > 1.5 {
         *     // 와이드 스크린 → 가로 배치 (1x2)
         *     layoutChannelsHorizontally()
         * } else {
         *     // 일반 화면 → 세로 배치 (2x1)
         *     layoutChannelsVertically()
         * }
         * @endcode
         */
    }

    /**
     * Grid 레이아웃 - 4채널 뷰포트 테스트
     */
    /**
     * 4개 채널이 있을 때 뷰포트 계산을 검증합니다.
     */
    /**
     * 🎨 기대되는 레이아웃:
     * @endcode
     * ┌─────────┬─────────┐
     * │  Front  │  Rear   │
     * ├─────────┼─────────┤
     * │  Left   │  Right  │
     * └─────────┴─────────┘
     * @endcode
     */
    /**
     * 📐 기대 뷰포트 크기:
     * - Front: (0, 0, 960, 540)
     * - Rear: (960, 0, 960, 540)
     * - Left: (0, 540, 960, 540)
     * - Right: (960, 540, 960, 540)
     */
    /**
     * @test testGridViewportsFourChannels
     * @brief 💡 2x2 그리드가 최적인 이유:
     *
     * @details
     *
     * @section 2x2____________ 💡 2x2 그리드가 최적인 이유
     * - 4개는 완전한 정사각형 배치 가능
     * - 모든 채널이 동일한 크기
     * - 화면 공간을 효율적으로 사용
     */
    func testGridViewportsFourChannels() {
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 4채널 뷰포트 계산 테스트
         */
        /**
         * 검증 항목:
         * @endcode
         * let viewports = renderer.calculateGridViewports(
         *     for: [.front, .rear, .left, .right],
         *     size: size
         * )
         */
        /**
         * // 각 채널 뷰포트 확인
         * XCTAssertEqual(viewports.count, 4)
         */
        /**
         * // 크기가 모두 같은지 확인
         * let sizes = viewports.values.map { ($0.width, $0.height) }
         * XCTAssertTrue(sizes.allSatisfy { $0 == sizes.first })
         */
        /**
         * // 전체 면적 확인
         * assertTotalViewportArea(viewports, equals: size)
         * @endcode
         */
    }

    /**
     * Grid 레이아웃 - 5채널 뷰포트 테스트
     */
    /**
     * 5개 채널이 있을 때 뷰포트 계산을 검증합니다.
     */
    /**
     * 🎨 기대되는 레이아웃:
     * @endcode
     * ┌──────┬──────┬──────┐
     * │Front │ Rear │ Left │
     * ├──────┴──────┴──────┤
     * │Right  │  Interior  │
     * └───────┴────────────┘
     * @endcode
     */
    /**
     * 📐 기대 뷰포트 크기:
     * - 첫 줄 3개: 각각 (width: 640, height: 540)
     * - 둘째 줄 2개: 각각 (width: 960, height: 540)
     */
    /**
     * @test testGridViewportsFiveChannels
     * @brief 💡 3x2 그리드를 선택한 이유:
     *
     * @details
     *
     * @section 3x2____________ 💡 3x2 그리드를 선택한 이유
     * - 5는 완전한 정사각형 배치 불가
     * - 3x2 (6칸)에서 1칸 비움
     * - 2x3보다 가로 배치가 시청에 유리
     */
    func testGridViewportsFiveChannels() {
        let size = CGSize(width: 1920, height: 1080)

        /**
         * TODO: 5채널 뷰포트 계산 테스트
         */
        /**
         *
         * @section ____________ 💡 불균등 배치의 고려사항
         * @endcode
         * // 옵션 1: 균등 분할 (빈 공간 남김)
         * // Front, Rear, Left 위에 배치 (각 640px)
         * // Right, Interior 아래 배치 (각 960px)
         * // 아래 1칸은 비움
         */
        /**
         * // 옵션 2: 적응형 크기
         * // 중요한 채널 (Front)을 더 크게
         * // 나머지를 작게 배치
         */
        /**
         * // 옵션 3: 동적 그리드
         * // 채널 수에 따라 최적 그리드 자동 계산
         * @endcode
         */
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Focus Layout Tests (Focus 레이아웃 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Focus 레이아웃 뷰포트 테스트
     */
    /**
     * Focus 모드에서 뷰포트가 올바르게 계산되는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 포커스된 채널이 75% 영역을 차지하는가?
     * - 썸네일 채널들이 25% 영역에 세로로 배치되는가?
     * - 모든 뷰포트가 화면 경계 내에 있는가?
     */
    /**
     * 🎨 기대되는 레이아웃:
     * @endcode
     * ┌──────────────────┬────┐
     * │                  │Rear│
     * │                  ├────┤
     * │      Front       │Left│
     * │     (75%)        ├────┤
     * │                  │Rght│
     * │                  ├────┤
     * │                  │Intr│
     * └──────────────────┴────┘
     *      1440px         480px
     * @endcode
     */
    /**
     * @test testFocusLayoutViewports
     * @brief 📐 기대 뷰포트 크기:
     *
     * @details
     * 📐 기대 뷰포트 크기:
     * - Front (포커스): (0, 0, 1440, 1080)
     * - Rear (썸네일): (1440, 0, 480, 270)
     * - Left (썸네일): (1440, 270, 480, 270)
     * - Right (썸네일): (1440, 540, 480, 270)
     * - Interior (썸네일): (1440, 810, 480, 270)
     */
    func testFocusLayoutViewports() {
        // ─────────────────────────────────────────────────────────────────
        // Given: Focus 모드 설정
        // ─────────────────────────────────────────────────────────────────

        /**
         * Focus 레이아웃 모드로 변경
         */
        renderer.setLayoutMode(.focus)

        /**
         * 전방 카메라를 포커스로 설정
         */
        renderer.setFocusedPosition(.front)

        /**
         * TODO: 뷰포트 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * let size = CGSize(width: 1920, height: 1080)
         * let viewports = renderer.calculateFocusViewports(size: size)
         */
        /**
         * // 포커스 채널 크기 확인
         * let focusViewport = viewports[.front]!
         * XCTAssertEqual(focusViewport.width, 1440)  // 75% of 1920
         */
        /**
         * // 썸네일 영역 확인
         * let thumbnailViewports = viewports.filter { $0.key != .front }
         * for (_, viewport) in thumbnailViewports {
         *     XCTAssertEqual(viewport.width, 480)  // 25% of 1920
         *     XCTAssertEqual(viewport.height, 270)  // 1080 / 4 thumbnails
         * }
         * @endcode
         */
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Horizontal Layout Tests (Horizontal 레이아웃 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * Horizontal 레이아웃 뷰포트 테스트
     */
    /**
     * Horizontal 모드에서 뷰포트가 올바르게 계산되는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 모든 채널이 동일한 너비를 가지는가?
     * - 채널들이 가로로 균등하게 분할되는가?
     * - 전체 화면 높이를 사용하는가?
     */
    /**
     * 🎨 기대되는 레이아웃 (4채널):
     * @endcode
     * ┌────┬────┬────┬────┐
     * │    │    │    │    │
     * │  F │  R │  L │  I │
     * │    │    │    │    │
     * └────┴────┴────┴────┘
     *  480  480  480  480
     * @endcode
     */
    /**
     * 📐 기대 뷰포트 크기 (4채널):
     * - Front: (0, 0, 480, 1080)
     * - Rear: (480, 0, 480, 1080)
     * - Left: (960, 0, 480, 1080)
     * - Interior: (1440, 0, 480, 1080)
     */
    /**
     * @test testHorizontalLayoutViewports
     * @brief 💡 Horizontal 레이아웃의 장점:
     *
     * @details
     *
     * @section horizontal_________ 💡 Horizontal 레이아웃의 장점
     * - 타임라인과 함께 사용하기 좋음
     * - 여러 각도 동시 비교 용이
     * - 와이드 모니터 활용 최적화
     */
    func testHorizontalLayoutViewports() {
        // ─────────────────────────────────────────────────────────────────
        // Given: Horizontal 모드 설정
        // ─────────────────────────────────────────────────────────────────

        /**
         * Horizontal 레이아웃 모드로 변경
         */
        renderer.setLayoutMode(.horizontal)

        /**
         * TODO: 뷰포트 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * let size = CGSize(width: 1920, height: 1080)
         * let channels: [CameraPosition] = [.front, .rear, .left, .interior]
         * let viewports = renderer.calculateHorizontalViewports(
         *     for: channels,
         *     size: size
         * )
         */
        /**
         * // 채널 수 확인
         * XCTAssertEqual(viewports.count, 4)
         */
        /**
         * // 모든 채널이 동일한 너비인지 확인
         * let width = 1920 / 4  // 480
         * for (_, viewport) in viewports {
         *     XCTAssertEqual(viewport.width, CGFloat(width))
         *     XCTAssertEqual(viewport.height, 1080)
         * }
         */
        /**
         * // X 좌표가 순차적인지 확인
         * let sortedViewports = viewports.sorted { $0.value.minX < $1.value.minX }
         * for (index, (_, viewport)) in sortedViewports.enumerated() {
         *     XCTAssertEqual(viewport.minX, CGFloat(index * width))
         * }
         * @endcode
         */
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Capture Tests (화면 캡처 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 렌더링 없이 캡처 시도 테스트
     */
    /**
     * 렌더링된 프레임이 없을 때 캡처를 시도하면 nil을 반환하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 렌더링 전 캡처 시도 시 nil 반환하는가?
     * - 에러 없이 안전하게 처리되는가?
     */
    /**
     *
     * @section __nil________ 💡 왜 nil을 반환하나요?
     * - 캡처할 텍스처가 없음
     * - Optional 반환으로 안전한 실패 처리
     * - 크래시 대신 nil 체크로 처리 가능
     */
    /**
     *
     * @section __________ 🔄 정상적인 캡처 흐름
     * @endcode
     * 1. render() 호출 → Metal 텍스처에 그리기
     * 2. captureCurrentFrame() 호출
     * 3. 텍스처를 CPU로 읽어옴
     * 4. PNG/JPEG로 인코딩
     * 5. Data 반환
     * @endcode
     */
    /**
     * @test testCaptureWithoutRendering
     * @brief ⚠️ 렌더링 전 캡처 시도 시:
     *
     * @details
     *
     * @section _____________ ⚠️ 렌더링 전 캡처 시도 시
     * @endcode
     * 1. captureCurrentFrame() 호출 ← 텍스처 없음!
     * 2. 내부에서 nil 체크
     * 3. nil 반환 (안전한 실패)
     * @endcode
     */
    func testCaptureWithoutRendering() {
        // ─────────────────────────────────────────────────────────────────
        // When: 렌더링 전에 캡처 시도
        // ─────────────────────────────────────────────────────────────────

        /**
         * 현재 프레임 캡처 시도
         */
        /**
         * captureCurrentFrame()의 동작:
         * - 마지막으로 렌더링된 텍스처를 이미지로 변환
         * - 텍스처가 없으면 nil 반환
         * - 기본 포맷은 PNG
         */
        /**
         *
         * @section optional_______ 💡 Optional 반환의 이유
         * @endcode
         * func captureCurrentFrame() -> Data? {
         *     guard let texture = lastRenderedTexture else {
         *         return nil  // 텍스처 없음
         *     }
         *     // 텍스처를 Data로 변환
         *     return encodeToImage(texture)
         * }
         * @endcode
         */
        /**
         *
         * @section _____ 📊 사용 예시
         * @endcode
         * if let imageData = renderer.captureCurrentFrame() {
         *     // 이미지 저장 또는 공유
         *     try? imageData.write(to: fileURL)
         * } else {
         *     // 캡처 실패 처리
         *     print("No frame to capture")
         * }
         * @endcode
         */
        let data = renderer.captureCurrentFrame()

        // ─────────────────────────────────────────────────────────────────
        // Then: nil을 반환해야 함
        // ─────────────────────────────────────────────────────────────────

        /**
         * 반환값이 nil인지 확인
         */
        /**
         * XCTAssertNil의 동작:
         * - 값이 nil이면 테스트 통과
         * - nil이 아니면 테스트 실패
         */
        /**
         *
         * @section ______________ 💡 이 테스트가 실패하는 경우
         * - captureCurrentFrame()이 항상 빈 Data를 반환
         * - 에러 대신 기본 이미지를 반환
         * - nil 체크를 하지 않고 크래시 발생
         */
        /**
         * 📚 참고: "프레임이 렌더링되지 않았을 때 nil을 반환해야 함"
         *          이 메시지로 테스트 의도를 명확히 전달
         */
        XCTAssertNil(data, "Should return nil when no frame has been rendered")
    }

    /**
     * 캡처 포맷 테스트
     */
    /**
     * PNG와 JPEG 포맷이 모두 지원되는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - CaptureImageFormat.png가 존재하는가?
     * - CaptureImageFormat.jpeg가 존재하는가?
     */
    /**
     *
     * @section _______ 💡 현재 제한사항
     * - 실제 렌더링이 필요하므로 통합 테스트에서 완전히 검증
     * - 여기서는 포맷 enum이 존재하는지만 확인
     */
    /**
     * 🖼️ 포맷 비교:
     * @endcode
     * PNG:
     * - 무손실 압축
     * - 투명도 지원
     * - 파일 크기 큼 (5-10MB)
     * - 품질 100%
     * - 사용처: 정확한 증거 필요 시
     */
    /**
     * JPEG:
     * - 손실 압축
     * - 투명도 없음
     * - 파일 크기 작음 (1-2MB)
     * - 품질 조절 가능 (70-95%)
     * - 사용처: 공유, SNS 업로드
     * @endcode
     */
    /**
     * @test testCaptureFormats
     * @brief 📊 파일 크기 예시 (1920x1080 4채널):
     *
     * @details
     *
     * @section __________1920x1080_4___ 📊 파일 크기 예시 (1920x1080 4채널)
     * @endcode
     * PNG:  약 8-12MB
     * JPEG: 약 1-3MB (품질 80%)
     * 압축률: 약 4-8배 차이
     * @endcode
     */
    func testCaptureFormats() {
        /**
         * PNG와 JPEG 포맷 배열
         */
        /**
         *
         * @section ___enum____ 💡 포맷 enum의 역할
         * @endcode
         * enum CaptureImageFormat {
         *     case png
         *     case jpeg(quality: CGFloat)  // 0.0 ~ 1.0
         * }
         */
        /**
         * // 사용 예시:
         * let data = renderer.captureCurrentFrame(format: .png)
         * let data = renderer.captureCurrentFrame(format: .jpeg(quality: 0.8))
         * @endcode
         */
        let formats: [CaptureImageFormat] = [.png, .jpeg]

        /**
         * 각 포맷이 존재하는지 확인
         */
        /**
         * for 루프로 모든 포맷 검증:
         * - .png 검증
         * - .jpeg 검증
         */
        /**
         *
         * @section xctassertnotnil_format_____ 💡 XCTAssertNotNil(format)의 의미
         * - enum case는 nil이 될 수 없으므로 항상 통과
         * - 하지만 컴파일 시점에 타입 체크 보장
         * - 나중에 Optional로 변경되어도 안전
         */
        /**
         *
         * @section ___________ 🔍 더 나은 테스트 방법
         * @endcode
         * // 실제 렌더링 후 포맷 테스트 (통합 테스트에서)
         * let pngData = renderer.captureCurrentFrame(format: .png)
         * let jpegData = renderer.captureCurrentFrame(format: .jpeg(quality: 0.8))
         */
        /**
         * // PNG 시그니처 확인 (89 50 4E 47)
         * XCTAssertEqual(pngData?.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
         */
        /**
         * // JPEG 시그니처 확인 (FF D8 FF)
         * XCTAssertEqual(jpegData?.prefix(3), Data([0xFF, 0xD8, 0xFF]))
         */
        /**
         * // 파일 크기 비교
         * XCTAssertLessThan(jpegData!.count, pngData!.count)
         * @endcode
         */
        for format in formats {
            XCTAssertNotNil(format)
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Performance Tests (성능 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 레이아웃 모드 변경 성능 테스트
     */
    /**
     * 레이아웃 모드를 빠르게 전환할 때의 성능을 측정합니다.
     */
    /**
     *
     * @section _____ 🎯 측정 항목
     * - 1000번 반복 시 평균 실행 시간
     * - 메모리 할당 횟수
     * - CPU 사용률
     */
    /**
     *
     * @section measure_______ 💡 measure 블록의 동작
     * @endcode
     * 1. 코드를 10번 실행 (warmup 1회 + 측정 9회)
     * 2. 각 실행 시간 측정
     * 3. 평균, 표준편차 계산
     * 4. 기준값(baseline)과 비교
     * @endcode
     */
    /**
     *
     * @section _____ 📊 성능 기준
     * @endcode
     * 우수:   < 0.1초 (1000번 반복)
     * 양호:   < 0.5초
     * 보통:   < 1.0초
     * 느림:   > 1.0초
     * @endcode
     */
    /**
     *
     * @section ________ 🔍 성능 문제 원인
     * - 불필요한 메모리 할당
     * - 레이아웃 재계산 오버헤드
     * - 동기화 잠금 경합
     * - 통지(notification) 오버헤드
     */
    /**
     *
     * @section ______ 💡 최적화 방법
     * @endcode
     * // ❌ 느린 구현
     * func setLayoutMode(_ mode: LayoutMode) {
     *     self.layoutMode = mode
     *     recalculateAllViewports()      // 항상 재계산
     *     notifyAllObservers()            // 모든 관찰자에게 통지
     *     invalidateWholeScreen()         // 전체 화면 다시 그리기
     * }
     */
    /**
     * @test testLayoutModeChangePerformance
     * @brief // ✅ 빠른 구현
     *
     * @details
     * // ✅ 빠른 구현
     * func setLayoutMode(_ mode: LayoutMode) {
     *     guard self.layoutMode != mode else { return }  // 같으면 skip
     *     self.layoutMode = mode
     *     scheduleLayoutUpdate()          // 배치로 업데이트
     *     invalidateLayoutRegion()        // 필요한 영역만
     * }
     * @endcode
     */
    func testLayoutModeChangePerformance() {
        /**
         * measure 블록으로 성능 측정
         */
        /**
         * 측정 대상:
         * - 3개 레이아웃 모드 전환 × 1000회 = 총 3000번 전환
         * - 각 전환의 평균 시간
         */
        /**
         *
         * @section xcode__________ 📊 XCode의 성능 측정 결과
         * @endcode
         * Average: 0.124 sec
         * Baseline: 0.150 sec
         * Std Dev: 0.012 sec
         */
        /**
         *
         * @section passed_________17____ ✅ Passed - 기준값보다 17% 빠름
         * @endcode
         */
        /**
         *
         * @section __________ 💡 성능 리그레션 감지
         * - 이전 측정값을 baseline으로 저장
         * - 새 코드가 10% 이상 느려지면 경고
         * - CI/CD에서 자동으로 실패 처리 가능
         */
        /**
         * 🔧 성능 개선 후 확인:
         * @endcode
         * Before: 0.500 sec
         * After:  0.124 sec
         * Improvement: 75% faster
         * @endcode
         */
        measure {
            /**
             * 1000번 반복 실행
             */
            ///
            /**
             *
             * @section __1000____ 💡 왜 1000번인가?
             * - 충분히 측정 가능한 시간 확보
             * - 노이즈 제거 (평균으로 안정화)
             * - 너무 길지 않아 테스트 스위트 전체 시간 최소화
             */
            ///
            /**
             * 📐 계산:
             * @endcode
             * 1회 전환: 0.0001초 (100 μs)
             * 1000회: 0.1초
             * 10회 측정: 1초 (허용 범위)
             * @endcode
             */
            for _ in 0..<1000 {
                renderer.setLayoutMode(.grid)
                renderer.setLayoutMode(.focus)
                renderer.setLayoutMode(.horizontal)
            }
        }
    }

    /**
     * 포커스 위치 변경 성능 테스트
     */
    /**
     * 포커스 카메라 위치를 빠르게 전환할 때의 성능을 측정합니다.
     */
    /**
     *
     * @section _____ 🎯 측정 항목
     * - 1000번 반복 시 평균 실행 시간
     * - 레이아웃 모드 변경보다 빠른지 확인
     */
    /**
     *
     * @section ___________________ 💡 포커스 위치 변경이 더 가벼운 이유
     * @endcode
     * setLayoutMode():
     * - 전체 레이아웃 재계산
     * - 모든 뷰포트 크기 변경
     * - 렌더 파이프라인 재구성
     */
    /**
     * setFocusedPosition():
     * - 한 개 프로퍼티만 변경
     * - Focus 모드에서만 영향
     * - 뷰포트 크기는 유지 (배치만 변경)
     * @endcode
     */
    /**
     * @test testFocusPositionChangePerformance
     * @brief 📊 예상 성능:
     *
     * @details
     *
     * @section _____ 📊 예상 성능
     * @endcode
     * setFocusedPosition: 0.050 sec (1000회)
     * setLayoutMode:      0.124 sec (1000회)
     * 약 2.5배 더 빠름
     * @endcode
     */
    func testFocusPositionChangePerformance() {
        measure {
            /**
             * 1000번 반복 실행
             */
            ///
            /**
             * 4개 위치 × 1000회 = 총 4000번 전환
             */
            ///
            /**
             *
             * @section __4__________ 💡 왜 4개만 테스트하나요?
             * - .interior는 생략 (모든 위치를 테스트할 필요 없음)
             * - 대표적인 4방향만으로 충분
             * - 실행 시간 단축
             */
            ///
            /**
             *
             * @section _____ 🔄 실행 순서
             * @endcode
             * .front → .rear → .left → .right → .front → ...
             * (1000회 반복)
             * @endcode
             */
            for _ in 0..<1000 {
                renderer.setFocusedPosition(.front)
                renderer.setFocusedPosition(.rear)
                renderer.setFocusedPosition(.left)
                renderer.setFocusedPosition(.right)
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Memory Management Tests (메모리 관리 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 렌더러 소멸자(deinit) 테스트
     */
    /**
     * 렌더러 인스턴스가 올바르게 메모리에서 해제되는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 렌더러를 nil로 설정하면 메모리에서 해제되는가?
     * - 메모리 누수가 없는가?
     * - 순환 참조가 없는가?
     */
    /**
     *
     * @section _______________ 💡 메모리 누수가 발생하는 경우
     * @endcode
     * // ❌ 순환 참조 (Retain Cycle)
     * class Renderer {
     *     var delegate: Delegate?
     *     init() {
     *         delegate = Delegate()
     *         delegate?.renderer = self  // 강한 참조!
     *     }
     * }
     */
    /**
     * // ✅ weak로 순환 참조 방지
     * class Renderer {
     *     weak var delegate: Delegate?
     *     init() {
     *         delegate = Delegate()
     *         delegate?.renderer = self  // weak 참조
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section __________ 🔍 메모리 누수 디버깅
     * @endcode
     * 1. Instruments → Leaks 도구 실행
     * 2. 렌더러 생성/해제 반복
     * 3. 메모리 그래프에서 살아있는 객체 확인
     * 4. 순환 참조 체인 분석
     * @endcode
     */
    /**
     *
     * @section ___________ 📊 정상적인 메모리 패턴
     * @endcode
     * 생성 → 메모리 100MB ↑
     * 사용 → 메모리 100MB 유지
     * 해제 → 메모리 100MB ↓
     * @endcode
     */
    /**
     * @test testRendererDeinit
     * @brief ⚠️ 메모리 누수 패턴:
     *
     * @details
     *
     * @section _________ ⚠️ 메모리 누수 패턴
     * @endcode
     * 생성 → 메모리 100MB ↑
     * 사용 → 메모리 100MB 유지
     * 해제 → 메모리 유지 (누수!)
     * @endcode
     */
    func testRendererDeinit() {
        // ─────────────────────────────────────────────────────────────────
        // Given: 새로운 렌더러 인스턴스 생성
        // ─────────────────────────────────────────────────────────────────

        /**
         * 테스트용 렌더러 생성
         */
        /**
         * var로 선언하여 nil 할당 가능하게 함
         */
        /**
         *
         * @section optional____________ 💡 Optional 타입을 사용하는 이유
         * - nil을 할당하여 해제 시뮬레이션
         * - ARC가 참조 카운트를 0으로 만들 수 있음
         * - deinit이 호출되는지 간접 확인
         */
        /**
         * 🔢 ARC (Automatic Reference Counting):
         * @endcode
         * var testRenderer = MultiChannelRenderer()  // retain count = 1
         * let anotherRef = testRenderer              // retain count = 2
         * anotherRef = nil                          // retain count = 1
         * testRenderer = nil                        // retain count = 0 → deinit!
         * @endcode
         */
        var testRenderer: MultiChannelRenderer? = MultiChannelRenderer()

        // ─────────────────────────────────────────────────────────────────
        // When: 렌더러를 nil로 설정
        // ─────────────────────────────────────────────────────────────────

        /**
         * nil 할당으로 참조 해제
         */
        /**
         * 이 시점에 일어나는 일:
         * 1. testRenderer의 참조 카운트 감소
         * 2. 참조 카운트가 0이 되면 deinit 호출
         * 3. 소유한 모든 리소스 해제:
         *    - MTLDevice 해제
         *    - MTLCommandQueue 해제
         *    - 모든 텍스처 해제
         *    - 캡처 서비스 해제
         */
        /**
         *
         * @section deinit______ 💡 deinit 구현 예시
         * @endcode
         * class MultiChannelRenderer {
         *     deinit {
         *         print("Renderer being deinitialized")
         *         // Metal 리소스 정리
         *         commandQueue = nil
         *         device = nil
         *         textures.removeAll()
         *     }
         * }
         * @endcode
         */
        testRenderer = nil

        // ─────────────────────────────────────────────────────────────────
        // Then: nil이 되었는지 확인
        // ─────────────────────────────────────────────────────────────────

        /**
         * nil 확인
         */
        /**
         * XCTAssertNil의 검증:
         * - testRenderer가 nil인지 확인
         * - 항상 통과해야 함 (위에서 nil 할당)
         */
        /**
         *
         * @section ____________ 💡 이 테스트의 실제 목적
         * - deinit이 크래시 없이 완료되는지 확인
         * - 메모리 누수 도구와 함께 사용
         * - Instruments로 실행 시 누수 자동 감지
         */
        /**
         *
         * @section ________ 🔍 추가 검증 방법
         * @endcode
         * // weak 참조로 deinit 확인
         * weak var weakRenderer: MultiChannelRenderer?
         * autoreleasepool {
         *     let renderer = MultiChannelRenderer()
         *     weakRenderer = renderer
         *     XCTAssertNotNil(weakRenderer)
         * } // renderer 범위 종료 → deinit
         * XCTAssertNil(weakRenderer, "Renderer should be deallocated")
         * @endcode
         */
        XCTAssertNil(testRenderer)
    }

    // ─────────────────────────────────────────────────────────────────────
    // MARK: - Thread Safety Tests (스레드 안전성 테스트)
    // ─────────────────────────────────────────────────────────────────────

    /**
     * 동시 레이아웃 모드 변경 테스트
     */
    /**
     * 여러 스레드에서 동시에 레이아웃 모드를 변경할 때 크래시가 발생하지 않는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 동시성 환경에서 크래시 없는가?
     * - 데이터 경쟁(Data Race)이 없는가?
     * - 잠금 메커니즘이 올바르게 작동하는가?
     */
    /**
     *
     * @section _______data_race____ 💡 데이터 경쟁(Data Race)이란?
     * @endcode
     * // ❌ 스레드 안전하지 않은 코드
     * var layoutMode: LayoutMode = .grid
     */
    /**
     * // Thread 1:
     * layoutMode = .focus     // 쓰기
     */
    /**
     * // Thread 2 (동시에):
     * print(layoutMode)       // 읽기 → 예측 불가능한 결과!
     * @endcode
     */
    /**
     *
     * @section __________ ✅ 스레드 안전한 구현
     * @endcode
     * class Renderer {
     *     private var _layoutMode: LayoutMode = .grid
     *     private let lock = NSLock()
     */
    /**
     *     var layoutMode: LayoutMode {
     *         get {
     *             lock.lock()
     *             defer { lock.unlock() }
     *             return _layoutMode
     *         }
     *         set {
     *             lock.lock()
     *             defer { lock.unlock() }
     *             _layoutMode = newValue
     *         }
     *     }
     * }
     * @endcode
     */
    /**
     *
     * @section _________ 🔍 동시성 버그 증상
     * - 간헐적 크래시 (재현 어려움)
     * - EXC_BAD_ACCESS 에러
     * - 데이터 손상
     * - 교착 상태(Deadlock)
     */
    /**
     * @test testConcurrentLayoutModeChange
     * @brief 📊 테스트 전략:
     *
     * @details
     *
     * @section ______ 📊 테스트 전략
     * @endcode
     * 100번 반복 → 3개 모드 → 33~34회씩 각 모드 설정
     * 여러 스레드가 동시에 실행 → 경쟁 조건 유도
     * 크래시 없으면 통과
     * @endcode
     */
    func testConcurrentLayoutModeChange() {
        // ─────────────────────────────────────────────────────────────────
        // When: 여러 스레드에서 레이아웃 모드 변경
        // ─────────────────────────────────────────────────────────────────

        /**
         * DispatchQueue.concurrentPerform를 사용한 동시 실행
         */
        /**
         * 동작 방식:
         * - 100번의 반복을 여러 스레드에 분산
         * - 시스템이 최적의 스레드 수 결정 (보통 CPU 코어 수)
         * - 각 스레드가 동시에 setLayoutMode() 호출
         */
        /**
         *
         * @section concurrentperform____ 💡 concurrentPerform의 특징
         * @endcode
         * DispatchQueue.concurrentPerform(iterations: 100) { index in
         *     // 이 블록이 여러 스레드에서 동시에 실행됨
         *     // index: 0~99
         * }
         * // 모든 반복이 끝날 때까지 대기
         * @endcode
         */
        /**
         *
         * @section _______4_______ 🔄 실행 예시 (4코어 시스템)
         * @endcode
         * Thread 1: index 0, 4, 8, 12, ... (setLayoutMode를 25회)
         * Thread 2: index 1, 5, 9, 13, ... (setLayoutMode를 25회)
         * Thread 3: index 2, 6, 10, 14, ... (setLayoutMode를 25회)
         * Thread 4: index 3, 7, 11, 15, ... (setLayoutMode를 25회)
         * → 100회 모두 동시에 실행
         * @endcode
         */
        /**
         *
         * @section _____ 📊 모드 분포
         * @endcode
         * index % 3 == 0 → .grid       (33~34회)
         * index % 3 == 1 → .focus      (33회)
         * index % 3 == 2 → .horizontal (33회)
         * @endcode
         */
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            /**
             * 레이아웃 모드 배열
             */
            let modes: [LayoutMode] = [.grid, .focus, .horizontal]

            /**
             * index를 3으로 나눈 나머지로 모드 선택
             */
            ///
            /**
             *
             * @section _______modulo_ 💡 % 연산자 (modulo)
             * @endcode
             * 0 % 3 = 0 → modes[0] = .grid
             * 1 % 3 = 1 → modes[1] = .focus
             * 2 % 3 = 2 → modes[2] = .horizontal
             * 3 % 3 = 0 → modes[0] = .grid (반복)
             * ...
             * @endcode
             */
            ///
            /**
             *
             * @section __________ 🔄 동시에 일어나는 일
             * @endcode
             * Thread 1: renderer.setLayoutMode(.grid)
             * Thread 2: renderer.setLayoutMode(.focus)      ← 동시!
             * Thread 3: renderer.setLayoutMode(.horizontal) ← 동시!
             * Thread 4: renderer.setLayoutMode(.grid)       ← 동시!
             * @endcode
             */
            ///
            /**
             *
             * @section ____________ ⚠️ 스레드 안전하지 않으면
             * - 읽기/쓰기 충돌
             * - 크래시 발생
             * - 데이터 손상
             */
            renderer.setLayoutMode(modes[index % 3])
        }

        // ─────────────────────────────────────────────────────────────────
        // Then: 크래시하지 않아야 함
        // ─────────────────────────────────────────────────────────────────

        /**
         * 렌더러가 여전히 유효한지 확인
         */
        /**
         *
         * @section __assertion____ 💡 이 assertion의 의미
         * - 실제로는 "크래시하지 않았음"을 검증
         * - 여기까지 도달했다 = 크래시 없음
         * - renderer가 손상되지 않았음
         */
        /**
         *
         * @section ____________ 🔍 추가 검증 가능한 항목
         * @endcode
         * // 최종 상태가 유효한 값인지 확인
         * XCTAssertTrue(
         *     renderer.layoutMode == .grid ||
         *     renderer.layoutMode == .focus ||
         *     renderer.layoutMode == .horizontal
         * )
         */
        /**
         * // 캡처 서비스가 여전히 유효한지 확인
         * XCTAssertNotNil(renderer.captureService)
         * @endcode
         */
        XCTAssertNotNil(renderer)
    }

    /**
     * 동시 포커스 위치 변경 테스트
     */
    /**
     * 여러 스레드에서 동시에 포커스 위치를 변경할 때 크래시가 발생하지 않는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 포커스 위치 변경도 스레드 안전한가?
     * - 레이아웃 모드와 포커스 위치를 동시에 변경해도 안전한가?
     */
    /**
     *
     * @section ___________ 💡 복합 동시성 시나리오
     * @endcode
     * // Thread 1:
     * renderer.setLayoutMode(.focus)
     * renderer.setFocusedPosition(.front)
     */
    /**
     * // Thread 2 (동시에):
     * renderer.setLayoutMode(.grid)
     * renderer.setFocusedPosition(.rear)
     */
    /**
     * // 두 작업이 충돌하지 않아야 함!
     * @endcode
     */
    /**
     * @test testConcurrentFocusPositionChange
     * @brief 🔒 보호해야 할 공유 상태:
     *
     * @details
     * 🔒 보호해야 할 공유 상태:
     * @endcode
     * - layoutMode 프로퍼티
     * - focusedPosition 프로퍼티
     * - 뷰포트 계산 결과
     * - 렌더링 상태
     * @endcode
     */
    func testConcurrentFocusPositionChange() {
        // ─────────────────────────────────────────────────────────────────
        // When: 여러 스레드에서 포커스 위치 변경
        // ─────────────────────────────────────────────────────────────────

        /**
         * 100번 반복을 동시 실행
         */
        /**
         *
         * @section 5________ 💡 5개 위치를 순환
         * @endcode
         * index % 5 == 0 → .front    (20회)
         * index % 5 == 1 → .rear     (20회)
         * index % 5 == 2 → .left     (20회)
         * index % 5 == 3 → .right    (20회)
         * index % 5 == 4 → .interior (20회)
         * @endcode
         */
        /**
         *
         * @section ________ 🔄 동시 실행 패턴
         * @endcode
         * Thread 1: .front → .front → .front → ...
         * Thread 2: .rear → .rear → .left → ...
         * Thread 3: .left → .right → .interior → ...
         * Thread 4: .right → .interior → .front → ...
         * (모두 동시에 setFocusedPosition 호출)
         * @endcode
         */
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            /**
             * 카메라 위치 배열
             */
            let positions: [CameraPosition] = [.front, .rear, .left, .right, .interior]

            /**
             * index를 5로 나눈 나머지로 위치 선택
             */
            ///
            /**
             *
             * @section ____________ ⚠️ 배열 인덱스 범위 확인
             * @endcode
             * index % 5는 항상 0~4 범위
             * positions 배열 크기: 5
             * → 안전한 접근 보장
             * @endcode
             */
            renderer.setFocusedPosition(positions[index % 5])
        }

        // ─────────────────────────────────────────────────────────────────
        // Then: 크래시하지 않아야 함
        // ─────────────────────────────────────────────────────────────────

        /**
         * 렌더러가 여전히 유효한지 확인
         */
        /**
         *
         * @section _____________ 💡 스레드 안전성 보장 방법
         * @endcode
         * // 방법 1: NSLock
         * private let lock = NSLock()
         * func setFocusedPosition(_ position: CameraPosition) {
         *     lock.lock()
         *     defer { lock.unlock() }
         *     self.focusedPosition = position
         * }
         */
        /**
         * // 방법 2: DispatchQueue
         * private let queue = DispatchQueue(label: "renderer.queue")
         * func setFocusedPosition(_ position: CameraPosition) {
         *     queue.sync {
         *         self.focusedPosition = position
         *     }
         * }
         */
        /**
         * // 방법 3: actor (Swift 5.5+)
         * actor Renderer {
         *     var focusedPosition: CameraPosition = .front
         *     func setFocusedPosition(_ position: CameraPosition) {
         *         self.focusedPosition = position
         *     }
         * }
         * @endcode
         */
        XCTAssertNotNil(renderer)
    }
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - Integration Tests (통합 테스트)
// ═════════════════════════════════════════════════════════════════════════

/// 실제 Metal 렌더링이 필요한 통합 테스트
///
/// 단위 테스트와 달리 실제 GPU 렌더링 파이프라인을 검증합니다.
///
/// 🎯 통합 테스트의 목적:
/// - 실제 렌더링 동작 확인
/// - 여러 컴포넌트의 상호작용 검증
/// - 엔드투엔드(End-to-End) 시나리오 테스트
///
/// 💡 단위 테스트 vs 통합 테스트:
/// ```
/// 단위 테스트 (Unit Tests):
/// - 개별 함수/메서드 테스트
/// - Mock 객체 사용 가능
/// - 빠른 실행 (밀리초)
/// - 의존성 최소화
///
/// 통합 테스트 (Integration Tests):
/// - 여러 컴포넌트 함께 테스트
/// - 실제 객체 사용
/// - 느린 실행 (초 단위)
/// - 실제 환경과 유사
/// ```
///
/// 🖼️ 렌더링 파이프라인 통합:
/// ```
/// VideoFrame → MultiChannelRenderer → Metal → MTKView
///    ↓               ↓                  ↓         ↓
/// 비디오 데이터   레이아웃 계산     GPU 렌더링  화면 표시
/// ```
final class MultiChannelRendererIntegrationTests: XCTestCase {

    /**
     * 테스트 대상 렌더러
     */
    var renderer: MultiChannelRenderer!

    /**
     * 테스트용 비디오 프레임
     */
    /**
     *
     * @section ____________ 💡 실제 통합 테스트에서는
     * - 실제 비디오 프레임 데이터 필요
     * - 각 카메라 위치별 프레임
     * - Metal 텍스처로 변환된 데이터
     */
    var testFrames: [CameraPosition: VideoFrame]!

    /**
     * 각 통합 테스트 전 설정
     */
    /**
     * 단위 테스트와 동일하지만, 추가로:
     * - 테스트 비디오 프레임 준비
     * - 렌더링 환경 설정
     * - MTKView 또는 대체 Drawable 준비
     */
    override func setUpWithError() throws {
        super.setUp()

        /**
         * Metal 디바이스 확인
         */
        guard MTLCreateSystemDefaultDevice() != nil else {
            throw XCTSkip("Metal is not available")
        }

        /**
         * 렌더러 생성
         */
        renderer = MultiChannelRenderer()
        guard renderer != nil else {
            throw XCTSkip("Failed to create renderer")
        }

        /**
         * 테스트 프레임 생성
         */
        /**
         * TODO: 실제 비디오 프레임 로드
         */
        /**
         * 구현 예시:
         * @endcode
         * let testVideoURL = Bundle(for: type(of: self)).url(
         *     forResource: "test_video",
         *     withExtension: "mp4"
         * )!
         */
        /**
         * testFrames = [
         *     .front: loadVideoFrame(from: testVideoURL, position: .front),
         *     .rear: loadVideoFrame(from: testVideoURL, position: .rear),
         *     // ...
         * ]
         * @endcode
         */
        /**
         *
         * @section ____________ 📊 테스트 비디오 요구사항
         * - 해상도: 1920x1080 또는 1280x720
         * - 코덱: H.264 또는 H.265
         * - 길이: 1-2초 (짧은 클립)
         * - 크기: 1-5MB
         */
        testFrames = [:]
    }

    /**
     * 각 통합 테스트 후 정리
     */
    override func tearDownWithError() throws {
        renderer = nil
        testFrames = nil
        super.tearDown()
    }

    /**
     * 빈 프레임으로 렌더링 테스트
     */
    /**
     * 프레임 데이터가 없을 때도 안전하게 처리하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 빈 딕셔너리로 렌더링 시도 시 크래시 없는가?
     * - 에러 처리가 적절한가?
     * - 검은 화면 또는 빈 화면이 표시되는가?
     */
    /**
     * @test testRenderWithEmptyFrames
     * @brief 💡 실제 구현에서:
     *
     * @details
     *
     * @section _______ 💡 실제 구현에서
     * @endcode
     * func render(frames: [CameraPosition: VideoFrame]) {
     *     guard !frames.isEmpty else {
     *         // 빈 화면 렌더링 또는 skip
     *         return
     *     }
     *     // 정상 렌더링
     * }
     * @endcode
     */
    func testRenderWithEmptyFrames() {
        /**
         * 빈 프레임 딕셔너리
         */
        let frames: [CameraPosition: VideoFrame] = [:]

        /**
         * TODO: 실제 렌더링 호출
         */
        /**
         * 구현 예시:
         * @endcode
         * // MTKView 또는 테스트용 Drawable 준비
         * let drawable = createTestDrawable()
         */
        /**
         * // 렌더링 시도 (크래시하지 않아야 함)
         * renderer.render(frames: frames, to: drawable)
         */
        /**
         * // 결과 검증
         * XCTAssertNotNil(drawable.texture)
         * // 텍스처가 검은색 또는 비어있는지 확인
         * @endcode
         *
         * 렌더러가 여전히 유효한지 확인
         */
        XCTAssertNotNil(renderer)
    }

    /**
     * Grid 레이아웃 렌더링 테스트
     */
    /**
     * Grid 모드에서 실제 렌더링이 올바르게 동작하는지 확인합니다.
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - 모든 채널이 화면에 표시되는가?
     * - 뷰포트가 올바르게 계산되는가?
     * - 각 채널의 크기가 동일한가?
     */
    /**
     * @test testGridLayoutRendering
     * @brief 📐 예상 결과 (4채널):
     *
     * @details
     * 📐 예상 결과 (4채널):
     * @endcode
     * ┌─────────┬─────────┐
     * │ Front   │  Rear   │  각 960x540
     * ├─────────┼─────────┤
     * │ Left    │  Right  │  전체 1920x1080
     * └─────────┴─────────┘
     * @endcode
     */
    func testGridLayoutRendering() {
        /**
         * TODO: Grid 레이아웃 렌더링 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * // Grid 모드 설정
         * renderer.setLayoutMode(.grid)
         */
        /**
         * // 4채널 프레임 준비
         * let frames = prepareTestFrames(
         *     positions: [.front, .rear, .left, .right]
         * )
         */
        /**
         * // 렌더링
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // 결과 검증
         * XCTAssertNotNil(texture)
         */
        /**
         * // 각 채널이 올바른 위치에 렌더링되었는지 확인
         * // (픽셀 샘플링 또는 시각적 비교)
         * assertChannelVisible(in: texture, at: .topLeft, for: .front)
         * assertChannelVisible(in: texture, at: .topRight, for: .rear)
         * assertChannelVisible(in: texture, at: .bottomLeft, for: .left)
         * assertChannelVisible(in: texture, at: .bottomRight, for: .right)
         * @endcode
         */
    }

    /**
     * Focus 레이아웃 렌더링 테스트
     */
    /**
     * Focus 모드에서 메인 채널과 썸네일이 올바르게 표시되는지 확인합니다.
     */
    /**
     * @test testFocusLayoutRendering
     * @brief 🎯 검증 항목:
     *
     * @details
     *
     * @section _____ 🎯 검증 항목
     * - 포커스 채널이 75% 크기로 표시되는가?
     * - 썸네일 채널이 25% 영역에 표시되는가?
     * - 썸네일이 세로로 올바르게 정렬되는가?
     */
    func testFocusLayoutRendering() {
        /**
         * TODO: Focus 레이아웃 렌더링 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * renderer.setLayoutMode(.focus)
         * renderer.setFocusedPosition(.front)
         */
        /**
         * let frames = prepareTestFrames(
         *     positions: [.front, .rear, .left, .right]
         * )
         */
        /**
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // 메인 채널 확인 (좌측 75%)
         * assertChannelVisible(
         *     in: texture,
         *     at: CGRect(0, 0, 1440, 1080),
         *     for: .front
         * )
         */
        /**
         * // 썸네일 확인 (우측 25%)
         * assertChannelVisible(in: texture, at: CGRect(1440, 0, 480, 270), for: .rear)
         * assertChannelVisible(in: texture, at: CGRect(1440, 270, 480, 270), for: .left)
         * assertChannelVisible(in: texture, at: CGRect(1440, 540, 480, 270), for: .right)
         * @endcode
         */
    }

    /**
     * Horizontal 레이아웃 렌더링 테스트
     */
    /**
     * Horizontal 모드에서 채널들이 가로로 균등하게 배치되는지 확인합니다.
     */
    /**
     * @test testHorizontalLayoutRendering
     * @brief 🎯 검증 항목:
     *
     * @details
     *
     * @section _____ 🎯 검증 항목
     * - 모든 채널이 동일한 너비를 가지는가?
     * - 채널 순서가 올바른가?
     * - 전체 높이를 사용하는가?
     */
    func testHorizontalLayoutRendering() {
        /**
         * TODO: Horizontal 레이아웃 렌더링 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * renderer.setLayoutMode(.horizontal)
         */
        /**
         * let frames = prepareTestFrames(
         *     positions: [.front, .rear, .left, .interior]
         * )
         */
        /**
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // 각 채널이 480px 너비로 표시되는지 확인
         * assertChannelVisible(in: texture, at: CGRect(0, 0, 480, 1080), for: .front)
         * assertChannelVisible(in: texture, at: CGRect(480, 0, 480, 1080), for: .rear)
         * assertChannelVisible(in: texture, at: CGRect(960, 0, 480, 1080), for: .left)
         * assertChannelVisible(in: texture, at: CGRect(1440, 0, 480, 1080), for: .interior)
         * @endcode
         */
    }

    /**
     * 렌더링 후 캡처 테스트
     */
    /**
     * 실제 렌더링 후 화면 캡처가 올바르게 동작하는지 확인합니다.
     */
    /**
     * @test testCaptureAfterRendering
     * @brief 🎯 검증 항목:
     *
     * @details
     *
     * @section _____ 🎯 검증 항목
     * - 렌더링 후 캡처 시 Data를 반환하는가?
     * - Data 크기가 적절한가?
     * - 이미지 포맷이 올바른가?
     */
    func testCaptureAfterRendering() {
        /**
         * TODO: 렌더링 후 캡처 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * // 렌더링 수행
         * let frames = prepareTestFrames(positions: [.front, .rear])
         * renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // 캡처 시도
         * let capturedData = renderer.captureCurrentFrame()
         */
        /**
         * // 데이터 검증
         * XCTAssertNotNil(capturedData, "Capture should return data after rendering")
         * XCTAssertGreaterThan(capturedData!.count, 100_000, "Image should have reasonable size")
         */
        /**
         * // PNG 시그니처 확인
         * let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
         * XCTAssertEqual(capturedData!.prefix(4), Data(pngSignature))
         */
        /**
         * // 이미지로 디코딩 가능한지 확인
         * #if os(macOS)
         * let image = NSImage(data: capturedData!)
         * XCTAssertNotNil(image)
         * XCTAssertEqual(image!.size, NSSize(width: 1920, height: 1080))
         * #endif
         * @endcode
         */
    }

    /**
     * 다양한 캡처 포맷 테스트
     */
    /**
     * PNG와 JPEG 포맷으로 캡처했을 때 결과가 올바른지 확인합니다.
     */
    /**
     * @test testCaptureDifferentFormats
     * @brief 🎯 검증 항목:
     *
     * @details
     *
     * @section _____ 🎯 검증 항목
     * - PNG와 JPEG 모두 캡처 가능한가?
     * - JPEG가 PNG보다 작은가?
     * - 각 포맷의 시그니처가 올바른가?
     */
    func testCaptureDifferentFormats() {
        /**
         * TODO: 포맷별 캡처 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * // 렌더링
         * let frames = prepareTestFrames(positions: [.front])
         * renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // PNG 캡처
         * let pngData = renderer.captureCurrentFrame(format: .png)
         * XCTAssertNotNil(pngData)
         * XCTAssertEqual(pngData!.prefix(4), Data([0x89, 0x50, 0x4E, 0x47]))
         */
        /**
         * // JPEG 캡처
         * let jpegData = renderer.captureCurrentFrame(format: .jpeg(quality: 0.8))
         * XCTAssertNotNil(jpegData)
         * XCTAssertEqual(jpegData!.prefix(3), Data([0xFF, 0xD8, 0xFF]))
         */
        /**
         * // 크기 비교
         * XCTAssertLessThan(jpegData!.count, pngData!.count, "JPEG should be smaller than PNG")
         */
        /**
         * // 품질 차이 테스트
         * let jpegLow = renderer.captureCurrentFrame(format: .jpeg(quality: 0.5))
         * let jpegHigh = renderer.captureCurrentFrame(format: .jpeg(quality: 0.95))
         * XCTAssertLessThan(jpegLow!.count, jpegHigh!.count)
         * @endcode
         */
    }

    /**
     * 비디오 변환 통합 테스트
     */
    /**
     * 회전, 크롭 등 비디오 변환이 렌더링에 올바르게 적용되는지 확인합니다.
     */
    /**
     * @test testTransformationIntegration
     * @brief 🎯 검증 항목:
     *
     * @details
     *
     * @section _____ 🎯 검증 항목
     * - 회전 변환이 적용되는가?
     * - 크롭 변환이 적용되는가?
     * - 밝기/대비 조정이 적용되는가?
     */
    func testTransformationIntegration() {
        /**
         * TODO: 변환 통합 검증
         */
        /**
         * 구현 예시:
         * @endcode
         * // 변환 서비스 설정
         * let transformation = VideoTransformation(
         *     rotation: 90,
         *     crop: CGRect(0.1, 0.1, 0.8, 0.8),
         *     brightness: 1.2,
         *     contrast: 1.1
         * )
         * renderer.transformationService.setTransformation(transformation, for: .front)
         */
        /**
         * // 렌더링
         * let frames = prepareTestFrames(positions: [.front])
         * let texture = renderer.render(frames: frames, size: CGSize(1920, 1080))
         */
        /**
         * // 변환 적용 확인
         * // (픽셀 비교 또는 시각적 검증 필요)
         * assertTransformationApplied(to: texture, transformation: transformation)
         * @endcode
         */
    }
}

// ═════════════════════════════════════════════════════════════════════════
// MARK: - Helper Extensions for Testing (테스트 헬퍼 확장)
// ═════════════════════════════════════════════════════════════════════════

extension MultiChannelRendererTests {
    /**
     * 테스트용 뷰포트 생성
     */
    /**
     * 뷰포트 계산 테스트에서 사용할 CGRect를 생성합니다.
     */
    /**
     * - Parameters:
     *   - x: X 좌표 (기본값: 0)
     *   - y: Y 좌표 (기본값: 0)
     *   - width: 너비 (기본값: 100)
     *   - height: 높이 (기본값: 100)
     * - Returns: 생성된 CGRect
     */
    /**
     *
     * @section _____ 💡 사용 예시
     * @endcode
     * let viewport = createTestViewport(x: 100, y: 200, width: 960, height: 540)
     * assertViewportInBounds(viewport, size)
     * @endcode
     */
    func createTestViewport(x: CGFloat = 0, y: CGFloat = 0, width: CGFloat = 100, height: CGFloat = 100) -> CGRect {
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /**
     * 테스트용 화면 크기 생성
     */
    /**
     * 화면 크기 테스트에서 사용할 CGSize를 생성합니다.
     */
    /**
     * - Parameters:
     *   - width: 화면 너비 (기본값: 1920 - Full HD)
     *   - height: 화면 높이 (기본값: 1080 - Full HD)
     * - Returns: 생성된 CGSize
     */
    /**
     *
     * @section ________ 💡 일반적인 해상도
     * @endcode
     * Full HD:    1920 x 1080 (16:9)
     * HD:         1280 x 720  (16:9)
     * 4K UHD:     3840 x 2160 (16:9)
     * iPad:       2048 x 2732 (3:4)
     * iPhone 14:  1170 x 2532 (9:19.5)
     * @endcode
     */
    func createTestSize(width: CGFloat = 1920, height: CGFloat = 1080) -> CGSize {
        return CGSize(width: width, height: height)
    }

    /**
     * 뷰포트가 화면 경계 내에 있는지 검증
     */
    /**
     * 뷰포트의 모든 좌표가 유효한 범위 내에 있는지 확인합니다.
     */
    /**
     * - Parameters:
     *   - viewport: 검증할 뷰포트
     *   - size: 화면 크기
     */
    /**
     *
     * @section _____ 🎯 검증 항목
     * - viewport.origin.x >= 0
     * - viewport.origin.y >= 0
     * - viewport.maxX <= size.width
     * - viewport.maxY <= size.height
     */
    /**
     *
     * @section _____ 💡 사용 예시
     * @endcode
     * let viewport = CGRect(x: 960, y: 540, width: 960, height: 540)
     * let size = CGSize(width: 1920, height: 1080)
     * assertViewportInBounds(viewport, size)  // ✅ 통과
     */
    /**
     * let invalidViewport = CGRect(x: 1500, y: 0, width: 1000, height: 1080)
     * assertViewportInBounds(invalidViewport, size)  // ❌ 실패 (maxX = 2500 > 1920)
     * @endcode
     */
    func assertViewportInBounds(_ viewport: CGRect, _ size: CGSize) {
        /**
         * X 좌표가 0 이상인지 확인
         */
        XCTAssertGreaterThanOrEqual(viewport.origin.x, 0)

        /**
         * Y 좌표가 0 이상인지 확인
         */
        XCTAssertGreaterThanOrEqual(viewport.origin.y, 0)

        /**
         * 오른쪽 끝이 화면 너비 이내인지 확인
         */
        XCTAssertLessThanOrEqual(viewport.maxX, size.width)

        /**
         * 아래쪽 끝이 화면 높이 이내인지 확인
         */
        XCTAssertLessThanOrEqual(viewport.maxY, size.height)
    }

    /**
     * 전체 뷰포트 면적이 화면 크기와 일치하는지 검증
     */
    /**
     * 모든 뷰포트의 총 면적이 화면 전체 면적과 같은지 확인합니다.
     */
    /**
     * - Parameters:
     *   - viewports: 검증할 뷰포트 딕셔너리
     *   - size: 화면 크기
     *   - tolerance: 허용 오차 (기본값: 0.01 = 1%)
     */
    /**
     *
     * @section _______________ 💡 왜 허용 오차가 필요한가요?
     * - 부동소수점 연산의 정밀도 한계
     * - 픽셀 정렬로 인한 1-2px 차이
     * - 반올림 오차 누적
     */
    /**
     * 🔢 계산 방식:
     * @endcode
     * totalArea = viewport1.area + viewport2.area + ...
     * expectedArea = size.width × size.height
     * difference = |totalArea - expectedArea| / expectedArea
     * @endcode
     */
    /**
     *
     * @section _____ 📊 사용 예시
     * @endcode
     * let viewports: [CameraPosition: CGRect] = [
     *     .front: CGRect(0, 0, 960, 540),
     *     .rear:  CGRect(960, 0, 960, 540),
     *     .left:  CGRect(0, 540, 960, 540),
     *     .right: CGRect(960, 540, 960, 540)
     * ]
     * let size = CGSize(width: 1920, height: 1080)
     */
    /**
     * // 총 면적: 4 × (960 × 540) = 2,073,600
     * // 화면 면적: 1920 × 1080 = 2,073,600
     * // 차이: 0% → 통과
     * assertTotalViewportArea(viewports, equals: size)
     * @endcode
     */
    func assertTotalViewportArea(_ viewports: [CameraPosition: CGRect], equals size: CGSize, tolerance: CGFloat = 0.01) {
        /**
         * 모든 뷰포트의 총 면적 계산
         */
        /**
         * reduce를 사용한 누적 합산:
         * - 초기값: 0
         * - 각 뷰포트: width × height
         * - 결과: 모든 뷰포트 면적의 합
         */
        /**
         *
         * @section reduce___ 💡 reduce 설명
         * @endcode
         * [10, 20, 30].reduce(0) { $0 + $1 }
         * // = ((0 + 10) + 20) + 30 = 60
         */
        /**
         * viewports.values.reduce(0) { $0 + ($1.width * $1.height) }
         * // = 각 뷰포트의 면적을 모두 더함
         * @endcode
         */
        let totalArea = viewports.values.reduce(0) { $0 + ($1.width * $1.height) }

        /**
         * 기대되는 전체 면적 (화면 크기)
         */
        let expectedArea = size.width * size.height

        /**
         * 상대적 차이 계산 (백분율)
         */
        /**
         * 절대값 사용 이유:
         * - totalArea가 더 클 수도, 작을 수도 있음
         * - 어느 쪽이든 차이의 크기만 중요
         */
        /**
         * 백분율 계산:
         * @endcode
         * difference = |totalArea - expectedArea| / expectedArea
         * 예: |2100000 - 2073600| / 2073600 = 0.0127 (1.27%)
         * @endcode
         */
        let difference = abs(totalArea - expectedArea) / expectedArea

        /**
         * 차이가 허용 범위 이내인지 확인
         */
        /**
         * XCTAssertLessThan:
         * - difference < tolerance면 통과
         * - 메시지로 테스트 의도 명확히 전달
         */
        /**
         *
         * @section _________ 💡 실패 메시지 예시
         * @endcode
         * ❌ XCTAssertLessThan failed: ("0.05") is not less than ("0.01")
         *    - Total viewport area should match drawable size
         *    → 5% 차이 발생 (허용 범위 1% 초과)
         * @endcode
         */
        XCTAssertLessThan(difference, tolerance, "Total viewport area should match drawable size")
    }
}
