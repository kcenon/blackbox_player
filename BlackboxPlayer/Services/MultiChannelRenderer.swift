/// @file MultiChannelRenderer.swift
/// @brief Metal-based multi-channel video renderer
/// @author BlackboxPlayer Development Team
/// @details
/// Metal을 사용하여 여러 비디오 채널을 GPU에서 렌더링하는 클래스입니다.
///
/// ## Metal이란?
/// - Apple의 저수준 GPU 프로그래밍 API
/// - CPU가 아닌 GPU(그래픽 카드)에서 고속 연산 수행
/// - 게임, 비디오 처리, 머신러닝 등에 사용
/// - OpenGL의 후속 기술, 훨씬 빠르고 효율적
///
/// ## GPU vs CPU:
/// ```
/// CPU (중앙처리장치):
/// - 복잡한 논리 연산
/// - 순차적 처리
/// - 코어: 8~16개
/// - 예: 파일 읽기, 디코딩, 제어 로직
///
/// GPU (그래픽처리장치):
/// - 단순한 병렬 연산
/// - 동시 처리
/// - 코어: 수천 개
/// - 예: 영상 렌더링, 픽셀 처리, 이미지 변환
/// ```
///
/// ## 렌더링 파이프라인:
/// ```
/// VideoFrame (CPU 메모리)
///   ↓
/// CVPixelBuffer (공유 메모리)
///   ↓
/// MTLTexture (GPU 메모리)
///   ↓
/// Vertex Shader (GPU)
///   ↓
/// Fragment Shader (GPU)
///   ↓
/// 화면 출력 (Drawable)
/// ```
///
/// ## 주요 기능:
/// 1. **멀티 채널 렌더링**: 4개 채널을 동시에 GPU에서 처리
/// 2. **레이아웃 모드**: Grid, Focus, Horizontal 배치
/// 3. **비디오 변환**: 밝기, 반전, 확대/축소 (GPU 셰이더)
/// 4. **화면 캡처**: 렌더링된 프레임을 이미지로 저장
/// 5. **텍스처 캐싱**: CVMetalTextureCache로 성능 최적화
///
/// ## Metal 주요 개념:
/// - **MTLDevice**: GPU 장치
/// - **MTLCommandQueue**: 명령 큐 (작업 대기열)
/// - **MTLTexture**: GPU 메모리의 이미지
/// - **MTLBuffer**: GPU 메모리의 데이터
/// - **MTLRenderPipelineState**: 렌더링 설정 (셰이더, 포맷 등)
/// - **MTLCommandBuffer**: 명령 묶음
/// - **MTLRenderCommandEncoder**: 렌더링 명령 인코더

import Foundation
import Metal
import MetalKit
import CoreVideo
import AVFoundation

/// @class MultiChannelRenderer
/// @brief Metal-based multi-channel video renderer
///
/// @details
/// Metal을 사용하여 여러 비디오 채널을 GPU에서 렌더링하는 클래스입니다.
class MultiChannelRenderer {
    // MARK: - Properties (속성)

    /// @var device
    /// @brief Metal 장치 (GPU)
    ///
    /// @details
    /// MTLDevice란?
    /// - GPU를 나타내는 객체
    /// - 모든 Metal 리소스의 출발점
    /// - 버퍼, 텍스처, 파이프라인 등을 생성
    ///
    /// 생성:
    /// ```swift
    /// MTLCreateSystemDefaultDevice()
    /// // 시스템의 기본 GPU 반환
    /// // Mac: 내장 GPU 또는 외장 GPU
    /// // iOS: A-시리즈 칩의 GPU
    /// ```
    ///
    /// nil인 경우:
    /// - Metal을 지원하지 않는 구형 하드웨어
    /// - 가상머신 (VMware, Parallels)
    /// - 일부 클라우드 인스턴스
    private let device: MTLDevice

    /// @var commandQueue
    /// @brief 명령 큐 (Command Queue)
    ///
    /// @details
    /// Command Queue란?
    /// - GPU에게 보낼 명령들의 대기열
    /// - 마치 프린터의 인쇄 대기열과 같은 개념
    /// - 여러 명령을 순서대로 GPU에 제출
    ///
    /// 동작 방식:
    /// ```
    /// [명령1: 텍스처 로드] → GPU 처리
    /// [명령2: 프레임 렌더링] → 대기
    /// [명령3: 화면 출력] → 대기
    /// ```
    ///
    /// CPU vs GPU:
    /// - CPU: commandQueue.makeCommandBuffer() (명령 생성)
    /// - GPU: commandBuffer.commit() 후 실제 실행
    private let commandQueue: MTLCommandQueue

    /// @var pipelineState
    /// @brief 렌더 파이프라인 상태 (Render Pipeline State)
    ///
    /// @details
    /// Pipeline State란?
    /// - 렌더링 설정의 묶음
    /// - 어떤 셰이더를 사용할지
    /// - 픽셀 포맷은 무엇인지
    /// - 정점 속성은 무엇인지
    ///
    /// 왜 미리 생성하나?
    /// - 생성 비용이 높음 (수 밀리초)
    /// - 재사용하면 빠름 (마이크로초)
    /// - 프레임마다 생성하면 성능 저하
    ///
    /// Optional(?):
    /// - 초기화 실패 시 nil
    /// - setupPipeline()에서 생성
    private var pipelineState: MTLRenderPipelineState?

