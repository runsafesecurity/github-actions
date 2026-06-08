#!/bin/sh
# Gremlin setup for .NET interceptor on Linux (bash/shell runners).

if [ ! -z "${RUNSAFE_DISABLED}" ]; then
    echo "[RunSafe Security] RunSafe protections disabled for this job";
elif [ -z "${RUNSAFE_IDENTIFY_ENABLED}" ]; then
    echo "[RunSafe Security] RunSafe .NET setup skipped for this job. Are you sure that Identify is enabled for this project?";
    echo "[RunSafe Security] If that does not resolve the issue, please contact support@runsafesecurity.com."
elif [ ! -f /etc/os-release ]; then
    echo "[RunSafe Security] RunSafe Identify is not supported on this operating system. Please contact support@runsafesecurity.com to inqure about adding support."
    else
    if command -v dotnet >/dev/null 2>&1; then
        case "$PATH" in
            # Already set, no need to do anything
            *".runsafe_dotnet_interceptor"*) ;;
            *)
                mkdir -p ${GITHUB_WORKSPACE}/.runsafe_dotnet_interceptor
                cp ${GITHUB_WORKSPACE}/RUNSAFE_SBOM_PACKAGES/bin/dotnet-cli-interceptor.sh ${GITHUB_WORKSPACE}/.runsafe_dotnet_interceptor/dotnet-cli-interceptor.sh
                export RUNSAFE_REAL_DOTNET_PATH=$(command -v dotnet)
                ln -sf ${GITHUB_WORKSPACE}/.runsafe_dotnet_interceptor/dotnet-cli-interceptor.sh ${GITHUB_WORKSPACE}/.runsafe_dotnet_interceptor/dotnet
                export PATH=${GITHUB_WORKSPACE}/.runsafe_dotnet_interceptor:${PATH}
                echo "[RunSafe Security] .NET CLI interceptor installed and active"
                echo "[RunSafe Security] .NET -> $(command -v dotnet)"
                ;;
        esac
    fi
fi
