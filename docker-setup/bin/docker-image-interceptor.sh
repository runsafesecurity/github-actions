#!/bin/sh
# Docker/Podman image interceptor script
# Captures image names and tags from build/pull/tag commands

CAPTURE_FILE="${RUNSAFE_DOCKER_IMAGES_CAPTURE_FILE:-${GITHUB_WORKSPACE}/.docker_images_captured/${GITHUB_RUN_ID}_built_images.txt}"
TOOL_NAME=$(basename "$0")

# Ensure capture file directory exists
mkdir -p "$(dirname "$CAPTURE_FILE")"

# Function to write image to capture file
capture_image() {
    local image="$1"
    if [ -n "$image" ] && [ "$image" != "<none>" ] && [ "$image" != "none" ]; then
    # Normalize image name (add :latest if no tag specified).
    # Tag is the part after the last colon in the name component (after last /);
    # registry:port (e.g. registry.example.com:5000/myimage) must not be treated as a tag.
    last_component="${image##*/}"
    if ! echo "$last_component" | grep -q ':'; then
        image="${image}:latest"
    fi
    echo "$image" >> "$CAPTURE_FILE" 2>/dev/null || true
    fi
}

# Find the real docker/podman binary
find_real_tool() {
    local tool="$1"
    local real_path=""
    local interceptor_dir=".runsafe_docker_interceptor"
    # Use a saved environment variable if available (set during setup)
    if [ -n "${RUNSAFE_REAL_DOCKER_PATH}" ] && [ "$tool" = "docker" ]; then
    real_path="${RUNSAFE_REAL_DOCKER_PATH}"
    elif [ -n "${RUNSAFE_REAL_PODMAN_PATH}" ] && [ "$tool" = "podman" ]; then
    real_path="${RUNSAFE_REAL_PODMAN_PATH}"
    else
    # Find the real binary by checking PATH, excluding our interceptor directory
    OLD_IFS="$IFS"
    IFS=:
    for path in $PATH; do
        if [ -x "$path/$tool" ] && echo "$path" | grep -qv "$interceptor_dir"; then
        real_path="$path/$tool"
        break
        fi
    done
    IFS="$OLD_IFS"
    # Fallback: check common system RUNSAFE_locations
    if [ -z "$real_path" ]; then
        for syspath in /usr/bin /usr/local/bin /bin /snap/bin; do
        if [ -x "$syspath/$tool" ]; then
            real_path="$syspath/$tool"
            break
        fi
        done
    fi
    fi
    echo "$real_path"
}

REAL_TOOL=$(find_real_tool "$TOOL_NAME")

if [ -z "$REAL_TOOL" ] || [ ! -x "$REAL_TOOL" ]; then
    echo "Error: Cannot find real $TOOL_NAME binary" >&2
    exit 1
fi

# Parse command and capture images by index so "$@" is never mutated.
# Avoid eval-based save/restore of the full argv; that can drop or split args
# (e.g. --secret pairs) when values contain $, quotes, or backslashes.
case "$1" in
    build)
    # docker build -t image:tag or podman build -t image:tag
    i=2
    while [ $i -le $# ]; do
        eval "arg=\$$i"
        case "$arg" in
        -t|--tag)
            next=$((i + 1))
            if [ $next -le $# ]; then
                eval "tag_image=\$$next"
                capture_image "$tag_image"
                i=$next
            fi
            ;;
        --tag=*)
            tag_image="${arg#*=}"
            capture_image "$tag_image"
            ;;
        esac
        i=$((i + 1))
    done
    ;;
    pull)
    # docker pull [OPTIONS] image:tag or podman pull [OPTIONS] image:tag
    # Flags that take a separate value: --platform, --policy, --registry-mirror (skip value so it is not captured as image)
    i=2
    while [ $i -le $# ]; do
        eval "arg=\$$i"
        case "$arg" in
        --platform|-p|--policy|--registry-mirror)
            if [ $i -lt $# ]; then
                i=$((i + 1))
            fi
            ;;
        --platform=*|--policy=*|--registry-mirror=*)
            ;;
        -*)
            ;;
        *)
            capture_image "$arg"
            ;;
        esac
        i=$((i + 1))
    done
    ;;
    tag)
    # docker tag source target or podman tag source target
    if [ $# -ge 3 ]; then
        eval "target=\$3"
        capture_image "$target"
    fi
    ;;
    push)
    # docker push [OPTIONS] image:tag - capture the image being pushed
    # Flags that take a separate value: --authfile, --cert-dir, --digestfile, --format, --sign-by (skip value so it is not captured as image)
    i=2
    while [ $i -le $# ]; do
        eval "arg=\$$i"
        case "$arg" in
        --authfile|--cert-dir|--digestfile|--format|--sign-by)
            if [ $i -lt $# ]; then
                i=$((i + 1))
            fi
            ;;
        --authfile=*|--cert-dir=*|--digestfile=*|--format=*|--sign-by=*)
            ;;
        -*)
            ;;
        *)
            capture_image "$arg"
            ;;
        esac
        i=$((i + 1))
    done
    ;;
    save|load|import|export)
    # These might have image references, but less common - skip for now
    ;;
    compose|docker-compose)
    # docker compose needs a complex script to parse yml files - skip for now
    ;;
esac

exec "$REAL_TOOL" "$@"