    /// @var textureCache
    /// @brief 텍스처 캐시 (Texture Cache)
    ///
    /// @details
    /// CVMetalTextureCache란?
    /// - CVPixelBuffer를 MTLTexture로 변환하는 캐시
    /// - CPU 메모리와 GPU 메모리 간 효율적 공유
    /// - 복사 없이 공유 메모리 사용 (Zero-Copy)
    ///
    /// 없으면 어떻게 되나?
    /// - 매번 CPU → GPU 메모리 복사
    /// - 느림 (수 밀리초)
    /// - 메모리 2배 사용
    ///
    /// 캐시 사용 시:
    /// - 공유 메모리 사용
    /// - 빠름 (마이크로초)
    /// - 메모리 절약
    ///
    /// CVPixelBuffer → CVMetalTexture → MTLTexture
    private var textureCache: CVMetalTextureCache?

    /// @var vertexBuffer
    /// @brief 정점 버퍼 (Vertex Buffer)
    ///
    /// @details
    /// Vertex Buffer란?
    /// - 정점(꼭짓점) 데이터를 담는 GPU 메모리
    /// - 여기서는 전체 화면을 덮는 사각형 (Quad)
    ///
    /// Vertex (정점)란?
    /// - 3D 모델의 점
    /// - 위치 (x, y) + 텍스처 좌표 (u, v)
    ///
    /// Full-Screen Quad:
    /// ```
    /// (-1, 1) ──────── (1, 1)    (0, 0) ──────── (1, 0)
    ///    │               │           │               │
    ///    │    화면        │           │   텍스처      │
    ///    │               │           │               │
    /// (-1,-1) ──────── (1,-1)    (0, 1) ──────── (1, 1)
    /// ```
    ///
    /// 왜 사각형 하나로 충분한가?
    /// - 각 채널마다 viewport만 다르게 설정
    /// - 같은 사각형을 여러 번 그림
    /// - GPU에서 매우 빠름
    private var vertexBuffer: MTLBuffer?

    /// @var layoutMode
    /// @brief 현재 레이아웃 모드 (Current Layout Mode)
    ///
    /// @details
    /// LayoutMode 종류:
    /// - .grid: 그리드 배치 (2×2, 2×3 등)
    /// - .focus: 하나 크게 + 나머지 작게
    /// - .horizontal: 가로로 나란히
    ///
    /// private(set):
    /// - 외부에서 읽기 가능
    /// - setLayoutMode()로만 변경 가능
    private(set) var layoutMode: LayoutMode = .grid

    /// @var focusedPosition
    /// @brief 포커스된 채널 (Focused Channel)
    ///
    /// @details
    /// Focus 레이아웃에서 크게 표시할 채널:
    /// - .front: 전방 카메라 (기본값)
    /// - .rear: 후방 카메라
    /// - .left, .right, .interior
    ///
    /// 사용:
    /// ```swift
    /// renderer.setLayoutMode(.focus)
    /// renderer.setFocusedPosition(.rear)
    /// // 후방 카메라를 크게, 나머지는 작게
    /// ```
    private(set) var focusedPosition: CameraPosition = .front

    /// @var samplerState
    /// @brief 샘플러 상태 (Sampler State)
    ///
    /// @details
    /// Sampler란?
    /// - 텍스처에서 픽셀 값을 읽는 방법 설정
    /// - 필터링 모드 (linear, nearest)
    /// - 경계 처리 (clamp, repeat)
    ///
    /// Linear vs Nearest:
    /// ```
    /// Nearest (가장 가까운 픽셀):
    /// [■][■][■][■]  → 계단 현상 (aliasing)
    ///
    /// Linear (선형 보간):
    /// [■▓░][■▓░]    → 부드러움
    /// ```
    ///
    /// Clamp vs Repeat:
    /// - Clamp: 경계에서 멈춤 (여백 없음)
    /// - Repeat: 경계에서 반복 (타일링)
    ///
    /// 설정:
    /// - minFilter, magFilter: .linear (부드러운 확대/축소)
    /// - addressMode: .clampToEdge (경계 반복 안 함)
    private var samplerState: MTLSamplerState?

    /// @var captureService
    /// @brief 화면 캡처 서비스 (Screen Capture Service)
    ///
    /// @details
    /// 역할:
    /// - 렌더링된 프레임을 이미지로 변환
    /// - PNG/JPEG 포맷 지원
    /// - 타임스탬프 오버레이
    /// - 파일 저장 다이얼로그
    ///
    /// 사용:
    /// ```swift
    /// renderer.captureAndSave(
    ///     format: .png,
    ///     timestamp: Date(),
    ///     defaultFilename: "Screenshot"
    /// )
    /// ```
    private(set) var captureService: ScreenCaptureService

    /// @var lastRenderedTexture
    /// @brief 마지막 렌더링된 텍스처 (Last Rendered Texture)
    ///
    /// @details
    /// 캡처를 위해 저장:
    /// - render() 호출 시 drawable.texture 저장
    /// - captureCurrentFrame()에서 사용
    /// - 마지막 프레임만 유지 (메모리 절약)
    ///
    /// Optional(?):
    /// - 초기에는 nil
    /// - 첫 렌더링 후 값 설정
    private var lastRenderedTexture: MTLTexture?

    /// @var transformationService
    /// @brief 변환 서비스 (Transformation Service)
    ///
    /// @details
    /// VideoTransformationService:
    /// - 밝기 (brightness)
    /// - 좌우 반전 (flipHorizontal)
    /// - 상하 반전 (flipVertical)
    /// - 확대/축소 (zoomLevel, zoomCenter)
    ///
    /// .shared: 싱글톤 패턴
    /// - 앱 전체에서 하나의 인스턴스만 사용
    /// - 설정이 모든 곳에서 공유됨
    private let transformationService = VideoTransformationService.shared

