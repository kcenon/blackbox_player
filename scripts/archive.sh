#!/bin/bash

#
# archive.sh
# BlackboxPlayer Archive Script
#
# Creates a release archive for distribution
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
ARCHIVE_DIR="${BUILD_DIR}/Archives"
EXPORT_DIR="${BUILD_DIR}/Export"

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

# Generate Xcode project
generate_project() {
    print_header "Generating Xcode Project"

    if command -v xcodegen &> /dev/null; then
        print_info "Running xcodegen..."
        xcodegen
        print_success "Xcode project generated successfully"
    else
        print_warning "xcodegen not found, skipping project generation"
    fi
}

# Archive the project
archive_project() {
    print_header "Creating Archive"

    mkdir -p "${ARCHIVE_DIR}"
    local archive_path="${ARCHIVE_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).xcarchive"
    local log_file="${BUILD_DIR}/archive_$(date +%Y%m%d_%H%M%S).log"

    print_info "Archive path: ${archive_path}"
    print_info "Log file: ${log_file}"
    print_info ""
    print_info "Creating archive (this may take a while)..."

    if xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "${SCHEME_NAME}" \
        -configuration Release \
        -derivedDataPath "${DERIVED_DATA_PATH}" \
        -archivePath "${archive_path}" \
        clean archive \
        2>&1 | tee "${log_file}"; then

        print_success "Archive created successfully"
        echo "${archive_path}" > "${ARCHIVE_DIR}/latest_archive.txt"
        return 0
    else
        print_error "Archive failed. Check log: ${log_file}"
        return 1
    fi
}

# Export the archive
export_archive() {
    print_header "Exporting Archive"

    local archive_path=$(cat "${ARCHIVE_DIR}/latest_archive.txt" 2>/dev/null)

    if [ ! -d "${archive_path}" ]; then
        print_error "Archive not found at: ${archive_path}"
        return 1
    fi

    mkdir -p "${EXPORT_DIR}"

    # Create export options plist
    local export_options="${EXPORT_DIR}/ExportOptions.plist"
    cat > "${export_options}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF

    print_info "Exporting archive..."
    local export_path="${EXPORT_DIR}/${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S)"

    if xcodebuild \
        -exportArchive \
        -archivePath "${archive_path}" \
        -exportPath "${export_path}" \
        -exportOptionsPlist "${export_options}" \
        2>&1 | tee "${BUILD_DIR}/export_$(date +%Y%m%d_%H%M%S).log"; then

        print_success "Export completed successfully"
        print_info "Exported to: ${export_path}"
        return 0
    else
        print_warning "Export failed. Application may still be in archive."
        print_info "You can manually export from Xcode Organizer:"
        print_info "  Archive location: ${archive_path}"
        return 1
    fi
}

# Create DMG (optional, requires create-dmg tool)
create_dmg() {
    print_header "Creating DMG"

    if ! command -v create-dmg &> /dev/null; then
        print_warning "create-dmg not found. Install with: brew install create-dmg"
        return 1
    fi

    local app_path="${EXPORT_DIR}/${PROJECT_NAME}.app"
    if [ ! -d "${app_path}" ]; then
        # Try to find the app in subdirectories
        app_path=$(find "${EXPORT_DIR}" -name "${PROJECT_NAME}.app" -type d -maxdepth 2 | head -n 1)
    fi

    if [ ! -d "${app_path}" ]; then
        print_warning "Application not found for DMG creation"
        return 1
    fi

    local dmg_name="${PROJECT_NAME}_$(date +%Y%m%d_%H%M%S).dmg"
    local dmg_path="${BUILD_DIR}/${dmg_name}"

    print_info "Creating DMG from: ${app_path}"
    print_info "DMG output: ${dmg_path}"

    if create-dmg \
        --volname "${PROJECT_NAME}" \
        --window-pos 200 120 \
        --window-size 800 400 \
        --icon-size 100 \
        --app-drop-link 600 185 \
        "${dmg_path}" \
        "${app_path}"; then

        print_success "DMG created: ${dmg_path}"
        return 0
    else
        print_warning "DMG creation failed"
        return 1
    fi
}

# Show archive summary
show_summary() {
    print_header "Archive Summary"

    local archive_path=$(cat "${ARCHIVE_DIR}/latest_archive.txt" 2>/dev/null)

    if [ -d "${archive_path}" ]; then
        print_success "Archive Location:"
        print_info "  ${archive_path}"
        print_info ""

        local app_path="${archive_path}/Products/Applications/${PROJECT_NAME}.app"
        if [ -d "${app_path}" ]; then
            print_info "Application Info:"
            print_info "  Bundle ID: $(defaults read "${app_path}/Contents/Info.plist" CFBundleIdentifier 2>/dev/null || echo 'N/A')"
            print_info "  Version: $(defaults read "${app_path}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo 'N/A')"
            print_info "  Build: $(defaults read "${app_path}/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo 'N/A')"
            print_info ""
            print_info "Application Size:"
            du -sh "${app_path}" | awk '{print "  " $1}'
        fi

        print_info ""
        print_info "To open in Xcode Organizer:"
        print_info "  open ${archive_path}"
    fi
}

# Main execution
main() {
    print_header "BlackboxPlayer Archive Script"
    print_info "Project: ${PROJECT_NAME}"
    print_info ""

    # Change to project root directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${SCRIPT_DIR}/.."

    print_info "Working directory: $(pwd)"
    print_info ""

    # Generate project
    generate_project

    # Archive
    if archive_project; then
        show_summary

        # Ask to export
        print_info ""
        read -p "Export archive? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            export_archive || true

            # Ask to create DMG
            print_info ""
            read -p "Create DMG? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                create_dmg || true
            fi
        fi

        print_header "Archive Complete"
        print_success "Archive completed successfully!"
        print_info "Archive directory: ${ARCHIVE_DIR}"
        exit 0
    else
        print_header "Archive Complete"
        print_error "Archive failed!"
        exit 1
    fi
}

# Run main function
main
