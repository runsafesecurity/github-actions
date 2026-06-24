# Gremlin cleanup for dotnet SBOM upload on Windows (mirrors cleanup_script_dotnet bash).

$ErrorActionPreference = 'Continue'

function Encode-RunSafePathSegment {
    param([string]$Value)
    $builder = New-Object System.Text.StringBuilder
    foreach ($byte in [System.Text.Encoding]::UTF8.GetBytes($Value)) {
        if ($byte -ge 33 -and $byte -le 126) {
            $character = [char]$byte
            if ($character -cmatch '^[A-Za-z0-9._~-]$') {
                [void]$builder.Append($character)
                continue
            }
        }
        [void]$builder.AppendFormat('%{0:X2}', $byte)
    }
    return $builder.ToString()
}

if ($env:RUNSAFE_DISABLED) {
    Write-Host '[RunSafe Security] RunSafe protections disabled for this job'
    exit 0
}

if (-not $env:RUNSAFE_IDENTIFY_ENABLED) {
    Write-Host '[RunSafe Security] RunSafe .NET cleanup skipped for this job. Are you sure that Identify is enabled for this project?'
    Write-Host '[RunSafe Security] If that does not resolve the issue, please contact support@runsafesecurity.com.'
    exit 0
}

Write-Host '[RunSafe Security] Generating SBOMs for .NET projects...'
$env:RUNSAFE_ROOT_PATH = $env:GITHUB_WORKSPACE

$captureFile = if ($env:RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE) {
    $env:RUNSAFE_DOTNET_PROJECTS_CAPTURE_FILE
} else {
    Join-Path $env:GITHUB_WORKSPACE ".dotnet_projects_captured\${env:GITHUB_RUN_ID}_scan_roots.txt"
}

if (-not (Test-Path -LiteralPath $captureFile) -or (Get-Item -LiteralPath $captureFile).Length -eq 0) {
    Write-Host '[RunSafe Security] No .NET project capture file found or file is empty (RunSafe .NET interceptor may not have been active or no .NET commands were run).'
    Write-Host '[RunSafe Security] If that is unexpected, please contact support@runsafesecurity.com.'
    exit 0
}

Write-Host '[RunSafe Security] Processing captured .NET project paths for SBOM generation...'

$uniqueLines = @(Get-Content -LiteralPath $captureFile | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } | Sort-Object -Unique)
Set-Content -LiteralPath $captureFile -Value $uniqueLines -Encoding utf8

if (-not $env:RUNSAFE_ORG_ID) {
    Write-Host '[RunSafe Security] Warning: RUNSAFE_ORG_ID is not set, skipping .NET SBOM upload (setup may have failed or runsafe.env not loaded).'
    exit 0
}

$packagesBin = Join-Path $env:GITHUB_WORKSPACE 'RUNSAFE_SBOM_PACKAGES\bin'
if (-not $env:RUNSAFE_SYFT_BIN) {
    $syftExe = Join-Path $packagesBin 'syft.exe'
    if (Test-Path -LiteralPath $syftExe) {
        $env:RUNSAFE_SYFT_BIN = $syftExe
    }
}

if (-not $env:RUNSAFE_SYFT_BIN -or -not (Test-Path -LiteralPath $env:RUNSAFE_SYFT_BIN)) {
    Write-Host '[RunSafe Security] Warning: syft not found (RUNSAFE_SYFT_BIN / packages bin), skipping .NET SBOM generation and upload'
    exit 0
}

