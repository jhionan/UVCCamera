#!/bin/bash
# Build UVC Button Helper for distribution.
#
# Prerequisites:
#   macOS:   brew install libusb
#   Linux:   apt install libusb-1.0-0-dev
#   Windows: Download libusb from https://github.com/libusb/libusb/releases
#            and place libusb-1.0.dll next to the built .exe
#
# Usage:
#   ./build.sh              # Build for current platform
#   ./build.sh windows      # Cross-compile for Windows (requires mingw-w64)

set -e

APP_NAME="uvc-button-helper"
VERSION="1.0.0"

build_current() {
    echo "Building ${APP_NAME} for current platform..."
    go build -ldflags="-s -w" -o "${APP_NAME}" .
    echo "Built: ${APP_NAME}"
}

build_windows() {
    echo "Building ${APP_NAME} for Windows (amd64)..."
    # Requires: brew install mingw-w64
    # Requires: Windows libusb headers/lib in /usr/local/opt/libusb-win or similar
    CGO_ENABLED=1 \
    GOOS=windows \
    GOARCH=amd64 \
    CC=x86_64-w64-mingw32-gcc \
    go build -ldflags="-s -w -H windowsgui" -o "${APP_NAME}.exe" .
    echo "Built: ${APP_NAME}.exe"
    echo "NOTE: Ship libusb-1.0.dll alongside the .exe"
}

case "${1:-}" in
    windows)
        build_windows
        ;;
    *)
        build_current
        ;;
esac
