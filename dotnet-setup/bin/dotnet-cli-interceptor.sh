#!/bin/sh
# dotnet CLI interceptor script
# Captures project and solution paths used by common dotnet commands.

CAPTURE_FILE="${RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE:-${GITHUB_WORKSPACE}/.dotnet_projects_captured/${GITHUB_RUN_ID}_scan_roots.txt}"
TOOL_NAME=$(basename "$0")

mkdir -p "$(dirname "$CAPTURE_FILE")"

# Appends one resolved scan root path as a line to CAPTURE_FILE (see file header / RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE).
# Returns 0 on success, 1 if the value is unusable or the append fails.
#
# Rules:
# - Reject empty input and anything that looks like a CLI flag (leading '-').
# - "." means "implicit project dir": record pwd so it matches dotnet after cd in the job.
# - Otherwise record the given path string as-is (callers are expected to pass real paths).
capture_scan_root() {
    scan_root="$1"

    # Reject empty scan root.
    if [ -z "$scan_root" ]; then
        return 1
    fi

    # Reject flag-like tokens; scan roots must be paths or ".".
    case "$scan_root" in
        -*)
            return 1
            ;;
    esac

    if [ "$scan_root" = "." ]; then
        # Match dotnet's implicit project resolution: use cwd (may differ from CI_PROJECT_DIR after cd).
        pwd >> "$CAPTURE_FILE" 2>/dev/null || return 1
        return 0
    fi

    echo "$scan_root" >> "$CAPTURE_FILE" 2>/dev/null || return 1
    return 0
}

# Echoes a path/solution string suitable for capture_scan_root, or returns 1 if this CLI token is not a scan root.
#
# Cases handled:
# 1) Raw token must look like a project/solution path (known extension); otherwise not a candidate.
# 2) Plain path: whole token is the candidate (subject to later checks).
# 3) -flag=value: only accepted if there is '='; candidate is the substring after the last '=' (value segment).
# 4) /p|/P|/property|/PROPERTY=value: same '=' rule as (3).
# 5) After extraction, reject empty or flag-like candidates (leading '-').
# 6) Final guard: candidate must still end with a known project/solution extension; then print it.
dotnet_scan_root_candidate_from_arg() {
    arg="$1"

    # (1) Gate on the raw token: must end with a known project/solution extension.
    case "$arg" in
        *.csproj|*.fsproj|*.vbproj|*.sln|*.slnx|*.slnf) ;;
        *) return 1 ;;
    esac

    # (2) Default: treat the whole token as the path; (3)(4) may replace candidate.
    candidate="$arg"
    case "$arg" in
        # (3) Dash-prefixed MSBuild-style switches: require '=' and take the value after the last '=' (${arg##*=}).
        -*)
            case "$arg" in
                *=*) candidate="${arg##*=}" ;;
                *) return 1 ;;
            esac
            ;;
        # (4) Slash MSBuild property switches: same '=' extraction rule as (3).
        /p:*|/P:*|/property:*|/PROPERTY:*)
            case "$arg" in
                *=*) candidate="${arg##*=}" ;;
                *) return 1 ;;
            esac
            ;;
    esac

    # (5) Reject empty or another flag token mistaken for a path.
    case "$candidate" in
        -*|'') return 1 ;;
    esac

    # (6) Re-validate extension on the extracted value, then emit the path for capture_scan_root.
    case "$candidate" in
        *.csproj|*.fsproj|*.vbproj|*.sln|*.slnx|*.slnf)
            printf '%s\n' "$candidate"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
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

# Parse command and capture scan roots by index so "$@" is never mutated.
# Avoid eval-based save/restore of the full argv; that can drop or split args
# when values contain $, quotes, or backslashes.
case "$1" in
    build|clean|msbuild|pack|publish|restore|test)
        captured_any=0
        i=2
        while [ $i -le $# ]; do
            eval "arg=\$$i"
            if candidate=$(dotnet_scan_root_candidate_from_arg "$arg"); then
                if capture_scan_root "$candidate"; then
                    captured_any=1
                fi
            fi
            i=$((i + 1))
        done

        if [ "$captured_any" -eq 0 ]; then
            capture_scan_root "."
        fi
        ;;
esac

exec "$REAL_TOOL" "$@"
