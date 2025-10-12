/// @file VideoTransformations.swift
/// @brief Video transformation parameters for brightness, flip, and zoom effects
/// @author BlackboxPlayer Development Team
/// @details
/// 이 파일은 재생 중인 영상에 실시간으로 적용할 수 있는 시각적 효과들을 정의합니다.
/// GPU 셰이더에서 밝기 조절, 반전, 디지털 줌 등의 변환을 수행할 파라미터를 제공합니다.

/**
 # VideoTransformations - 영상 변환 효과

 ## 🎨 영상 변환이란?

 재생 중인 영상에 실시간으로 적용할 수 있는 시각적 효과들입니다.

 ### 지원하는 변환 효과:

 1. **밝기 조절 (Brightness)**
    - 영상을 더 밝게 또는 어둡게 만듦
    - 야간 영상 개선에 유용

 2. **좌우 반전 (Horizontal Flip)**
    - 영상을 좌우로 뒤집음
    - 백미러 영상에 유용

 3. **상하 반전 (Vertical Flip)**
    - 영상을 상하로 뒤집음
    - 거꾸로 설치된 카메라 보정

 4. **디지털 줌 (Digital Zoom)**
    - 영상의 특정 부분 확대
    - 번호판 확인 등에 유용

 ## 🎯 작동 원리

 ### GPU 셰이더에서 처리:
 ```
 원본 프레임
   ↓
 Fragment Shader (GPU)
   ↓ 변환 파라미터 적용
   - brightness: 픽셀 밝기 조정
   - flip: 좌표 반전
   - zoom: 좌표 확대
   ↓
 변환된 프레임
 ```

 ### 셰이더 코드 예시:
 ```metal
 // Metal Shader
 fragment float4 videoFragmentShader(
     VertexOut in [[stage_in]],
     texture2d<float> texture [[texture(0)]],
     constant Transforms &transforms [[buffer(0)]]
 ) {
     // 1. 좌표 변환 (줌, 반전)
     float2 coord = in.texCoord;

     // 좌우 반전
     if (transforms.flipH) {
         coord.x = 1.0 - coord.x;
     }

     // 줌 적용
     coord = (coord - transforms.zoomCenter) / transforms.zoomLevel + transforms.zoomCenter;

     // 2. 텍스처 샘플링
     float4 color = texture.sample(sampler, coord);

     // 3. 밝기 조정
     color.rgb += transforms.brightness;

     return color;
 }
 ```

 ## 💡 실시간 처리

 ### 왜 GPU에서 처리하나?
 - CPU: 1920×1080 = 2,073,600 픽셀을 순차 처리 (느림)
 - GPU: 모든 픽셀을 병렬 처리 (빠름, 60fps 유지)

 ### 성능 영향:
 - 변환 효과는 GPU에서 처리되므로 성능 영향 최소
 - 모든 효과를 동시에 적용해도 프레임 드롭 없음

 ## 📚 사용 예제

 ```swift
 // 1. 서비스 접근 (싱글톤)
 let service = VideoTransformationService.shared

 // 2. 밝기 조절 (+30%)
 service.setBrightness(0.3)

 // 3. 좌우 반전 토글
 service.toggleFlipHorizontal()

 // 4. 디지털 줌 (2배 확대)
 service.setZoomLevel(2.0)
 service.setZoomCenter(x: 0.7, y: 0.3)  // 우상단 확대

 // 5. 모든 효과 리셋
 service.resetTransformations()
 ```

 ## 🔄 영속성 (Persistence)

 설정은 UserDefaults에 자동 저장되며, 앱을 다시 시작해도 유지됩니다.

 ```
 앱 시작
   ↓
 UserDefaults에서 설정 로드
   ↓
 사용자가 밝기 조절
   ↓
 UserDefaults에 즉시 저장
   ↓
 앱 종료
   ↓
 설정 유지됨
 ```

 ---

 이 모듈은 사용자가 영상을 더 명확하게 볼 수 있도록 실시간 변환 효과를 제공합니다.
 */

import Foundation
import Combine

// MARK: - Video Transformations Struct

