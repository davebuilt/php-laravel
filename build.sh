#!/bin/bash
#
# Build all PHP Laravel base images
# Creates both 'base' (production) and 'dev' (full development) variants
# for each supported PHP version.
#
# Usage:
#   ./build.sh              # Build all versions
#   ./build.sh 8.2          # Build specific version only
#   ./build.sh 8.4 --no-cache  # Build with --no-cache flag
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="davebuilt/php-laravel"

# Supported PHP versions
VERSIONS=("8.2" "8.3" "8.4")

# Parse arguments
SPECIFIC_VERSION=""
BUILD_ARGS=""

for arg in "$@"; do
    case $arg in
        8.*)
            SPECIFIC_VERSION="$arg"
            ;;
        --no-cache|--pull|--quiet)
            BUILD_ARGS="$BUILD_ARGS $arg"
            ;;
    esac
done

# If specific version requested, only build that one
if [ -n "$SPECIFIC_VERSION" ]; then
    VERSIONS=("$SPECIFIC_VERSION")
fi

echo "========================================"
echo "Building PHP Laravel Base Images"
echo "========================================"
echo "Image name: $IMAGE_NAME"
echo "Versions: ${VERSIONS[*]}"
echo "Build args: ${BUILD_ARGS:-none}"
echo "----------------------------------------"

cd "$SCRIPT_DIR"

for VERSION in "${VERSIONS[@]}"; do
    echo ""
    echo "Building PHP $VERSION..."
    echo "----------------------------------------"

    # Build base stage
    echo "  -> ${IMAGE_NAME}:${VERSION}-base"
    docker build \
        --build-arg PHP_VERSION="$VERSION" \
        --target base \
        -t "${IMAGE_NAME}:${VERSION}-base" \
        $BUILD_ARGS \
        .

    # Build dev stage
    echo "  -> ${IMAGE_NAME}:${VERSION}-dev"
    docker build \
        --build-arg PHP_VERSION="$VERSION" \
        --target dev \
        -t "${IMAGE_NAME}:${VERSION}-dev" \
        $BUILD_ARGS \
        .

    echo "  Done: PHP $VERSION"
done

echo ""
echo "========================================"
echo "Build Complete"
echo "========================================"
echo ""
echo "Available images:"
docker images | grep "$IMAGE_NAME" | sort
echo ""
echo "Usage in docker-compose.yml:"
echo ""
echo "  # Option 1: Use pre-built image"
echo "  services:"
echo "    app:"
echo "      image: ${IMAGE_NAME}:8.2-dev"
echo ""
echo "  # Option 2: Build with custom UID/GID"
echo "  services:"
echo "    app:"
echo "      build:"
echo "        context: ~/docker-bases/php-laravel"
echo "        target: dev"
echo "        args:"
echo "          PHP_VERSION: \"8.2\""
echo "          USER_ID: \${USER_ID:-1000}"
echo "          GROUP_ID: \${GROUP_ID:-1000}"
