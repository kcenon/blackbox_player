/// @file AppSettings.swift
/// @brief 앱 설정 모델
/// @author BlackboxPlayer Development Team
/// @details
/// 앱의 전역 설정을 관리하는 모델입니다.
/// UserDefaults를 사용하여 설정을 저장하고 불러옵니다.

import Foundation
import SwiftUI

/// @struct AppSettings
/// @brief 앱 설정 관리 클래스
/// @details
/// ObservableObject로 구현되어 설정 변경 시 자동으로 UI 업데이트
class AppSettings: ObservableObject {
    // MARK: - Singleton

    static let shared = AppSettings()

    private init() {
        loadSettings()
    }

    // MARK: - UI Settings

    /// 사이드바 기본 표시 여부
    @Published var showSidebarByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showSidebarByDefault, forKey: "showSidebarByDefault") }
    }

    /// 디버그 로그 기본 표시 여부
    @Published var showDebugLogByDefault: Bool = false {
        didSet { UserDefaults.standard.set(showDebugLogByDefault, forKey: "showDebugLogByDefault") }
    }

    // MARK: - Overlay Settings

    /// GPS 오버레이 기본 표시 여부
    @Published var showGPSOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showGPSOverlayByDefault, forKey: "showGPSOverlayByDefault") }
    }

    /// 메타데이터 오버레이 기본 표시 여부
    @Published var showMetadataOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showMetadataOverlayByDefault, forKey: "showMetadataOverlayByDefault") }
    }

    /// 지도 오버레이 기본 표시 여부
    @Published var showMapOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showMapOverlayByDefault, forKey: "showMapOverlayByDefault") }
    }

    /// 그래프 오버레이 기본 표시 여부
    @Published var showGraphOverlayByDefault: Bool = true {
        didSet { UserDefaults.standard.set(showGraphOverlayByDefault, forKey: "showGraphOverlayByDefault") }
    }

    // MARK: - Playback Settings

    /// 기본 재생 속도
    @Published var defaultPlaybackSpeed: Double = 1.0 {
        didSet { UserDefaults.standard.set(defaultPlaybackSpeed, forKey: "defaultPlaybackSpeed") }
    }

    /// 기본 볼륨
    @Published var defaultVolume: Double = 0.8 {
        didSet { UserDefaults.standard.set(defaultVolume, forKey: "defaultVolume") }
    }

    /// 자동 재생 여부
    @Published var autoPlayOnSelect: Bool = false {
        didSet { UserDefaults.standard.set(autoPlayOnSelect, forKey: "autoPlayOnSelect") }
    }

    // MARK: - Video Settings

    /// 기본 레이아웃 모드
    @Published var defaultLayoutMode: String = "grid" {
        didSet { UserDefaults.standard.set(defaultLayoutMode, forKey: "defaultLayoutMode") }
    }

    /// 컨트롤 자동 숨김 시간 (초)
    @Published var controlsAutoHideDelay: Double = 3.0 {
        didSet { UserDefaults.standard.set(controlsAutoHideDelay, forKey: "controlsAutoHideDelay") }
    }

    // MARK: - Performance Settings

    /// 목표 프레임율
    @Published var targetFrameRate: Int = 30 {
        didSet { UserDefaults.standard.set(targetFrameRate, forKey: "targetFrameRate") }
    }

    /// 하드웨어 가속 사용 여부
    @Published var useHardwareAcceleration: Bool = true {
        didSet { UserDefaults.standard.set(useHardwareAcceleration, forKey: "useHardwareAcceleration") }
    }

    // MARK: - Methods

    /// 설정 불러오기
    private func loadSettings() {
        let defaults = UserDefaults.standard

        // UI Settings
        if defaults.object(forKey: "showSidebarByDefault") != nil {
            showSidebarByDefault = defaults.bool(forKey: "showSidebarByDefault")
        }
        if defaults.object(forKey: "showDebugLogByDefault") != nil {
            showDebugLogByDefault = defaults.bool(forKey: "showDebugLogByDefault")
        }

        // Overlay Settings
        if defaults.object(forKey: "showGPSOverlayByDefault") != nil {
            showGPSOverlayByDefault = defaults.bool(forKey: "showGPSOverlayByDefault")
        }
        if defaults.object(forKey: "showMetadataOverlayByDefault") != nil {
            showMetadataOverlayByDefault = defaults.bool(forKey: "showMetadataOverlayByDefault")
        }
        if defaults.object(forKey: "showMapOverlayByDefault") != nil {
            showMapOverlayByDefault = defaults.bool(forKey: "showMapOverlayByDefault")
        }
        if defaults.object(forKey: "showGraphOverlayByDefault") != nil {
            showGraphOverlayByDefault = defaults.bool(forKey: "showGraphOverlayByDefault")
        }

        // Playback Settings
        if defaults.object(forKey: "defaultPlaybackSpeed") != nil {
            defaultPlaybackSpeed = defaults.double(forKey: "defaultPlaybackSpeed")
        }
        if defaults.object(forKey: "defaultVolume") != nil {
            defaultVolume = defaults.double(forKey: "defaultVolume")
        }
        if defaults.object(forKey: "autoPlayOnSelect") != nil {
            autoPlayOnSelect = defaults.bool(forKey: "autoPlayOnSelect")
        }

        // Video Settings
        if let layoutMode = defaults.string(forKey: "defaultLayoutMode") {
            defaultLayoutMode = layoutMode
        }
        if defaults.object(forKey: "controlsAutoHideDelay") != nil {
            controlsAutoHideDelay = defaults.double(forKey: "controlsAutoHideDelay")
        }

        // Performance Settings
        if defaults.object(forKey: "targetFrameRate") != nil {
            targetFrameRate = defaults.integer(forKey: "targetFrameRate")
        }
        if defaults.object(forKey: "useHardwareAcceleration") != nil {
            useHardwareAcceleration = defaults.bool(forKey: "useHardwareAcceleration")
        }
    }

    /// 설정 초기화
    func resetToDefaults() {
        // UI Settings
        showSidebarByDefault = true
        showDebugLogByDefault = false

        // Overlay Settings
        showGPSOverlayByDefault = true
        showMetadataOverlayByDefault = true
        showMapOverlayByDefault = true
        showGraphOverlayByDefault = true

        // Playback Settings
        defaultPlaybackSpeed = 1.0
        defaultVolume = 0.8
        autoPlayOnSelect = false

        // Video Settings
        defaultLayoutMode = "grid"
        controlsAutoHideDelay = 3.0

        // Performance Settings
        targetFrameRate = 30
        useHardwareAcceleration = true
    }
}
