$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$appRoot = Join-Path $repositoryRoot 'apps\endless_app'
$releaseRoot = Join-Path $appRoot 'build\windows\x64\runner\Release'
$nativeRoot = Join-Path $repositoryRoot 'build\native'
$nativeLibrary = Join-Path $nativeRoot 'isar.dll'
$bootstrapDatabase = Join-Path $nativeRoot 'bootstrap-database'
$distributionRoot = Join-Path $repositoryRoot 'dist\endless-windows-x64'

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock] $Command,
        [Parameter(Mandatory = $true)]
        [string] $Description
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Description failed with exit code $LASTEXITCODE."
    }
}

Push-Location $repositoryRoot
try {
    Invoke-Checked { dart pub get } 'Dependency resolution'
    Push-Location $appRoot
    try {
        Invoke-Checked {
            flutter build windows --release
        } 'Flutter Windows build'
    }
    finally {
        Pop-Location
    }

    New-Item -ItemType Directory -Path $nativeRoot -Force | Out-Null
    Invoke-Checked {
        dart run packages\persistence_isar\tool\bootstrap_native.dart `
            $nativeLibrary $bootstrapDatabase
    } 'Isar native library bootstrap'
    Invoke-Checked {
        dart compile exe apps\locald\bin\locald.dart `
            -o (Join-Path $releaseRoot 'locald.exe')
    } 'locald compilation'
    Invoke-Checked {
        dart compile exe apps\endless_cli\bin\endless_cli.dart `
            -o (Join-Path $releaseRoot 'endless.exe')
    } 'CLI compilation'

    Copy-Item -LiteralPath $nativeLibrary `
        -Destination (Join-Path $releaseRoot 'isar.dll') -Force
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'packaging\version.json') `
        -Destination (Join-Path $releaseRoot 'version.json') -Force

    $resolvedDistribution = [System.IO.Path]::GetFullPath($distributionRoot)
    $resolvedDistParent = [System.IO.Path]::GetFullPath(
        (Join-Path $repositoryRoot 'dist')
    )
    if (-not $resolvedDistribution.StartsWith(
        "$resolvedDistParent$([System.IO.Path]::DirectorySeparatorChar)",
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Unsafe distribution path: $resolvedDistribution"
    }
    if (Test-Path -LiteralPath $resolvedDistribution) {
        Remove-Item -LiteralPath $resolvedDistribution -Recurse -Force
    }
    New-Item -ItemType Directory -Path $resolvedDistribution -Force |
        Out-Null
    Copy-Item -Path (Join-Path $releaseRoot '*') `
        -Destination $resolvedDistribution -Recurse -Force

    Write-Output "Windows bundle: $resolvedDistribution"
}
finally {
    Pop-Location
}
