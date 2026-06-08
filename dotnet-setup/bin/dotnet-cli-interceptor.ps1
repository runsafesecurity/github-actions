# dotnet CLI interceptor — captures project/solution paths for SBOM scan roots (mirrors dotnet-cli-interceptor.sh).

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArguments
)

$captureRelative = if ($env:RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE) {
    $env:RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE
} else {
    Join-Path $env:GITHUB_WORKSPACE ".dotnet_projects_captured\${env:GITHUB_RUN_ID}_scan_roots.txt"
}

$null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $captureRelative)

function Add-RunSafeScanRoot {
    param([string]$ScanRoot)

    if ([string]::IsNullOrWhiteSpace($ScanRoot)) {
        return
    }
    if ($ScanRoot.StartsWith('-')) {
        return
    }

    if ($ScanRoot -eq '.') {
        $resolved = if ($env:GITHUB_WORKSPACE) { $env:GITHUB_WORKSPACE } else { (Get-Location).Path }
        Add-Content -LiteralPath $captureRelative -Value $resolved -Encoding utf8
        return
    }

    Add-Content -LiteralPath $captureRelative -Value $ScanRoot -Encoding utf8
}

function Get-RunSafeRealDotnetPath {
    if ($env:RUNSAFE_REAL_DOTNET_PATH -and (Test-Path -LiteralPath $env:RUNSAFE_REAL_DOTNET_PATH)) {
        return $env:RUNSAFE_REAL_DOTNET_PATH
    }

    $excludeSegment = '.runsafe_dotnet_interceptor'
    $candidates = Get-Command dotnet -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -and ($_.Path -notmatch [regex]::Escape($excludeSegment)) }

    if ($candidates) {
        return ($candidates | Select-Object -First 1).Path
    }

    $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
    $programFilesX86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    foreach ($candidatePath in @(
            (Join-Path $programFiles 'dotnet\dotnet.exe'),
            (Join-Path $programFilesX86 'dotnet\dotnet.exe'))) {
        if ($candidatePath -and (Test-Path -LiteralPath $candidatePath)) {
            return $candidatePath
        }
    }

    return $null
}

$realDotnetPath = Get-RunSafeRealDotnetPath
if (-not $realDotnetPath) {
    Write-Error '[RunSafe Security] Cannot find real dotnet binary.'
    exit 1
}

$verbs = @('build', 'clean', 'msbuild', 'pack', 'publish', 'restore', 'test')
$firstArg = if ($CliArguments.Count -gt 0) { $CliArguments[0] } else { $null }

if ($firstArg -in $verbs) {
    $remainingAfterVerb = if ($CliArguments.Count -gt 1) { $CliArguments[1..($CliArguments.Count - 1)] } else { @() }
    $capturedAny = $false
    foreach ($argument in $remainingAfterVerb) {
        if ($argument -match '\.(csproj|fsproj|vbproj|sln|slnx|slnf)$') {
            Add-RunSafeScanRoot -ScanRoot $argument
            $capturedAny = $true
        }
    }
    if (-not $capturedAny) {
        Add-RunSafeScanRoot -ScanRoot '.'
    }
}

& $realDotnetPath @CliArguments
exit $LASTEXITCODE
