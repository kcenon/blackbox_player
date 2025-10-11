#!/bin/bash

#
# build.sh
# BlackboxPlayer Build Script
#
# Automates the build process for Debug and Release configurations
#

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project configuration
PROJECT_NAME="BlackboxPlayer"
SCHEME_NAME="BlackboxPlayer"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
BUILD_DIR="build"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"

# Build configuration (default: Debug)
CONFIGURATION="${1:-Debug}"

# Validate configuration
if [[ "$CONFIGURATION" != "Debug" && "$CONFIGURATION" != "Release" ]]; then
    echo -e "${RED}Error: Invalid configuration '$CONFIGURATION'. Use 'Debug' or 'Release'.${NC}"
    exit 1
fi

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  ${1}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if xcodegen exists
check_xcodegen() {
    if ! command -v xcodegen &> /dev/null; then
        print_warning "xcodegen not found. Installing via Homebrew..."
        if command -v brew &> /dev/null; then
            brew install xcodegen
            print_success "xcodegen installed successfully"
        else
            print_error "Homebrew not found. Please install xcodegen manually:"
            print_info "brew install xcodegen"
            exit 1
        fi
    fi
}

# Generate Xcode project from project.yml
generate_project() {
    print_header "Generating Xcode Project"

    if [ ! -f "project.yml" ]; then
        print_error "project.yml not found in current directory"
        exit 1
    fi

    print_info "Running xcodegen..."
    xcodegen
    print_success "Xcode project generated successfully"
}

# Clean build directory
clean_build() {
    print_header "Cleaning Build Directory"

    if [ -d "${BUILD_DIR}" ]; then
        print_info "Removing ${BUILD_DIR} directory..."
        rm -rf "${BUILD_DIR}"
        print_success "Build directory cleaned"
    else
        print_info "Build directory does not exist, skipping..."
    fi
}

# Build the project
build_project() {
    print_header "Building ${PROJECT_NAME} (${CONFIGURATION})"

    local log_file="${BUILD_DIR}/build_${CONFIGURATION}_$(date +%Y%m%d_%H%M%S).log"
    mkdir -p "${BUILD_DIR}"

    print_info "Configuration: ${CONFIGURATION}"
    print_info "Log file: ${log_file}"
    print_info ""
    print_info "Building project..."

    # Build command
    if xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME_NAME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        clean build \
        2>&1 | tee "${log_file}"; then

        print_success "Build completed successfully"
        return 0
    else
        print_error "Build failed. Check log file: ${log_file}"
        return 1
    fi
}

# Show build artifacts
show_artifacts() {
    print_header "Build Artifacts"

    local app_path="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${PROJECT_NAME}.app"

    if [ -d "${app_path}" ]; then
        print_success "Application built at:"
        print_info "  ${app_path}"
        print_info ""
        print_info "Application info:"
        print_info "  Bundle ID: $(defaults read "${app_path}/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo 'N/A')"
        print_info "  Version: $(defaults read "${app_path}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo 'N/A')"
        print_info "  Build: $(defaults read "${app_path}/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo 'N/A')"
        print_info ""
        print_info "Application size:"
        du -sh "${app_path}" | awk '{print "  " $1}'
    else
        print_warning "Application bundle not found at expected location"
    fi
}

# Run tests (optional)
run_tests() {
    print_header "Running Tests"

    local log_file="${BUILD_DIR}/test_$(date +%Y%m%d_%H%M%S).log"

    print_info "Running unit tests..."

    if xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME_NAME}" \
        -configuration "${CONFIGURATION}" \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        test \
        2>&1 | tee "${log_file}"; then

        print_success "Tests passed"
        return 0
    else
        print_warning "Tests failed or no tests found. Check log: ${log_file}"
        return 1
    fi
}

# Main execution
main() {
    print_header "BlackboxPlayer Build Script"
    print_info "Configuration: ${CONFIGURATION}"
    print_info "Project: ${PROJECT_NAME}"
    print_info ""

    # Change to project root directory (script should be in scripts/ subdirectory)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${SCRIPT_DIR}/.."

    print_info "Working directory: $(pwd)"
    print_info ""

    # Check prerequisites
    check_xcodegen

    # Generate project
    generate_project

    # Clean (optional, only for Release builds)
    if [ "${CONFIGURATION}" = "Release" ]; then
        clean_build
    fi

    # Build
    if build_project; then
        show_artifacts

        # Run tests only for Debug builds
        if [ "${CONFIGURATION}" = "Debug" ]; then
            print_info ""
            read -p "Run tests? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                run_tests || true  # Don't fail build if tests fail
            fi
        fi

        print_header "Build Summary"
        print_success "Build completed successfully!"
        print_info "Configuration: ${CONFIGURATION}"
        print_info "Build artifacts: ${BUILD_DIR}"

        exit 0
    else
        print_header "Build Summary"
        print_error "Build failed!"
        exit 1
    fi
}

# Run main function
main