/// @struct VideoTransformations
/// @brief GPU 셰이더에 전달할 영상 변환 파라미터들을 담는 구조체
///
/// @details
/// ## 특징:
/// - **Codable**: JSON으로 직렬화/역직렬화 가능 (저장/로드)
/// - **Equatable**: 두 설정이 같은지 비교 가능
/// - **값 타입 (struct)**: 복사 시 독립적인 사본 생성
///
/// ## GPU 셰이더와 연동:
/// ```swift
/// // Swift 측:
/// let transforms = VideoTransformations(brightness: 0.3)
///
/// // GPU 측 (Metal Shader):
/// struct Transforms {
///     float brightness;
///     bool flipHorizontal;
///     bool flipVertical;
///     float zoomLevel;
///     float2 zoomCenter;
/// };
/// ```
///
/// ## 메모리 레이아웃:
/// ```
/// Swift struct → 24 bytes → GPU Uniform Buffer
/// ┌──────────────┬──────────┬──────────┬──────────┬────────────┐
/// │ brightness   │ flipH    │ flipV    │ zoomLvl  │ zoomCenter │
/// │ 4 bytes      │ 1 byte   │ 1 byte   │ 4 bytes  │ 8 bytes    │
/// └──────────────┴──────────┴──────────┴──────────┴────────────┘
/// ```
struct VideoTransformations: Codable, Equatable {

    // MARK: - Properties

    /// @var brightness
    /// @brief 밝기 조절 (-1.0 ~ +1.0)
    /// @details
    /// 값의 의미:
    /// - **-1.0**: 완전히 어둡게 (검은색)
    /// - **-0.5**: 50% 어둡게
    /// - **0.0**: 변화 없음 (기본값)
    /// - **+0.5**: 50% 밝게
    /// - **+1.0**: 완전히 밝게 (흰색)
    ///
    /// 작동 방식:
    /// ```
    /// 셰이더에서:
    /// outputColor.rgb = originalColor.rgb + brightness
    ///
    /// 예: 회색 픽셀 (0.5, 0.5, 0.5)
    /// - brightness = +0.3 → (0.8, 0.8, 0.8) 밝아짐
    /// - brightness = -0.3 → (0.2, 0.2, 0.2) 어두워짐
    /// ```
    ///
    /// 주의사항:
    /// - 너무 높은 값: 과다 노출 (하얗게 날림)
    /// - 너무 낮은 값: 과다 노출 (검게 뭉개짐)
    /// - 권장 범위: -0.5 ~ +0.5
    var brightness: Float = 0.0

    /// @var flipHorizontal
    /// @brief 좌우 반전 (Horizontal Flip)
    /// @details
    /// 영상을 좌우로 뒤집습니다. 거울처럼 보입니다.
    ///
    /// 사용 예:
    /// ```
    /// 원본:                반전 후:
    /// ┌──────────┐         ┌──────────┐
    /// │  ←  Car  │    →    │  Car  →  │
    /// └──────────┘         └──────────┘
    /// ```
    ///
    /// 작동 방식:
    /// ```
    /// 셰이더에서:
    /// if (flipHorizontal) {
    ///     texCoord.x = 1.0 - texCoord.x;
    /// }
    ///
    /// 예: texCoord.x = 0.2 (좌측 20% 지점)
    ///      → 1.0 - 0.2 = 0.8 (우측 80% 지점)
    /// ```
    ///
    /// 활용 사례:
    /// - 백미러 영상 보정
    /// - 좌우가 바뀐 카메라 보정
    var flipHorizontal: Bool = false

    /// @var flipVertical
    /// @brief 상하 반전 (Vertical Flip)
    /// @details
    /// 영상을 상하로 뒤집습니다.
    ///
    /// 사용 예:
    /// ```
    /// 원본:                반전 후:
    /// ┌──────────┐         ┌──────────┐
    /// │   Sky    │         │   Road   │
    /// │   Road   │    →    │   Sky    │
    /// └──────────┘         └──────────┘
    /// ```
    ///
    /// 작동 방식:
    /// ```
    /// 셰이더에서:
    /// if (flipVertical) {
    ///     texCoord.y = 1.0 - texCoord.y;
    /// }
    /// ```
    ///
    /// 활용 사례:
    /// - 거꾸로 설치된 카메라 보정
    /// - 천장 장착 카메라
    var flipVertical: Bool = false

