#!/usr/bin/env bash
set -eo pipefail

IMAGE_NAME="${CHAINBOX_IMAGE:-7feilee/chainbox}"
PLATFORM="${CHAINBOX_PLATFORM:-linux/amd64,linux/arm64}"
USERNAME="${CHAINBOX_USER:-agent}"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build the chainbox Docker image for multiple platforms."
    echo ""
    echo "Options:"
    echo "  --push          Build and push to registry"
    echo "  --load          Build and load into local Docker (single platform only)"
    echo "  --no-cache      Build without using Docker layer cache"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  CHAINBOX_IMAGE     Image name (default: 7feilee/chainbox)"
    echo "  CHAINBOX_PLATFORM  Target platforms (default: linux/amd64,linux/arm64)"
    echo "  CHAINBOX_USER      Container username (default: agent)"
    echo ""
    echo "Examples:"
    echo "  $0 --push                                          # Build multi-arch and push"
    echo "  $0 --load                                          # Build for local arch and load"
    echo "  CHAINBOX_IMAGE=myuser/chainbox $0 --push           # Push to your own repo"
    echo "  CHAINBOX_USER=alice $0 --load                      # Build with custom username"
    echo "  CHAINBOX_PLATFORM=linux/arm64 $0 --push            # Build for arm64 only"
}

BUILD_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --push)
            BUILD_ARGS+=("--push")
            shift
            ;;
        --load)
            BUILD_ARGS+=("--load")
            # --load only supports a single platform; default to current arch
            PLATFORM="linux/$(docker info -f '{{.Architecture}}' 2>/dev/null | sed 's/x86_64/amd64/;s/aarch64/arm64/')"
            shift
            ;;
        --no-cache)
            BUILD_ARGS+=("--no-cache")
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ ${#BUILD_ARGS[@]} -eq 0 ]]; then
    echo "No action specified. Use --push to push or --load to load locally."
    echo ""
    usage
    exit 1
fi

PROXY_ARGS=()
for var in HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy; do
    [[ -n "${!var:-}" ]] && PROXY_ARGS+=("--build-arg" "${var}=${!var}")
done

echo "Building ${IMAGE_NAME} for ${PLATFORM} (user: ${USERNAME})..."
docker buildx build \
    --network=host \
    --platform="${PLATFORM}" \
    --build-arg USERNAME="${USERNAME}" \
    "${PROXY_ARGS[@]}" \
    -t "${IMAGE_NAME}" \
    "${BUILD_ARGS[@]}" \
    .