if (-not (Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    Write-Host '[RunSafe Security] Warning: curl.exe not found, skipping .NET SBOM generation and upload'
    exit 0
}

$outputDir = Join-Path $env:GITHUB_WORKSPACE '.dotnet_projects_captured'
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

foreach ($line in Get-Content -LiteralPath $captureFile) {
    $scanRoot = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($scanRoot)) {
        continue
    }
    if ($scanRoot.StartsWith('#')) {
        continue
    }

    $normalizedRoot = $scanRoot -replace '/', [System.IO.Path]::DirectorySeparatorChar

    $isAbsoluteWindows = $normalizedRoot.Length -ge 2 -and $normalizedRoot[1] -eq ':'
    $isAbsoluteUnix = $normalizedRoot.StartsWith('\') -or ($normalizedRoot.StartsWith('/') -and -not $isAbsoluteWindows)

    if ($isAbsoluteUnix -or $isAbsoluteWindows) {
        $runsafeScanPath = $normalizedRoot
        $runsafeScanFilePath = $normalizedRoot
        $projectRoot = $env:GITHUB_WORKSPACE.TrimEnd('\', '/')
        if ($normalizedRoot.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $runsafeScanFilePath = $normalizedRoot.Substring($projectRoot.Length).TrimStart('\', '/')
        }
    } else {
        $runsafeScanPath = Join-Path $env:GITHUB_WORKSPACE $normalizedRoot
        $runsafeScanFilePath = $normalizedRoot -replace '\\', '/'
    }

    $projectDirComparable = $env:GITHUB_WORKSPACE.TrimEnd('\', '/')
    if (($runsafeScanFilePath -replace '\\', '/') -eq ($projectDirComparable -replace '\\', '/')) {
        $runsafeScanFilePath = '.'
    }

    if (Test-Path -LiteralPath $runsafeScanPath -PathType Leaf) {
        $runsafeSyftTarget = Split-Path -Parent $runsafeScanPath
    } else {
        $runsafeSyftTarget = $runsafeScanPath
    }

    if (-not (Test-Path -LiteralPath $runsafeSyftTarget)) {
        Write-Host "[RunSafe Security] Warning: Skipping missing .NET scan root: $scanRoot"
        continue
    }

    Write-Host "[RunSafe Security] Generating SBOM for .NET scan root: $runsafeScanFilePath"
    $safeName = ($runsafeScanFilePath -replace '[^A-Za-z0-9._-]', '-')
    $sbomFile = Join-Path $outputDir "sbom-$safeName.cdx.json"

    & $env:RUNSAFE_SYFT_BIN @($runsafeSyftTarget, '--enrich', 'all', '-o', "cyclonedx-json=$sbomFile") 2>$null
    $syftExitCode = $LASTEXITCODE

    if ($syftExitCode -ne 0) {
        Write-Host "[RunSafe Security] Warning: Failed to generate SBOM for $runsafeScanFilePath"
        continue
    }

    Write-Host "[RunSafe Security] Successfully generated SBOM for $runsafeScanFilePath"

    $startSbomUrl = "$($env:RUNSAFE_SBOM_SERVER)/api/organizations/$($env:RUNSAFE_ORG_ID)/audits/$($env:RUNSAFE_DOTNET_AUDIT_ID)/start-sbom"
    # Do not use curl.exe `-d ''` here: PowerShell often passes it incorrectly so curl treats the URL as --data (empty stdout + --fail). POST with no body matches bash `curl ... -d ""`.
    $sbomIdResponse = & curl.exe @(
        '--fail', '-s', '-L', '-X', 'POST',
        '-H', "x-runsafe-license-key: $($env:RUNSAFE_LICENSE_KEY)",
        $startSbomUrl
    ) 2>$null

    if (-not $sbomIdResponse) {
        Write-Host "[RunSafe Security] Warning: Could not obtain SBOM ID from start-sbom for $runsafeScanFilePath (empty response; curl may have failed). Skipping upload for this path. Please review the RunSafe Platform Setup step for any errors. Contact support@runsafesecurity.com if you need assistance."
        continue
    }

    $tempSbomId = ($sbomIdResponse.Trim() -replace '^\uFEFF', '').Trim().Trim('"')
    $hash = (Get-FileHash -LiteralPath $sbomFile -Algorithm SHA256).Hash.ToLowerInvariant()
    $encodedPath = Encode-RunSafePathSegment -Value $runsafeScanFilePath

    $uploadUrl = "$($env:RUNSAFE_SBOM_SERVER)/api/organizations/$($env:RUNSAFE_ORG_ID)/audits/$($env:RUNSAFE_DOTNET_AUDIT_ID)/sboms/$tempSbomId" +
        "?hash=$hash&status=complete&filePath=$encodedPath"

    # curl -v writes diagnostics to stderr; merge to stdout so GitHub shows it in the job log.
    & curl.exe --fail -s -L -X PATCH `
        -H "x-runsafe-license-key: $($env:RUNSAFE_LICENSE_KEY)" `
        -H 'Content-Type: application/octet-stream' `
        --data-binary "@$sbomFile" `
        -o NUL `
        $uploadUrl 2>$null
    $patchUploadExitCode = $LASTEXITCODE

    if ($patchUploadExitCode -eq 0) {
        Write-Host "[RunSafe Security] Successfully uploaded SBOM for $runsafeScanFilePath to $($env:RUNSAFE_SBOM_SERVER)"
    } else {
        Write-Host "[RunSafe Security] Warning: Failed to upload SBOM for $runsafeScanFilePath (curl exit code: $patchUploadExitCode)"
    }

    Remove-Item -LiteralPath $sbomFile -Force -ErrorAction SilentlyContinue
}

Write-Host '[RunSafe Security] Finished processing .NET projects for SBOM generation'

$finalizeUrl = "$($env:RUNSAFE_SBOM_SERVER)/api/organizations/$($env:RUNSAFE_ORG_ID)/audits/$($env:RUNSAFE_DOTNET_AUDIT_ID)/finalize"
& curl.exe --fail -sS -L -X POST `
    -H "x-runsafe-license-key: $($env:RUNSAFE_LICENSE_KEY)" `
    -H 'Accept: application/json' `
    -H 'Content-Type: application/json' `
    -H 'Content-Length: 0' `
    $finalizeUrl -o NUL 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host '[RunSafe Security] Warning: Failed to finalize .NET audit (finalize API returned an error). Please contact support@runsafesecurity.com.'
}