    /// @var zoomLevel
    /// @brief 디지털 줌 레벨 (1.0 ~ 5.0)
    /// @details
    /// 영상의 확대 배율입니다.
    ///
    /// 값의 의미:
    /// - **1.0**: 확대 없음 (원본 크기) - 기본값
    /// - **1.5**: 1.5배 확대
    /// - **2.0**: 2배 확대
    /// - **3.0**: 3배 확대
    /// - **5.0**: 5배 확대 (최대)
    ///
    /// 줌 원리:
    /// ```
    /// 줌 레벨 = 2.0 (2배 확대):
    ///
    /// 원본 영상 영역:          화면에 표시:
    /// ┌─────────────────┐      ┌─────────────────┐
    /// │ ┌─────────────┐ │      │                 │
    /// │ │  이 부분만   │ │  →   │  2배로 확대해서  │
    /// │ │  잘라서      │ │      │  전체 화면 표시  │
    /// │ └─────────────┘ │      │                 │
    /// └─────────────────┘      └─────────────────┘
    ///  (50% 영역)              (100% 화면)
    /// ```
    ///
    /// 셰이더 수식:
    /// ```
    /// newCoord = (originalCoord - zoomCenter) / zoomLevel + zoomCenter
    ///
    /// 예: zoomLevel = 2.0, zoomCenter = (0.5, 0.5)
    /// - (0.0, 0.0) → (0.25, 0.25)  좌상단 → 중심 근처
    /// - (1.0, 1.0) → (0.75, 0.75)  우하단 → 중심 근처
    /// - (0.5, 0.5) → (0.5, 0.5)    중심 → 중심 (고정)
    /// ```
    ///
    /// 화질 손실:
    /// - 디지털 줌은 원본 픽셀을 확대하는 것
    /// - 배율이 높을수록 화질 저하 (픽셀이 보임)
    /// - 광학 줌(렌즈)과 다름
    var zoomLevel: Float = 1.0

    /// @var zoomCenterX
    /// @brief 줌 중심 X 좌표 (0.0 ~ 1.0)
    /// @details
    /// 확대할 때 중심으로 삼을 가로 위치입니다.
    ///
    /// 정규화 좌표 (Normalized Coordinates):
    /// - **0.0**: 좌측 끝
    /// - **0.5**: 가운데 (기본값)
    /// - **1.0**: 우측 끝
    ///
    /// 시각적 예:
    /// ```
    /// 0.0              0.5              1.0
    ///  ↓                ↓                ↓
    /// ┌────────────────┬────────────────┐
    /// │ 좌측            │ 가운데  │ 우측 │
    /// └────────────────┴────────────────┘
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// // 우측 번호판 확대
    /// service.setZoomCenter(x: 0.8, y: 0.5)
    /// service.setZoomLevel(3.0)
    ///
    /// // 좌측 사이드미러 확대
    /// service.setZoomCenter(x: 0.2, y: 0.6)
    /// service.setZoomLevel(2.5)
    /// ```
    var zoomCenterX: Float = 0.5

    /// @var zoomCenterY
    /// @brief 줌 중심 Y 좌표 (0.0 ~ 1.0)
    /// @details
    /// 확대할 때 중심으로 삼을 세로 위치입니다.
    ///
    /// 정규화 좌표:
    /// - **0.0**: 하단 (Metal 좌표계는 좌하단이 원점)
    /// - **0.5**: 가운데 (기본값)
    /// - **1.0**: 상단
    ///
    /// Metal 좌표계:
    /// ```
    /// (0.0, 1.0) ────────── (1.0, 1.0)
    ///    │                      │
    ///    │      화면             │
    ///    │                      │
    /// (0.0, 0.0) ────────── (1.0, 0.0)
    /// ```
    ///
    /// 주의:
    /// - 일반적인 화면 좌표 (좌상단 원점)와 반대
    /// - Metal/OpenGL은 좌하단 원점 사용
    var zoomCenterY: Float = 0.5

    // MARK: - Methods

    /// @brief 모든 변환 리셋
    ///
    /// @details
    /// 모든 파라미터를 기본값으로 되돌립니다.
    ///
    /// 리셋되는 값:
    /// ```
    /// brightness    → 0.0   (밝기 조절 없음)
    /// flipHorizontal → false (반전 없음)
    /// flipVertical   → false (반전 없음)
    /// zoomLevel      → 1.0   (확대 없음)
    /// zoomCenterX    → 0.5   (중앙)
    /// zoomCenterY    → 0.5   (중앙)
    /// ```
    ///
    /// mutating이란?
    /// - struct는 기본적으로 불변(immutable)
    /// - 자신의 프로퍼티를 변경하는 메서드는 mutating 필요
    /// - class는 mutating 불필요 (참조 타입)
    ///
    /// 사용 예:
    /// ```swift
    /// var transforms = VideoTransformations()
    /// transforms.brightness = 0.5
    /// transforms.zoomLevel = 2.0
    ///
    /// transforms.reset()
    /// // brightness = 0.0, zoomLevel = 1.0
    /// ```
    mutating func reset() {
        brightness = 0.0
        flipHorizontal = false
        flipVertical = false
        zoomLevel = 1.0
        zoomCenterX = 0.5
        zoomCenterY = 0.5
    }