    /// @var uniformBuffer
    /// @brief 유니폼 버퍼 (Uniform Buffer)
    ///
    /// @details
    /// Uniform이란?
    /// - 모든 정점/픽셀에 동일하게 적용되는 값
    /// - 예: 밝기, 반전 여부, 확대 배율
    ///
    /// Uniform vs Attribute:
    /// - Attribute: 정점마다 다름 (위치, 텍스처 좌표)
    /// - Uniform: 모든 정점에 같음 (변환 파라미터)
    ///
    /// 버퍼 구조 (6개 float):
    /// ```
    /// [0] brightness      (밝기)
    /// [1] flipHorizontal  (좌우 반전)
    /// [2] flipVertical    (상하 반전)
    /// [3] zoomLevel       (확대 배율)
    /// [4] zoomCenterX     (확대 중심 X)
    /// [5] zoomCenterY     (확대 중심 Y)
    /// ```
    ///
    /// 셰이더와 공유:
    /// - CPU에서 값 업데이트
    /// - GPU 셰이더에서 읽기
    /// - 실시간 변환 적용
    private var uniformBuffer: MTLBuffer?

    // MARK: - Initialization (초기화)

    /// @brief 렌더러를 초기화합니다.
    ///
    /// @details
    /// Failable Initializer (init?):
    /// - 실패 가능한 초기화
    /// - nil 반환 가능
    /// - guard let으로 사용
    ///
    /// 초기화 과정:
    /// 1. Metal 장치 생성 (GPU)
    /// 2. Command Queue 생성
    /// 3. Texture Cache 생성
    /// 4. Capture Service 생성
    /// 5. Pipeline 설정
    /// 6. Vertex Buffer 생성
    /// 7. Sampler 설정
    /// 8. Uniform Buffer 생성
    ///
    /// 실패 원인:
    /// - Metal 미지원 하드웨어
    /// - 리소스 생성 실패
    init?() {
        // 1. Metal 장치 가져오기
        guard let device = MTLCreateSystemDefaultDevice() else {
            // MTLCreateSystemDefaultDevice():
            // - 시스템의 기본 GPU 반환
            // - nil: Metal 미지원

            print("Metal is not supported on this device")
            return nil
            // Failable init: nil 반환하여 초기화 실패
        }
        self.device = device

        // 2. Command Queue 생성
        guard let commandQueue = device.makeCommandQueue() else {
            // makeCommandQueue():
            // - 명령 대기열 생성
            // - nil: 생성 실패 (드물음)

            print("Failed to create Metal command queue")
            return nil
        }
        self.commandQueue = commandQueue

        // 3. Texture Cache 생성
        var cache: CVMetalTextureCache?
        // Optional 변수 선언 (포인터로 전달하기 위해)

        let result = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,  // 기본 메모리 할당자
            nil,                  // 캐시 옵션 (nil = 기본값)
            device,               // Metal 장치
            nil,                  // 텍스처 옵션 (nil = 기본값)
            &cache                // 결과를 저장할 변수의 포인터
        )
        // C API: 성공 코드 반환, 결과는 포인터로

        guard result == kCVReturnSuccess, let textureCache = cache else {
            // result 확인 + Optional 바인딩
            print("Failed to create texture cache")
            return nil
        }
        self.textureCache = textureCache

        // 4. Capture Service 생성
        self.captureService = ScreenCaptureService(device: device)
        // GPU 장치를 공유하여 성능 최적화

        // 5-8. 나머지 설정
        setupPipeline()       // 렌더 파이프라인
        setupVertexBuffer()   // 정점 버퍼
        setupSampler()        // 샘플러
        setupUniformBuffer()  // 유니폼 버퍼

