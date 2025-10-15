/// @file SettingsView.swift
/// @brief 앱 설정 페이지
/// @author BlackboxPlayer Development Team
/// @details
/// 앱의 모든 설정을 관리하는 설정 페이지입니다.
/// 카테고리별로 설정을 그룹화하여 표시합니다.

import SwiftUI

/// 앱 설정 뷰
///
/// ## 설정 카테고리
/// - UI 설정: 사이드바, 디버그 로그 표시 여부
/// - 오버레이 설정: GPS, 메타데이터, 지도, 그래프 오버레이 기본값
/// - 재생 설정: 기본 재생 속도, 볼륨, 자동 재생
/// - 비디오 설정: 레이아웃 모드, 컨트롤 자동 숨김 시간
/// - 성능 설정: 프레임율, 하드웨어 가속
///
/// ## 사용 예
/// ```swift
/// .sheet(isPresented: $showSettings) {
///     SettingsView()
/// }
/// ```
struct SettingsView: View {
    // MARK: - Properties

    /// 앱 설정 (Singleton)
    @ObservedObject var settings = AppSettings.shared

    /// 설정 창 닫기 액션
    @Environment(\.dismiss) private var dismiss

    /// 리셋 확인 알림 표시 여부
    @State private var showResetAlert = false

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header

            Divider()

            // 설정 컨텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    uiSettingsSection
                    overlaySettingsSection
                    playbackSettingsSection
                    videoSettingsSection
                    performanceSettingsSection
                }
                .padding(24)
            }

            Divider()

            // 하단 버튼
            footer
        }
        .frame(width: 600, height: 700)
        .alert("설정 초기화", isPresented: $showResetAlert) {
            Button("취소", role: .cancel) { }
            Button("초기화", role: .destructive) {
                settings.resetToDefaults()
            }
        } message: {
            Text("모든 설정을 기본값으로 초기화하시겠습니까?")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("설정")
                .font(.system(size: 24, weight: .bold))

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("닫기")
        }
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: { showResetAlert = true }) {
                Text("기본값으로 초기화")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { dismiss() }) {
                Text("완료")
                    .frame(width: 80)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - UI Settings Section

    private var uiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "UI 설정",
                icon: "sidebar.left",
                description: "사용자 인터페이스 표시 설정"
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.showSidebarByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("사이드바 기본 표시")
                            .font(.body)
                        Text("앱 실행 시 사이드바를 표시합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showDebugLogByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("디버그 로그 기본 표시")
                            .font(.body)
                        Text("앱 실행 시 디버그 로그를 표시합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Overlay Settings Section

    private var overlaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "오버레이 설정",
                icon: "square.stack.3d.up",
                description: "비디오 위에 표시되는 정보 레이어 설정"
            )

            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.showGPSOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GPS 오버레이 기본 표시")
                            .font(.body)
                        Text("속도, 좌표 등 GPS 정보를 표시합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showMetadataOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("메타데이터 오버레이 기본 표시")
                            .font(.body)
                        Text("비디오 파일 정보를 표시합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showMapOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("지도 오버레이 기본 표시")
                            .font(.body)
                        Text("GPS 궤적을 지도 위에 표시합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.showGraphOverlayByDefault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("그래프 오버레이 기본 표시")
                            .font(.body)
                        Text("속도, 가속도 등의 그래프를 표시합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Playback Settings Section

    private var playbackSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "재생 설정",
                icon: "play.circle",
                description: "비디오 재생 관련 설정"
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("기본 재생 속도")
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.2fx", settings.defaultPlaybackSpeed))
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.defaultPlaybackSpeed, in: 0.25...4.0, step: 0.25)

                    HStack {
                        Text("0.25x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("4.0x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("기본 볼륨")
                            .font(.body)
                        Spacer()
                        Text("\(Int(settings.defaultVolume * 100))%")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.defaultVolume, in: 0.0...1.0, step: 0.05)

                    HStack {
                        Text("0%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("100%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Toggle(isOn: $settings.autoPlayOnSelect) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("파일 선택 시 자동 재생")
                            .font(.body)
                        Text("파일을 선택하면 자동으로 재생을 시작합니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Video Settings Section

    private var videoSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "비디오 설정",
                icon: "video",
                description: "비디오 표시 관련 설정"
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("기본 레이아웃 모드")
                        .font(.body)

                    Picker("", selection: $settings.defaultLayoutMode) {
                        Text("그리드").tag("grid")
                        Text("단일 화면").tag("single")
                        Text("PIP").tag("pip")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("컨트롤 자동 숨김 시간")
                            .font(.body)
                        Spacer()
                        Text(String(format: "%.1f초", settings.controlsAutoHideDelay))
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $settings.controlsAutoHideDelay, in: 1.0...10.0, step: 0.5)

                    HStack {
                        Text("1초")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("10초")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Performance Settings Section

    private var performanceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "성능 설정",
                icon: "speedometer",
                description: "비디오 재생 성능 관련 설정"
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("목표 프레임율")
                            .font(.body)
                        Spacer()
                        Text("\(settings.targetFrameRate) FPS")
                            .font(.body.monospacedDigit())
                            .foregroundColor(.secondary)
                    }

                    Picker("", selection: $settings.targetFrameRate) {
                        Text("24 FPS").tag(24)
                        Text("30 FPS").tag(30)
                        Text("60 FPS").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Toggle(isOn: $settings.useHardwareAcceleration) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("하드웨어 가속 사용")
                            .font(.body)
                        Text("GPU를 사용하여 비디오 디코딩 성능을 향상시킵니다")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.leading, 8)
        }
    }

    // MARK: - Helper Views

    /// 섹션 헤더
    private func sectionHeader(title: String, icon: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.accentColor)

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
