$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

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
    Invoke-Checked {
        dart format --output=none --set-exit-if-changed .
    } 'Formatting check'
    Invoke-Checked { flutter analyze } 'Static analysis'
    Invoke-Checked {
        dart run tool\check_architecture.dart
    } 'Architecture check'

    foreach ($package in @(
        'packages\client_domain',
        'packages\client_application',
        'packages\local_api',
        'packages\local_attachments',
        'packages\local_backup',
        'packages\platform_runtime'
    )) {
        Push-Location (Join-Path $repositoryRoot $package)
        try {
            Invoke-Checked { dart test } "Tests for $package"
        }
        finally {
            Pop-Location
        }
    }

    Push-Location (Join-Path $repositoryRoot 'packages\persistence_isar')
    try {
        Invoke-Checked { dart test -j 1 } 'Isar integration tests'
    }
    finally {
        Pop-Location
    }

    Push-Location (Join-Path $repositoryRoot 'apps\locald')
    try {
        Invoke-Checked { dart test -j 1 } 'locald integration tests'
    }
    finally {
        Pop-Location
    }

    Push-Location (Join-Path $repositoryRoot 'apps\endless_app')
    try {
        Invoke-Checked { flutter test } 'Flutter widget tests'
    }
    finally {
        Pop-Location
    }
}
finally {
    Pop-Location
}
