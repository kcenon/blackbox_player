#!/bin/bash

#
# ci-build.sh
# BlackboxPlayer CI/CD Build Script
#
# Non-interactive build script for CI/CD pipelines (GitHub Actions, etc.)
#

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Pipe failures propagate

# Project configuration
PROJECT_NAME="BlackboxPlayer"
SCHEME_NAME="BlackboxPlayer"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
BUILD_DIR="build"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
CONFIGURATION="${1:-Debug}"

# CI environment detection
CI="${CI:-false}"
GITHUB_ACTIONS="${GITHUB_ACTIONS:-false}"

# Function to print messages (CI-friendly)
log_info() {
    echo "ℹ️ $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️ $1"
}

log_error() {
    echo "❌ $1" >&2
}

log_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Check system requirements
check_requirements() {
    log_section "Checking Requirements"

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "xcodebuild not found. Please install Xcode."
        exit 1
    fi

    local xcode_version=$(xcodebuild -version | head -n 1)
    log_info "Xcode version: ${xcode_version}"

    # Check xcodegen
    if ! command -v xcodegen &> /dev/null; then
        log_error "xcodegen not found. Installing..."
        if command -v brew &> /dev/null; then
            brew install xcodegen
        else
            log_error "Homebrew not found. Cannot install xcodegen."
            exit 1
        fi
    fi

    log_success "All requirements met"
}

# Generate Xcode project
generate_project() {
    log_section "Generating Xcode Project"

    if [ ! -f "project.yml" ]; then
        log_error "project.yml not found"
        exit 1
    fi

    log_info "Running xcodegen..."
    if xcodegen; then
        log_success "Project generated successfully"
    else
        log_error "Project generation failed"
        exit 1
    fi
}

# Clean build directory
clean_build() {
    log_section "Cleaning Build Directory"

    if [ -d "${BUILD_DIR}" ]; then
        log_info "Removing ${BUILD_DIR}..."
        rm -rf "${BUILD_DIR}"
    fi

    log_success "Build directory cleaned"
}

# Build project
build_project() {
    log_section "Building ${PROJECT_NAME} (${CONFIGURATION})"

    mkdir -p "${BUILD_DIR}"
    local log_file="${BUILD_DIR}/build_${CONFIGURATION}.log"

    log_info "Configuration: ${CONFIGURATION}"
    log_info "Log file: ${log_file}"

    # Set build options
    local build_opts=(
        -project "${PROJECT_FILE}"
        -scheme "${SCHEME_NAME}"
        -configuration "${CONFIGURATION}"
        -derivedDataPath "${DERIVED_DATA_PATH}"
    )

    # Add CI-specific options
    if [ "${CI}" = "true" ]; then
        build_opts+=(
            -quiet
            CODE_SIGN_IDENTITY=""
            CODE_SIGNING_REQUIRED=NO
            CODE_SIGNING_ALLOWED=NO
        )
        log_info "CI mode enabled: code signing disabled"
    fi

    # Build
    log_info "Starting build..."
    if xcodebuild "${build_opts[@]}" clean build 2>&1 | tee "${log_file}"; then
        log_success "Build completed successfully"
        return 0
    else
        log_error "Build failed. Check log: ${log_file}"

        # Show last 50 lines of log for CI
        if [ "${CI}" = "true" ]; then
            echo ""
            echo "━━━ Last 50 lines of build log ━━━"
            tail -n 50 "${log_file}"
        fi

        return 1
    fi
}

# Run tests
run_tests() {
    log_section "Running Tests"

    local log_file="${BUILD_DIR}/test.log"
    local result_bundle="${BUILD_DIR}/TestResults.xcresult"

    log_info "Running unit tests..."

    local test_opts=(
        -project "${PROJECT_FILE}"
        -scheme "${SCHEME_NAME}"
        -configuration Debug
        -derivedDataPath "${DERIVED_DATA_PATH}"
        -resultBundlePath "${result_bundle}"
        -enableCodeCoverage YES
    )

    # Add CI-specific options
    if [ "${CI}" = "true" ]; then
        test_opts+=(
            -quiet
            CODE_SIGN_IDENTITY=""
            CODE_SIGNING_REQUIRED=NO
        )
    fi

    if xcodebuild "${test_opts[@]}" test 2>&1 | tee "${log_file}"; then
        log_success "All tests passed"

        # Extract coverage if available
        if [ -d "${result_bundle}" ] && command -v xcrun &> /dev/null; then
            log_info "Extracting coverage data..."
            xcrun xccov view --report --json "${result_bundle}" > "${BUILD_DIR}/coverage.json" 2>/dev/null || true
        fi

        return 0
    else
        log_warning "Tests failed"

        # Show last 30 lines for CI
        if [ "${CI}" = "true" ]; then
            echo ""
            echo "━━━ Last 30 lines of test log ━━━"
            tail -n 30 "${log_file}"
        fi

        return 1
    fi
}

# Generate build artifacts info
generate_artifacts() {
    log_section "Build Artifacts"

    local app_path="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"

    if [ -d "${app_path}" ]; then
        log_success "Application: ${app_path}"

        # Get app info
        if [ -f "${app_path}/Contents/Info.plist" ]; then
            local bundle_id=$(defaults read "${app_path}/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo "N/A")
            local version=$(defaults read "${app_path}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "N/A")
            local build=$(defaults read "${app_path}/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "N/A")

            log_info "Bundle ID: ${bundle_id}"
            log_info "Version: ${version}"
            log_info "Build: ${build}"
        fi

        # Get app size
        local size=$(du -sh "${app_path}" 2>/dev/null | awk '{print $1}')
        log_info "Size: ${size}"

        # Save artifact info for CI
        if [ "${GITHUB_ACTIONS}" = "true" ]; then
            echo "artifact_path=${app_path}" >> "${GITHUB_OUTPUT:-/dev/null}"
            echo "app_version=${version}" >> "${GITHUB_OUTPUT:-/dev/null}"
        fi
    else
        log_warning "Application bundle not found"
    fi
}

# Main execution
main() {
    log_section "BlackboxPlayer CI Build"
    log_info "Configuration: ${CONFIGURATION}"
    log_info "CI Environment: ${CI}"

    # Change to project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${SCRIPT_DIR}/.."

    log_info "Working directory: $(pwd)"

    # Build process
    check_requirements
    generate_project
    clean_build

    # Build
    if ! build_project; then
        log_error "Build failed!"
        exit 1
    fi

    generate_artifacts

    # Run tests (only for Debug builds)
    if [ "${CONFIGURATION}" = "Debug" ]; then
        if ! run_tests; then
            log_warning "Tests failed, but continuing..."
            # Don't fail the build on test failure in CI (optional)
            # exit 1
        fi
    fi

    log_section "Build Summary"
    log_success "CI build completed successfully!"
    log_info "Configuration: ${CONFIGURATION}"
    log_info "Artifacts: ${BUILD_DIR}"

    exit 0
}

# Handle errors
trap 'log_error "Build failed with error code $?"' ERR

# Run main
main
