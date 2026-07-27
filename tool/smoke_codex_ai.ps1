$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

Push-Location $repositoryRoot
try {
    dart run packages\codex_app_server\tool\smoke.dart
    if ($LASTEXITCODE -ne 0) {
        throw "Codex AI smoke failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
