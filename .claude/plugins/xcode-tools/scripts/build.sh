#!/bin/bash
# Xcode build wrapper with error parsing
# Usage: build.sh [ios|mac] [scheme] [action]
# Actions: build (default), test

set -o pipefail

PLATFORM="${1:-mac}"
SCHEME="${2:-composer}"
ACTION="${3:-build}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Find project file
find_project() {
    local workspace=$(find . -maxdepth 1 -name "*.xcworkspace" ! -path "./*/project.xcworkspace" | head -1)
    local project=$(find . -maxdepth 1 -name "*.xcodeproj" | head -1)

    if [ -n "$workspace" ]; then
        echo "-workspace $workspace"
    elif [ -n "$project" ]; then
        echo "-project $project"
    else
        echo ""
    fi
}

# Get destination based on platform
get_destination() {
    case "$PLATFORM" in
        ios)
            # Find first available iPhone simulator
            local sim=$(xcrun simctl list devices available | grep -E "iPhone.*\(" | head -1 | sed 's/.*(\([^)]*\)).*/\1/')
            if [ -n "$sim" ]; then
                echo "platform=iOS Simulator,id=$sim"
            else
                echo "platform=iOS Simulator,name=iPhone 16"
            fi
            ;;
        mac|macos)
            echo "platform=macOS"
            ;;
        *)
            echo "platform=macOS"
            ;;
    esac
}

# Main build function
main() {
    local project_flag=$(find_project)

    if [ -z "$project_flag" ]; then
        echo -e "${RED}Error: No Xcode project or workspace found in current directory${NC}"
        exit 1
    fi

    local destination=$(get_destination)

    echo -e "${CYAN}Building for $PLATFORM...${NC}"
    echo -e "${CYAN}Scheme: $SCHEME${NC}"
    echo -e "${CYAN}Destination: $destination${NC}"
    echo ""

    # Build command
    local cmd="xcodebuild $project_flag -scheme $SCHEME -destination '$destination' -configuration Debug"

    # Add action-specific flags
    case "$ACTION" in
        test)
            cmd="$cmd test"
            ;;
        build)
            cmd="$cmd build"
            ;;
        clean)
            cmd="$cmd clean"
            ;;
    esac

    # Run xcodebuild and capture output
    local log_file="/tmp/xcode-build-$$.log"

    eval "$cmd" 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    echo ""
    echo "---"

    # Parse and summarize results
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}BUILD SUCCEEDED${NC}"

        # Count warnings
        local warning_count=$(grep -c "warning:" "$log_file" 2>/dev/null || echo "0")
        if [ "$warning_count" -gt 0 ]; then
            echo -e "${YELLOW}Warnings: $warning_count${NC}"
            echo ""
            echo "Warnings:"
            grep "warning:" "$log_file" | head -10
        fi
    else
        echo -e "${RED}BUILD FAILED${NC}"
        echo ""
        echo "Errors:"
        # Extract errors with file:line info
        grep -E "error:" "$log_file" | while read -r line; do
            echo -e "${RED}$line${NC}"
        done

        # Show any undefined symbol errors
        grep -E "Undefined symbol" "$log_file" | head -5

        # Show linker errors
        grep -E "ld: " "$log_file" | head -5
    fi

    # Cleanup
    rm -f "$log_file"

    exit $exit_code
}

main
