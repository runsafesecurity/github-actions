#!/bin/sh
# dotnet CLI interceptor script
# Captures project and solution paths used by common dotnet commands.

CAPTURE_FILE="${RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE:-${GITHUB_WORKSPACE}/.dotnet_projects_captured/${GITHUB_RUN_ID}_scan_roots.txt}"
TOOL_NAME=$(basename "$0")

mkdir -p "$(dirname "$CAPTURE_FILE")"

capture_scan_root() {
    scan_root="$1"

    if [ -z "$scan_root" ]; then
        return
    fi

    case "$scan_root" in
        -*)
            return
            ;;
    esac

    if [ "$scan_root" = "." ]; then
        echo "${GITHUB_WORKSPACE:-$(pwd)}" >> "$CAPTURE_FILE" 2>/dev/null || true
        return
    fi

    echo "$scan_root" >> "$CAPTURE_FILE" 2>/dev/null || true
}

find_real_dotnet() {
    real_path=""
    interceptor_dir=".runsafe_dotnet_interceptor"

    if [ -n "${RUNSAFE_REAL_DOTNET_PATH}" ]; then
        real_path="${RUNSAFE_REAL_DOTNET_PATH}"
    else
        OLD_IFS="$IFS"
        IFS=:
        for path in $PATH; do
            if [ -x "$path/$TOOL_NAME" ] && echo "$path" | grep -qv "$interceptor_dir"; then
                real_path="$path/$TOOL_NAME"
                break
            fi
        done
        IFS="$OLD_IFS"

        if [ -z "$real_path" ]; then
            for syspath in /usr/bin /usr/local/bin /bin /snap/bin; do
                if [ -x "$syspath/$TOOL_NAME" ]; then
                    real_path="$syspath/$TOOL_NAME"
                    break
                fi
            done
        fi
    fi

    echo "$real_path"
}

REAL_TOOL=$(find_real_dotnet)

if [ -z "$REAL_TOOL" ] || [ ! -x "$REAL_TOOL" ]; then
    echo "Error: Cannot find real $TOOL_NAME binary" >&2
    exit 1
fi

ORIG_ARGS_COUNT=$#
index=1
while [ $index -le $# ]; do
    eval "ORIG_ARG_$index=\"\$$index\""
    index=$((index + 1))
done

case "$1" in
    build|clean|msbuild|pack|publish|restore|test)
        shift
        captured_any=0
        while [ $# -gt 0 ]; do
            case "$1" in
                *.csproj|*.fsproj|*.vbproj|*.sln|*.slnx|*.slnf)
                    capture_scan_root "$1"
                    captured_any=1
                    ;;
            esac
            shift
        done

        if [ "$captured_any" -eq 0 ]; then
            capture_scan_root "."
        fi
        ;;
esac

index=1
if [ $ORIG_ARGS_COUNT -gt 0 ]; then
    eval "set -- \"\$ORIG_ARG_1\""
    index=2
    while [ $index -le $ORIG_ARGS_COUNT ]; do
        eval "set -- \"\$@\" \"\$ORIG_ARG_$index\""
        index=$((index + 1))
    done
else
    set --
fi

exec "$REAL_TOOL" "$@"