    /// @var hasActiveTransformations
    /// @brief 활성 변환 확인
    /// @return true면 하나 이상의 변환이 활성화됨, false면 모든 값이 기본값
    /// @details
    /// 현재 어떤 변환이라도 적용되어 있는지 확인합니다.
    ///
    /// 활용 예:
    /// ```swift
    /// // 1. UI에서 "리셋" 버튼 표시/숨김
    /// if transforms.hasActiveTransformations {
    ///     showResetButton()  // 변환이 있으면 버튼 표시
    /// }
    ///
    /// // 2. 성능 최적화 (불필요한 셰이더 처리 스킵)
    /// if !transforms.hasActiveTransformations {
    ///     // 변환 없으면 원본 그대로 렌더링 (빠름)
    ///     renderOriginal()
    /// } else {
    ///     // 변환 있으면 셰이더 적용 (느림)
    ///     renderWithTransformations()
    /// }
    /// ```
    ///
    /// 확인하는 조건:
    /// ```
    /// brightness != 0.0      → 밝기 조절 있음
    /// flipHorizontal == true → 좌우 반전 있음
    /// flipVertical == true   → 상하 반전 있음
    /// zoomLevel != 1.0       → 줌 있음
    /// ```
    var hasActiveTransformations: Bool {
        return brightness != 0.0 ||
               flipHorizontal ||
               flipVertical ||
               zoomLevel != 1.0
    }
}

// MARK: - Video Transformation Service

/// @class VideoTransformationService
/// @brief 영상 변환 설정을 관리하고 UserDefaults에 영속적으로 저장하는 서비스
///
/// @details
/// ## 주요 책임:
/// 1. 변환 파라미터 관리 (brightness, flip, zoom)
/// 2. UserDefaults에 자동 저장/로드
/// 3. 값 검증 (범위 clamping)
/// 4. SwiftUI와 연동 (@Published, ObservableObject)
///
/// ## 싱글톤 패턴:
/// ```
/// 앱 전체에서 하나의 인스턴스만 사용
/// → 모든 화면에서 동일한 설정 공유
/// → 메모리 효율적
/// ```
///
/// ## SwiftUI 연동:
/// ```swift
/// struct SettingsView: View {
///     @ObservedObject var service = VideoTransformationService.shared
///
///     var body: some View {
///         Slider(value: $service.transformations.brightness)
///         // ↑ transformations가 변경되면 자동으로 UI 업데이트
///     }
/// }
/// ```
class VideoTransformationService: ObservableObject {

    // MARK: - Singleton

    /// @var shared
    /// @brief 싱글톤 인스턴스
    /// @details
    /// 싱글톤 패턴이란?
    /// 클래스의 인스턴스를 앱 전체에서 하나만 생성하는 패턴입니다.
    ///
    /// 장점:
    /// - 전역 접근 가능
    /// - 메모리 절약 (하나만 존재)
    /// - 상태 공유 용이
    ///
    /// 단점:
    /// - 테스트 어려움
    /// - 의존성 숨김
    ///
    /// 사용 예:
    /// ```swift
    /// // 어디서든 접근 가능:
    /// VideoTransformationService.shared.setBrightness(0.5)
    ///
    /// // 여러 곳에서 접근해도 같은 인스턴스:
    /// let service1 = VideoTransformationService.shared
    /// let service2 = VideoTransformationService.shared
    /// // service1 === service2 (true)
    /// ```
    static let shared = VideoTransformationService()

    // MARK: - Properties

    /// @var userDefaults
    /// @brief UserDefaults 인스턴스
    /// @details
    /// UserDefaults란?
    /// 앱의 간단한 설정을 저장하는 key-value 저장소입니다.
    ///
    /// 특징:
    /// - 앱 종료 후에도 데이터 유지
    /// - 작은 데이터만 저장 (설정, 옵션 등)
    /// - 자동 암호화 (iOS/macOS)
    ///
    /// 저장 위치:
    /// - macOS: ~/Library/Preferences/com.yourapp.plist
    /// - iOS: /Library/Preferences/
    ///
    /// 비유:
    /// - UserDefaults = "메모장"
    /// - 간단한 것만 적음 (밝기, 줌 등)
    /// - 큰 데이터는 파일/데이터베이스 사용
    private let userDefaults = UserDefaults.standard