        // 초기화 성공
        // nil 반환 안 함 = 정상 초기화
    }

    // MARK: - Setup (설정)

    /// @brief 렌더 파이프라인을 설정합니다.
    ///
    /// @details
    /// Pipeline이란?
    /// - 렌더링 과정의 단계들
    /// - 각 단계마다 설정 필요
    ///
    /// Pipeline 단계:
    /// ```
    /// 1. Vertex Shader   (정점 변환)
    ///    ↓
    /// 2. Rasterization   (픽셀 생성)
    ///    ↓
    /// 3. Fragment Shader (픽셀 색상 계산)
    ///    ↓
    /// 4. Output          (화면 출력)
    /// ```
    ///
    /// 설정 내용:
    /// - Vertex Shader 함수
    /// - Fragment Shader 함수
    /// - 픽셀 포맷 (BGRA8)
    /// - 정점 속성 (위치, 텍스처 좌표)
    private func setupPipeline() {
        // 1. Shader Library 생성
        guard let library = device.makeDefaultLibrary() else {
            // makeDefaultLibrary():
            // - 프로젝트의 .metal 파일들을 컴파일한 라이브러리
            // - 모든 셰이더 함수 포함

            print("Failed to create Metal library")
            return
        }

        // 2. Shader 함수 찾기
        guard let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            // makeFunction(name:):
            // - 이름으로 셰이더 함수 찾기
            // - MultiChannelShaders.metal 파일에 정의됨

            print("Failed to find shader functions")
            return
        }

        // 3. Pipeline Descriptor 생성
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        // Descriptor: 설정을 담는 객체

        pipelineDescriptor.vertexFunction = vertexFunction
        // 정점 셰이더 지정

        pipelineDescriptor.fragmentFunction = fragmentFunction
        // 픽셀 셰이더 지정

        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        // 출력 픽셀 포맷:
        // - BGRA: Blue, Green, Red, Alpha 순서
        // - 8: 채널당 8비트 (0~255)
        // - Unorm: Unsigned Normalized (0.0~1.0)

        // 4. Vertex Descriptor 설정
        let vertexDescriptor = MTLVertexDescriptor()
        // 정점 속성 레이아웃 정의

        // Position 속성 (attribute 0)
        vertexDescriptor.attributes[0].format = .float2
        // float2: 2개의 float (x, y)

        vertexDescriptor.attributes[0].offset = 0
        // 버퍼 시작부터의 오프셋 = 0바이트

        vertexDescriptor.attributes[0].bufferIndex = 0
        // 버퍼 인덱스 = 0

        // TexCoord 속성 (attribute 1)
        vertexDescriptor.attributes[1].format = .float2
        // float2: 2개의 float (u, v)

        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.size * 2
        // 오프셋 = 8바이트 (float 2개 크기)
        // position 다음부터 시작

        vertexDescriptor.attributes[1].bufferIndex = 0
        // 같은 버퍼 사용 (인터리브)

        // Layout 설정
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 4
        // Stride (간격): 16바이트
        // = float 4개 (position 2 + texCoord 2)

        vertexDescriptor.layouts[0].stepFunction = .perVertex
        // 정점마다 다음 데이터로 이동

        /*
         버퍼 레이아웃:
         [px, py, tx, ty, px, py, tx, ty, ...]
          └─────┘ └─────┘  ← 정점 1 (16바이트)
                  └─────┘ └─────┘  ← 정점 2
         */

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        // 5. Pipeline State 생성
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            // 생성 비용이 높음 (수 밀리초)
            // 한 번만 생성하고 재사용
        } catch {
            print("Failed to create pipeline state: \(error)")
        }
    }

    /// @brief 정점 버퍼를 생성합니다.
    ///
    /// @details
    /// Full-Screen Quad:
    /// - 화면 전체를 덮는 사각형
    /// - 2개의 삼각형으로 구성
    /// - Triangle Strip으로 그림
    ///
    /// Vertex 데이터:
    /// - Position: NDC (Normalized Device Coordinates)
    ///   - (-1,-1) = 왼쪽 아래
    ///   - (1, 1) = 오른쪽 위
    /// - TexCoord: 텍스처 좌표
    ///   - (0, 0) = 왼쪽 위
    ///   - (1, 1) = 오른쪽 아래
    ///
    /// Triangle Strip:
    /// ```
    /// 3 ──── 4        순서: 1→2→3→4
    /// │ ╲    │        삼각형1: 1,2,3
    /// │   ╲  │        삼각형2: 2,4,3
    /// 1 ──── 2
    /// ```
    private func setupVertexBuffer() {
        // Full-screen quad vertices (position + texCoord)
        let vertices: [Float] = [
            // Position (x, y)    TexCoord (u, v)
            -1.0, -1.0,           0.0, 1.0,  // Bottom-left
             1.0, -1.0,           1.0, 1.0,  // Bottom-right
            -1.0,  1.0,           0.0, 0.0,  // Top-left
             1.0,  1.0,           1.0, 0.0   // Top-right
        ]
        // 4개 정점 × 4개 float = 16개 float

        /*
         좌표 설명:
         NDC (Normalized Device Coordinates):
           (-1, 1) ──────── (1, 1)
              │               │
              │   화면 중심    │
              │     (0, 0)    │
              │               │
           (-1,-1) ──────── (1,-1)

         Texture Coordinates:
           (0, 0) ──────── (1, 0)
              │               │
              │               │
              │               │
           (0, 1) ──────── (1, 1)
         */

        let size = vertices.count * MemoryLayout<Float>.size
        // 16 × 4바이트 = 64바이트

        vertexBuffer = device.makeBuffer(bytes: vertices, length: size, options: [])
        // GPU 메모리에 정점 데이터 복사
        // options: [] = 기본 옵션
    }

    /// @brief 샘플러를 설정합니다.
    ///
    /// @details
    /// Sampler란?
    /// - 텍스처에서 색상을 읽는 방법
    /// - 필터링, 경계 처리 등 설정
    ///
    /// 설정 내용:
    /// - minFilter: 축소 필터 = linear
    /// - magFilter: 확대 필터 = linear
    /// - sAddressMode: S축(가로) 경계 = clampToEdge
    /// - tAddressMode: T축(세로) 경계 = clampToEdge
    /// - mipFilter: 밉맵 = 사용 안 함
    private func setupSampler() {
        let samplerDescriptor = MTLSamplerDescriptor()

        // Linear 필터링
        samplerDescriptor.minFilter = .linear
        // 축소 시: 인접 픽셀 보간
        samplerDescriptor.magFilter = .linear
        // 확대 시: 인접 픽셀 보간

        /*
         Linear vs Nearest:
         Original:  [R][G][B][W]

         Nearest:   [R][R][G][G][B][B][W][W]  (계단 현상)
         Linear:    [R][Y][G][C][B][P][W][W]  (부드러움)
                       ↑      ↑      ↑
                     보간된 색상
         */

        // Clamp 경계 처리
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        // 경계를 넘으면 가장자리 픽셀 반복

        /*
         Clamp vs Repeat:
         Clamp:  [ABC|ABC|ABC]  경계에서 멈춤
         Repeat: [ABC ABC ABC]  경계에서 반복 (타일링)
         */

        // 밉맵 사용 안 함
        samplerDescriptor.mipFilter = .notMipmapped
        // Mipmap: 여러 해상도의 텍스처 (성능 최적화)
        // 비디오는 원본 해상도만 사용

        samplerState = device.makeSamplerState(descriptor: samplerDescriptor)
    }

    /// @brief 유니폼 버퍼를 생성합니다.
    ///
    /// @details
    /// Uniform Buffer:
    /// - 변환 파라미터를 저장
    /// - CPU에서 업데이트
    /// - GPU 셰이더에서 읽기
    ///
    /// 버퍼 크기:
    /// - 6개 float × 4바이트 = 24바이트
    ///
    /// 버퍼 내용:
    /// - [0] brightness
    /// - [1] flipHorizontal
    /// - [2] flipVertical
    /// - [3] zoomLevel
    /// - [4] zoomCenterX
    /// - [5] zoomCenterY
    ///
    /// storageModeShared:
    /// - CPU와 GPU가 공유하는 메모리
    /// - CPU에서 쓰고, GPU에서 읽기
    /// - 복사 없이 빠름
    private func setupUniformBuffer() {
        // Create uniform buffer for transformation parameters
        // Size matches TransformUniforms struct in Metal shader (6 floats)
        let uniformSize = MemoryLayout<Float>.size * 6
        // Float 크기(4바이트) × 6 = 24바이트

        uniformBuffer = device.makeBuffer(length: uniformSize, options: [.storageModeShared])
        // 공유 메모리로 생성
        // CPU ↔ GPU 양방향 접근 가능

        if uniformBuffer == nil {
            errorLog("[MultiChannelRenderer] Failed to create uniform buffer")
        } else {
            debugLog("[MultiChannelRenderer] Created uniform buffer with size \(uniformSize) bytes")
        }
    }

    /// @brief 유니폼 버퍼를 업데이트합니다.
    ///
    /// @details
    /// 업데이트 과정:
    /// 1. 현재 변환 설정 가져오기
    /// 2. 버퍼 포인터 얻기
    /// 3. 각 값을 버퍼에 쓰기
    ///
    /// 호출 시점:
    /// - 매 프레임 렌더링 전
    /// - 변환 설정이 바뀌었을 때
    ///
    /// 성능:
    /// - 24바이트 복사: 매우 빠름 (나노초)
    /// - 공유 메모리: 복사 없음
    private func updateUniformBuffer() {
        guard let buffer = uniformBuffer else {
            return
        }

        // 1. 현재 변환 설정 가져오기
        let transformations = transformationService.transformations
        // VideoTransformationService.shared의 설정

        // 2. 버퍼 포인터 얻기
        let pointer = buffer.contents().assumingMemoryBound(to: Float.self)
        // contents(): UnsafeMutableRawPointer
        // assumingMemoryBound(to:): Float 포인터로 캐스팅

        // 3. 각 값 쓰기
        pointer[0] = transformations.brightness
        // 밝기: 0.0 (어두움) ~ 1.0 (보통) ~ 2.0 (밝음)

        pointer[1] = transformations.flipHorizontal ? 1.0 : 0.0
        // 좌우 반전: 1.0 = 반전, 0.0 = 정상

        pointer[2] = transformations.flipVertical ? 1.0 : 0.0
        // 상하 반전: 1.0 = 반전, 0.0 = 정상

        pointer[3] = transformations.zoomLevel
        // 확대 배율: 1.0 (100%) ~ 2.0 (200%)

        pointer[4] = transformations.zoomCenterX
        // 확대 중심 X: 0.0 (왼쪽) ~ 1.0 (오른쪽)

        pointer[5] = transformations.zoomCenterY
        // 확대 중심 Y: 0.0 (위) ~ 1.0 (아래)

        /*
         버퍼 메모리 레이아웃:
         [brightness][flipH][flipV][zoom][centerX][centerY]
          4바이트     4바이트  4바이트  4바이트  4바이트  4바이트
         */
    }

    // MARK: - Public Methods (공개 메서드)

    /// @brief 프레임들을 drawable에 렌더링합니다.
    ///
    /// @param frames 각 채널의 프레임 (카메라 위치 → 프레임)
    /// @param drawable 렌더링 대상 (화면 버퍼)
    /// @param drawableSize 화면 크기
    ///
    /// @details
    /// Drawable이란?
    /// - 화면에 표시될 최종 이미지
    /// - MTKView가 제공
    /// - 더블 버퍼링 (Front + Back buffer)
    ///
    /// 렌더링 과정:
    /// 1. Command Buffer 생성
    /// 2. Render Pass 설정 (화면 지우기)
    /// 3. Render Encoder 생성
    /// 4. Viewport 계산 (각 채널의 위치/크기)
    /// 5. 각 채널 렌더링
    ///    - Pixel Buffer → Texture 변환
    ///    - Viewport 설정
    ///    - Buffers 바인딩
    ///    - Draw 호출
    /// 6. 화면 출력 (Present)
    func render(
        frames: [CameraPosition: VideoFrame],
        to drawable: CAMetalDrawable,
        drawableSize: CGSize
    ) {
        // 1. Pipeline 확인
        guard let pipelineState = pipelineState else {
            return  // 초기화 안 됨
        }

        // 2. 프레임 확인
        guard !frames.isEmpty else {
            return  // 렌더링할 프레임 없음
        }

        // 3. Command Buffer 생성
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        // Command Buffer: GPU 명령들을 담는 컨테이너

        // 4. Render Pass Descriptor 생성
        let renderPassDescriptor = MTLRenderPassDescriptor()
        // Render Pass: 렌더링 작업 단위

        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        // 렌더링 대상: drawable의 텍스처 (화면 버퍼)

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        // Load Action: 렌더링 시작 시 동작
        // .clear: 화면 지우기

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        // 지울 색: 검정색 (R=0, G=0, B=0, A=1)

        renderPassDescriptor.colorAttachments[0].storeAction = .store
        // Store Action: 렌더링 종료 시 동작
        // .store: 결과 저장

        // 5. Render Encoder 생성
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        // Render Encoder: 렌더링 명령을 인코딩

        // 6. Pipeline State 설정
        renderEncoder.setRenderPipelineState(pipelineState)
        // 어떤 셰이더 사용할지 설정

        // 7. Uniform Buffer 업데이트
        updateUniformBuffer()
        // 변환 파라미터를 최신 값으로 업데이트

        // 8. 정렬된 채널 목록 생성
        let sortedPositions = frames.keys.sorted { $0.rawValue < $1.rawValue }
        // 스레드 안전한 순서 보장
        // rawValue 순서: front, rear, left, right, interior

        // 9. Viewport 계산
        let viewports = calculateViewports(for: sortedPositions, in: drawableSize)
        // 각 채널의 화면 위치와 크기 계산
        // 레이아웃 모드에 따라 다름

        // 10. 각 채널 렌더링
        for (position, frame) in frames {
            // 10-1. Viewport 확인
            guard let viewport = viewports[position] else {
                debugLog("[MultiChannelRenderer] No viewport for position \(position.displayName)")
                continue  // 다음 채널로
            }

            // 10-2. Pixel Buffer 변환
            guard let pixelBuffer = frame.toPixelBuffer() else {
                debugLog("[MultiChannelRenderer] Failed to create pixel buffer for frame at \(String(format: "%.2f", frame.timestamp))s")
                continue
            }
            // VideoFrame의 픽셀 데이터를 CVPixelBuffer로 변환

            // 10-3. Texture 생성
            guard let texture = createTexture(from: pixelBuffer) else {
                debugLog("[MultiChannelRenderer] Failed to create texture from pixel buffer")
                continue
            }
            // CVPixelBuffer → MTLTexture (GPU 메모리)

            // 10-4. Viewport 설정
            renderEncoder.setViewport(MTLViewport(
                originX: Double(viewport.origin.x),
                originY: Double(viewport.origin.y),
                width: Double(viewport.size.width),
                height: Double(viewport.size.height),
                znear: 0.0,
                zfar: 1.0
            ))
            // 이 채널을 그릴 화면 영역 지정

            // 10-5. Vertex Buffer 바인딩
            if let vertexBuffer = vertexBuffer {
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                // 정점 데이터 (사각형 4개 정점)
            }

            // 10-6. Uniform Buffer 바인딩
            if let uniformBuffer = uniformBuffer {
                renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
                // Vertex Shader의 buffer(1)

                renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 0)
                // Fragment Shader의 buffer(0)
            }

            // 10-7. Texture 바인딩
            renderEncoder.setFragmentTexture(texture, index: 0)
            // Fragment Shader의 texture(0)

            // 10-8. Sampler 바인딩
            if let samplerState = samplerState {
                renderEncoder.setFragmentSamplerState(samplerState, index: 0)
                // Fragment Shader의 sampler(0)
            }

            // 10-9. Draw 호출
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            // Triangle Strip: 4개 정점으로 2개 삼각형 그리기
            // GPU에서 Vertex Shader → Rasterization → Fragment Shader 실행
        }

        // 11. Encoding 종료
        renderEncoder.endEncoding()
        // 더 이상 렌더링 명령 없음

        // 12. 마지막 텍스처 저장 (캡처용)
        lastRenderedTexture = drawable.texture

        // 13. Drawable 표시
        commandBuffer.present(drawable)
        // 화면에 출력 (Front/Back buffer 교환)

        // 14. Command Buffer 제출
        commandBuffer.commit()
        // GPU에 명령 전달
        // 이제 GPU가 실제로 렌더링 시작
    }

    /// @brief 현재 프레임을 이미지로 캡처합니다.
    ///
    /// @param format 이미지 포맷 (.png 또는 .jpeg)
    /// @param timestamp 오버레이할 날짜/시간
    /// @param videoTimestamp 비디오 재생 시간
    ///
    /// @return 이미지 데이터 (nil = 실패)
    ///
    /// @details
    /// 캡처 과정:
    /// 1. 마지막 렌더링된 텍스처 확인
    /// 2. ScreenCaptureService로 변환
    /// 3. PNG/JPEG 데이터 반환
    func captureCurrentFrame(
        format: CaptureImageFormat = .png,
        timestamp: Date? = nil,
        videoTimestamp: TimeInterval? = nil
    ) -> Data? {
        guard let texture = lastRenderedTexture else {
            errorLog("[MultiChannelRenderer] No rendered texture available for capture")
            return nil
        }

        return captureService.captureFrame(
            from: texture,
            format: format,
            timestamp: timestamp,
            videoTimestamp: videoTimestamp
        )
    }

    /// @brief 현재 프레임을 캡처하고 저장 다이얼로그를 표시합니다.
    ///
    /// @param format 이미지 포맷
    /// @param timestamp 오버레이할 날짜/시간 (기본: 현재 시간)
    /// @param videoTimestamp 비디오 재생 시간
    /// @param defaultFilename 기본 파일명 (확장자 제외)
    ///
    /// @return 저장 성공 여부
    ///
    /// @details
    /// 편의 메서드:
    /// - captureCurrentFrame() + 파일 저장
    /// - NSSavePanel로 저장 위치 선택
    /// - 자동으로 확장자 추가 (.png 또는 .jpg)
    ///
    /// @discardableResult:
    /// - 반환값을 무시해도 경고 안 나옴
    /// - renderer.captureAndSave() // OK
    @discardableResult
    func captureAndSave(
        format: CaptureImageFormat = .png,
        timestamp: Date? = Date(),
        videoTimestamp: TimeInterval? = nil,
        defaultFilename: String = "BlackboxCapture"
    ) -> Bool {
        guard let data = captureCurrentFrame(
            format: format,
            timestamp: timestamp,
            videoTimestamp: videoTimestamp
        ) else {
            return false
        }

        return captureService.showSavePanel(
            data: data,
            format: format,
            defaultFilename: defaultFilename
        )
    }

    /// @brief 레이아웃 모드를 설정합니다.
    ///
    /// @param mode 새 레이아웃 모드
    ///
    /// @details
    /// 레이아웃 모드:
    /// - .grid: 그리드 배치 (2×2, 2×3 등)
    /// - .focus: 하나 크게 + 나머지 작게
    /// - .horizontal: 가로로 나란히
    func setLayoutMode(_ mode: LayoutMode) {
        self.layoutMode = mode
    }

    /// @brief 포커스할 채널을 설정합니다.
    ///
    /// @param position 포커스할 카메라 위치
    ///
    /// @details
    /// Focus 레이아웃에서만 사용:
    /// - 지정된 채널을 크게 표시
    /// - 나머지 채널은 작게 표시
    func setFocusedPosition(_ position: CameraPosition) {
        self.focusedPosition = position
    }

    // MARK: - Private Methods (비공개 메서드)

    /// @brief Pixel Buffer에서 Metal Texture를 생성합니다.
    ///
    /// @param pixelBuffer 변환할 CVPixelBuffer
    ///
    /// @return GPU 텍스처 (nil = 실패)
    ///
    /// @details
    /// 변환 과정:
    /// 1. Texture Cache 사용
    /// 2. CVMetalTextureCache로 변환
    /// 3. MTLTexture 추출
    ///
    /// Zero-Copy:
    /// - 메모리 복사 없이 공유
    /// - CPU 메모리와 GPU 메모리 공유
    /// - 빠르고 효율적
    private func createTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else {
            debugLog("[MultiChannelRenderer] Texture cache is nil")
            return nil
        }

        // 1. Pixel Buffer 정보 가져오기
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        debugLog("[MultiChannelRenderer] Creating texture: \(width)x\(height), format: \(pixelFormat)")

        // 2. CVMetalTexture 생성
        var texture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,    // 메모리 할당자
            textureCache,           // 텍스처 캐시
            pixelBuffer,            // 원본 Pixel Buffer
            nil,                    // 옵션 (nil = 기본값)
            .bgra8Unorm,            // Metal 픽셀 포맷
            width,                  // 너비
            height,                 // 높이
            0,                      // Plane 인덱스 (0 = 첫 번째)
            &texture                // 결과를 저장할 변수
        )

        guard result == kCVReturnSuccess else {
            errorLog("[MultiChannelRenderer] CVMetalTextureCacheCreateTextureFromImage failed with code: \(result)")
            return nil
        }

        guard let cvTexture = texture else {
            errorLog("[MultiChannelRenderer] CVMetalTexture is nil after successful creation")
            return nil
        }

        // 3. MTLTexture 추출
        guard let metalTexture = CVMetalTextureGetTexture(cvTexture) else {
            errorLog("[MultiChannelRenderer] Failed to get MTLTexture from CVMetalTexture")
            return nil
        }

        debugLog("[MultiChannelRenderer] Successfully created Metal texture")
        return metalTexture
    }

    /// @brief 각 채널의 viewport를 계산합니다.
    ///
    /// @param positions 채널 위치 배열 (정렬됨)
    /// @param size 전체 화면 크기
    ///
    /// @return 각 채널의 viewport
    ///
    /// @details
    /// Viewport란?
    /// - 화면에서 렌더링할 영역
    /// - 위치 (x, y) + 크기 (width, height)
    ///
    /// 레이아웃 모드별 계산:
    /// - .grid: calculateGridViewports
    /// - .focus: calculateFocusViewports
    /// - .horizontal: calculateHorizontalViewports
    private func calculateViewports(
        for positions: [CameraPosition],
        in size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]

        switch layoutMode {
        case .grid:
            viewports = calculateGridViewports(positions: positions, size: size)
        case .focus:
            viewports = calculateFocusViewports(positions: positions, size: size)
        case .horizontal:
            viewports = calculateHorizontalViewports(positions: positions, size: size)
        }

        return viewports
    }

    /// @brief 그리드 레이아웃의 viewport를 계산합니다.
    ///
    /// @param positions 채널 위치 배열
    /// @param size 전체 화면 크기
    ///
    /// @return 각 채널의 viewport
    ///
    /// @details
    /// Grid Layout:
    /// - N×M 그리드 (행×열)
    /// - 자동으로 최적 배치 계산
    ///
    /// 계산 방법:
    /// 1. 채널 수에서 √N (제곱근)
    /// 2. 올림하여 열 수 계산
    /// 3. 행 수 = 채널 수 / 열 수 (올림)
    /// 4. 각 셀 크기 = 화면 / 그리드
    ///
    /// 예:
    /// - 1채널: 1×1 (전체 화면)
    /// - 2채널: 1×2 (가로 2개)
    /// - 3채널: 2×2 (3개 + 빈 공간 1개)
    /// - 4채널: 2×2
    /// - 5채널: 2×3 (5개 + 빈 공간 1개)
    private func calculateGridViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let count = positions.count

        // 1. 그리드 크기 계산
        let cols = Int(ceil(sqrt(Double(count))))
        // sqrt: 제곱근
        // ceil: 올림
        // 예: count=4 → sqrt(4)=2.0 → ceil(2.0)=2

        let rows = Int(ceil(Double(count) / Double(cols)))
        // 행 수 = 채널 수 / 열 수 (올림)
        // 예: count=5, cols=3 → ceil(5/3)=2

        // 2. 셀 크기 계산
        let cellWidth = size.width / CGFloat(cols)
        let cellHeight = size.height / CGFloat(rows)

        // 3. 각 채널의 viewport 계산
        for (index, position) in positions.enumerated() {
            // enumerated(): (인덱스, 요소) 튜플 반환

            let col = index % cols
            // 열 = 인덱스를 열 수로 나눈 나머지
            // 예: index=3, cols=2 → col=1

            let row = index / cols
            // 행 = 인덱스를 열 수로 나눈 몫
            // 예: index=3, cols=2 → row=1

            let x = CGFloat(col) * cellWidth
            let y = CGFloat(row) * cellHeight

            viewports[position] = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
        }

        /*
         예: 4채널 Grid (2×2)
         ┌─────────┬─────────┐
         │ Front   │ Rear    │
         │ (0,0)   │ (1,0)   │
         ├─────────┼─────────┤
         │ Left    │ Right   │
         │ (0,1)   │ (1,1)   │
         └─────────┴─────────┘
         */

        return viewports
    }

    /// @brief 포커스 레이아웃의 viewport를 계산합니다.
    ///
    /// @param positions 채널 위치 배열
    /// @param size 전체 화면 크기
    ///
    /// @return 각 채널의 viewport
    ///
    /// @details
    /// Focus Layout:
    /// - 하나의 채널을 크게 (75% 너비)
    /// - 나머지는 작게 (25% 너비, 세로로 나열)
    ///
    /// 배치:
    /// - 왼쪽 75%: 포커스된 채널
    /// - 오른쪽 25%: 나머지 채널들 (썸네일)
    ///
    /// 예:
    /// ```
    /// ┌─────────────────────┬──────┐
    /// │                     │Rear  │
    /// │                     ├──────┤
    /// │   Front (포커스)      │Left  │
    /// │                     ├──────┤
    /// │                     │Right │
    /// └─────────────────────┴──────┘
    /// ```
    private func calculateFocusViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]

        // 1. 메인 viewport 크기
        let mainWidth = size.width * 0.75   // 75% 너비
        let mainHeight = size.height        // 전체 높이

        // 2. 썸네일 영역 크기
        let thumbWidth = size.width * 0.25  // 25% 너비
        let thumbHeight = size.height / CGFloat(max(1, positions.count - 1))
        // 나머지 채널 수로 높이 나눔
        // max(1, ...): 0으로 나누기 방지

        // 3. 썸네일 인덱스
        var thumbnailIndex = 0

        // 4. 각 채널 배치
        for position in positions {
            if position == focusedPosition {
                // 포커스된 채널: 왼쪽 큰 영역
                viewports[position] = CGRect(x: 0, y: 0, width: mainWidth, height: mainHeight)
            } else {
                // 나머지 채널: 오른쪽 작은 영역
                let y = CGFloat(thumbnailIndex) * thumbHeight
                viewports[position] = CGRect(x: mainWidth, y: y, width: thumbWidth, height: thumbHeight)
                thumbnailIndex += 1
            }
        }

        return viewports
    }

    /// @brief 가로 레이아웃의 viewport를 계산합니다.
    ///
    /// @param positions 채널 위치 배열
    /// @param size 전체 화면 크기
    ///
    /// @return 각 채널의 viewport
    ///
    /// @details
    /// Horizontal Layout:
    /// - 모든 채널을 가로로 나란히 배치
    /// - 같은 너비로 분할
    /// - 전체 높이 사용
    ///
    /// 예:
    /// ```
    /// 4채널:
    /// ┌─────┬─────┬─────┬─────┐
    /// │Front│Rear │Left │Right│
    /// │     │     │     │     │
    /// └─────┴─────┴─────┴─────┘
    /// ```
    private func calculateHorizontalViewports(
        positions: [CameraPosition],
        size: CGSize
    ) -> [CameraPosition: CGRect] {
        var viewports: [CameraPosition: CGRect] = [:]
        let count = positions.count

        guard count > 0 else {
            return viewports  // 채널 없으면 빈 딕셔너리
        }

        // 1. 셀 크기 계산
        let cellWidth = size.width / CGFloat(count)
        // 너비를 채널 수로 나눔

        let cellHeight = size.height
        // 전체 높이 사용

        // 2. 각 채널 배치
        for (index, position) in positions.enumerated() {
            let x = CGFloat(index) * cellWidth
            viewports[position] = CGRect(x: x, y: 0, width: cellWidth, height: cellHeight)
        }

        return viewports
    }
}

