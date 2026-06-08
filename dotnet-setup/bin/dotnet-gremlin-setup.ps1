# Gremlin setup for dotnet interceptor on Windows (batch/PowerShell runners).

$ErrorActionPreference = 'Continue'

function Install-RunSafeDotnetInterceptorWindows {
    if ($env:RUNSAFE_DISABLED) {
        Write-Host '[RunSafe Security] RunSafe protections disabled for this job'
        return
    }

    if (-not $env:RUNSAFE_IDENTIFY_ENABLED) {
        Write-Host '[RunSafe Security] RunSafe .NET setup skipped for this job. Are you sure that Identify is enabled for this project?'
        Write-Host '[RunSafe Security] If that does not resolve the issue, please contact support@runsafesecurity.com.'
        return
    }

    $packagesBin = Join-Path $env:GITHUB_WORKSPACE 'RUNSAFE_SBOM_PACKAGES\bin'
    $interceptorDir = Join-Path $env:GITHUB_WORKSPACE '.runsafe_dotnet_interceptor'

    $dotnetCommands = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue
    if (-not $dotnetCommands) {
        return
    }

    $realDotnet = $dotnetCommands |
        Where-Object { $_.Path -and ($_.Path -notmatch '\\.runsafe_dotnet_interceptor\\') } |
        Select-Object -First 1

    if (-not $realDotnet) {
        return
    }

    New-Item -ItemType Directory -Force -Path $interceptorDir | Out-Null

    Copy-Item -Force (Join-Path $packagesBin 'dotnet-cli-interceptor.ps1') (Join-Path $interceptorDir 'dotnet-cli-interceptor.ps1')
    Copy-Item -Force (Join-Path $packagesBin 'dotnet-cli-interceptor.sh') (Join-Path $interceptorDir 'dotnet-cli-interceptor.sh')
    Copy-Item -Force (Join-Path $packagesBin 'dotnet-cli-interceptor.cmd') (Join-Path $interceptorDir 'dotnet.cmd')

    $env:RUNSAFE_REAL_DOTNET_PATH = $realDotnet.Path
    $env:PATH = "$interceptorDir;$env:PATH"

    $syftExe = Join-Path $packagesBin 'syft.exe'
    $syftLinux = Join-Path $packagesBin 'syft'
    if (Test-Path -LiteralPath $syftExe) {
        $env:RUNSAFE_SYFT_BIN = $syftExe
    } elseif (Test-Path -LiteralPath $syftLinux) {
        $env:RUNSAFE_SYFT_BIN = $syftLinux
    }

    Write-Host '[RunSafe Security] .NET CLI interceptor installed and active'
    Write-Host "[RunSafe Security] .NET -> $(Get-Command dotnet | Select-Object -First 1 -ExpandProperty Path)"
}

Install-RunSafeDotnetInterceptorWindows