    /// @var transformationsKey
    /// @brief UserDefaults 키
    /// @details
    /// 이 키로 설정을 저장/로드합니다.
    /// ```
    /// UserDefaults:
    /// {
    ///     "VideoTransformations": {
    ///         "brightness": 0.3,
    ///         "flipHorizontal": true,
    ///         "flipVertical": false,
    ///         "zoomLevel": 2.0,
    ///         "zoomCenterX": 0.5,
    ///         "zoomCenterY": 0.5
    ///     }
    /// }
    /// ```
    private let transformationsKey = "VideoTransformations"

    /// @var transformations
    /// @brief 현재 변환 설정
    /// @details
    /// @Published란?
    /// - Combine 프레임워크의 property wrapper
    /// - 값이 변경되면 자동으로 알림 발송
    /// - SwiftUI View가 자동으로 업데이트됨
    ///
    /// 작동 방식:
    /// ```
    /// transformations.brightness = 0.5  (값 변경)
    ///      ↓
    /// @Published가 감지
    ///      ↓
    /// objectWillChange.send()  (알림 발송)
    ///      ↓
    /// SwiftUI View 자동 재렌더링
    /// ```
    ///
    /// 구독 예제:
    /// ```swift
    /// service.$transformations
    ///     .sink { newValue in
    ///         print("변환 설정 변경: \(newValue)")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    @Published var transformations = VideoTransformations()

    // MARK: - Initialization

    /// @brief 프라이빗 초기화
    ///
    /// @details
    /// private init()이란?
    /// - 외부에서 인스턴스 생성 불가
    /// - 싱글톤 패턴 강제
    ///
    /// 사용 불가:
    /// ```swift
    /// let service = VideoTransformationService()  // 컴파일 에러!
    /// ```
    ///
    /// 사용 가능:
    /// ```swift
    /// let service = VideoTransformationService.shared  // OK
    /// ```
    ///
    /// 초기화 시 동작:
    /// 1. UserDefaults에서 저장된 설정 로드
    /// 2. 없으면 기본값 사용
    private init() {
        loadTransformations()
    }

    // MARK: - Persistence Methods

    /// @brief UserDefaults에서 설정 로드
    ///
    /// @details
    /// 앱 시작 시 호출되어 이전에 저장된 설정을 복원합니다.
    ///
    /// 처리 흐름:
    /// ```
    /// 1. UserDefaults에서 Data 가져오기
    ///    ↓
    /// 2. JSON → VideoTransformations 디코딩
    ///    ↓
    /// 3. transformations 프로퍼티 설정
    ///    ↓
    /// 4. 성공 로그 기록
    ///
    /// 실패 시:
    ///    → 기본값 사용 (reset 상태)
    ///    → 정보 로그 기록
    /// ```
    ///
    /// JSONDecoder란?
    /// JSON 데이터를 Swift 객체로 변환하는 도구입니다.
    ///
    /// ```
    /// JSON Data (UserDefaults):
    /// {
    ///     "brightness": 0.3,
    ///     "flipHorizontal": true,
    ///     ...
    /// }
    ///     ↓ JSONDecoder
    /// VideoTransformations(
    ///     brightness: 0.3,
    ///     flipHorizontal: true,
    ///     ...
    /// )
    /// ```
    ///
    /// 예외 처리:
    /// - 저장된 데이터 없음 → 기본값
    /// - JSON 파싱 실패 → 기본값
    /// - 데이터 손상 → 기본값
    func loadTransformations() {
        // ===== 1단계: UserDefaults에서 Data 가져오기 =====
        guard let data = userDefaults.data(forKey: transformationsKey),
              // ===== 2단계: JSON 디코딩 =====
              let loaded = try? JSONDecoder().decode(VideoTransformations.self, from: data) else {
            // 로드 실패 → 기본값 사용
            infoLog("[VideoTransformationService] No saved transformations found, using defaults")
            return
        }

        // ===== 3단계: 설정 적용 =====
        transformations = loaded

        // ===== 4단계: 로그 기록 =====
        infoLog("[VideoTransformationService] Loaded transformations: brightness=\(loaded.brightness), flipH=\(loaded.flipHorizontal), flipV=\(loaded.flipVertical), zoom=\(loaded.zoomLevel)")
    }