// MARK: - Supporting Types (지원 타입)

/// @enum LayoutMode
/// @brief 멀티 채널 표시 레이아웃 모드
///
/// @details
/// enum + String:
/// - rawValue로 문자열 사용
/// - UserDefaults 저장/불러오기 편리
///
/// CaseIterable:
/// - LayoutMode.allCases로 모든 케이스 접근
/// - UI 선택 메뉴 생성 시 유용
enum LayoutMode: String, CaseIterable {
    /// @var grid
    /// @brief Grid 레이아웃 (그리드)
    ///
    /// @details
    /// N×M 그리드로 배치:
    /// - 1채널: 1×1 (전체 화면)
    /// - 2채널: 1×2 (가로 2분할)
    /// - 3채널: 2×2 (4칸 중 3개 사용)
    /// - 4채널: 2×2
    /// - 5채널: 2×3 (6칸 중 5개 사용)
    case grid       // Grid layout (2x2, 2x3, etc.)

    /// @var focus
    /// @brief Focus 레이아웃 (포커스)
    ///
    /// @details
    /// 하나 크게 + 나머지 작게:
    /// - 왼쪽 75%: 포커스된 채널
    /// - 오른쪽 25%: 나머지 썸네일
    case focus      // One large + thumbnails

    /// @var horizontal
    /// @brief Horizontal 레이아웃 (가로)
    ///
    /// @details
    /// 가로로 나란히:
    /// - 같은 너비로 분할
    /// - 전체 높이 사용
    case horizontal // Side-by-side horizontal

    /// @brief UI에 표시할 이름
    ///
    /// @return 사용자 친화적 이름
    ///
    /// @details
    /// computed property:
    /// - 각 케이스의 사용자 친화적 이름
    /// - 메뉴, 버튼 등에 표시
    var displayName: String {
        switch self {
        case .grid:
            return "Grid"
        case .focus:
            return "Focus"
        case .horizontal:
            return "Horizontal"
        }
    }
}
