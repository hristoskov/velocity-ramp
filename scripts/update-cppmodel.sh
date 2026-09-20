#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPS_DIR="${DEPS_DIR:-$PROJECT_ROOT/dependencies}"
BASE_URL="${BASE_URL:-https://download.cppmodel.com/}"
ARCH="${ARCH:-$(uname -m)}"
COMPILER="${COMPILER:-}"

case "$ARCH" in
    x86_64|aarch64) ;;
    *) echo "Unsupported arch '$ARCH'. Set ARCH=x86_64|aarch64."; exit 1 ;;
esac

if [[ -z "$COMPILER" ]]; then
    cxx="$(command -v c++ || command -v g++ || command -v clang++ || true)"
    if [[ "$cxx" == *clang* ]]; then
        COMPILER="clang21"
    elif [[ -n "$cxx" ]]; then
        ver="$("$cxx" -dumpversion 2>/dev/null | cut -d. -f1)"
        case "$ver" in
            12) COMPILER="gcc12" ;;
            16) COMPILER="gcc16" ;;
            *) echo "Detected gcc major version '$ver', no published archive for it. Set COMPILER=gcc12|gcc16|clang21."; exit 1 ;;
        esac
    else
        echo "Could not detect compiler. Set COMPILER=gcc12|gcc16|clang21."
        exit 1
    fi
fi

PLATFORM_TAG="Linux-${ARCH}-${COMPILER}"
ARCHIVE="CppModel-latest-${PLATFORM_TAG}.tar.gz"
echo "Target platform: $PLATFORM_TAG"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
echo "Downloading $ARCHIVE ..."
curl -fL -o "$TMP_DIR/$ARCHIVE" "${BASE_URL}${ARCHIVE}"

STAGING_DIR="$TMP_DIR/staging"
mkdir -p "$STAGING_DIR"
tar -xzf "$TMP_DIR/$ARCHIVE" -C "$STAGING_DIR"
VERSION_DIR="$(find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d | head -1)"

rm -rf "$DEPS_DIR"
mkdir -p "$DEPS_DIR"
cp -a "$VERSION_DIR"/. "$DEPS_DIR"/

VERSION_LABEL="$(basename "$VERSION_DIR")"
VERSION_LABEL="${VERSION_LABEL#CppModel-}"
echo "Installed CppModel $VERSION_LABEL into $DEPS_DIR"