    /// @brief UserDefaults에 설정 저장
    ///
    /// @details
    /// 변환 설정이 변경될 때마다 호출되어 설정을 영속화합니다.
    ///
    /// 처리 흐름:
    /// ```
    /// 1. VideoTransformations → JSON 인코딩
    ///    ↓
    /// 2. UserDefaults에 Data 저장
    ///    ↓
    /// 3. 디스크에 자동 동기화
    ///    ↓
    /// 4. 로그 기록
    ///
    /// 실패 시:
    ///    → 에러 로그만 기록
    ///    → 설정은 메모리에 유지 (다음 저장 시도)
    /// ```
    ///
    /// JSONEncoder란?
    /// Swift 객체를 JSON 데이터로 변환하는 도구입니다.
    ///
    /// ```
    /// VideoTransformations(
    ///     brightness: 0.3,
    ///     flipHorizontal: true,
    ///     ...
    /// )
    ///     ↓ JSONEncoder
    /// JSON Data:
    /// {
    ///     "brightness": 0.3,
    ///     "flipHorizontal": true,
    ///     ...
    /// }
    /// ```
    ///
    /// 자동 호출:
    /// 모든 변환 메서드 (setBrightness, toggleFlip 등)가
    /// 이 메서드를 자동으로 호출합니다.
    ///
    /// ```swift
    /// service.setBrightness(0.5)
    ///   ↓ 내부에서 호출
    /// saveTransformations()
    ///   ↓
    /// UserDefaults에 저장됨
    /// ```
    func saveTransformations() {
        // ===== 1단계: JSON 인코딩 =====
        guard let data = try? JSONEncoder().encode(transformations) else {
            errorLog("[VideoTransformationService] Failed to encode transformations")
            return
        }

        // ===== 2단계: UserDefaults에 저장 =====
        // set(_:forKey:)는 즉시 반환하고, 백그라운드에서 디스크 동기화
        userDefaults.set(data, forKey: transformationsKey)

        // ===== 3단계: 로그 기록 =====
        debugLog("[VideoTransformationService] Saved transformations: brightness=\(transformations.brightness), flipH=\(transformations.flipHorizontal), flipV=\(transformations.flipVertical), zoom=\(transformations.zoomLevel)")
    }

    // MARK: - Transformation Methods

    /// @brief 밝기 설정
    ///
    /// @param value 밝기 값 (-1.0 ~ +1.0)
    ///
    /// @details
    /// 밝기 값을 설정하고, 범위를 검증한 후 저장합니다.
    ///
    /// 값 검증 (Clamping):
    /// ```
    /// 입력값 범위: -∞ ~ +∞
    ///      ↓ max(-1.0, ...)
    /// -1.0 ~ +∞
    ///      ↓ min(1.0, ...)
    /// -1.0 ~ +1.0 (최종)
    /// ```
    ///
    /// max, min 함수:
    /// ```swift
    /// max(-1.0, value)  // -1.0보다 작으면 -1.0로 제한
    /// min(1.0, value)   // 1.0보다 크면 1.0로 제한
    ///
    /// 예:
    /// - setBrightness(1.5)  → 1.0 (상한)
    /// - setBrightness(-2.0) → -1.0 (하한)
    /// - setBrightness(0.5)  → 0.5 (그대로)
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// // Slider에서 호출
    /// Slider(value: $brightness, in: -1.0...1.0)
    ///     .onChange(of: brightness) { newValue in
    ///         service.setBrightness(newValue)
    ///     }
    /// ```
    func setBrightness(_ value: Float) {
        // ===== 값 검증 (Clamping) =====
        let clamped = max(-1.0, min(1.0, value))

        // ===== 설정 적용 =====
        transformations.brightness = clamped

        // ===== 자동 저장 =====
        saveTransformations()
    }

    /// @brief 좌우 반전 토글
    ///
    /// @details
    /// 현재 상태를 반대로 전환합니다.
    ///
    /// toggle()이란?
    /// ```swift
    /// var flag = false
    /// flag.toggle()  // flag = true
    ///
    /// flag.toggle()  // flag = false
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// // 버튼 클릭 시
    /// Button("좌우 반전") {
    ///     service.toggleFlipHorizontal()
    /// }
    ///
    /// // 키보드 단축키
    /// .keyboardShortcut("h", modifiers: .command)
    /// ```
    ///
    /// 상태 변화:
    /// ```
    /// false → toggle() → true  → toggle() → false
    /// (반전 없음)        (좌우 반전)        (반전 없음)
    /// ```
    func toggleFlipHorizontal() {
        // ===== 상태 토글 =====
        transformations.flipHorizontal.toggle()

        // ===== 자동 저장 =====
        saveTransformations()
    }

    /// @brief 상하 반전 토글
    ///
    /// @details
    /// 현재 상태를 반대로 전환합니다.
    ///
    /// 사용 예:
    /// ```swift
    /// Button("상하 반전") {
    ///     service.toggleFlipVertical()
    /// }
    /// ```
    func toggleFlipVertical() {
        // ===== 상태 토글 =====
        transformations.flipVertical.toggle()

        // ===== 자동 저장 =====
        saveTransformations()
    }

    /// @brief 줌 레벨 설정
    ///
    /// @param level 줌 배율 (1.0 ~ 5.0)
    ///
    /// @details
    /// 줌 배율을 설정하고, 범위를 검증한 후 저장합니다.
    ///
    /// 값 검증:
    /// ```
    /// 최소: 1.0 (원본 크기)
    /// 최대: 5.0 (5배 확대)
    ///
    /// 예:
    /// - setZoomLevel(0.5)  → 1.0 (하한)
    /// - setZoomLevel(10.0) → 5.0 (상한)
    /// - setZoomLevel(2.5)  → 2.5 (그대로)
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// // Slider로 줌 조절
    /// Slider(value: $zoomLevel, in: 1.0...5.0, step: 0.1)
    ///     .onChange(of: zoomLevel) { newValue in
    ///         service.setZoomLevel(newValue)
    ///     }
    ///
    /// // 버튼으로 고정 배율
    /// Button("2배 확대") { service.setZoomLevel(2.0) }
    /// Button("리셋") { service.setZoomLevel(1.0) }
    /// ```
    ///
    /// 화질 손실:
    /// - 1.0 ~ 2.0: 화질 양호
    /// - 2.0 ~ 3.0: 약간 픽셀 보임
    /// - 3.0 ~ 5.0: 확실히 픽셀 보임
    func setZoomLevel(_ level: Float) {
        // ===== 값 검증 (1.0 ~ 5.0) =====
        let clamped = max(1.0, min(5.0, level))

        // ===== 설정 적용 =====
        transformations.zoomLevel = clamped

        // ===== 자동 저장 =====
        saveTransformations()
    }

    /// @brief 줌 중심점 설정
    ///
    /// @param x 가로 중심 (0.0 ~ 1.0)
    /// @param y 세로 중심 (0.0 ~ 1.0)
    ///
    /// @details
    /// 확대할 영역의 중심 좌표를 설정합니다.
    ///
    /// 값 검증:
    /// ```
    /// x, y 모두 0.0 ~ 1.0 범위로 제한
    ///
    /// 예:
    /// - x = -0.5 → 0.0 (좌측 끝)
    /// - x = 1.5  → 1.0 (우측 끝)
    /// - x = 0.7  → 0.7 (우측 70% 지점)
    /// ```
    ///
    /// 사용 예:
    /// ```swift
    /// // 마우스 클릭으로 줌 중심 이동
    /// .onTapGesture { location in
    ///     let x = Float(location.x / viewWidth)
    ///     let y = Float(location.y / viewHeight)
    ///     service.setZoomCenter(x: x, y: y)
    /// }
    ///
    /// // 고정 위치로 이동
    /// Button("좌상단") { service.setZoomCenter(x: 0.25, y: 0.75) }
    /// Button("중앙") { service.setZoomCenter(x: 0.5, y: 0.5) }
    /// Button("우하단") { service.setZoomCenter(x: 0.75, y: 0.25) }
    /// ```
    ///
    /// 좌표계 주의:
    /// - x: 0.0(좌) ~ 1.0(우)
    /// - y: 0.0(하) ~ 1.0(상) ← Metal 좌표계!
    func setZoomCenter(x: Float, y: Float) {
        // ===== 값 검증 (0.0 ~ 1.0) =====
        transformations.zoomCenterX = max(0.0, min(1.0, x))
        transformations.zoomCenterY = max(0.0, min(1.0, y))

        // ===== 자동 저장 =====
        saveTransformations()
    }

    /// @brief 모든 변환 리셋
    ///
    /// @details
    /// 모든 변환 효과를 기본값으로 되돌립니다.
    ///
    /// 리셋되는 것:
    /// - 밝기 → 0.0
    /// - 좌우 반전 → off
    /// - 상하 반전 → off
    /// - 줌 → 1.0 (원본)
    /// - 줌 중심 → 화면 중앙
    ///
    /// 사용 예:
    /// ```swift
    /// // "리셋" 버튼
    /// Button("모두 리셋") {
    ///     service.resetTransformations()
    /// }
    ///
    /// // 새 영상 로드 시 자동 리셋
    /// func loadNewVideo() {
    ///     service.resetTransformations()
    ///     // ... 영상 로드
    /// }
    /// ```
    ///
    /// 효과:
    /// - 즉시 원본 영상으로 복원
    /// - UserDefaults에 저장 (다음 실행 시도 리셋 상태)
    func resetTransformations() {
        // ===== VideoTransformations.reset() 호출 =====
        transformations.reset()

        // ===== 자동 저장 =====
        saveTransformations()

        // ===== 로그 기록 =====
        infoLog("[VideoTransformationService] Reset all transformations to default")
    }
}

/**
 # VideoTransformations 통합 가이드

 ## GPU 셰이더에서 사용:

 ### 1. Uniform Buffer 생성:
 ```swift
 // Swift 측:
 let transforms = service.transformations
 let uniformBuffer = device.makeBuffer(
     bytes: &transforms,
     length: MemoryLayout<VideoTransformations>.size,
     options: []
 )
 ```

 ### 2. Metal Shader에서 접근:
 ```metal
 // Shaders.metal
 struct Transforms {
     float brightness;
     bool flipHorizontal;
     bool flipVertical;
     float zoomLevel;
     float2 zoomCenter;
 };

 fragment float4 videoFragmentShader(
     VertexOut in [[stage_in]],
     texture2d<float> texture [[texture(0)]],
     constant Transforms &transforms [[buffer(0)]]
 ) {
     float2 coord = in.texCoord;

     // 반전 적용
     if (transforms.flipHorizontal) {
         coord.x = 1.0 - coord.x;
     }
     if (transforms.flipVertical) {
         coord.y = 1.0 - coord.y;
     }

     // 줌 적용
     coord = (coord - transforms.zoomCenter) / transforms.zoomLevel + transforms.zoomCenter;

     // 텍스처 샘플링
     float4 color = texture.sample(sampler, coord);

     // 밝기 적용
     color.rgb += transforms.brightness;
     color.rgb = clamp(color.rgb, 0.0, 1.0);

     return color;
 }
 ```

 ## SwiftUI에서 UI 구성:

 ```swift
 struct TransformationControlView: View {
     @ObservedObject var service = VideoTransformationService.shared

     var body: some View {
         VStack {
             // 밝기 슬라이더
             HStack {
                 Text("밝기")
                 Slider(value: $service.transformations.brightness,
                        in: -1.0...1.0)
                     .onChange(of: service.transformations.brightness) { value in
                         service.setBrightness(value)
                     }
                 Text(String(format: "%.2f", service.transformations.brightness))
             }

             // 반전 토글
             Toggle("좌우 반전", isOn: Binding(
                 get: { service.transformations.flipHorizontal },
                 set: { _ in service.toggleFlipHorizontal() }
             ))

             // 줌 컨트롤
             HStack {
                 Text("줌")
                 Slider(value: Binding(
                     get: { service.transformations.zoomLevel },
                     set: { service.setZoomLevel($0) }
                 ), in: 1.0...5.0, step: 0.1)
                 Text(String(format: "%.1fx", service.transformations.zoomLevel))
             }

             // 리셋 버튼
             if service.transformations.hasActiveTransformations {
                 Button("모두 리셋") {
                     service.resetTransformations()
                 }
             }
         }
         .padding()
     }
 }
 ```

 ## 성능 최적화 팁:

 1. **불필요한 셰이더 처리 스킵**
    ```swift
    if !transforms.hasActiveTransformations {
        // 원본 그대로 렌더링 (빠름)
        renderPassDescriptor.colorAttachments[0].texture = sourceTexture
    } else {
        // 셰이더 적용 (느림)
        applyTransformationsShader()
    }
    ```

 2. **변환 캐싱**
    ```swift
    private var cachedTransforms: VideoTransformations?
    private var cachedUniformBuffer: MTLBuffer?

    func updateUniformBuffer() {
        if cachedTransforms == service.transformations {
            return  // 변경 없으면 스킵
        }
        // ... buffer 업데이트
    }
    ```

 3. **UserDefaults 저장 빈도 제한**
    ```swift
    // Slider 드래그 중에는 저장 안 함 (성능)
    Slider(value: $brightness)
        .onDragEnded { _ in
            service.setBrightness(brightness)  // 드래그 끝날 때만 저장
        }
    ```
 */
